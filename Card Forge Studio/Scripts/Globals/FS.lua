--[[!
@fqxn CFS.Modules.FS
@desc
<section aria-label="File System overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">File System</h2><p style="font-size:1.15rem;margin:0">FS is Studio's virtual file system: a shared, read-only map that helps scripts and tools find the right files for the active game and card set. It supports safer file access by validating project locations and giving file-loading services a consistent starting point for their own path checks.</p></div>
<h3>How it fits into your work</h3><p>Creation builds required folders and starter files. Preparation validates the selected project before publishing its active paths. New projects include an Exports folder; preparation checks that the selected project’s required folders exist.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.Game">Game</a></h3><p style="margin:0">Game uses FS for project discovery, creation, metadata paths, and activation preparation.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.CardSet">Card Set</a></h3><p style="margin:0">CardSet uses FS to create files and locate its metadata within its parent game.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys">Processing System</a></h3><p style="margin:0">The processor consumes the active paths when loading scripts, data, and watched files.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Display names and UUID folder identities serve different purposes. Failed creation rolls back only that attempt's files; FS is not a general deletion interface.</p></aside>
<h3>A virtual address book for real files</h3>
<p>Think of FS as a shared address book. The files still live in ordinary folders, but the rest of Studio can ask for the active game’s scripts or the active set’s drawing file without rebuilding the full address each time. This shared view is the virtual layer: one agreed map over the real folders, not a second disk or a copy of your project.</p>
<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
    <article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)"><h3>Application addresses</h3><p>Templates, application settings, game storage, and exporter source locations give startup and creation services their common reference points.</p></article>
    <article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)"><h3>Game addresses</h3><p>The active game map identifies shared Scripts, Config, Environment, Styles, Wiki, Docs, and Exports locations.</p></article>
    <article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)"><h3>Card-set addresses</h3><p>The active set map identifies its CSV data, metadata, front and back drawing scripts, row processor, and code-column definitions.</p></article>
</div>
<h3>Relative paths keep a project together</h3>
<p>A relative path describes a file’s place inside the game, such as <code>Artwork/example.png</code>, instead of naming a personal computer folder. When the project moves together, that relationship can remain the same. FS supplies the active game root; imports and image drawing use it as their starting point.</p>
<p>The <a href="#CFS.Modules.Globals.ImportSystem">import service</a> rejects absolute paths, dot-directory segments, and invalid filenames before resolving an import. <a href="#CFS.Modules.Forge">Forge</a> also checks image paths and rejects attempts to step outside the game through parent-directory segments. These are path checks made by the consumers of FS, rather than automatic rules applied to every possible disk operation.</p>
<h3>Switching projects without mixing their files</h3>
<ol><li><strong>Find the project:</strong> game and set identifiers are validated before FS constructs their locations.</li><li><strong>Check the game:</strong> required files and directories must exist before the active game map is replaced. A failed validation keeps the previous game addresses.</li><li><strong>Check ownership:</strong> preparing a card set verifies that it belongs to the active game.</li><li><strong>Publish the map:</strong> services then read the agreed active addresses. Ordinary assignments to the public FS, Game, and CardSet maps are rejected.</li></ol>
<h3>How this supports script execution</h3>
<p>FS locates the inputs; it does not run the scripts. The import service reads a validated relative source file, compiles it in <a href="#CFS.UserEnv">UserEnv</a>, and runs it through a protected call so a runtime failure can be returned to the caller. ProcSys uses the prepared environment when loading the active set’s processing and drawing instructions.</p>
<p>Keeping location, execution environment, and error handling separate makes mistakes easier to identify. The read-only address map prevents ordinary accidental reassignment; it is not a replacement for operating-system permissions.</p>
<h3>Creation and loading have different jobs</h3>
<p>Creating a new project writes starter folders and files from templates. If creation fails, cleanup is limited to that attempt’s recorded files and directories. Loading an existing project checks its required structure rather than silently rebuilding missing source files. This distinction helps preserve work you already have.</p>

<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

