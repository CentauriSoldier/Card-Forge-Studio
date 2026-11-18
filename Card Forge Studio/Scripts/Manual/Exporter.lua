--[[!
@fqxn CFS.Manual.Exporter
@desc Stages Lua-generated manual HTML and game-owned assets before replacing only Web or PDF under the bound game's Exports/Manual folder. PDF is serialized by the Lua writer. Native previews retain an in-memory layout, not a browser profile.
!]]

local wx		= require("wx");
local Documents	= require("Manual.Documents");
local JSON		= require("Manual.Lib.dkjson");
local Exporter	= {};
local _tCSS = {"bootstrap.min.css", "intro-preview.css", "glossary.css", "Reader.css", "Components.css", "Print.css"};
local _tJS = {"glossary.js", "Reader.js", "bootstrap.bundle.min.js"};

--[[!
@fqxn CFS.Manual.Exporter.Private.Functions.absolute
@desc Normalizes a native path without changing the current working directory.
@param string pPath Native path.
@return string pAbsolute Absolute path with forward separators.
@vis private
!]]
local function absolute(pPath)
	local oPath	= wx.wxFileName(pPath);
	local sPath;
	assert(oPath:Normalize(wx.wxPATH_NORM_DOTS + wx.wxPATH_NORM_ABSOLUTE), "Cannot normalize the export path.");
	sPath = oPath:GetFullPath():gsub("\\", "/"):gsub("/+$", "");
	oPath:delete();
	return sPath;
end

--[[!
@fqxn CFS.Manual.Exporter.Private.Functions.write
@desc Writes a newly staged file and verifies its handle is closed.
@param string pFile Owned staging filename.
@param string sText Complete bytes.
@vis private
!]]
local function write(pFile, sText)
	local hFile = assert(io.open(pFile, "wb"));
	assert(hFile:write(sText));
	assert(hFile:close());
end

--[[!
@fqxn CFS.Manual.Exporter.Private.Functions.copy
@desc Copies an asset tree using native wxWidgets APIs. Directory enumeration does not follow links; symbolic-link entries are refused rather than traversed.
@param string pSource Existing asset folder.
@param string pTarget Owned new staging folder.
@param function|nil fProgress Reports asset progress.
@param function fCheck Checks cancellation and yields through the job scheduler.
@vis private
!]]
local function copy(pSource, pTarget, fProgress, fCheck)
	local oDir;
	local bFound;
	local sName;
	local pFrom;
	assert(wx.wxDirExists(pSource), "Missing export asset folder: "..pSource);
	assert(wx.wxDirExists(pTarget) or wx.wxMkdir(pTarget), "Cannot create staged asset folder.");
	oDir = wx.wxDir(pSource);
	assert(oDir:IsOpened(), "Cannot read export assets.");
	bFound, sName = oDir:GetFirst("", wx.wxDIR_FILES + wx.wxDIR_DIRS + wx.wxDIR_HIDDEN + wx.wxDIR_NO_FOLLOW);
	while (bFound) do
		pFrom = pSource.."/"..sName;
        if (fProgress) then fProgress("assets", "Copying asset: "..pFrom); end
        fCheck();
		-- wxFILE_EXISTS_SYMLINK is absent from this Lua binding; the documented
		-- wxWidgets value includes NO_FOLLOW and is used only for this test.
		assert(not wx.wxFileName.Exists(pFrom, 0x1004), "Linked export assets are not supported: "..pFrom);
		if (wx.wxDirExists(pFrom)) then copy(pFrom, pTarget.."/"..sName, fProgress, fCheck);
		else assert(wx.wxCopyFile(pFrom, pTarget.."/"..sName, false), "Cannot copy an export asset."); end
		bFound, sName = oDir:GetNext();
	end
	oDir:delete();
end

