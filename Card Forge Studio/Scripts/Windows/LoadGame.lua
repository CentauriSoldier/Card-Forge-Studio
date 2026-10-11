--[[!
@fqxn CFS.Windows.LoadGame
@desc
<section aria-label="LoadGame overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">LoadGame</h2><p style="font-size:1.15rem;margin:0">The game chooser presents projects as easy-to-scan logo cards.</p></div>
<h3>How it fits into your work</h3><p>Choose a discovered game. A readable square Logo.png in its root supplies the picture; other cases use the shared fallback.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.Game">Game</a></h3><p style="margin:0">A game is the home for a whole project: its name, shared settings, and collection of card sets.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Loaders.Common">Loaders.Common</a></h3><p style="margin:0">The shared chooser supplies the same visual language for games and card sets.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.WindowState">WindowState</a></h3><p style="margin:0">WindowState remembers useful native-window choices outside game folders.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">The chooser starts with room for three items, remembers resized dimensions, and centers over Studio.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

local LoadGame = {};


--[[!
@fqxn CFS.Windows.LoadGame.Functions.Show
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
        @fqxn CFS.Windows.LoadGame.Private.Functions.root
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