local wx = require("wx");
local _sOriginalPackagePath = package.path;
--[[
██████╗ ███████╗ ██████╗██╗      █████╗ ██████╗  █████╗ ████████╗██╗ ██████╗ ███╗   ██╗███████╗
██╔══██╗██╔════╝██╔════╝██║     ██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
██║  ██║█████╗  ██║     ██║     ███████║██████╔╝███████║   ██║   ██║██║   ██║██╔██╗ ██║███████╗
██║  ██║██╔══╝  ██║     ██║     ██╔══██║██╔══██╗██╔══██║   ██║   ██║██║   ██║██║╚██╗██║╚════██║
██████╔╝███████╗╚██████╗███████╗██║  ██║██║  ██║██║  ██║   ██║   ██║╚██████╔╝██║ ╚████║███████║
╚═════╝ ╚══════╝ ╚═════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝--]]


--[[
╭─╴╭─╮╭┬╮╭─╴
│╶╮├─┤│││├╴
╰─╯╵ ╵╵ ╵╰─╴--]]
--[[!
@fqxn CFS.Modules.FS.Game
@pulsarlua table FS.Game
@desc Read-only active Game paths populated during filesystem preparation.
@field string Root Active Root path.
@field string Wiki Active Wiki path.
@field string Docs Active Docs path.
@field string CardSets Active CardSets path.
@field string CSVBackup Active CSVBackup path.
@field string Exports Active Exports path.
@field string Scripts Active Scripts path.
@field string Symbols Active Symbols path.
@field string CFG Active CFG path.
@field string ENV Active ENV path.
@field string Info Active Info path.
@field string Styles Active Styles path.
!]]
local tGame     = {
    Root        = "",
    Wiki        = "",
    Docs        = "",
    CardSets    = "",
    --Set         = "",
    CSVBackup   = "",
    Exports     = "",
    Scripts     = "",
    Symbols     = "",
    CFG         = "",
    ENV         = "",
    Info        = "",
    Styles      = "",
};
local tGameDecoy    = {};
local tGameMeta     = {
    __index = tGame,
    __newindex = function(t, k, v)
        error("Attempt to write to read-only FS.Game table.");
    end,
    __metatable = false,
};

setmetatable(tGameDecoy, tGameMeta);


--[[
╭─╴╭─╮╭─╮╶┬╮╭─╮╭─╴╶┬╴
│  ├─┤├┬╯ ││╰─╮├╴  │
╰─╴╵ ╵╵╰╴╶┴╯╰─╯╰─╴ ╵ --]]
--[[!
@fqxn CFS.Modules.FS.CardSet
@pulsarlua table FS.CardSet
@desc Read-only active CardSet paths populated during filesystem preparation.
@field string Root Active Root path.
@field string Data Active Data path.
@field string Draw Active Draw path.
@field string DrawBack Active DrawBack path.
@field string Info Active Info path.
@field string RowProc Active RowProc path.
@field string CodeColumns Active CodeColumns path.
!]]
local tCardSet = {
    Root            = "",
    Data            = "",
    Draw        = "",
    DrawBack    = "",
    Info            = "",
    RowProc     = "",
    CodeColumns     = "",
};
local tCardSetDecoy    = {};
local tCardSetMeta     = {
    __index = tCardSet,
    __newindex = function(t, k, v)
        error("Attempt to write to read-only FS.CardSet table.");
    end,
    __metatable = false,
};

setmetatable(tCardSetDecoy, tCardSetMeta);

--[[
╭─╴╭─╮
├╴ ╰─╮
╵  ╰─╯--]]
--preset values, constant throughout program flow
local pTemplates   = _Scripts.."/../Docs/Templates";
local pAppDir      = _AppDataLocal;
local pGames       = pAppDir.."\\Games";
local pAppCFG_T    = pTemplates.."\\"..APP_CFG; --template
local pAppCFG      = pAppDir.."\\"..APP_CFG;
local pTutorials   = _Docs.."\\Tutorials";
local pExporters   = _Scripts.."\\Exporters";

