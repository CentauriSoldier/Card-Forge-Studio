--[[!
@fqxn CFS.Classes.Forge
@desc
<section aria-label="Forge · Retained Class Reference overview">
    <header style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem">
        <p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p>
        <h2 style="margin:.5rem 0">Forge · Retained Class Reference</h2>
        <p style="font-size:1.15rem;margin:0">This branch contains documentation retained from the earlier renderer.</p>
    </header>
    <h3>How this part fits</h3>
    <p>The active native Forge is a shared service under Modules. Use that overview to understand current drawing and preview behavior. This category keeps the older Draw documentation discoverable without presenting it as a second active renderer.</p>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,250px),1fr));gap:1rem;margin:1rem 0">
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Forge">Active Forge</a></h3>
            <p style="margin:0">Current drawing callbacks, preview rendering, and image output.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Windows.Main">Main window</a></h3>
            <p style="margin:0">Hosts the native preview canvas and interaction controls.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Classes.Forge.Methods.Draw">Retained Draw entry</a></h3>
            <p style="margin:0">Reference material attached to the retained renderer implementation.</p>
        </article>
    </div>
    <aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0">
        <strong>Good to know</strong>
        <p style="margin:.4rem 0 0">This branch does not mean you should construct a separate Forge class for the current application. The active implementation is the Forge module.</p>
    </aside>
</section>
!]]
