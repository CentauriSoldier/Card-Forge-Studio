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
    local bOK, sRetOrError = pcall(fChunk);

    if not (bOK) then
        error("Error running "..sName.." file for Game "..sGame..".\r\n"..sRetOrError, 2);
    end

    local tUserTable = sRetOrError;

    if not (type(tUserTable) == "table") then
        error("Error in return from "..sName.." file for Game "..sGame..".\r\nExpected type table, Got "..type(tUserTable)..'.', 2);
    end

    return tUserTable;
end

local _nUserFileRepoInterval = 400;





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
                    Game.Activate(sGame);
                    MainMenu.RefreshGamesList();
                end

            end

        end,
        Activate = function(oGame) --TODO REDO THIS NOW THAT IT'S IN THIS MODULE TO INCLUDE VERIFYING THE INPUT

            if not (type(oGame) == "Game") then
                error("Game.Activate: Error activating game. Expected game object. Got "..type(oGame)..'.');
            end

            _oActiveGame = oGame;

            FS.PrepGame(oGame); --set the filepaths for the current game

            local sGame = oGame.GetName();
--TODO MOVING TO PROCSYS
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
    },
    {--PRIVATE
        Env__AUTOR_             = null,
        CFG__AUTOR_             = null,
        CardSets                = {},
        IncludePlugins__AUTOA_  = false,
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
