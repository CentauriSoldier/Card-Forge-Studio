--[[!
@fqxn CFS.Classes.Game
@desc
<section aria-label="Game overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Game</h2><p style="font-size:1.15rem;margin:0">A game is the home for a whole project: its name, shared settings, and collection of card sets.</p></div>
<h3>How it fits into your work</h3><p>Choose a game, then one of its card sets. Creating a project prepares its files; activation selects it for work. Game keeps project identity separate from the cards you are editing.</p>
<figure style="margin:1.5rem 0"><figcaption style="font-weight:700;margin-bottom:.8rem">The big picture</figcaption><div role="img" aria-label="Discover a game then Activate the project then Choose a card set then Load and preview" style="display:flex;flex-wrap:wrap;align-items:center;gap:.7rem"><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Discover a game</span><span aria-hidden="true" style="color:var(--accent)">→</span><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Activate the project</span><span aria-hidden="true" style="color:var(--accent)">→</span><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Choose a card set</span><span aria-hidden="true" style="color:var(--accent)">→</span><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Load and preview</span></div></figure>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.FS">File System</a></h3><p style="margin:0">Game asks FS to discover project folders, create starter files, and validate paths before activation.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.CardSet">Card Set</a></h3><p style="margin:0">Game discovers and caches the card sets owned by its project. Choosing one is the next step after game activation.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys">Processing System</a></h3><p style="margin:0">Activation asks ProcSys to prepare the new game and release the previous card preview. Loading a set happens separately.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.GameEditor">GameEditor</a></h3><p style="margin:0">The editor changes the shared Environment and Config files that belong to the game.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Activation does not load a card set or automatically rebuild game documentation. ProcSys handles the working data after a set is chosen.</p></aside>
<h3>A game’s lifecycle</h3><ol><li><strong>Discover:</strong> Studio scans game folders and reads usable metadata for the chooser.</li><li><strong>Create:</strong> a new game receives its starter folders and files, then returns as an object ready for the caller to activate.</li><li><strong>Activate:</strong> paths are prepared, card sets are discovered, and the previous set’s processing state is cleared.</li><li><strong>Work:</strong> choose a card set to load its data and scripts. Game remains the project owner while the other services do the editing and rendering.</li></ol><p>Think of Game as the project binder: it knows which collection belongs where. It does not need to do the work of the spreadsheet, drawing desk, or export service.</p>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

local _tGames       = {}; --keys are uuids, values are {Game = GameObject, Name = NameString}
local _oActiveGame  = false;

-- CardSet is imported when discovery is requested.

--[[!
@fqxn CFS.Classes.Game.Private.Functions.SortByName
@desc Compares game or card-set objects by display name.
@param any oItemA o Item A.

@param any oItemB o Item B.
!]]
local function SortByName(oItemA, oItemB)
    return oItemA.GetName() < oItemB.GetName();
end

--[[!
@fqxn CFS.Classes.Game.Private.Functions.UpdateCardSets
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
        @fqxn CFS.Classes.Game.Methods.Deactivate
        @pulsarlua function Game.Deactivate
        @desc Closes active processing and filesystem state without removing the game from discovery or deleting its files.
        !]]
        Deactivate = function()
            ProcSys.CloseGame();
            FS.Game.Clear();
            _oActiveGame = false;
            Log.Note("Game closed: no active game.");
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
