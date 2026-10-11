--[[!
@fqxn CFS.Classes
@desc
<section aria-label="Classes overview">
    <header style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem">
        <p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p>
        <h2 style="margin:.5rem 0">Classes</h2>
        <p style="font-size:1.15rem;margin:0">Project objects and reusable types give different parts of Studio a clear identity.</p>
    </header>
    <h3>How this part fits</h3>
    <p>A game and a card set represent things you work on. Other classes supply reusable behavior, such as text styling, logging, and file watching. Start with their overview cards; follow their child entries when you need individual operations.</p>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,250px),1fr));gap:1rem;margin:1rem 0">
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Classes.Game">Game</a></h3>
            <p style="margin:0">The project owner: shared settings and the collection of card sets.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Classes.CardSet">Card Set</a></h3>
            <p style="margin:0">One collection’s identity, dimensions, and metadata.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Classes.FontStyle">Font Style</a></h3>
            <p style="margin:0">Reusable text appearance, including inherited settings and effects.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Classes.LiveFileRepo">Live File Repository</a></h3>
            <p style="margin:0">Watches tracked files and reports changes to the processing system.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Classes.Log">Log</a></h3>
            <p style="margin:0">Keeps recorded messages available on disk and in the log window.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Classes.Forge">Retained Forge reference</a></h3>
            <p style="margin:0">Explains why an older renderer reference appears here and points to the active service.</p>
        </article>
    </div>
    <aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0">
        <strong>Good to know</strong>
        <p style="margin:.4rem 0 0">Classes and modules are navigation categories, not competing systems. Lua files can return classes; Studio groups object types here and shared services under Modules.</p>
    </aside>
</section>
!]]
