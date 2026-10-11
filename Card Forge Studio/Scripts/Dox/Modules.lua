--[[!
@fqxn CFS.Modules
@desc
<section aria-label="Modules overview">
    <header style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem">
        <p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p>
        <h2 style="margin:.5rem 0">Modules</h2>
        <p style="font-size:1.15rem;margin:0">Shared services connect project files, processing, artwork, and output.</p>
    </header>
    <h3>How this part fits</h3>
    <p>These pieces do jobs for the application rather than representing an individual game or card set. Their overviews explain the handoffs so you can follow a card from its source values to its finished image.</p>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,250px),1fr));gap:1rem;margin:1rem 0">
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.FS">File System</a></h3>
            <p style="margin:0">Finds and prepares the files other services use.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.ProcSys">Processing System</a></h3>
            <p style="margin:0">Loads scripts and data, processes values, and coordinates updates.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Forge">Forge</a></h3>
            <p style="margin:0">Draws the selected card and supplies rendered output.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Exporter">Exporter</a></h3>
            <p style="margin:0">Stages and commits the files produced by a dedicated exporter.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.UserEnv">User Environment</a></h3>
            <p style="margin:0">Prepares the shared environment used by game scripts.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Wiki">Wiki</a></h3>
            <p style="margin:0">Connects written game material with document formatting and storage.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Documentation">Documentation names</a></h3>
            <p style="margin:0">Keeps matching generated Dox names aligned with metadata renames.</p>
        </article>
    </div>
    <aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0">
        <strong>Good to know</strong>
        <p style="margin:.4rem 0 0">A module overview describes its role. Its child entries describe exact APIs; deferred services are identified explicitly.</p>
    </aside>
</section>
!]]
