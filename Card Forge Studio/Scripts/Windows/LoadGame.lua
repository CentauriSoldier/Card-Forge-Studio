--[[!
@fqxn CFS.Windows.LoadGame
@desc Styled game-selection dialog using game-root Logo.png or the shared fallback.
!]]

local LoadGame = {};


--[[!
@fqxn CFS.Windows.LoadGame.Show
@pulsarlua function LoadGame.Show
@desc Opens the game-card chooser with a three-card default height. User resizing is remembered; position remains centered on the parent.
@param wxWindow dParent Parent window.
@param table tGames Discovered games in display order.
@return number Zero-based selected index, or -1 after cancellation.
!]]
function LoadGame.Show(dParent, tGames)
    return require("Windows.Loaders.Common").Show(dParent, tGames, {
        description = "Choose a game to continue creating.",
        heading     = "Your Games",
        --[[!
        @fqxn CFS.Windows.LoadGame.Private.root
        @desc Returns the selected game's root folder for logo lookup.
        @param any oGame Game.
        @vis private
        !]]
        root        = function(oGame) return FS.Game.GetRoot(oGame.GetUUID()); end,
        state       = "LoadGame",
        title       = "Load Game",
    });
end


return LoadGame;
