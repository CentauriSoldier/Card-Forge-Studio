--[[!
@fqxn CFS.Windows.Loaders
@desc
<section aria-label="Shared Chooser Support overview">
    <header style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem">
        <p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p>
        <h2 style="margin:.5rem 0">Shared Chooser Support</h2>
        <p style="font-size:1.15rem;margin:0">Game and card-set selection use the same visual language.</p>
    </header>
    <h3>How this part fits</h3>
    <p>The common chooser builds logo cards and checks that supplied logos are readable and square. Individual chooser windows supply their own project list and remembered dimensions.</p>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,250px),1fr));gap:1rem;margin:1rem 0">
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Windows.Loaders.Common">Common chooser</a></h3>
            <p style="margin:0">Shared layout, logo validation, and fallback behavior.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Windows.LoadGame">Load Game</a></h3>
            <p style="margin:0">Choose a project.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Windows.LoadCardSet">Load Card Set</a></h3>
            <p style="margin:0">Choose a collection in the active project.</p>
        </article>
    </div>
    <aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0">
        <strong>Good to know</strong>
        <p style="margin:.4rem 0 0">These pages explain the chooser interface, not the processing that happens after a selection is accepted.</p>
    </aside>
</section>
!]]