local tFS       = {
    Templates       = pTemplates,
    AppDir          = pAppDir,
    Games           = pGames,
    AppCFG_T        = pAppCFG_T,
    AppCFG          = pAppCFG,
    Tutorials       = pTutorials,
    Exporters       = pExporters,
    Game            = tGameDecoy,
    CardSet         = tCardSetDecoy,
};


--[[!
@fqxn CFS.Modules.FS.Functions.GetManifest
@pulsarlua function FS.GetManifest
@desc Returns a fresh required-file manifest and starter contents shared by project creation and package repair. Context supplies name, gameName, width and height; returned tables can be inspected without changing FS.
@param string sKind Game or CardSet.
@param table tContext Metadata for generated defaults.
@return table tManifest Required folders and file records with repair contents.
!]]
tFS.GetManifest = function(sKind, tContext)
    tContext = tContext or {};
    local sName = assert(tContext.name);
    assert(rawtype(sName) == "string" and sName:match("%S") and not sName:find("[%c]"), "Invalid manifest name.");
    if (sKind == "Game") then
        local tFiles = { ["autocomplete.lua"] = "return {version = 1, items = {}};\r\n", ["Info.ini"] = "[SETTINGS]\r\nIncludePlugins=false\r\nName="..sName.."\r\n" };
        for sTarget, sTemplate in pairs({["Scripts/CFG.lua"] = "CFG.lua", ["Scripts/ENV.lua"] = "ENV.lua", ["Styles.ini"] = "Styles.ini"}) do
            local hFile = assert(io.open(pTemplates.."/"..sTemplate, "rb"));
            tFiles[sTarget] = assert(hFile:read("a")); assert(hFile:close());
        end
        return {folders = {"", FOLDER_CARD_SETS, "CSV Backup", "Docs", "Exports", "Scripts", "Scripts/CFG", "Scripts/ENV", "Symbols", FOLDER_WIKI}, files = tFiles};
    end
    assert(sKind == "CardSet", "Unknown manifest kind.");
    local nWidth, nHeight = tContext.width, tContext.height;
    assert(rawtype(nWidth) == "number" and rawtype(nHeight) == "number" and nWidth > 0 and nHeight > 0 and nWidth < math.huge and nHeight < math.huge and nWidth == math.floor(nWidth) and nHeight == math.floor(nHeight), "Invalid manifest dimensions.");
    local sNamespace    = (tContext.gameName or "Game").."."..sName;
    local sDrawing      = "--[[!\r\n@fqxn "..sNamespace..".Draw\r\n@desc Draws this card face. Add drawing calls inside the returned function.\r\n]]\r\nreturn function(sObject, D, hDC)\r\nend\r\n";
    local sProcessor    = "--[[!\r\n@fqxn "..sNamespace..".RowProc\r\n@desc Returns a cell's processed text; the starter keeps its original value.\r\n]]\r\nreturn function(nRow, nColumn, sHeader, tRow, sText, fGetFinalValue)\r\n    return sText;\r\nend\r\n";
    local sInfo         = "[SETTINGS]\r\nName="..sName.."\r\nCardWidth="..nWidth.."\r\nCardHeight="..nHeight.."\r\n\r\n"..
        "[Export.PNG]\r\nType=PNG\r\nSides=fronts\r\nBacks=shared\r\nBackRow=0\r\nScalePercent=100\r\nLastExportFolder=\r\n\r\n"..
        "[Editor.Navigation]\r\nActiveFile=1:"..FILESPEC_CARDSET_DRAW.Full.."\r\n";
    local tFiles        = {
        [FILESPEC_CARDSET_CODECOLUMMS.Full] = "",
        [FILESPEC_CARDSET_DATA.Full]        = "Name\r\n",
        [FILESPEC_CARDSET_DRAW.Full]        = sDrawing,
        [FILESPEC_CARDSET_DRAWBACK.Full]    = sDrawing:gsub("(@fqxn [^\r\n]+)%.Draw\r\n", "%1.DrawBack\r\n"),
        [FILESPEC_CARDSET_INFO.Full]        = sInfo,
        [FILESPEC_CARDSET_ROWPROC.Full]     = sProcessor,
        ["Notes.txt"]                      = "",
    };

    return {folders = {""}, files = tFiles};
