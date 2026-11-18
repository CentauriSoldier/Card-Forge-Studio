--[[!
@fqxn CFS.Manual.Services
@desc Game-bound filesystem services for the original web editor. Browser requests name logical manual files, never arbitrary system paths. Snapshot versions retain exact original bytes for conflict-aware saves.
!]]

local wx		= require("wx");
local Documents	= require("Manual.Documents");
local Services	= {};

--[[!
@fqxn CFS.Manual.Services.Functions.create
@desc Creates isolated services for one active-game window. Existing document services retain staged saves, portable filenames, file management and order maintenance. Does not change the active Studio game or card set.
@param table tContext gameName, gameRoot, manualRoot and exportRoot.
@return table tService snapshot, request and context.
!]]
function Services.create(tContext)
	local tService	= {context = tContext};
	local tVersions	= {};
	local nVersion	= 0;
	local tFixed	= {
		["Content/_ORDER_.txt"] = true,
		["Config/glossary-alternatives.json"] = true,
		["Config/glossary-settings.json"] = true,
		["Config/editor-settings.json"] = true,
		["Styles/font-styles.css"] = true,
	};

	--[[!
	@fqxn CFS.Manual.Services.Private.Functions.fPath
	@desc Resolves only whitelisted configuration/style files or one flat Markdown filename under the bound game manual. Rejects traversal and alternate path separators.
	@param string sRelative Logical manual-relative filename.
	@return string pFile Bound native filename.
	@vis private
	!]]
	local function fPath(sRelative)
		local sChapter;
		assert(type(sRelative) == "string", "A logical manual filename is required.");
		if (not tFixed[sRelative]) then
			sChapter = sRelative:match("^Content/([^/\\]+)$");
			assert(sChapter and Documents.filename(sChapter) == sChapter, "File is outside the manual editor's supported files.");
		end
		return tContext.manualRoot.."/"..sRelative;
	end

	--[[!
	@fqxn CFS.Manual.Services.Private.Functions.fRead
	@desc Reads a supported existing file and assigns a session version only when its exact bytes change.
	@param string sRelative Logical manual-relative filename.
	@return table tRecord Text and version.
	@vis private
	!]]
	local function fRead(sRelative)
		local sText	= Documents.read(fPath(sRelative));
		local tOld	= tVersions[sRelative];
		if (not tOld or tOld.text ~= sText) then
			nVersion = nVersion + 1;
			tVersions[sRelative] = {text = sText, version = "manual-"..nVersion};
		end
		return {text = sText, version = tVersions[sRelative].version};
	end

	--[[!
	@fqxn CFS.Manual.Services.Private.Functions.fGenerateFonts
	@desc Uses the current Studio font parser to update generated CSS when game style inputs change. Copies a missing output placeholder from the application template, never creates a font collection.
	@vis private
	!]]
	local function fGenerateFonts()
		local pFile		= fPath("Styles/font-styles.css");
		local sINI		= Documents.read(tContext.gameRoot.."/Styles.ini");
		local sCFG		= Documents.read(tContext.gameRoot.."/Scripts/CFG.lua");
		local sSignature	= sINI.."\0"..sCFG;
		local sOld;
		local sCSS;
		local tWarnings;
		if (tService.fontSignature == sSignature and wx.wxFileExists(pFile) and Documents.read(pFile) == tService.fontCSS) then return; end
		if (not wx.wxFileExists(pFile)) then assert(wx.wxCopyFile(_Scripts.."/../Docs/Templates/Manual/Styles/font-styles.css", pFile, false), "Cannot install the generated font CSS placeholder."); end
		sOld = Documents.read(pFile);
		sCSS, tWarnings = require("Manual.FontCSS").generate(tContext.gameRoot, sOld);
		assert(Documents.read(tContext.gameRoot.."/Scripts/CFG.lua") == sCFG, "CFG.lua changed during generation; try again.");
		Documents.save(pFile, sOld, sCSS);
		tService.fontSignature, tService.fontWarnings, tService.fontCSS = sSignature, tWarnings, sCSS;
	end

	--[[!
	@fqxn CFS.Manual.Services.Instance.snapshot
	@desc Reads current chapters, order, glossary configuration and generated game styles. Generated game CSS is optional for a newly created game. Copies values into a transport object rather than exposing service version storage.
	@param boolean|nil bDelta Return changed versions and removed paths after a save. All source bytes are still checked for external edits.
	@return table tSnapshot Bound context and logical files, or a save delta.
	!]]
	function tService.snapshot(bDelta)
        local tPrevious = {};
        if (bDelta) then for sName, tRecord in pairs(tVersions) do tPrevious[sName] = tRecord.version; end end
		local tFiles	= {};
		local tNames	= Documents.list(tContext.manualRoot);
		if (CFS and CFS.FontStyle) then fGenerateFonts(); end
		for _, sName in ipairs(tNames) do tFiles["Content/"..sName] = fRead("Content/"..sName); end
		for sRelative in pairs(tFixed) do
			if (wx.wxFileExists(fPath(sRelative))) then tFiles[sRelative] = fRead(sRelative); end
		end
        local sAppearance = require("Manual.Appearance").css(tContext.manualRoot, ".manual-appearance", tContext.manualURL:gsub("/$", "").."/Images/", nil, tService.fontCSS);
        local tSnapshot = {appearanceCSS = sAppearance, context = tContext, files = tFiles, fontCurrent = tService.fontSignature ~= nil, fontWarnings = tService.fontWarnings or {}};
        if (bDelta) then
            tSnapshot.context = nil; tSnapshot.removed = {};
            for sName in pairs(tPrevious) do
                if (not tFiles[sName]) then tSnapshot.removed[#tSnapshot.removed + 1] = sName; tVersions[sName] = nil; end
            end
            for sName, tRecord in pairs(tFiles) do if (tPrevious[sName] == tRecord.version) then tFiles[sName] = nil; end end
            if (tService.appearanceCSS == sAppearance) then tSnapshot.appearanceCSS = nil; end
        end
        tService.appearanceCSS = sAppearance;
        return tSnapshot;
	end

	--[[!
	@fqxn CFS.Manual.Services.Instance.request
	@desc Dispatches supported filesystem operations. Batch writes validate every version and original before the first mutation, then roll back completed writes if a later write fails. File-management requests also update order through Documents.change. Unsupported operations report errors rather than claiming success.
	@param table tRequest Action with operation-specific fields.
	@return table tResult Action result with a full snapshot for navigation or changed records for a successful write batch.
	!]]
	function tService.request(tRequest)
		local sAction	= tRequest.action;
		local tWrites	= {};
		local tDone		= {};
		local bOK;
		local sError;
		if (sAction == "draft-state") then tService.dirty = tRequest.dirty == true; return {ok = true}; end
		if (sAction == "editor-options") then
			return {ok = true, lineNumbers = INIFile.GetValue(FS.AppCFG, "ManualEditor", "LineNumbers") == "1"};
		end
		if (sAction == "snapshot") then return {ok = true, snapshot = tService.snapshot()}; end
		if (sAction == "documents") then
			local sRelative	= "Content/"..Documents.filename(tRequest.name);
			local tOld		= tVersions[sRelative];
			local sSelected;
			assert(tRequest.operation == "create" or (tOld and tOld.version == tRequest.version), "The chapter version changed. Reload before continuing.");
			sSelected = Documents.change(tContext.manualRoot, tRequest.operation, tRequest.name, tRequest.newName, tOld and tOld.text);
			if (tRequest.operation ~= "create") then tVersions[sRelative] = nil; end
			return {ok = true, selected = sSelected, snapshot = tService.snapshot()};
		end
		assert(sAction == "write-batch", "This editor operation has not been connected to Lua yet.");
		assert(type(tRequest.files) == "table" and #tRequest.files > 0, "No files were supplied for saving.");
		for _, tFile in ipairs(tRequest.files) do
			local pFile	= fPath(tFile.path);
			local tOld	= tVersions[tFile.path];
			assert(not tWrites[tFile.path], "The same file was supplied twice.");
			assert(type(tFile.text) == "string" and #tFile.text <= 4000000, "Invalid manual file contents.");
			assert(tOld and tOld.version == tFile.version and Documents.read(pFile) == tOld.text, "A manual file changed outside this editor. Your draft is preserved; reload before saving.");
			tWrites[tFile.path] = {path = pFile, old = tOld.text, text = tFile.text};
		end

		--[[!
		@fqxn CFS.Manual.Services.Private.Functions.fCommit
		@desc Applies preflighted file writes and records each successful replacement for rollback.
		@vis private
		!]]
		local function fCommit()
			for _, tFile in pairs(tWrites) do
				Documents.save(tFile.path, tFile.old, tFile.text);
				tDone[#tDone + 1] = tFile;
			end
		end
		bOK, sError = pcall(fCommit);
		if (not bOK) then
			for nIndex = #tDone, 1, -1 do
				local tFile = tDone[nIndex];
				local bRestored, sRestore = pcall(Documents.save, tFile.path, tFile.text, tFile.old);
				if (not bRestored) then sError = tostring(sError).." Rollback requires review: "..tostring(sRestore); end
			end
			error(sError, 2);
		end
		return {ok = true, delta = tService.snapshot(true)};
	end
	return tService;
end

return Services;
