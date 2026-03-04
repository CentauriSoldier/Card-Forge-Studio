local _tGames       = {}; --keys are uuids, values are {Game = GameObject, Name = NameString}
local _oActiveGame  = false;
local GetCRC        = File.GetCRC
local ReadToString  = TextFile.ReadToString;
local io            = io;
--TODO with New methods, checkf or existing item first...do not overwrite

local CardSet   = require("Game.CardSet");
local GameUtil  = require("Game.GameUtil");

local function BuildUserTable(sGame, sName)
    --TODO FIX FINISH THIS SHOULD NOT BE CALLED HERE WITHOUT SAFE ENV
    --Load any config and user environment that may exist TODO BUG FIX - FINISH - USE PROTECTED environment for loading this
    --local sInitChunk    = _oActiveCardSet.GetCallCode("CellProc");
    --TODO IT CAN BE USED IN THINGS LIKE oGame.RefreshCFG() and oGame.RefreshEnv() or just oGame.ReInit()
    local sInitChunk = TextFile.ReadToString(FS.Scripts.."\\"..sName..".lua");
    --TODO CHECK AND ERROR on bad file
    --TODO Clear/Refresh UserEnv

    --the error message in case things go south
    local sChunkName = sGame.." sName";

    --try to load the chuck
    local fChunk, sError = load(sInitChunk, sChunkName, "t", UserEnv.Get());
    if not (fChunk) then
        error("Error running "..sName.." file for Game "..sGame..".\r\n"..sError, 2);
    end

    --try to call the chunk
    local tInit = {pcall(fChunk)};

    if not (tInit[1]) then
        error("Error running "..sName.." file for Game "..sGame..".\r\n"..tInit[2], 2);
    end

    local tUserTable = table.unpack(tInit, 2);

    if not (type(tUserTable) == "table") then
        error("Error in return from "..sName.." file for Game "..sGame..".\r\nExpected type table, Got "..type(tUserTable)..'.', 2);
    end

    return tUserTable;
end


local function UpdateFileRepo(oGame)
    --update the game's LiveFileRepo
    local oOldLiveFileRepo = oGame.GetLiveFileRepo();

    if (type(oOldLiveFileRepo) == "LiveFileRepo") then
        LiveFile.Destroy(oOldLiveFileRepo);
    end