end

--[[!
@fqxn CFS.Modules.FS.Functions.GetResourceRoot
@pulsarlua function FS.GetResourceRoot
@desc Returns the imported set dependency root when present, otherwise the active game root.
@return string pRoot Resource root.
!]]
tFS.GetResourceRoot = function()
    local pBundle = tCardSet.Root ~= "" and tCardSet.Root.."/Dependencies" or "";
    if (pBundle ~= "" and wx.wxFileExists(pBundle.."/Environment.ini") and INIFile.GetValue(pBundle.."/Environment.ini", "Environment", "Version") == "1") then return pBundle; end
    return tGame.Root;
end

--[[
██╗      ██████╗  ██████╗ █████╗ ██╗
██║     ██╔═══██╗██╔════╝██╔══██╗██║
██║     ██║   ██║██║     ███████║██║
██║     ██║   ██║██║     ██╔══██║██║
███████╗╚██████╔╝╚██████╗██║  ██║███████╗
╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝--]]

--[[!
@fqxn CFS.Modules.FS.Private.Functions.GetSubfolderUUIDs
@desc Discovers valid UUID-named subfolders and returns them in sorted order.
@param any pFolder Folder.
@param any sCaller Caller.
@vis private
!]]
local function GetSubfolderUUIDs(pFolder, sCaller)
    if (not wx.wxDirExists(pFolder)) then return {}; end

    local tRet;
    local tFolders = {};
    local oFolder  = wx.wxDir(pFolder);

    if (oFolder:IsOpened()) then
        local bFound, sName = oFolder:GetFirst("", wx.wxDIR_DIRS);

        while (bFound) do
            tFolders[#tFolders + 1] = pFolder.."/"..sName;
            bFound, sName = oFolder:GetNext();
        end
    end

    oFolder:delete();

    if (tFolders) then
        tRet = {};

        for _, pFolder in pairs(tFolders) do
            local sDirName  = assert(pFolder:gsub("\\", "/"):match("([^/]+)$")):upper();

            if (sDirName:isuuid()) then
                tRet[#tRet + 1] = sDirName:upper();
            else

                if (sDirName ~= ".IGNORE") then
                    Log.Warning("FS.GetSubfolderUUIDs (called by '"..sCaller.."'): Folder '"..sDirName.."' at path '"..pFolder.."' is invalid.\r\nFolder name must be a valid UUID string.");
                end

            end

        end

    end

    return tRet;
end
--[[!
@fqxn CFS.Modules.FS.Private.Functions.CheckFile
@desc Checks that a required game file exists without writing it.
@param any pFile p File.
!]]
local function CheckFile(pFile)
    if (not wx.wxFileExists(pFile)) then error("Required game file is missing: "..pFile..". Linked game data is read-only.", 2); end
end

--[[!
@fqxn CFS.Modules.FS.Private.Functions.CheckFolder
@desc Checks that a required game directory exists without creating it.
@param any pFolder p Folder.
!]]
local function CheckFolder(pFolder)
    if (not wx.wxDirExists(pFolder)) then error("Required game folder is missing: "..pFolder..". Linked game data is read-only.", 2); end
end

--[[!
@fqxn CFS.Modules.FS.Private.Functions.ProcessUUID
@desc Validates and normalizes a UUID before constructing a filesystem path.
@param any sUUID s UUID.

@param any sCaller s Caller.
!]]
local function ProcessUUID(sUUID, sCaller)
    if (rawtype(sUUID) ~= "string" or not sUUID:isuuid()) then
        error((sCaller or "FS")..": Expected a valid UUID string.", 2);
    end

    return sUUID:upper();
end


--[[
 ██████╗  █████╗ ███╗   ███╗███████╗
██╔════╝ ██╔══██╗████╗ ████║██╔════╝
██║  ███╗███████║██╔████╔██║█████╗
██║   ██║██╔══██║██║╚██╔╝██║██╔══╝
╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗
 ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝--]]
--[[!
@fqxn CFS.Modules.FS.Game.Functions.Create
@pulsarlua function FS.Game.Create
@desc Creates a new UUID game folder from bundled templates. Failed creation removes only files and directories owned by this attempt.
@param string sUUID New game identifier.
@param string sName Display name stored in Info.ini.
@return string Created game directory.
!]]
tGame.Create = function(sUUID, sName)
    if (rawtype(sName) ~= "string" or not sName:match("%S") or sName:find("[%c]")) then
        error("A game name must contain visible text and no control characters.", 2);
    end

    local pRoot         = tGame.GetRoot(sUUID);
    local tCreatedDirs  = {};
    local tCreatedFiles = {};
    local tManifest     = tFS.GetManifest("Game", {name = sName});
    local tFiles        = tManifest.files;

    CheckFolder(tFS.AppDir);
    if (wx.wxDirExists(pRoot) or wx.wxFileExists(pRoot)) then
        error("The new game directory already exists: "..pRoot, 2);
    end

    local bOK, sError = xpcall(function()
        if (not wx.wxDirExists(tFS.Games)) then
            if (not wx.wxMkdir(tFS.Games)) then error("Cannot create Games folder: "..tFS.Games); end
            tCreatedDirs[#tCreatedDirs + 1] = tFS.Games;
        end

        local tFolders = tManifest.folders;

        -- Record each successful creation so cleanup cannot remove pre-existing data.
        for _, sFolder in ipairs(tFolders) do
            local pFolder = sFolder == "" and pRoot or pRoot.."\\"..sFolder;
            if (not wx.wxMkdir(pFolder)) then error("Cannot create folder: "..pFolder); end
            tCreatedDirs[#tCreatedDirs + 1] = pFolder;
        end

        for sFile, sContents in pairs(tFiles) do
            local pFile = pRoot.."\\"..sFile;
            local hFile, sOpenError = io.open(pFile, "wb");
            if (not hFile) then error(sOpenError); end
            tCreatedFiles[#tCreatedFiles + 1] = pFile;

            local bWritten, sWriteError = hFile:write(sContents);
            local bClosed, sCloseError = hFile:close();
            if (not bWritten or not bClosed) then error(sWriteError or sCloseError); end
        end
    end, debug.traceback);

    if (not bOK) then
        for nIndex = #tCreatedFiles, 1, -1 do
            if (not wx.wxRemoveFile(tCreatedFiles[nIndex])) then
                Log.Warning("Could not remove incomplete game file: "..tCreatedFiles[nIndex]);
            end
        end

        for nIndex = #tCreatedDirs, 1, -1 do
            if (not wx.wxRmdir(tCreatedDirs[nIndex])) then
                Log.Warning("Could not remove incomplete game folder: "..tCreatedDirs[nIndex]);
            end
        end

        error(sError, 2);
    end

    return pRoot;
end

--[[!
@fqxn CFS.Modules.FS.Game.Functions.GetCardSetUUIDs
@pulsarlua function FS.Game.GetCardSetUUIDs
@desc Lists the card-set identifiers within a game.
@param any vUUID v UUID.
!]]
tGame.GetCardSetUUIDs = function(vUUID)
    local sGameUUID = ProcessUUID(vUUID, "FS.Game.GetCardSetUUIDs");
    local tRet;

    if (sGameUUID) then
        local pCardSets = tFS.Games.."\\"..sGameUUID:upper().."\\"..FOLDER_CARD_SETS;

        if not (wx.wxDirExists(pCardSets)) then
            Log.Warning("Error getting Game's CardSet UUIDs: The specified Game path does not exist.");
            return;
        end

        tRet = GetSubfolderUUIDs(pCardSets, "FS.Game.GetCardSetUUIDs");
    end

    return tRet;
end

--[[!
@fqxn CFS.Modules.FS.Game.Functions.GetInfoINIPath
@pulsarlua function FS.Game.GetInfoINIPath
@desc Resolves game metadata from a validated UUID.
@param any vUUID v UUID.
!]]
tGame.GetInfoINIPath = function(vUUID)
    local sUUID = ProcessUUID(vUUID);
    return tGame.GetRoot(sUUID).."\\Info.ini";
end

--[[!
@fqxn CFS.Modules.FS.Game.Functions.GetRoot
@pulsarlua function FS.Game.GetRoot
@desc Resolves a game directory from its UUID.
@param any vUUID v UUID.
!]]
tGame.GetRoot = function(vUUID)
    local sUUID = ProcessUUID(vUUID);
    return tFS.Games.."\\"..sUUID;
end

--[[!
@fqxn CFS.Modules.FS.Game.Functions.GetUUIDs
@pulsarlua function FS.Game.GetUUIDs
@desc Lists discoverable game identifiers.
!]]
tGame.GetUUIDs = function()
    return GetSubfolderUUIDs(tFS.Games, "FS.Game.GetUUIDs");
end

--[[!
@fqxn CFS.Modules.FS.Game.Functions.Prep
@pulsarlua function FS.Game.Prep
@desc Validates a game's required paths before publishing them. Existing game data is preserved; a missing generated autocomplete file is created during loading.
@param Game oGame Game to prepare.
!]]
tGame.Prep = function(oGame)
    if (type(oGame) ~= "Game") then error("FS.Game.Prep requires a Game object.", 2); end

    local pRoot    = tGame.GetRoot(oGame.GetUUID());
    local pScripts = pRoot.."\\Scripts";
    local tPaths   = {
        CardSets    = pRoot.."\\"..FOLDER_CARD_SETS,
        CFG         = pScripts.."\\CFG",
        CSVBackup   = pRoot.."\\CSV Backup",
        Docs        = pRoot.."\\Docs",
        ENV         = pScripts.."\\ENV",
        Exports     = pRoot.."\\Exports",
        Info        = pRoot.."\\Info.ini",
        Root        = pRoot,
        Scripts     = pScripts,
        Styles      = pRoot.."\\Styles.ini",
        Symbols     = pRoot.."\\Symbols",
        Wiki        = pRoot.."\\"..FOLDER_WIKI,
    };

    for sKey, pPath in pairs(tPaths) do
        if (sKey == "Info" or sKey == "Styles") then
            CheckFile(pPath);
        elseif (sKey ~= "Wiki") then
            CheckFolder(pPath);
        end
    end

    CheckFile(pScripts.."\\CFG.lua");
    CheckFile(pScripts.."\\ENV.lua");

    local pAutocomplete = pRoot.."/autocomplete.lua";
    if (not wx.wxFileExists(pAutocomplete)) then
        assert(not wx.wxDirExists(pAutocomplete), "Autocomplete path is a directory.");
        local hAutocomplete = assert(io.open(pAutocomplete, "wb"));
        local bWritten, sError = hAutocomplete:write("return {version = 1, items = {}};\r\n");
        local bClosed, sCloseError = hAutocomplete:close();
        assert(bWritten, sError); assert(bClosed, sCloseError);
    end

    -- Commit only validated paths, retaining the old active paths on validation failure.
    tCardSet.Clear();
    for sKey, pPath in pairs(tPaths) do
        tGame[sKey] = pPath;
    end

    package.path = _sOriginalPackagePath..";"..pScripts.."\\?.lua";
    Log.Note("FS.Game.Prep: Active game paths updated.");
end


--[[
 ██████╗ █████╗ ██████╗ ██████╗ ███████╗███████╗████████╗
██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝╚══██╔══╝
██║     ███████║██████╔╝██║  ██║███████╗█████╗     ██║
██║     ██╔══██║██╔══██╗██║  ██║╚════██║██╔══╝     ██║
╚██████╗██║  ██║██║  ██║██████╔╝███████║███████╗   ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝   ╚═╝   --]]

--[[!
@fqxn CFS.Modules.FS.CardSet.Functions.Create
@pulsarlua function FS.CardSet.Create
@desc Creates a new card-set directory and its required files, removing only this attempt's files on failure.
@param string sGameUUID Owning game identifier.
@param string sUUID New card-set identifier.
@param string sName Display name.
@param number nWidth Card width in pixels.
@param number nHeight Card height in pixels.
@return string Created directory.
!]]
tCardSet.Create = function(sGameUUID, sUUID, sName, nWidth, nHeight)
    if (rawtype(sName) ~= "string" or not sName:match("%S") or sName:find("[%c]")) then
        error("A card-set name must contain visible text and no control characters.", 2);
    end

    for _, nDimension in ipairs({nWidth, nHeight}) do
        if (rawtype(nDimension) ~= "number" or nDimension <= 0 or nDimension >= math.huge or nDimension ~= math.floor(nDimension)) then
            error("Card dimensions must be positive finite integers.", 2);
        end
    end
    if (nWidth == nil or nHeight == nil) then error("Both card dimensions are required.", 2); end

    local pParent       = tGame.GetRoot(sGameUUID).."\\"..FOLDER_CARD_SETS;
    local pRoot         = pParent.."\\"..ProcessUUID(sUUID, "FS.CardSet.Create");
    local tCreatedFiles = {};
    local bCreated      = false;
    local tFiles = tFS.GetManifest("CardSet", {name = sName, gameName = INIFile.GetValue(tGame.GetInfoINIPath(sGameUUID), "SETTINGS", "Name"), width = nWidth, height = nHeight}).files;
    CheckFolder(pParent);
    if (wx.wxDirExists(pRoot) or wx.wxFileExists(pRoot)) then
        error("The card-set directory already exists: "..pRoot, 2);
    end

    -- Create only a fresh UUID directory; existing user files are never opened for writing.
    local bOK, sError = xpcall(function()
        if (not wx.wxMkdir(pRoot)) then error("Cannot create card-set folder: "..pRoot); end
        bCreated = true;

        for sFile, sContents in pairs(tFiles) do
            local pFile = pRoot.."\\"..sFile;
            local hFile, sOpenError = io.open(pFile, "wb");
            if (not hFile) then error(sOpenError); end
            tCreatedFiles[#tCreatedFiles + 1] = pFile;

            local bWritten, sWriteError = hFile:write(sContents);
            local bClosed, sCloseError = hFile:close();
            if (not bWritten or not bClosed) then error(sWriteError or sCloseError); end
        end
    end, debug.traceback);

    if (not bOK) then
        for nIndex = #tCreatedFiles, 1, -1 do
            if (not wx.wxRemoveFile(tCreatedFiles[nIndex])) then
                Log.Warning("Could not remove incomplete card-set file: "..tCreatedFiles[nIndex]);
            end
        end

        if (bCreated and not wx.wxRmdir(pRoot)) then
            Log.Warning("Could not remove incomplete card-set directory: "..pRoot);
        end

        error(sError, 2);
    end

    return pRoot;
end


--[[!
@fqxn CFS.Modules.FS.CardSet.GetInfoINIPath
@pulsarlua function FS.CardSet.GetInfoINIPath
@desc Resolves the metadata path for a validated game and card-set identifier.
@param any vGameUUID v Game UUID.

@param any vUUID v UUID.
!]]
tCardSet.GetInfoINIPath = function(vGameUUID, vUUID)
    local sGameUUID = ProcessUUID(vGameUUID, "FS.CardSet.GetInfoINIPath");
    local sUUID     = ProcessUUID(vUUID, "FS.CardSet.GetInfoINIPath");
    local sRet;

    if (sGameUUID and sUUID) then
        sRet = tCardSet.GetRoot(vGameUUID, sUUID).."\\"..FILESPEC_CARDSET_INFO.Full;
    end

    return sRet;
end


--[[!
@fqxn CFS.Modules.FS.CardSet.Functions.GetRoot
@pulsarlua function FS.CardSet.GetRoot
@desc Resolves an existing card-set directory.
@param any vGameUUID v Game UUID.

@param any vUUID v UUID.
!]]
tCardSet.GetRoot = function(vGameUUID, vUUID)
    local sGameUUID = ProcessUUID(vGameUUID, "FS.CardSet.GetRoot");
    local sUUID     = ProcessUUID(vUUID, "FS.CardSet.GetRoot");
    local sRet;

    if (sGameUUID and sUUID) then
        sRet = tFS.Games.."\\"..sGameUUID.."\\"..FOLDER_CARD_SETS.."\\"..sUUID;

        if not (wx.wxDirExists(sRet)) then
            Log.Warning("Error getting CardSet's path ("..sUUID..") at path '"..sRet.."': The specified path does not exist.");
            return;
        end

    end

    return sRet;
end

--[[!
@fqxn CFS.Modules.FS.CardSet.Functions.Prep
@pulsarlua function FS.CardSet.Prep
@desc Publishes the paths used by card processing.
@param any oCardSet o Card Set.
!]]
tCardSet.Prep = function(oCardSet)
    if (type(oCardSet) ~= "CardSet") then error("FS.CardSet.Prep requires a CardSet object.", 2); end

    local sUUID    = oCardSet.GetUUID();
    local pCardSet = tCardSet.GetRoot(oCardSet.GetGameUUID(), sUUID);
    if (not pCardSet or pCardSet ~= tGame.Root.."\\"..FOLDER_CARD_SETS.."\\"..sUUID) then
        error("The card set does not belong to the active game.", 2);
    end

    tCardSet.Root           = pCardSet;
    tCardSet.Data           = pCardSet.."\\"..FILESPEC_CARDSET_DATA.Full;
    tCardSet.Draw           = pCardSet.."\\"..FILESPEC_CARDSET_DRAW.Full;
    tCardSet.DrawBack       = pCardSet.."\\"..FILESPEC_CARDSET_DRAWBACK.Full;
    tCardSet.Info           = pCardSet.."\\"..FILESPEC_CARDSET_INFO.Full;
    tCardSet.RowProc        = pCardSet.."\\"..FILESPEC_CARDSET_ROWPROC.Full;
    tCardSet.CodeColumns    = pCardSet.."\\"..FILESPEC_CARDSET_CODECOLUMMS.Full;

end

--[[
██████╗ ███████╗████████╗██╗   ██╗██████╗ ███╗   ██╗
██╔══██╗██╔════╝╚══██╔══╝██║   ██║██╔══██╗████╗  ██║
██████╔╝█████╗     ██║   ██║   ██║██████╔╝██╔██╗ ██║
██╔══██╗██╔══╝     ██║   ██║   ██║██╔══██╗██║╚██╗██║
██║  ██║███████╗   ██║   ╚██████╔╝██║  ██║██║ ╚████║
╚═╝  ╚═╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝--]]
--[[!
@fqxn CFS.Modules.FS.CardSet.Functions.Clear
@pulsarlua function FS.CardSet.Clear
@desc Clears active card-set paths without changing files.
!]]
tCardSet.Clear = function()
    for sKey, vValue in pairs(tCardSet) do
        if (rawtype(vValue) == "string") then tCardSet[sKey] = ""; end
    end
end

--[[!
@fqxn CFS.Modules.FS.Game.Functions.Clear
@pulsarlua function FS.Game.Clear
@desc Clears active project paths and restores the application module search path without changing files.
!]]
tGame.Clear = function()
    tCardSet.Clear();
    for sKey, vValue in pairs(tGame) do
        if (rawtype(vValue) == "string") then tGame[sKey] = ""; end
    end
    package.path = _sOriginalPackagePath;
end

local tFSMeta     = {
    __index = function(t, k)
        return tFS[k];
    end,
    __newindex = function(t, k, v) error("Attempt to write to read only FS table.") end,
    __metatable = false,
};

local tFSDecoy    = {};
setmetatable(tFSDecoy, tFSMeta);

return tFSDecoy;
