--[[!
@fqxn CFS.Modules.Exporter.Exporters
@desc
<section aria-label="Export Formats overview">
    <header style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem">
        <p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p>
        <h2 style="margin:.5rem 0">Export Formats</h2>
        <p style="font-size:1.15rem;margin:0">Dedicated exporters decide what to produce while the coordinator handles safe file commits.</p>
    </header>
    <h3>How this part fits</h3>
    <p>Choose a working format from the grid. Each implementation plans its own output and rendering choices. This category keeps available output separate from the retained future-format skeletons.</p>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,250px),1fr));gap:1rem;margin:1rem 0">
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Exporter.Exporters.ExporterPNG">PNG · Available</a></h3>
            <p style="margin:0">Produces card image files with face, scale, scope, and destination choices.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Exporter.Exporters.ExporterAtlas">Atlas · Available</a></h3>
            <p style="margin:0">Packs card artwork into PNG sheets with Generic format 1 JSON or LÖVE 11.5 Lua metadata. Choose the target version, sheet size, padding, faces, and scale; options are saved per card set.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Exporter.Exporters.ExporterCSV">CSV · Available</a></h3>
            <p style="margin:0">Writes finalized text values as UTF-8 CSV, with optional headers and spreadsheet BOM. Preserves the requested rows and original column order.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Exporter.Exporters.ExporterHTML">HTML · Available</a></h3>
            <p style="margin:0">Builds a themed offline gallery with search, filters, sorting, enlarged viewing, front/back switching, and finalized details.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Exporter.Exporters.ExporterJSON">JSON · Available</a></h3>
            <p style="margin:0">Writes finalized text values as CFS Card Data version 1 JSON, with ordered columns and original source-row identifiers.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Exporter.Exporters.ExporterLua">Lua · Available</a></h3>
            <p style="margin:0">Writes finalized text values as a plain Lua data table, using the same ordered schema as JSON.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Exporter.Exporters.ExporterPDFSheets">PDFSheets · Deferred</a></h3>
            <p style="margin:0">Reserved format skeleton; not currently an enabled export workflow.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Exporter.Exporters.ExporterPlayingCardsIO">PlayingCardsIO · Deferred</a></h3>
            <p style="margin:0">Reserved format skeleton; not currently an enabled export workflow.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Exporter.Exporters.ExporterPrintAndPlay">PrintAndPlay · Deferred</a></h3>
            <p style="margin:0">Reserved format skeleton; not currently an enabled export workflow.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Exporter.Exporters.ExporterScreentop">Screentop · Deferred</a></h3>
            <p style="margin:0">Reserved format skeleton; not currently an enabled export workflow.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Exporter.Exporters.ExporterTabletopPlayground">TabletopPlayground · Deferred</a></h3>
            <p style="margin:0">Reserved format skeleton; not currently an enabled export workflow.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Exporter.Exporters.ExporterTableTopSimulator">TableTopSimulator · Deferred</a></h3>
            <p style="margin:0">Reserved format skeleton; not currently an enabled export workflow.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Exporter.Exporters.ExporterUnityPackage">UnityPackage · Deferred</a></h3>
            <p style="margin:0">Reserved format skeleton; not currently an enabled export workflow.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Exporter.Exporters.ExporterZip">ZIP · Available</a></h3>
            <p style="margin:0">Packages chosen PNG artwork, finalized CSV/JSON/Lua data, and a themed HTML gallery into one ZIP. Gallery contents include their required artwork.</p>
        </article>
    </div>
    <aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0">
        <strong>Good to know</strong>
        <p style="margin:.4rem 0 0">PNG, Atlas, CSV, JSON, Lua, HTML, and ZIP are enabled. Each keeps its own settings and destination per card set. Atlas supports Generic format 1 and LÖVE 11.5; other atlas targets, print, engine packages, and tabletop formats remain planned.</p>
    </aside>
</section>
!]]
