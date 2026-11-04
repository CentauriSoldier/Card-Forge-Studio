local Archive      = require("ImportExport.Archive");
local ImportExport = {};
local nVersion     = 1;
local tCompatible  = {[1] = true};

--[[!
@fqxn CFS.Modules.ImportExport
@pulsarlua table ImportExport
@desc
<section aria-label="Project Packages overview">
<h2>Take your project with you</h2>
<p>Game packages carry the editable project and its card sets. Standalone card-set packages carry one collection plus a snapshot of the shared scripts, styles and artwork it needs, so it can be brought into another game.</p>
<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,260px),1fr));gap:1rem">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface)"><h3>Export saved work</h3><p>Save your data and source editors first. Game packages use <code>.cfsg</code>; card-set packages use <code>.cfscs</code>. Both are ZIP files with a versioned manifest, rather than finished artwork exports.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface)"><h3>Import without switching</h3><p>Studio checks a temporary copy, repairs missing required files from its starter templates, and asks before replacing an existing ID. Close an active matching project first. Imported projects remain unloaded until you choose them.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface)"><h3>Clear results</h3><p>Repairs and skipped items are listed in the Log. Previous files are retained in a backup on replacement. Defaults do not recover lost custom behavior or artwork. Lua syntax is checked without executing scripts; runtime behavior is checked when you subsequently load the project.</p></article>
</div>
<p>The shared package version is separate from your game version. Only explicitly supported versions can be imported. Extraction is limited to 2 GiB total, 512 MiB per file and fewer than 65,535 entries; linked files and unsafe paths are rejected.</p>
</section>
!]]

--[[!
@fqxn CFS.Modules.ImportExport.Private.Functions.read
@desc Reads a checked binary file.
@vis private
!]]
local function read(pFile)
    local hFile = assert(io.open(pFile, "rb")); local sText = assert(hFile:read("a")); assert(hFile:close()); return sText;
end

--[[!
@fqxn CFS.Modules.ImportExport.Private.Functions.write
@desc Writes checked staged contents.
@vis private
!]]
local function write(pFile, sText)
    assert(wx.wxFileName.Mkdir(wx.wxFileName(pFile):GetPath(), 511, wx.wxPATH_MKDIR_FULL));
    local hFile = assert(io.open(pFile, "wb")); assert(hFile:write(sText)); assert(hFile:close());
end

--[[!
@fqxn CFS.Modules.ImportExport.Private.Functions.stage
@desc Creates a uniquely owned temporary directory.
@vis private
!]]
local function stage()
    local pRoot = wx.wxFileName.GetTempDir().."/cfs-package-"..string.uuid(true);
    assert(wx.wxMkdir(pRoot), "Cannot create package staging directory."); return pRoot;
end