--[[!
@fqxn CFS.Manual.Exporter.Private.Functions.remove
@desc Deletes only an explicitly selected child of the normalized Exports/Manual root. Uses native recursive removal, never a shell or a browser-supplied path.
@param string pRoot Bound export root.
@param string pFolder Owned child folder.
@vis private
!]]
local function remove(pRoot, pFolder)
	local pChecked = absolute(pFolder);
	pRoot = absolute(pRoot);
	assert(pChecked:sub(1, #pRoot + 1) == pRoot.."/" and not pChecked:sub(#pRoot + 2):find("/", 1, true), "Refusing cleanup outside the manual export folder.");
	if (wx.wxDirExists(pChecked)) then
		-- wxPATH_RMDIR_RECURSIVE (0x0002) is not exported by this Lua binding.
		assert(wx.wxFileName.Rmdir(pChecked, 0x0002), "Cannot clean the owned export folder: "..pChecked);
	end
end

--[[!
@fqxn CFS.Manual.Exporter.Functions.run
@desc Stages Lua-generated Web output or a completed Lua PDF layout, then replaces
    only the selected published directory. No browser or subprocess is launched.
@param table tContext Bound export paths and cancellation/progress callbacks.
@param string sKind web or pdf.
@param string|table vDocument Web HTML or PDFLayout result.
@param table tSettings Saved export settings.
@param boolean|nil bPreview Retain a PDF layout without publishing a file.
@return table tResult Output path or in-memory preview, with status.
!]]
function Exporter.run(tContext, sKind, vDocument, tSettings, bPreview)
    local pRoot = absolute(tContext.exportRoot.."/Manual");
    local sType = sKind == "web" and "Web" or "PDF";
    local pOutput = pRoot.."/"..sType;
    local pStage, pPrevious, pUnique;
    local oTemporary;
    local bOK, sFailure;
    local bPrevious = false;
    local fCheck;
    local fBuild;

    assert(sKind == "web" or sKind == "pdf", "Unknown manual export type.");
    if (sKind == "pdf") then
        assert(type(vDocument) == "table" and vDocument.document and vDocument.pageCount > 0, "PDF export requires a completed Lua layout.");
        if (bPreview) then return {ok = true, layout = vDocument, message = "PDF preview ready: "..vDocument.pageCount.." pages, prepared entirely in Lua."}; end
    else
        assert(type(vDocument) == "string" and #vDocument > 0 and #vDocument <= 4000000, "Invalid or oversized rendered Web manual.");
    end
    fCheck = function()
        if (tContext.checkpoint) then tContext.checkpoint(); end
        assert(not tContext.cancelled, "Manual export cancelled; the previous export was preserved.");
    end;
    fCheck();
    assert(wx.wxDirExists(tContext.exportRoot), "The game's export folder is unavailable.");
    assert(wx.wxDirExists(pRoot) or wx.wxMkdir(pRoot), "Cannot create the manual export root.");
    oTemporary = wx.wxFile();
    pUnique = wx.wxFileName.CreateTempFileName(pRoot.."/."..sType.."-", oTemporary);
    if (oTemporary:IsOpened()) then oTemporary:Close(); end
    oTemporary:delete();
    assert(pUnique ~= "" and wx.wxRemoveFile(pUnique), "Cannot reserve an export staging name.");
    pStage, pPrevious = pUnique.."-stage", pUnique.."-previous";
    assert(wx.wxMkdir(pStage), "Cannot create the export staging folder.");
    fBuild = function()
        if (sKind == "pdf") then
            if (tContext.onProgress) then tContext.onProgress("writing", "Writing "..vDocument.pageCount.." PDF pages with embedded fonts and artwork."); end
            fCheck();
            vDocument.document.save(pStage.."/Manual.pdf", fCheck, tContext.onProgress);
            return;
        end
        if (tContext.onProgress) then tContext.onProgress("assets", "Copying saved manual styles, scripts and artwork for Web export."); end
        assert(wx.wxMkdir(pStage.."/css"), "Cannot create export CSS folder.");
        assert(wx.wxMkdir(pStage.."/js"), "Cannot create export script folder.");
        assert(wx.wxMkdir(pStage.."/images"), "Cannot create export artwork folder.");
        for _, sName in ipairs(_tCSS) do
            if (tContext.onProgress) then tContext.onProgress("assets", "Copying stylesheet: "..sName); end
            fCheck();
            assert(wx.wxCopyFile(_Scripts.."/Manual/Web/css/"..sName, pStage.."/css/"..sName, false), "Cannot copy shared manual CSS.");
        end
        for _, sName in ipairs(_tJS) do
            if (tContext.onProgress) then tContext.onProgress("assets", "Copying script: "..sName); end
            fCheck();
            assert(wx.wxCopyFile(_Scripts.."/Manual/Web/js/"..sName, pStage.."/js/"..sName, false), "Cannot copy Web reader script: "..sName);
        end
        copy(tContext.manualRoot.."/Images", pStage.."/content-images", tContext.onProgress, fCheck);
        assert(wx.wxMkdir(pStage.."/fonts"), "Cannot create export font folder.");
        for _, tFont in ipairs(tContext.webFonts or {}) do
            if (tContext.onProgress) then tContext.onProgress("assets", "Packaging font: "..tFont.source); end
            fCheck();
            assert(wx.wxCopyFile(tFont.source, pStage.."/fonts/"..tFont.name, false), "Cannot package font: "..tFont.source);
        end
        write(pStage.."/css/packaged-fonts.css", tContext.webFontCSS or "");
        if (tContext.onProgress) then tContext.onProgress("writing", "Writing generated styles, index.html and export settings."); end
        fCheck();
        write(pStage.."/css/appearance.css", tContext.appearanceCSS or "");
        write(pStage.."/css/font-styles.css", tContext.gameCSS or Documents.read(tContext.manualRoot.."/Styles/font-styles.css"));
        write(pStage.."/index.html", vDocument);
        write(pStage.."/settings.json", JSON.encode(tSettings, {indent = true}));
    end;
    bOK, sFailure = pcall(function()
        fBuild();
        fCheck();
        if (tContext.onProgress) then tContext.onProgress("publishing", "Installing the verified "..sType.." export."); end
        fCheck();
    end);
    if (not bOK) then
        local bRemoved, sRemoveError = pcall(remove, pRoot, pStage);

        if (not bRemoved) then sFailure = tostring(sFailure).." Temporary files remain at "..pStage..": "..tostring(sRemoveError); end
        error(sFailure, 2);
    end
    if (wx.wxDirExists(pOutput)) then
        assert(wx.wxRenameFile(pOutput, pPrevious, false), "Cannot hold the previous export; staged output remains at "..pStage);
        bPrevious = true;
    end
    if (not wx.wxRenameFile(pStage, pOutput, false)) then
        if (bPrevious) then assert(wx.wxRenameFile(pPrevious, pOutput, false), "Cannot restore the previous export from "..pPrevious); end
        error("Cannot install the export; staged output remains at "..pStage, 2);
    end
    if (bPrevious) then remove(pRoot, pPrevious); end
    if (tContext.onProgress) then tContext.onProgress("done", sType.." export saved to "..pOutput); end
    return {ok = true, path = pOutput..(sKind == "pdf" and "/Manual.pdf" or "/index.html"), layout = sKind == "pdf" and vDocument or nil,
        message = sType.." export saved to "..pOutput};
end

--[[!
@fqxn CFS.Manual.Exporter.Functions.discard
@desc Releases an in-memory native preview; accepts legacy owned staging folders
    only for cleanup. Published Web/PDF folders cannot be removed here.
@param table tContext Bound export paths.
@param table tPreview Preview result.
!]]
function Exporter.discard(tContext, tPreview)
    if (tPreview.layout and tPreview.layout.dispose) then tPreview.layout.dispose(); end
    if (tPreview.stage) then
        local pRoot = absolute(tContext.exportRoot.."/Manual");
        local pStage = absolute(tPreview.stage);

        assert(pStage:sub(#pRoot + 2):match("^%.PD[^/]+%-stage$"), "Refusing cleanup of a non-preview folder.");
        remove(pRoot, pStage);
    end
end

--[[!
@fqxn CFS.Manual.Exporter.Functions.preflight
@desc Checks required website assets and CSS-local references before staging. Returns a validator for output-relative content links and images. External URLs are not fetched.
@param table tData Saved manual snapshot.
@param table tIssues Blocking issues accumulated by the coordinator.
@return function fAsset Local reference validator.
!]]
function Exporter.preflight(tData, tIssues)
    local tContext = tData.context;
    local tGenerated = {['index.html'] = true, ['settings.json'] = true,
        ['css/appearance.css'] = true, ['css/font-styles.css'] = true};
    local tSources, tChecked = {}, {};
    for _, sName in ipairs(_tCSS) do tSources['css/'..sName] = _Scripts..'/Manual/Web/css/'..sName; end
    for _, sName in ipairs(_tJS) do tSources['js/'..sName] = _Scripts..'/Manual/Web/js/'..sName; end
    local function asset(sURL, sOwner, sBase)
        if (sURL:match('^[%a][%w+.-]*:') or sURL:sub(1, 2) == '//') then return; end
        if (sURL == '' or sURL:sub(1, 1) == '#') then return; end
        local sPath = sURL:match('^[^?#]*'):gsub('%%(%x%x)', function(sHex) return string.char(tonumber(sHex, 16)); end);
        local tParts = {};
        if (sPath:find('[%z\1-\31]') or sPath:find('\\', 1, true) or sPath:sub(1, 1) == '/') then
            tIssues[#tIssues + 1] = sOwner..': invalid local URL '..sURL; return;
        end
        for sPart in ((sBase or '')..sPath):gmatch('[^/]+') do
            if (sPart == '..') then
                if (#tParts == 0) then tIssues[#tIssues + 1] = sOwner..': URL leaves the website: '..sURL; return; end
                tParts[#tParts] = nil;
            elseif (sPart ~= '.') then tParts[#tParts + 1] = sPart; end
        end
        sPath = table.concat(tParts, '/');
        if (tGenerated[sPath]) then return; end
        local pSource = tSources[sPath];
        if (sPath:sub(1, 15) == 'content-images/') then pSource = tContext.manualRoot..'/Images/'..sPath:sub(16);
        elseif (sPath:sub(1, 18) == 'images/components/') then pSource = _Scripts..'/Manual/Web/'..sPath; end
        if (not pSource or not wx.wxFileExists(pSource)) then
            tIssues[#tIssues + 1] = sOwner..': missing exported asset '..sURL;
        end
    end
    for sTarget, pSource in pairs(tSources) do
        if (tContext.checkpoint) then tContext.checkpoint(); end
        local bOK, sText = pcall(Documents.read, pSource);
        if (not bOK) then tIssues[#tIssues + 1] = 'Missing or unreadable website asset: '..pSource;
        elseif (sTarget:sub(-4) == '.css') then
            tChecked[#tChecked + 1] = {name = sTarget, text = sText};
        end
    end
    tChecked[#tChecked + 1] = {name = 'css/appearance.css', text = tData.appearanceCSS or ''};
    tChecked[#tChecked + 1] = {name = 'css/font-styles.css', text = tData.gameCSS};
    for _, tCSS in ipairs(tChecked) do
        for sURL in tCSS.text:gsub('/%*.-%*/', ''):gmatch('url%s*%((.-)%)') do
            sURL = sURL:match('^%s*(.-)%s*$');
            if (sURL:sub(1, 1) == '"' or sURL:sub(1, 1) == "'") then sURL = sURL:sub(2, -2); end
            asset(sURL, tCSS.name, 'css/');
        end
    end
    for _, pRoot in ipairs({tContext.manualRoot..'/Images'}) do
        if (not wx.wxDirExists(pRoot)) then tIssues[#tIssues + 1] = 'Missing asset directory: '..pRoot; end
    end
    return asset;
end

return Exporter;
