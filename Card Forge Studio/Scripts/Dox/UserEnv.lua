--[[!
@fqxn CFS.Modules.UserEnv
@desc
<section aria-label="User Environment Service overview">
    <header style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem">
        <p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p>
        <h2 style="margin:.5rem 0">User Environment Service</h2>
        <p style="font-size:1.15rem;margin:0">This service prepares the shared workspace that game scripts use.</p>
    </header>
    <h3>How this part fits</h3>
    <p>ProcSys loads Config and Environment values and evaluates scripts against UserEnv. This branch describes the service operations; the separate UserEnv topic describes the names made available inside scripts.</p>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,250px),1fr));gap:1rem;margin:1rem 0">
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.UserEnv">Script-visible environment</a></h3>
            <p style="margin:0">Explore the helpers and drawing commands scripts can use.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.UserEnv.Functions.Get">Get the environment</a></h3>
            <p style="margin:0">The service provides the prepared environment used for execution.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.UserEnv.Functions.GetCommandList">List commands</a></h3>
            <p style="margin:0">Inspect the callable names exposed by that environment.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Modules.ProcSys">Processing System</a></h3>
            <p style="margin:0">Loads and updates game values before processing cards.</p>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem"><a href="#CFS.Windows.GameEditor">Game Editor</a></h3>
            <p style="margin:0">Edits shared Config and Environment source files.</p>
        </article>
    </div>
    <aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0">
        <strong>Good to know</strong>
        <p style="margin:.4rem 0 0">The two branches have different audiences: service methods support Studio; script-visible commands support your game code.</p>
    </aside>
<h3>Follow the handoffs</h3><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,260px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">Why there are two views</h3><p style="margin:0">This service page describes the machinery that prepares the script workspace. The User Environment API pages describe the names an author uses inside a game script. They concern the same workspace from two different viewpoints: Studio prepares it, and your scripts use it.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">The connection to processing</h3><p style="margin:0">Loading a game and a card set gives ProcSys the information needed to prepare the environment. Processing and row selection then supply card values, while Forge supplies drawing operations. The environment is the meeting point for those inputs, not another copy of the CSV or a separate project.</p></article>
</div>
</section>
!]]