--[[!
@fqxn CFS.Modules.ImportExport.Private.Functions.walk
@desc Visits project files recursively without executing source.
@vis private
!]]
local function walk(pRoot, fFile)
    local oDir = wx.wxDir(pRoot); assert(oDir:IsOpened(), "Cannot read package folder.");
    local bFound, sName = oDir:GetFirst("", wx.wxDIR_FILES + wx.wxDIR_HIDDEN);
    while (bFound) do fFile(pRoot.."/"..sName, sName); bFound, sName = oDir:GetNext(); end
    local tDirs = {}; bFound, sName = oDir:GetFirst("", wx.wxDIR_DIRS + wx.wxDIR_HIDDEN);
    while (bFound) do tDirs[#tDirs + 1] = sName; bFound, sName = oDir:GetNext(); end
    oDir:delete(); for _, sDir in ipairs(tDirs) do walk(pRoot.."/"..sDir, fFile); end
end

--[[!
@fqxn CFS.Modules.ImportExport.Private.Functions.children
@desc Lists immediate directories in stable order.
@vis private
!]]
local function children(pRoot)
    local tNames = {}; local oDir = wx.wxDir(pRoot);
    if (oDir:IsOpened()) then
        local bFound, sName = oDir:GetFirst("", wx.wxDIR_DIRS);
        while (bFound) do tNames[#tNames + 1] = sName; bFound, sName = oDir:GetNext(); end
    end
    oDir:delete(); table.sort(tNames); return tNames;
end

--[[!
@fqxn CFS.Modules.ImportExport.Private.Functions.identity
@desc Validates a package UUID before it is used in a filesystem path.
@vis private
!]]
local function identity(sValue)
    assert(type(sValue) == "string" and sValue:isuuid(), "Invalid package identifier."); return sValue:upper();
end

--[[!
@fqxn CFS.Modules.ImportExport.Private.Functions.metadata
@desc Reads visible project metadata and finite positive card dimensions.
@vis private
!]]
local function metadata(pRoot, sKind)
    local pInfo = pRoot.."/Info.ini";
    local sName = INIFile.GetValue(pInfo, "SETTINGS", "Name");
    assert(type(sName) == "string" and sName:match("%S") and not sName:find("[%c]"), "Missing or invalid project name.");
    local tMeta = {name = sName};
    if (sKind == "CardSet") then
        tMeta.width = tonumber(INIFile.GetValue(pInfo, "SETTINGS", "CardWidth"));
        tMeta.height = tonumber(INIFile.GetValue(pInfo, "SETTINGS", "CardHeight"));
        FS.GetManifest(sKind, tMeta);
    end
    return tMeta;
end

--[[!
@fqxn CFS.Modules.ImportExport.Private.Functions.validate
@desc Repairs missing required files, checks metadata and Lua syntax without execution, and skips isolated unusable CSV rows with logged reasons.
@vis private
!]]
local function validate(pRoot, sKind, tMeta, tReport)
    local tManifest = FS.GetManifest(sKind, tMeta);
    for _, sFolder in ipairs(tManifest.folders) do
        assert(wx.wxFileName.Mkdir(pRoot.."/"..sFolder, 511, wx.wxPATH_MKDIR_FULL), "Cannot create required package folder.");
    end
    for sFile, sDefault in pairs(tManifest.files) do
        local pFile = pRoot.."/"..sFile;
        if (not wx.wxFileExists(pFile)) then
            write(pFile, sDefault);
            tReport[#tReport + 1] = "Repaired missing "..sKind.." file: "..sFile.." using starter defaults; original content was not recovered.";
        end
    end
    local tActual = metadata(pRoot, sKind);
    assert(tActual.name == tMeta.name, "Package name does not match project metadata.");
    if (sKind == "CardSet") then assert(tActual.width == tMeta.width and tActual.height == tMeta.height, "Package dimensions do not match metadata."); end
    walk(pRoot, function(pFile, sName)
        if (sName:lower():match("%.lua$")) then assert(load(read(pFile), "@"..sName, "t", {})); end
    end);
    if (sKind == "CardSet") then
        local tRows, tHeaders = FTCSV.parse(read(pRoot.."/Data.csv"), CSV_DELIMITER, {loadFromString = true});
        local tSeen, sNameHeader = {}, nil;
        for _, sHeader in ipairs(tHeaders) do
            assert(not tSeen[sHeader:upper()], "Duplicate CSV column."); tSeen[sHeader:upper()] = true;
            if (sHeader:upper() == "NAME") then sNameHeader = sHeader; end
        end
        assert(sNameHeader, "Card data requires a Name column.");
        local tCodes = {};
        for sColumn in read(pRoot.."/CodeColumns.txt"):gmatch("[^\r\n]+") do
            sColumn = sColumn:match("^%s*(.-)%s*$");
            if (sColumn ~= "") then
                local sActual;
                for _, sHeader in ipairs(tHeaders) do if (sHeader:upper() == sColumn:upper()) then sActual = sHeader; end end
                assert(sActual, "CodeColumns names an unknown CSV column."); tCodes[#tCodes + 1] = sActual;
            end
        end
        local tValid = {}; local bSkipped = false;
        for nRow, tRow in ipairs(tRows) do
            if (not tostring(tRow[sNameHeader] or ""):match("%S")) then
                -- The CSV library represents a header-only file as one empty row.
                if (#tRows ~= 1 or read(pRoot.."/Data.csv"):gsub("\r", ""):gsub("\n+$", "") ~= sNameHeader) then
                    tReport[#tReport + 1] = "Skipped card row "..nRow..": missing card name."; bSkipped = true;
                end
            else
                local sBadColumn;
                for _, sColumn in ipairs(tCodes) do
                    local sCell = tRow[sColumn] or "";
                    if (sCell ~= "") then
                        local bCode = pcall(function() assert(load(base64.dec(sCell), "Code cell", "t", {})); end);
                        if (not bCode) then sBadColumn = sColumn; break; end
                    end
                end
                if (sBadColumn) then
                    tReport[#tReport + 1] = "Skipped card row "..nRow..": invalid encoded Lua in column "..sBadColumn.."."; bSkipped = true;
                else tValid[#tValid + 1] = tRow; end
            end
        end
        if (bSkipped) then
            local function quote(sValue) return '"'..tostring(sValue or ""):gsub('"', '""')..'"'; end
            local tLines = {}; local tCells = {};
            for i, h in ipairs(tHeaders) do tCells[i] = quote(h); end; tLines[1] = table.concat(tCells, CSV_DELIMITER);
            for _, row in ipairs(tValid) do for i,h in ipairs(tHeaders) do tCells[i] = quote(row[h]); end; tLines[#tLines + 1] = table.concat(tCells, CSV_DELIMITER); end
            write(pRoot.."/Data.csv", table.concat(tLines, "\r\n").."\r\n");
        end
    end
end

--[[!
@fqxn CFS.Modules.ImportExport.Functions.GetVersion
@pulsarlua function ImportExport.GetVersion
@desc Returns the shared import/export format version and a fresh list of supported input versions. Both directions advance together when the package contract changes.
!]]
function ImportExport.GetVersion()
    local tVersions = {}; for n in pairs(tCompatible) do tVersions[#tVersions + 1] = n; end; table.sort(tVersions); return nVersion, tVersions;
end

--[[!
@fqxn CFS.Modules.ImportExport.Functions.Export_1
@pulsarlua function ImportExport.Export_1
@desc Exports editable version-1 Game or standalone CardSet packages, retaining IDs and bundling set dependencies. Existing output files are never overwritten.
@param string sKind Game or CardSet.
@param any oProject Project object.
@param string pArchive Destination archive.
!]]
function ImportExport.Export_1(sKind, oProject, pArchive)
    assert(sKind == "Game" or sKind == "CardSet", "Invalid package type.");
    assert(not wx.wxFileExists(pArchive) and not wx.wxDirExists(pArchive), "The export destination already exists.");
    local sUUID = identity(oProject.GetUUID());
    local sGameUUID = sKind == "Game" and sUUID or identity(oProject.GetGameUUID());
    local pSource = sKind == "Game" and FS.Game.GetRoot(sUUID) or FS.CardSet.GetRoot(sGameUUID, sUUID);
    local tMeta = metadata(pSource, sKind); local pStage = stage(); local pPayload = pStage.."/payload";
    Log.Note("Exporting "..sKind.." package: "..tMeta.name);
    local bOK, sError = xpcall(function()
        Archive.run("copy", pSource, pPayload);
        if (sKind == "Game") then
            for _, sSet in ipairs(children(pSource.."/CardSets")) do
                identity(sSet); Archive.run("copy", pSource.."/CardSets/"..sSet, pPayload.."/CardSets/"..sSet);
                local tSetMeta = metadata(pSource.."/CardSets/"..sSet, "CardSet");
                write(pStage.."/Sets/"..sSet..".ini", "[Metadata]\r\nName="..tSetMeta.name.."\r\nWidth="..tSetMeta.width.."\r\nHeight="..tSetMeta.height.."\r\n");
            end
        elseif (not wx.wxDirExists(pPayload.."/Dependencies")) then
            Archive.run("copy", FS.Game.GetRoot(sGameUUID), pPayload.."/Dependencies");
        end
        if (sKind == "CardSet") then
            -- Preserve game-relative references to this set's own assets without nesting its dependency bundle.
            Archive.run("copyAssets", pSource, pPayload.."/Dependencies/CardSets/"..sUUID);
            write(pPayload.."/Dependencies/Environment.ini", "[Environment]\r\nVersion=1\r\n");
        end
        local sManifest = "[Package]\r\nVersion="..nVersion.."\r\nKind="..sKind.."\r\nUUID="..sUUID.."\r\nGameUUID="..sGameUUID.."\r\nName="..tMeta.name.."\r\n";
        if (sKind == "CardSet") then sManifest = sManifest.."Width="..tMeta.width.."\r\nHeight="..tMeta.height.."\r\nDependencyName="..metadata(pPayload.."/Dependencies", "Game").name.."\r\n"; end
        write(pStage.."/Package.ini", sManifest);
        local tInventory = {};
        walk(pPayload, function(pFile) tInventory[#tInventory + 1] = pFile:sub(#pPayload + 2); end);
        table.sort(tInventory); write(pStage.."/Files.txt", table.concat(tInventory, "\n").."\n");
        local pPacked = pStage..".zip";
        local bPacked, sPackError = pcall(function()
            Archive.run("pack", pStage, pPacked);
            Archive.run("deliver", pPacked, pArchive);
        end);
        if (wx.wxFileExists(pPacked)) then assert(os.remove(pPacked), "Cannot remove staged package archive."); end
        assert(bPacked, sPackError);
    end, debug.traceback);
    local bClean, sClean = pcall(Archive.run, "remove", pStage);
    if (not bClean) then Log.Warning(sClean); end
    if (not bOK) then error(sError, 0); end
    Log.Note(sKind.." package export complete: "..tMeta.name); return pArchive;
end

--[[!
@fqxn CFS.Modules.ImportExport.Functions.Import_1
@pulsarlua function ImportExport.Import_1
@desc Imports a version-1 package into inactive storage. Rejects active IDs, asks before replacement, retains replacement backups, logs repairs and skipped sets, and never activates imported content.
@param string pArchive Package file.
@param string sKind Expected package type.
@param Game|nil oDestination Owning game for standalone card-set import.
@param function fConfirm Replacement confirmation callback.
@return boolean bImported False when replacement is declined.
!]]
function ImportExport.Import_1(pArchive, sKind, oDestination, fConfirm)
    local pStage = stage(); local tReport = {}; local bImported = false;
    Log.Note("Importing "..sKind.." package.");
    local bOK, sError = xpcall(function()
        Archive.run("unpack", pArchive, pStage);
        local pManifest = pStage.."/Package.ini";
        local function value(k) return INIFile.GetValue(pManifest, "Package", k); end
        local nInput = tonumber(value("Version"));
        assert(tCompatible[nInput] and nInput == 1, "Cannot automatically import this package: its format version is not compatible with this importer.");
        assert(value("Kind") == sKind, "The package has the wrong project type.");
        local sUUID = identity(value("UUID")); local sOrigin = identity(value("GameUUID"));
        local oActive = Game.GetActive(); local oSet = ProcSys.GetActiveCardSet();
        assert(not (sKind == "Game" and oActive and oActive.GetUUID() == sUUID), "Cannot import this game now: it is currently active. Close Game, then try importing again.");
        assert(not (sKind == "CardSet" and oSet and oSet.GetUUID() == sUUID), "Cannot import this card set now: it is currently active. Close Card Set, then try importing again.");
        local pTarget;
        if (sKind == "Game") then pTarget = FS.Game.GetRoot(sUUID);
        else assert(oDestination, "Load the destination game before importing a card set."); pTarget = FS.Game.GetRoot(oDestination.GetUUID()).."/CardSets/"..sUUID; end
        if (wx.wxDirExists(pTarget)) then if (not fConfirm(sKind, value("Name"))) then return; end end
        local pPayload = pStage.."/payload";
        if (wx.wxFileExists(pStage.."/Files.txt")) then
            local fSafePath = require("Globals.ImportSystem").SanitizePath;
            for sFile in read(pStage.."/Files.txt"):gmatch("[^\r\n]+") do
                local sSafe = fSafePath(sFile);
                if (not wx.wxFileExists(pPayload.."/"..sSafe)) then
                    tReport[#tReport + 1] = "Missing package file: "..sFile..". Required files may receive starter defaults; original assets cannot be recovered.";
                end
            end
        else tReport[#tReport + 1] = "Package file inventory is missing; removed custom assets cannot be identified."; end
        local tMeta = {name = value("Name"), width = tonumber(value("Width")), height = tonumber(value("Height"))};
        if (sKind == "Game") then
            assert(sOrigin == sUUID, "Game package identity mismatch.");
            -- Validate game source independently; bad child sets may be skipped.
            local pSets = pPayload.."/CardSets";
            local tSets = children(pSets);
            if (oSet) then
                for _, sSetID in ipairs(tSets) do
                    assert(sSetID:upper() ~= oSet.GetUUID(), "Cannot import this game package now: one of its card-set IDs is currently active. Close Card Set, then try importing again.");
                end
            end
            local pHold = pStage.."/held-sets"; assert(wx.wxMkdir(pHold));
            for _, id in ipairs(tSets) do assert(wx.wxRenameFile(pSets.."/"..id, pHold.."/"..id), "Cannot stage child set."); end
            validate(pPayload, "Game", tMeta, tReport);
            for _, id in ipairs(tSets) do
                local bSet, sSetError = pcall(function()
                    identity(id);
                    local pIndex = pStage.."/Sets/"..id..".ini";
                    local m;
                    if (wx.wxFileExists(pIndex)) then
                        m = {name = INIFile.GetValue(pIndex, "Metadata", "Name"), width = tonumber(INIFile.GetValue(pIndex, "Metadata", "Width")), height = tonumber(INIFile.GetValue(pIndex, "Metadata", "Height"))};
                    else m = metadata(pHold.."/"..id, "CardSet"); end
                    validate(pHold.."/"..id, "CardSet", m, tReport);
                    assert(wx.wxRenameFile(pHold.."/"..id, pSets.."/"..id), "Cannot restore validated set.");
                end);
                if (not bSet) then tReport[#tReport + 1] = "Skipped card set "..id..": "..tostring(sSetError); end
            end
        else
            validate(pPayload, "CardSet", tMeta, tReport);
            local pDependencies = pPayload.."/Dependencies";
            if (not wx.wxDirExists(pDependencies)) then
                tReport[#tReport + 1] = "Missing dependency bundle replaced with starter defaults; original artwork and custom behavior were not recovered.";
            end
            validate(pDependencies, "Game", {name = value("DependencyName")}, tReport);
            write(pDependencies.."/Environment.ini", "[Environment]\r\nVersion=1\r\n");
        end
        local sInstall = Archive.run("install", pPayload, pTarget);
        if (sInstall:match("%S")) then tReport[#tReport + 1] = sInstall; end
        bImported = true;
        if (sKind == "Game") then Game.Refresh(); else oDestination.UpdateCardSets(); end
    end, debug.traceback);
    local bClean, sClean = pcall(Archive.run, "remove", pStage);
    if (not bClean) then Log.Warning(sClean); end
    for _, sMessage in ipairs(tReport) do Log.Warning(sMessage); end
    if (not bOK) then error(sError, 0); end
    Log.Note(bImported and (sKind.." package import complete; project activation unchanged.") or "Package import canceled; existing files unchanged.");
    return bImported, tReport;
end
--[[!
@fqxn CFS.Modules.ImportExport.Functions.Export
@pulsarlua function ImportExport.Export
@desc Dispatches output through the shared current package version.
!]]
function ImportExport.Export(...)
    local tWriters = {[1] = ImportExport.Export_1};
    return assert(tWriters[nVersion], "Unsupported export version.")(...);
end

--[[!
@fqxn CFS.Modules.ImportExport.Functions.Import
@pulsarlua function ImportExport.Import
@desc Dispatches validated input through the current importer and its explicit compatibility handlers.
!]]
function ImportExport.Import(...)
    local tReaders = {[1] = ImportExport.Import_1};
    return assert(tReaders[nVersion], "Unsupported importer version.")(...);
end
return ImportExport;
