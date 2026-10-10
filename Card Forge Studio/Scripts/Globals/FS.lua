--[[!
@fqxn CFS.Modules.FS
@desc Validates application, game, and card-set paths and creates new games and card sets from templates.
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
local pTemplates   = _Docs.."\\Templates";
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


--[[
██╗      ██████╗  ██████╗ █████╗ ██╗
██║     ██╔═══██╗██╔════╝██╔══██╗██║
██║     ██║   ██║██║     ███████║██║
██║     ██║   ██║██║     ██╔══██║██║
███████╗╚██████╔╝╚██████╗██║  ██║███████╗
╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝--]]

--[[!
@fqxn CFS.Modules.FS.Private.GetSubfolderUUIDs
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
@fqxn CFS.Modules.FS.Private.CheckFile
@desc Checks that a required game file exists without writing it.
@param any pFile p File.
!]]
local function CheckFile(pFile)
    if (not wx.wxFileExists(pFile)) then error("Required game file is missing: "..pFile..". Linked game data is read-only.", 2); end
end

--[[!
@fqxn CFS.Modules.FS.Private.CheckFolder
@desc Checks that a required game directory exists without creating it.
@param any pFolder p Folder.
!]]
local function CheckFolder(pFolder)
    if (not wx.wxDirExists(pFolder)) then error("Required game folder is missing: "..pFolder..". Linked game data is read-only.", 2); end
end

--[[!
@fqxn CFS.Modules.FS.Private.ProcessUUID
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
@fqxn CFS.Modules.FS.Game.Create
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
    local tFiles        = {};
    local tTemplates    = {
        ["Scripts\\CFG.lua"] = "CFG.lua",
        ["Scripts\\ENV.lua"] = "ENV.lua",
        ["Styles.ini"]       = "Styles.ini",
    };

    CheckFolder(tFS.AppDir);
    if (wx.wxDirExists(pRoot) or wx.wxFileExists(pRoot)) then
        error("The new game directory already exists: "..pRoot, 2);
    end

    -- Read every template first; a missing resource must not leave a partial game.
    for sTarget, sTemplate in pairs(tTemplates) do
        local hFile, sError = io.open(pTemplates.."\\"..sTemplate, "rb");
        if (not hFile) then error(sError, 2); end

        local sContents, sReadError = hFile:read("a");
        local bClosed, sCloseError = hFile:close();
        if (not sContents or not bClosed) then error(sReadError or sCloseError, 2); end

        tFiles[sTarget] = sContents;
    end

    tFiles["Info.ini"] = "[SETTINGS]\r\nIncludePlugins=false\r\nName="..sName.."\r\n";
    local bOK, sError = xpcall(function()
        if (not wx.wxDirExists(tFS.Games)) then
            if (not wx.wxMkdir(tFS.Games)) then error("Cannot create Games folder: "..tFS.Games); end
            tCreatedDirs[#tCreatedDirs + 1] = tFS.Games;
        end

        local tFolders = {
            "", FOLDER_CARD_SETS, "CSV Backup", "Docs", "Exports",
            "Scripts", "Scripts\\CFG", "Scripts\\ENV", "Symbols", FOLDER_WIKI,
        };

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
@fqxn CFS.Modules.FS.Game.GetCardSetUUIDs
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
@fqxn CFS.Modules.FS.Game.GetInfoINIPath
@pulsarlua function FS.Game.GetInfoINIPath
@desc Resolves game metadata from a validated UUID.
@param any vUUID v UUID.
!]]
tGame.GetInfoINIPath = function(vUUID)
    local sUUID = ProcessUUID(vUUID);
    return tGame.GetRoot(sUUID).."\\Info.ini";
end

--[[!
@fqxn CFS.Modules.FS.Game.GetRoot
@pulsarlua function FS.Game.GetRoot
@desc Resolves a game directory from its UUID.
@param any vUUID v UUID.
!]]
tGame.GetRoot = function(vUUID)
    local sUUID = ProcessUUID(vUUID);
    return tFS.Games.."\\"..sUUID;
end

--[[!
@fqxn CFS.Modules.FS.Game.GetUUIDs
@pulsarlua function FS.Game.GetUUIDs
@desc Lists discoverable game identifiers.
!]]
tGame.GetUUIDs = function()
    return GetSubfolderUUIDs(tFS.Games, "FS.Game.GetUUIDs");
end

--[[!
@fqxn CFS.Modules.FS.Game.Prep
@pulsarlua function FS.Game.Prep
@desc Validates a game's required paths before publishing them. Existing game data is never repaired or written during loading.
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

    -- Commit only validated paths, retaining the old active paths on validation failure.
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
@fqxn CFS.Modules.FS.CardSet.Create
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
    local sNamespace    = INIFile.GetValue(tGame.GetInfoINIPath(sGameUUID), "SETTINGS", "Name").."."..sName;
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
@fqxn CFS.Modules.FS.CardSet.GetRoot
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
@fqxn CFS.Modules.FS.CardSet.Prep
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
