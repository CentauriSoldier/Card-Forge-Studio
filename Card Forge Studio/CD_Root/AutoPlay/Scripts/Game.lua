local _tGames       = {}; --keys are uuids, values are {Game = GameObject, Name = NameString}
local _oActiveGame  = false;
local GetCRC        = File.GetCRC
local ReadToString  = TextFile.ReadToString;
local io            = io;
--TODO with New methods, checkf or existing item first...do not overwrite

local CardSet   = require("CardSet");

local function SortByName(oItemA, oItemB)
    return oItemA.GetName() < oItemB.GetName();
end

local function UpdateCardSets(this, cdat)
    local pri = cdat.pri;

    --updade the game's card sets
    pri.CardSets = {};

    local sGameUUID = this.GetUUID();

    --iterate over all potential card set folders
    local tCardSetUUIDs  = FS.Game.GetCardSetUUIDs(sGameUUID);

    if (tCardSetUUIDs) then

        for _, sUUID in pairs(tCardSetUUIDs) do

                --try to create the new cardset object
                local oCardSet = CardSet(sGameUUID, sUUID);
                --TODO check that card set is valid (at least check inside cardset const)
                pri.CardSets[sUUID] = {
                    Name    = oCardSet.GetName();
                    Object  = oCardSet,
                };


        end

    end

end

return class("Game",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --Game = function(this, sAuthCode) end, --static constructor (runs after class object creation)
        --INFOINI_SECTIONS = _eInfoINISections,
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
                    --Game.Activate(sGame);
                    MainMenu.RefreshGamesList();
                end

            end

        end,
        Activate = function(oGame)

            if not (type(oGame) == "Game") then
                error("Game.Activate: Error activating game. Expected Game object. Got "..type(oGame)..'.');
            end

            _oActiveGame = oGame;

            Log.Note("Game.Activate: Loading game, \""..oGame.GetName()..'".');

            --set the filepaths for the current game
            FS.Game.Prep(oGame);
            --update this game's card sets
            oGame.UpdateCardSets();
            --TODO get this boolean from INI file before running Dox
            ProcessDox();
            ProcSys.PrepGame(oGame);

            Log.Note("Game.Activate: Game loaded.");
        end,
        --rebuilds all game objects and refreshes the private static info
        Refresh = function()
            --clear out all games
            _tGames = {};

            --iterate over all potential game folders
            local tGameUUIDs = FS.Game.GetUUIDs();

            if (tGameUUIDs) then

                for _, sUUID in pairs(tGameUUIDs) do

                    --try to create the new game object
                    local bSuccess, oGameOrErr = pcall(Game, sUUID);

                    if (bSuccess) then
                        local sName = oGameOrErr.GetName();

                        if (sName:isempty()) then
                            Log.Warning("Error creating game object, '"..sUUID.."'.\r\nGame name must be a non-blank string.");
                        else
                            --if the game is valid, add it to the list of games
                            _tGames[sUUID] = {
                                Name    = sName,
                                Object  = oGameOrErr,
                            };

                        end

                    else
                        Log.Warning("Error creating game object, '"..sUUID.."'.\r\n"..oGameOrErr);
                    end

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
        UUID__AUTOR_            = null,
    },
    {--PROTECTED

    },
    {--PUBLIC
        --assumes this is being called by the refresh function (after getting data from FS)
        Game = function(this, cdat, sUUID)
            local pri = cdat.pri;

            --TODO validate input

            pri.UUID = sUUID:upper();

            local pINI = FS.Game.GetInfoINIPath(sUUID);
            local sSection = "SETTINGS";

            pri.IncludePlugins  = INIFile.GetValueBoolean(  pINI, sSection, "IncludePlugins");
            pri.Name            = INIFile.GetValue(         pINI, sSection, "Name");

            --UpdateCardSets(this, pri);
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
        --[[GetCardSetNames = function(this, cdat)
            local pri = cdat.pri;
            local tRet = {};

            for sUUID, tCardSet in pairs(pri.CardSets) do
                tRet[#tRet + 1] = tCardSet.Name;
            end

            table.sort(tRet, SortByName);

            return tRet;
        end,
        NewCardSet = function(this, cdat)

        end,]]
        --updates game, all game's card sets, and all LiveFiles
        UpdateCardSets = UpdateCardSets,
    },
    nil,   --extending class
    true,  --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
