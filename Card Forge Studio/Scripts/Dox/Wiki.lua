--[[!
@fqxn CFS.Modules.Wiki
@desc
<section aria-label="Wiki Services overview">
    <header style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem">
        <p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p>
        <h2 style="margin:.5rem 0">Wiki Services</h2>
        <p style="font-size:1.15rem;margin:0">The Wiki services keep the game’s written material organized, readable, and safely stored.</p>
    </header>
    <h3>How this part fits</h3>
    <p>The Wiki window is where you write. Supporting services handle rich-text document structure, page and image storage, and reading palettes. Keeping those jobs separate lets presentation change without confusing page identity.</p>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,250px),1fr));gap:1rem;margin:1rem 0">
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Windows.Wiki">Wiki window</a></h3>
            <p style="margin:0">Navigate and edit game pages with rich text, code, and images.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Wiki.Document">Documents</a></h3>
            <p style="margin:0">Formats headings, lists, code boxes, and serialized rich text.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Wiki.Store">Storage</a></h3>
            <p style="margin:0">Manages drafts, stable page identities, images, and conflict-aware saves.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.Wiki.Themes">Themes</a></h3>
            <p style="margin:0">Supplies palettes with an independent Wiki selection.</p>
        </article>
    </div>
    <aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0">
        <strong>Good to know</strong>
        <p style="margin:.4rem 0 0">Game Wiki pages and generated Studio API documentation are different kinds of content with separate storage and presentation.</p>
    </aside>
</section>
!]]
