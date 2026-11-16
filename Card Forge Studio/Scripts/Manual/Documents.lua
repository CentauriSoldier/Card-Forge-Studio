--[[!
@fqxn CFS.Manual.Documents
@desc Reads game-owned manual documents and saves drafts using external-change checks and staged replacement. Does not parse or rewrite Markdown during ordinary source editing.
!]]

local wx		= require("wx");
local Documents	= {};

--[[!
@fqxn CFS.Manual.Documents.Functions.filename
@desc Validates a portable, flat Markdown filename. Adds .md when omitted. Refuses path separators, control characters, Windows device names and trailing dots/spaces. Does not silently alter the requested basename.
@param string sName Requested filename.
@return string sFile Validated filename with .md extension.
!]]
function Documents.filename(sName)
	local sStem;
	local sDevice;
	assert(type(sName) == "string" and #sName <= 128, "Use a filename of at most 128 characters.");
	sStem = sName:gsub("%.[mM][dD]$", "");
	assert(sStem:match("^[A-Za-z0-9][A-Za-z0-9 _.-]*$") and not sStem:find("..", 1, true) and not sStem:match("[ .]$"), "Use letters, numbers, spaces, hyphens, underscores or single dots; no folders or trailing spaces/dots.");
	sDevice = sStem:match("^[^.]+"):upper();
	assert(not ({CON = true, PRN = true, AUX = true, NUL = true})[sDevice] and not sDevice:match("^COM[1-9]$") and not sDevice:match("^LPT[1-9]$"), "That filename is reserved by the operating system.");
	return sStem..(sName:match("%.[mM][dD]$") or ".md");
end

--[[!
@fqxn CFS.Manual.Documents.Functions.read
@desc Reads a complete document as bytes, closing its handle before returning.
@param string pFile Existing document path selected by the native editor.
@return string sText Original file contents.
!]]
function Documents.read(pFile)
	local hFile	= assert(io.open(pFile, "rb"));
	local sText	= assert(hFile:read("a"));
	assert(hFile:close());
	return sText;
end

--[[!
@fqxn CFS.Manual.Documents.Functions.list
@desc Lists and sorts Markdown chapter filenames directly in the active manual's Content folder. Does not traverse outside the selected game.
@param string pManual Active game's prepared Manual folder.
@return table tNames Sorted Markdown filenames.
!]]
function Documents.list(pManual)
	local tNames	= {};
	local oDir		= wx.wxDir(pManual.."/Content");
	local bFound;
	local sName;
	assert(oDir:IsOpened(), "Cannot open this game's manual Content folder.");
	bFound, sName = oDir:GetFirst("", wx.wxDIR_FILES);
	while (bFound) do
		if (sName:lower():match("%.md$")) then tNames[#tNames + 1] = sName; end
		bFound, sName = oDir:GetNext();
	end
	oDir:delete();
	table.sort(tNames);
	return tNames;
end

--[[!
@fqxn CFS.Manual.Documents.Functions.order
@desc Resolves document-order stems to existing chapter filenames and appends unlisted chapters. Ignores stale entries without deleting files.
@param string pManual Active Manual directory.
@return table tNames Ordered chapter filenames.
@return string sOriginal Original order bytes for conflict checking.
!]]
function Documents.order(pManual)
	local sOriginal	= Documents.read(pManual.."/Content/_ORDER_.txt");
	local tFiles	= Documents.list(pManual);
	local tByStem	= {};
	local tUsed		= {};
	local tNames	= {};
	for _, sFile in ipairs(tFiles) do tByStem[sFile:sub(1, -4):lower()] = sFile; end
	for sLine in (sOriginal.."\n"):gmatch("([^\n]*)\n") do
		local sFile = tByStem[sLine:match("^%s*(.-)%s*$"):lower()];
		if (sFile and not tUsed[sFile]) then tNames[#tNames + 1] = sFile; tUsed[sFile] = true; end
	end
	for _, sFile in ipairs(tFiles) do
		if (not tUsed[sFile]) then tNames[#tNames + 1] = sFile; end
	end
	return tNames, sOriginal;
end

--[[!
@fqxn CFS.Manual.Documents.Functions.move
@desc Moves a chapter within a supplied order snapshot and immediately saves the order. Validates that the snapshot contains every current chapter exactly once before saving; external order edits are rejected by the save service.
@param string pManual Active Manual directory.
@param table tNames Snapshot of ordered filenames.
@param string sOriginal Original order bytes.
@param number nFrom One-based source position.
@param number nTo One-based destination position.
@return table tUpdated New ordered filenames.
@return string sSaved New saved order bytes.
!]]
function Documents.move(pManual, tNames, sOriginal, nFrom, nTo)
	local tFiles	= Documents.list(pManual);
	local tKnown	= {};
	local tUpdated	= {};
	local tLines	= {};
	local sNewline	= sOriginal:find("\r\n", 1, true) and "\r\n" or "\n";
	assert(#tFiles == #tNames, "The content file list changed. Reopen Document Order.");
	assert(nFrom >= 1 and nFrom <= #tNames and nTo >= 1 and nTo <= #tNames and nFrom % 1 == 0 and nTo % 1 == 0, "Invalid document position.");
	for _, sFile in ipairs(tFiles) do tKnown[sFile] = true; end
	for nIndex, sFile in ipairs(tNames) do
		assert(tKnown[sFile], "The content file list changed. Reopen Document Order.");
		tKnown[sFile] = nil;
		tUpdated[nIndex] = sFile;
	end
	table.insert(tUpdated, nTo, table.remove(tUpdated, nFrom));
	for nIndex, sFile in ipairs(tUpdated) do tLines[nIndex] = sFile:sub(1, -4); end
	return tUpdated, Documents.save(pManual.."/Content/_ORDER_.txt", sOriginal, table.concat(tLines, sNewline)..sNewline);
end

--[[!
@fqxn CFS.Manual.Documents.Functions.save
@desc Saves a draft only if the on-disk contents still equal its loaded original. Stages beside the target, preserves a uniquely named recovery copy, checks for external changes again, and replaces the target. A failed save retains its recovery copy. Returns the new original bytes after success.
@param string pFile Existing game-owned document path.
@param string sOriginal Bytes loaded before editing.
@param string sDraft New document contents.
@return string sSaved Saved bytes.
!]]
function Documents.save(pFile, sOriginal, sDraft)
	local oStage;
	local pStage;
	local oRecovery;
	local pRecovery;
	local hFile;
	local bOK;
	local sError;
	assert(Documents.read(pFile) == sOriginal, "This file changed outside the editor. Reopen it before saving.");
	if (sDraft == sOriginal) then return sOriginal; end
	oStage = wx.wxFile();
	pStage = wx.wxFileName.CreateTempFileName(pFile..".draft-", oStage);
	if (oStage:IsOpened()) then oStage:Close(); end
	oStage:delete();
	assert(pStage ~= "", "Cannot stage the manual document.");
	bOK, sError = xpcall(function()
		hFile = assert(io.open(pStage, "wb"));
		local bWritten, sWriteError = hFile:write(sDraft);
		local bClosed, sCloseError = hFile:close();
		assert(bWritten, sWriteError);
		assert(bClosed, sCloseError);
		assert(Documents.read(pFile) == sOriginal, "This file changed while saving. Original preserved.");
		oRecovery = wx.wxFile();
		pRecovery = wx.wxFileName.CreateTempFileName(pFile..".recovery-", oRecovery);
		if (oRecovery:IsOpened()) then oRecovery:Close(); end
		oRecovery:delete();
		assert(pRecovery ~= "" and wx.wxCopyFile(pFile, pRecovery, true), "Cannot preserve the original document.");
		assert(wx.wxRenameFile(pStage, pFile, true), "Cannot install the saved document.");
	end, debug.traceback);
	if (wx.wxFileExists(pStage)) then wx.wxRemoveFile(pStage); end
	if (not bOK) then
		error(tostring(sError)..(pRecovery and " Recovery copy: "..pRecovery or ""), 2);
	end
	if (pRecovery) then wx.wxRemoveFile(pRecovery); end
	return sDraft;
end

--[[!
@fqxn CFS.Manual.Documents.Private.Functions.updateOrder
@desc Replaces or removes complete filename stems in document order, preserving the existing newline convention. New files append to the current order. Does not reorder unrelated chapters.
@param string sOrder Current order text.
@param string|nil sOld Existing filename, including .md.
@param string|nil sNew New filename, including .md.
@return string sUpdated Updated order.
@vis private
!]]
local function updateOrder(sOrder, sOld, sNew)
	local sNewline	= sOrder:find("\r\n", 1, true) and "\r\n" or "\n";
	local sOldStem	= sOld and sOld:sub(1, -4):lower();
	local sNewStem	= sNew and sNew:sub(1, -4);
	local tLines	= {};
	local bMatched	= false;
	local bFinal	= sOrder:sub(-1) == "\n";
	local sNormalized = sOrder:gsub("\r\n", "\n");
	if (sNormalized:sub(-1) == "\n") then sNormalized = sNormalized:sub(1, -2); end
	for sLine in (sNormalized ~= "" and sNormalized.."\n" or ""):gmatch("([^\n]*)\n") do
		if (sOldStem and sLine:match("^%s*(.-)%s*$"):lower() == sOldStem) then
			bMatched = true;
			if (sNewStem) then tLines[#tLines + 1] = sNewStem; end
		else
			tLines[#tLines + 1] = sLine;
		end
	end
	if (sNewStem and not bMatched) then tLines[#tLines + 1] = sNewStem; bFinal = true; end
	return table.concat(tLines, sNewline)..(bFinal and #tLines > 0 and sNewline or "");
end

--[[!
@fqxn CFS.Manual.Documents.Functions.change
@desc Creates, renames or deletes one Markdown file and updates document order. Checks original chapter bytes before rename/delete, refuses existing targets, and rolls the chapter operation back if order saving fails. Deletion confirmation belongs to the UI. Case-only renames use a temporary holding path. Does not rewrite links inside chapter text.
@param string pManual Active Manual directory.
@param string sOperation create, rename or delete.
@param string sName Current filename, or new filename for create.
@param string|nil sNewName Requested new name for rename.
@param string|nil sOriginal Loaded bytes required for rename/delete.
@return string|nil sSelected Created or renamed filename; nil after delete.
!]]
function Documents.change(pManual, sOperation, sName, sNewName, sOriginal)
	local sFile		= Documents.filename(sName);
	local sNew		= sOperation == "rename" and Documents.filename(sNewName) or sOperation == "create" and sFile or nil;
	local pSource	= pManual.."/Content/"..sFile;
	local pTarget	= sNew and pManual.."/Content/"..sNew;
	local pOrder		= pManual.."/Content/_ORDER_.txt";
	local sOrder		= Documents.read(pOrder);
	local sUpdated;
	local oHolding;
	local pHolding;
	local hFile;
	local sCreated;
	local bOK;
	local sError;
	local bRestored;
	assert(sOperation == "create" or sOperation == "rename" or sOperation == "delete", "Unknown manual document operation.");
	if (sOperation == "rename" and sFile == sNew) then return sFile; end
	if (sOperation ~= "create") then
		assert(type(sOriginal) == "string" and Documents.read(pSource) == sOriginal, "The chapter changed outside this editor. Reopen it before renaming or deleting.");
	end
	if (pTarget and not (sOperation == "rename" and sFile:lower() == sNew:lower())) then
		assert(not wx.wxFileExists(pTarget) and not wx.wxDirExists(pTarget), "That filename already exists.");
		for _, sExisting in ipairs(Documents.list(pManual)) do
			assert(sExisting:lower() ~= sNew:lower(), "That filename already exists with different capitalization.");
		end
	end
	sUpdated = updateOrder(sOrder, sOperation ~= "create" and sFile or nil, sNew);
	oHolding = wx.wxFile();
	pHolding = wx.wxFileName.CreateTempFileName(pSource..".operation-", oHolding);
	if (oHolding:IsOpened()) then oHolding:Close(); end
	oHolding:delete();
	assert(pHolding ~= "", "Cannot prepare the chapter operation.");
	if (sOperation == "create") then
		sCreated = "<!-- section: "..sFile:sub(1, -4):lower():gsub("[^a-z0-9_-]", "-").."; source: 0 -->\n## "..sFile:sub(1, -4).."\n\n";
		hFile = assert(io.open(pHolding, "wb"));
		local bWritten, sWriteError = hFile:write(sCreated);
		local bClosed, sCloseError = hFile:close();
		if (not bWritten or not bClosed) then wx.wxRemoveFile(pHolding); error(sWriteError or sCloseError, 2); end
		assert(wx.wxRenameFile(pHolding, pTarget, false), "Cannot create the chapter; existing files were preserved.");
	else
		assert(wx.wxRemoveFile(pHolding), "Cannot prepare the chapter holding path.");
		assert(wx.wxRenameFile(pSource, pHolding, false), "Cannot move the original chapter to its holding path.");
		if (sOperation == "rename" and not wx.wxRenameFile(pHolding, pTarget, false)) then
			bRestored = wx.wxRenameFile(pHolding, pSource, false);
			error("Cannot rename chapter. "..(bRestored and "Original restored." or "Original retained at "..pHolding), 2);
		end
	end
	bOK, sError = pcall(Documents.save, pOrder, sOrder, sUpdated);
	if (not bOK) then
		if (sOperation == "create") then
			bRestored = Documents.read(pTarget) == sCreated and wx.wxRemoveFile(pTarget);
		else
			bRestored = wx.wxRenameFile(sOperation == "rename" and pTarget or pHolding, pSource, false);
		end
		error(tostring(sError)..(bRestored and " Chapter operation rolled back." or " Chapter rollback failed; inspect its source/target or holding path: "..pHolding), 2);
	end
	if (sOperation == "delete") then assert(wx.wxRemoveFile(pHolding), "Chapter removed from order; its recovery copy remains at "..pHolding); end
	return sNew;
end

return Documents;
