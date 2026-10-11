--[[!
@fqxn CFS.Windows.LoadCardSet
@desc
<section aria-label="LoadCardSet overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">LoadCardSet</h2><p style="font-size:1.15rem;margin:0">The card-set chooser presents the active game's sets as logo cards.</p></div>
<h3>How it fits into your work</h3><p>Choose a set. Readable square set-root Logo.png images are shown; missing or invalid images use the shared fallback.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.CardSet">Card Set</a></h3><p style="margin:0">A card set brings together one collection of cards, its dimensions, and the files that describe how those cards look and behave.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Loaders.Common">Loaders.Common</a></h3><p style="margin:0">The shared chooser supplies the same visual language for games and card sets.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.WindowState">WindowState</a></h3><p style="margin:0">WindowState remembers useful native-window choices outside game folders.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Its remembered dimensions are independent of the game chooser's size.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

local LoadCardSet = {};


--[[!
@fqxn CFS.Windows.LoadCardSet.Functions.Show
@pulsarlua function LoadCardSet.Show
@desc Opens a card-set chooser with square logos and the shared NoLogo fallback. Size is remembered independently of the game chooser.
@param wxWindow dParent Parent window.
@param table tCardSets Card sets in display order.
@return number Zero-based selected index, or -1 after cancellation.
!]]
function LoadCardSet.Show(dParent, tCardSets)
    return require("Windows.Loaders.Common").Show(dParent, tCardSets, {
        description = "Choose a card set to continue creating.",
        heading     = "Your Card Sets",
        --[[!
        @fqxn CFS.Windows.LoadCardSet.Private.Functions.root
        @desc Returns the selected card set's root folder for logo lookup.
        @param any oCardSet Card set.
        @vis private
        !]]
        root        = function(oCardSet) return FS.CardSet.GetRoot(oCardSet.GetGameUUID(), oCardSet.GetUUID()); end,
        state       = "LoadCardSet",
        title       = "Load Card Set",
    });
end


return LoadCardSet;