--TODO LEFT OFF HERE - NOT YET WORKING 
    local oLiveFileRepo = LiveFile.CreateRepo();
    oGame.SetLiveFileRepo(oLiveFileRepo);

    local function RebuildCFG(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        local tCFG = BuildUserTable(sGame, "CFG");
        UserEnv.UpdateCFG(tCFG);
        --tLiveFile, sOldText, sNewText, nOldCRC, nCRC
        p(nOldCRC)
    end

    LiveFile.Register(oLiveFileRepo, "CFG", FS.Scripts.."\\CFG.lua", 2000, RebuildCFG);
    local tCFGFiles = File.Find(FS.CFG.."\\", "*.lua", false, false, nil, nil);

    if (type(tCFGFiles) == "table") then

        for nIndex, pFile in pairs(tCFGFiles) do
            LiveFile.Register(oLiveFileRepo, "CFG"..tostring(nIndex):format("%02d"), pFile, 2000, RebuildCFG);
        end

    end

    local function RebuildENV(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        local tEnv = BuildUserTable(sGame, "ENV");
        UserEnv.UserUpdateRoot(tEnv);
    end

    LiveFile.Register(oLiveFileRepo, "ENV", FS.Scripts.."\\ENV.lua", 2000, RebuildENV);
    local tENVFiles = File.Find(FS.ENV.."\\", "*.lua", false, false, nil, nil);

    if (type(tENVFiles) == "table") then

        for nIndex, pFile in pairs(tENVFiles) do
            LiveFile.Register(oLiveFileRepo, "ENV"..tostring(nIndex):format("%02d"), pFile, 2000, RebuildENV);
        end

    end

end


local function ValidateAndUpdateGame(this, cdat)
    local pri           = cdat.pri;
    local pFolder       = pri.Path;
    local nErrorLevel   = 3;
    local sType         = "Game";

    --get and validate the game's uuid
    local sUUID = GameUtil.ValidateObjectFolder(pFolder, sType);

    --validate the game's name
    local sName = GameUtil.ValidateObjectName(pFolder, sType);

    pri.UUID = sUUID;
    pri.Name = sName;

    --register/update the game object's reference
    _tGames[pri.UUID] = {
        Name    = sName,
        Object  = this,
    };

    --updade the game's card sets
    pri.CardSets = {};

    --iterate over all potential card set folders
    local tCardSetFolders  = Folder.Find(pFolder.."\\"..FOLDER_CARD_SETS.."\\", "*", false, nil);

    if (type(tCardSetFolders) == "table") then

        for _, pCardSetFolder in pairs(tCardSetFolders) do

            if (io.getenddir(pCardSetFolder):lower() ~= ".ignore") then

                --try to create the new cardset object
                local oCardSet = CardSet(pCardSetFolder);

                pri.CardSets[oCardSet.GetUUID()] = {
                    Name    = oCardSet.GetName();
                    Object  = oCardSet,
                };

            end

        end

    end

end

local function SortByName(oItemA, oItemB)
    return oItemA.GetName() < oItemB.GetName();
end


return class("Game",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --Game = function(this, sAuthCode) end, --static constructor (runs after class object creation)
        GetActive = function()
            return _oActiveGame;
        end,
        GetAll = function()
            local tRet = {};

            for sUUID, tGame in pairs(_tGames) do
                tRet[#tRet + 1] = tGame.Object;
            end

            table.sort(tRet, SortByName);

            return tRet;
        end,
        GetNames = function()
            local tRet = {};

            for sUUID, tGame in pairs(_tGames) do
                tRet[#tRet + 1] = tGame.Name;
            end

            table.sort(tRet, SortByName);

            return tRet;
        end,
        --GameExists = function(sGame) end
        GetByName = function(sName)
            local vRet;

            if not (rawtype(sName) == "string") then
                error("Game.GetByName: Argument 1 must be of type string. Got "..rawtype(sName)..'.');
            end

            for sUUID, tGame in pairs(_tGames) do

                if (sName == tGame.Name) then
                    vRet = tGame.Object;
                    break;
                end

            end

            return vRet;
        end,
        New = function()
            local sGame             = Dialog.Input("Create New Game", "Game name:", "", MB_ICONINFORMATION);
            local bCancelPressed    = sGame == "CANCEL";
            local bIsEmpty          = sGame:isempty();

            if (not bCancelPressed and not bIsEmpty) then

                if (bIsFilesafe) then
                    Game.Prep(sGame);
                    MainMenu.RefreshGamesList();
                end

            end

        end,
        Prep = function(vGame) --TODO REDO THIS NOW THAT IT'S IN THIS MODULE TO INCLUDE VERIFYING THE INPUT

            if not (type(vGame) == "string" and not vGame:isempty()) then
                error("Game.Prep: Error prepping game. Argument 1 must be a non-blank string. Got "..tostring(vGame)..' ('..type(vGame)..').');
            end

            local sGame = vGame;

            local oGame = Game.GetByName(sGame);

            if not (type(oGame) == "Game") then
                error("Game.Prep: Error prepping game. Could not find game object for \""..sGame..'."');
            end

            Game.SetActive(sGame);

            FS.PrepGame(oGame); --set the filepaths for the current game

            --load in the user's CFG table
            local tCFG = BuildUserTable(sGame, "CFG");
            UserEnv.UpdateCFG(tCFG);

            --load in the user's ENV table
            local tEnv = BuildUserTable(sGame, "ENV");
            UserEnv.UserUpdateRoot(tEnv);

            UpdateFileRepo(oGame);

            --reset the BuildMechanics var (it gets reloaded in Init.lua if present)
            BuildMechanics = nil; --TODO WHAT IS THIS?'

            --build the user's mechanics html if it exists QUESTION qhat is this? Is it used?
            if type(BuildMechanics) == "function" then
                local sHTML = BuildMechanics(CFG);

                if (type(sHTML) == "string") then
                    TextFile.WriteFromString(_pGame.."\\Mechanics.html", sHTML, false);
                end

            end

            ProcessDox(pGame);--TODO get this boolean from INI file before running Dox

            Forge.LoadStyles();
        end,
        --rebuilds all game objects and refreshes the private static info
        Refresh = function()
            --clear out all games
            _tGames = {};

            --iterate over all potential game folders
            local tGameFolders  = Folder.Find(FS.Games.."\\", "*", false, nil);

            if (type(tGameFolders) == "table") then

                for _, pGameFolder in pairs(tGameFolders) do
                    --try to create the new game object
                    Game(pGameFolder);
                end

            end

        end,
        SetActive = function(vGame) --TODO update game objects MOVE THIS TO LOCAL SINCE NO ONE OUTSIDE THE CLASS WILL BE CALLING IT AND REMOVE CHECKS SINCE WE ALREADY DO THAT FIRST
            local zName = type(vGame);
            local oGame;

            if (zName == "string") then

                if (_tGames[vGame] ~= nil) then
                    oGame = _tGames[vGame].Object;

                else

                    for sUUID, tGame in pairs(_tGames) do

                        if (tGame.Name:lower() == vGame:lower()) then
                            oGame = tGame.Object;
                            break;
                        end

                    end

                end

            elseif (zName == "Game") then
                _oActiveGame = vGame;

            else
                error("TODO: BAD THINGS HERE WRONG TYPE");

            end

            if not (oGame) then
                error("TODO: BAD THINGS HERE..no game object found");
            end

            _oActiveGame = oGame;
        end
    },
    {--PRIVATE
        Env__AUTOR_             = null,
        CFG__AUTOR_             = null,
        CardSets                = {},
        IncludePlugins__AUTOA_  = false,
        LiveFileRepo__AUTO__    = null,
        Name__AUTOA_            = '',
        Path__AUTOR_            = null,
        UUID__AUTOR_            = null,
    },
    {--PROTECTED

    },
    {--PUBLIC
        Game = function(this, cdat, pFolder)
            local pri = cdat.pri;

            --validate the input string and ensure it leads to a valid directory
            if not (rawtype(pFolder) == "string" and Folder.DoesExist(pFolder)) then
                error("Invalid game: Game path must lead to an existing directory.", 3);
            end

            --set the game's folder
            pri.Path = pFolder;
            --create the LiveFileRepo

            --update my info
            ValidateAndUpdateGame(this, cdat);
        end,
        GetAllCardSets = function(this, cdat)
            local pri = cdat.pri;
            local tRet = {};

            for sUUID, tCardSet in pairs(pri.CardSets) do
                tRet[#tRet + 1] = tCardSet.Object;
            end

            table.sort(tRet, SortByName);

            return tRet;
        end,
        GetCardSet = function(this, cdat, sUUID)
            local pri = cdat.pri;
            local vRet;

            if not (rawtype(sUUID) == "string") then
                error("GetCardSet: Argument 1 must be of type string. Got "..rawtype(sUUID)..'.');
            end

            for sCardSetUUID, tCardSet in pairs(pri.CardSets) do

                if (sCardSetUUID:lower() == sUUID:lower()) then
                    vRet = tCardSet.Object;
                    break;
                end

            end

            return vRet;
        end,
        GetCardSetByName = function(this, cdat, sName)
            local pri = cdat.pri;
            local vRet;

            if not (rawtype(sName) == "string") then
                error("GetCardSetByName: Argument 1 must be of type string. Got "..rawtype(sName)..'.');
            end

            for sUUID, tCardSet in pairs(pri.CardSets) do

                if (sName == tCardSet.Name) then
                    vRet = tCardSet.Object;
                    break;
                end

            end

            return vRet;
        end,
        GetCardSetNames = function(this, cdat)
            local pri = cdat.pri;
            local tRet = {};

            for sUUID, tCardSet in pairs(pri.CardSets) do
                tRet[#tRet + 1] = tCardSet.Name;
            end

            table.sort(tRet, SortByName);

            return tRet;
        end,
        NewCardSet = function(this, cdat)

        end,
        --updates game, all game's card sets, and all LiveFiles
        Update = ValidateAndUpdateGame,
    },
    nil,   --extending class
    true,  --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
