--[[!
@fqxn CFS.Classes.Game
@desc Game discovery, creation, activation, and card-set metadata access.
!]]

local _tGames       = {}; --keys are uuids, values are {Game = GameObject, Name = NameString}
local _oActiveGame  = false;

-- CardSet is imported when discovery is requested.

--[[!
@fqxn CFS.Classes.Game.Private.SortByName
@desc Compares game or card-set objects by display name.
@param any oItemA o Item A.

@param any oItemB o Item B.
!]]
local function SortByName(oItemA, oItemB)
    return oItemA.GetName() < oItemB.GetName();
end

--[[!
@fqxn CFS.Classes.Game.Private.UpdateCardSets
@desc Rebuilds card-set discovery for this game.
!]]
local function UpdateCardSets(this, cdat)
    local CardSet = require("CardSet");
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
        --[[!
        @fqxn CFS.Classes.Game.Methods.Activate
        @pulsarlua function Game.Activate
        @desc Prepares filesystem paths, discovers card sets, and activates processing.
        @param any oGame o Game.
        !]]
        Activate = function(oGame)

            if not (type(oGame) == "Game") then
                error("Game.Activate: Error activating game. Expected Game object. Got "..type(oGame)..'.');
            end

            Log.Note("Game.Activate: Loading game, \""..oGame.GetName()..'".');

            --set the filepaths for the current game
            FS.Game.Prep(oGame);

            --update this game's card sets
            oGame.UpdateCardSets();
            -- TODO Restore ProcessDox as an explicit writable operation; it writes game documentation.
            ProcSys.PrepGame(oGame);
            _oActiveGame = oGame;

            Log.Note("Game.Activate: Game loaded.");
        end,


        --[[!
        @fqxn CFS.Classes.Game.Methods.GetActive
        @pulsarlua function Game.GetActive
        @desc Returns the active game, or false when none is loaded.
        !]]
        GetActive = function()
            return _oActiveGame;
        end,


        --[[!
        @fqxn CFS.Classes.Game.Methods.GetAll
        @pulsarlua function Game.GetAll
        @desc Returns discovered game objects sorted by name.
        !]]
        GetAll = function()
            local tRet = {};

            for sUUID, tGame in pairs(_tGames) do
                tRet[#tRet + 1] = tGame.Object;
            end

            table.sort(tRet, SortByName);

            return tRet;
        end,


        --[[!
        @fqxn CFS.Classes.Game.Methods.GetByName
        @pulsarlua function Game.GetByName
        @desc Finds a discovered game with the specified display name.
        @param any sName s Name.
        !]]
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


        --[[!
        @fqxn CFS.Classes.Game.Methods.GetNames
        @pulsarlua function Game.GetNames
        @desc Returns discovered game names sorted alphabetically.
        !]]
        GetNames = function()
            local tRet = {};

            for sUUID, tGame in pairs(_tGames) do
                tRet[#tRet + 1] = tGame.Name;
            end

            table.sort(tRet);

            return tRet;
        end,


        --[[!
        @fqxn CFS.Classes.Game.Methods.New
        @pulsarlua function Game.New
        @desc Creates and registers an empty game. Activation is left to the caller so normal unsaved-change checks can run first.
        @param string sName Display name.
        @return Game New game object.
        !]]
        New = function(sName)
            if (rawtype(sName) ~= "string" or not sName:match("%S") or sName:find("[%c]")) then
                error("A game name must contain visible text and no control characters.", 2);
            end

            local sUUID = string.uuid(true);
            FS.Game.Create(sUUID, sName);
            local oGame = Game(sUUID);
            _tGames[sUUID] = {
                Name   = oGame.GetName(),
                Object = oGame,
            };

            return oGame;
        end,


        --[[!
        @fqxn CFS.Classes.Game.Methods.Refresh
        @pulsarlua function Game.Refresh
        @desc Rebuilds game discovery and logs invalid metadata.
        !]]
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
                --[[!
        @fqxn CFS.Classes.Game.Methods.GetEnv
        @pulsarlua function Game.GetEnv
        @desc Returns the stored Env value through the generated public accessor.
        @return any Stored Env value.
        !]]
Env__AUTOR_             = null,
                --[[!
        @fqxn CFS.Classes.Game.Methods.GetCFG
        @pulsarlua function Game.GetCFG
        @desc Returns the stored CFG value through the generated public accessor.
        @return any Stored CFG value.
        !]]
CFG__AUTOR_             = null,
        CardSets                = {},
                --[[!
        @fqxn CFS.Classes.Game.Methods.GetIncludePlugins
        @pulsarlua function Game.GetIncludePlugins
        @desc Returns the stored IncludePlugins value through the generated public accessor.
        @return any Stored IncludePlugins value.
        !]]
IncludePlugins__AUTOA_  = false,
        Name__AUTOA_            = '',
                --[[!
        @fqxn CFS.Classes.Game.Methods.GetUUID
        @pulsarlua function Game.GetUUID
        @desc Returns the stored UUID value through the generated public accessor.
        @return any Stored UUID value.
        !]]
UUID__AUTOR_            = null,
    },
    {--PROTECTED

    },
    {--PUBLIC
        --[[!
        @fqxn CFS.Classes.Game.Methods.Game
        @pulsarlua function Game
        @desc Loads game metadata from its existing Info.ini.
        @param any sUUID s UUID.
        !]]
        Game = function(this, cdat, sUUID)
            local pri = cdat.pri;

            if (rawtype(sUUID) ~= "string" or not sUUID:isuuid()) then
                error("Game requires a valid UUID string.", 2);
            end

            pri.UUID = sUUID:upper();

            local pINI = FS.Game.GetInfoINIPath(sUUID);
            local sSection = "SETTINGS";

            pri.IncludePlugins  = INIFile.GetValueBoolean(  pINI, sSection, "IncludePlugins");
            pri.Name            = INIFile.GetValue(         pINI, sSection, "Name");

            if (rawtype(pri.Name) ~= "string" or not pri.Name:match("%S") or pri.Name:find("[%c]")) then
                error("Invalid game name in "..pINI, 2);
            end
        end,


        --[[!
        @fqxn CFS.Classes.Game.Methods.GetAllCardSets
        @pulsarlua function Game.GetAllCardSets
        @desc Returns this game’s card sets sorted by name.
        !]]
        GetAllCardSets = function(this, cdat)
            local pri = cdat.pri;
            local tRet = {};

            for sUUID, tCardSet in pairs(pri.CardSets) do
                tRet[#tRet + 1] = tCardSet.Object;
            end

            table.sort(tRet, SortByName);

            return tRet;
        end,


        --[[!
        @fqxn CFS.Classes.Game.Methods.GetCardSet
        @pulsarlua function Game.GetCardSet
        @desc Finds a card set by its identifier.
        @param any sUUID s UUID.
        !]]
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


        --[[!
        @fqxn CFS.Classes.Game.Methods.GetCardSetByName
        @pulsarlua function Game.GetCardSetByName
        @desc Finds a card set by its display name.
        @param any sName s Name.
        !]]
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


        --[[!
        @fqxn CFS.Classes.Game.Methods.RefreshInfo
        @pulsarlua function Game.RefreshInfo
        @desc Refreshes the loaded game name after metadata changes.
        !]]
        RefreshInfo = function(this, cdat)
            local pri = cdat.pri;
            local pInfo = FS.Game.GetInfoINIPath(pri.UUID);
            local sName = INIFile.GetValue(pInfo, "SETTINGS", "Name");
            assert(type(sName) == "string" and sName:match("%S") and not sName:find("[\r\n]"), "Invalid game name in "..pInfo);
            pri.Name = sName;
            if (_tGames[pri.UUID]) then _tGames[pri.UUID].Name = sName; end
        end,


        --updates game, all game's card sets, and all LiveFiles
        UpdateCardSets = UpdateCardSets,
    },
    nil,   --extending class
    true,  --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
