--[[!
@fqxn CFS.Windows.Editors
@desc
<section aria-label="Shared Editor Support overview">
    <header style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem">
        <p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p>
        <h2 style="margin:.5rem 0">Shared Editor Support</h2>
        <p style="font-size:1.15rem;margin:0">Common editing support protects drafts and makes file saving consistent.</p>
    </header>
    <h3>How this part fits</h3>
    <p>The game and card-set editors show different files, but they share validation, staging, and external-edit checks. This group documents that supporting layer rather than another source window.</p>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,250px),1fr));gap:1rem;margin:1rem 0">
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Windows.Editors.Common">Common helper</a></h3>
            <p style="margin:0">Draft handling and protected source-file saves.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Windows.GameEditor">Game Editor</a></h3>
            <p style="margin:0">Shared Environment and Config sources.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Windows.CardSetEditor">Card Set Editor</a></h3>
            <p style="margin:0">Drawing and processing sources for the active set.</p>
        </article>
    </div>
    <aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0">
        <strong>Good to know</strong>
        <p style="margin:.4rem 0 0">Use the actual editor windows to work on files. These helpers explain the common behavior behind them.</p>
    </aside>
</section>
!]]
