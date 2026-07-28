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
local tGame     = {
    Root        = "",
    Docs        = "",
    Temp        = "",
    CardSets    = "",
    --Set         = "",
    CSVBackup   = "",
    Exports     = "",
    Scripts     = "",
    Symbols     = "",
    CFG         = "",
    ENV         = "",
    Info        = "",
    Scratch     = "",
    Styles      = "",
    RowFilters  = "",
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
local tCardSet = {
    Root            = "",
    Data            = "",
    DrawPath        = "",
    DrawBackPath    = "",
    Info            = "",
    RowProcPath     = "",
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
local pAppDir      = _AppDataLocal.."\\"..APP_NAME;
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
local function BuildInfoFile(sGame) --TODO move this
    local sRet =[[
[SETTINGS]
;true puts all Plugin/luaEx Dox in your API help file(increases boot time)
IncludePlugins=false
Name=${game}]] % {
    game = sGame,
};

    return sRet;
end

local function GetSubfolderUUIDs(pFolder, sCaller)
    local tRet;
    local tFolders = Folder.Find(pFolder.."\\", "*", false, nil);

    if (tFolders) then
        tRet = {};

        for _, pFolder in pairs(tFolders) do
            local sDirName  = io.getenddir(pFolder):upper();

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

--assumes pFile and vFile are good  TODO warnings
local function CheckFile(pFile, vFile)

    if not (File.DoesExist(pFile)) then

        if (File.DoesExist(vFile)) then
            File.Copy(vFile, pFile, true, false, false, true, nil);
        else
            TextFile.WriteFromString(pFile, vFile, false);
        end

    end

end

local function CheckFolder(pFolder)

    if not (Folder.DoesExist(pFolder)) then
        Folder.Create(pFolder);
    end

end

--validates and returns uppered
local function ProcessUUID(sUUID, sCaller)

    if (type(sUUID) ~= "string" and not sUUID:isempty()) then
        Log.Warning(sCaller..": Error processing UUID input: UUID must be a valid UUID string.");
        return;
    end

    return sUUID:upper();
end

local function EnsureGameStructure()

end

local function EnsureCardSetStructure()

end


--[[
 ██████╗  █████╗ ███╗   ███╗███████╗
██╔════╝ ██╔══██╗████╗ ████║██╔════╝
██║  ███╗███████║██╔████╔██║█████╗
██║   ██║██╔══██║██║╚██╔╝██║██╔══╝
╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗
 ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝--]]

--Set when game is prepped
tGame.Prep = function(oGame)
    --reset the package path
    package.path = _sOriginalPackagePath;

    if not (type(oGame) == "Game") then
        error("FS: Error prepping game paths. Argument 1 must be of type Game. Got "..type(oGame)..'.');
    end

    Log.Note("FS.PrepGame: Updating virtual file system.");

    local sGameUUID = oGame.GetUUID();
    local pGames    = tFS.Games;
    local pGame     = pGames.."\\"..sGameUUID;

    if not (io.isdirectchild(pGames, pGame)) then
        error("FS: Error prepping game paths.\r\n\"${game}\" is not located in the expected directory of\r\n\"${games}.\"" % {game = pGame, games = pGames});
    end


    --TODO USE FILESPECs WHERE POSSIBLE

    --setup the game's folder
    tGame.Root             = pGame;                                        --CheckFolder(pGame);
    tGame.Docs             = pGame             .."\\Docs";                 CheckFolder(tGame.Docs);
    tGame.Temp             = pGame             .."\\Temp";                 CheckFolder(tGame.Temp);
    tGame.CardSets         = pGame             .."\\"..FOLDER_CARD_SETS;   CheckFolder(tGame.CardSets);
    --tGame.Set              = ""; --Gets set during set loading QUESTION DOes it? How? What is this path for?
    tGame.CSVBackup        = pGame             .."\\CSV Backup";           CheckFolder(tGame.CSVBackup);
    --tGame.CSVExport    = pGame             .."\\CSV Export";           CheckFolder(tGame.CSVExport);
    --NOTE: FIX This has been changed to filters
    --tGame.UserExporters    = pGame             .."\\Exporters";            CheckFolder(tGame.UserExporters);
--        for _, sName in Exporter.CATALOGUE() do
--            local sFullName = "UserExporters"..sName;
        --tFS.Game[sFullName] = tGame.UserExporters.."\\"..sName;              CheckFolder(tFS.Game[sFullName]);
--          end

    tGame.Exports          = pGame             .."\\Exports";              CheckFolder(tGame.Exports);
    tGame.Scripts          = pGame             .."\\Scripts";              CheckFolder(tGame.Scripts);
    tGame.Symbols          = pGame             .."\\Symbols";              CheckFolder(tGame.Symbols);
    tGame.CFG              = tGame.Scripts  .."\\CFG";                  CheckFolder(tGame.CFG);
    tGame.ENV              = tGame.Scripts  .."\\ENV";                  CheckFolder(tGame.ENV);

    --set the game name
    _sGame = oGame.GetName(); --TODO FINISH UPDATE THIS

    --setup the game's files --TODO use FILESPECS HERE
    tGame.Info          = pGame              .."\\Info.ini";         CheckFile(tGame.Info,                          BuildInfoFile(_sGame));
    tGame.Scratch       = tGame.Temp      .."\\Scratch.lua";      CheckFile(tGame.Scratch,                       "");
    tGame.Styles        = pGame              .."\\Styles.ini";       CheckFile(tGame.Styles,                        pTemplates.."\\Styles.ini");
    tGame.RowFilters    = tGame.Scripts   .."\\RowFilters.lua";   CheckFile(tGame.RowFilters,                    pTemplates.."\\RowFilters.lua");
                                                                        CheckFile(tGame.Scripts.."\\CFG.lua",          pTemplates.."\\CFG.lua");
                                                                        CheckFile(tGame.Scripts.."\\ENV.lua",          pTemplates.."\\ENV.lua");

    --add game's scripts folder to the package path
    package.path = _sOriginalPackagePath..";"..pGame.."\\Scripts\\?.lua";

    Log.Note("FS.PrepGame: Virtual file system updated for current game.");
end

tGame.GetCardSetUUIDs = function(vUUID)
    local sGameUUID = ProcessUUID(vUUID, "FS.Game.GetCardSetUUIDs");
    local tRet;

    if (sGameUUID) then
        local pCardSets = tFS.Games.."\\"..sGameUUID:upper().."\\"..FOLDER_CARD_SETS;

        if not (Folder.DoesExist(pCardSets)) then
            Log.Warning("Error getting Game's CardSet UUIDs: The specified Game path does not exist.");
            return;
        end

        tRet = GetSubfolderUUIDs(pCardSets, "FS.Game.GetCardSetUUIDs");
    end

    return tRet;
end

tGame.GetUUIDs = function()
    return GetSubfolderUUIDs(tFS.Games, "FS.Game.GetUUIDs");
end


--for Game constructor bootstrapping
tGame.GetInfoINIPath = function(vUUID)
    --TODO asssertions
    local sUUID = ProcessUUID(vUUID);
    return FS.Game.GetRoot(sUUID.."\\Info.ini");
end

--for Game constructor bootstrapping
tGame.GetRoot = function(vUUID)
    --TODO asssertions
    local sUUID = ProcessUUID(vUUID);
    return tFS.Games.."\\"..sUUID;
end


--[[
 ██████╗ █████╗ ██████╗ ██████╗ ███████╗███████╗████████╗
██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝╚══██╔══╝
██║     ███████║██████╔╝██║  ██║███████╗█████╗     ██║
██║     ██╔══██║██╔══██╗██║  ██║╚════██║██╔══╝     ██║
╚██████╗██║  ██║██║  ██║██████╔╝███████║███████╗   ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝   ╚═╝   --]]

tCardSet.GetInfoINIPath = function(vGameUUID, vUUID) --TODO BUG FIX thiese paths are not correct
    --TODO asssertions
    local sGameUUID = ProcessUUID(vGameUUID, "FS.CardSet.GetInfoINIPath");
    local sUUID     = ProcessUUID(vUUID, "FS.CardSet.GetInfoINIPath");
    local sRet;

    if (sGameUUID and sUUID) then
        sRet = tCardSet.GetRoot(vGameUUID, sUUID).."\\"..FILESPEC_CARDSET_INFO.Full;
    end

    return sRet;
end


tCardSet.GetRoot = function(vGameUUID, vUUID)
    --TODO asssertions
    local sGameUUID = ProcessUUID(vGameUUID, "FS.CardSet.GetRoot");
    local sUUID     = ProcessUUID(vUUID, "FS.CardSet.GetRoot");
    local sRet;

    if (sGameUUID and sUUID) then
        sRet = tFS.Games.."\\"..sGameUUID.."\\"..FOLDER_CARD_SETS.."\\"..sUUID;

        if not (Folder.DoesExist(sRet)) then
            Log.Warning("Error getting CardSet's path ("..sUUID..") at path '"..sRet.."': The specified path does not exist.");
            return;
        end

    end

    return sRet;
end

tCardSet.Prep = function(oCardSet) --TODO LEFT OFF HERE
    --TODO validate input
    local sUUID             = oCardSet.GetUUID()
    local pCardSet          = tGame.Root.."\\"..FOLDER_CARD_SETS.."\\"..sUUID;

    tCardSet.Root           = pCardSet;
    tCardSet.Data           = pCardSet.."\\"..FILESPEC_CARDSET_DATA.Full;
    tCardSet.Draw           = pCardSet.."\\"..FILESPEC_CARDSET_DRAW.Full;
    tCardSet.DrawBack       = pCardSet.."\\"..FILESPEC_CARDSET_DRAWBACK.Full;
    tCardSet.Info           = pCardSet.."\\"..FILESPEC_CARDSET_INFO.Full;
    tCardSet.RowProc        = pCardSet.."\\"..FILESPEC_CARDSET_ROWPROC.Full;
    tCardSet.CodeColumns    = pCardSet.."\\"..FILESPEC_CARDSET_CODECOLUMMS.Full;

    --tFS.Cards               = tFS.Game.."\\"..FOLDER_CARD_SETS;   CheckFolder(tFS.Cards);
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
    __newindex = function(t, k, v) error("Atempt to write to read only FS table.") end,
    --TODO Set __metatable = false after finding bug
};

local tFSDecoy    = {};
setmetatable(tFSDecoy, tFSMeta);

return tFSDecoy;
