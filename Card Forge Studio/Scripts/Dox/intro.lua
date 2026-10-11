--[[!
@fqxn CFS.Documentation.Introduction
@desc Supplies the theme-aware Start Here content used on the first page of Studio's generated API documentation. The CFS overview remains a separate topic.
@return string sContent Introduction HTML with links into the generated reference.
@vis private
!]]
return [[
<style>
    body:has(#cfs-start-here) #DOX_topic,
    body:has(#cfs-start-here) #DOX_location { display: none; }
</style>
<section id="cfs-start-here" aria-label="Start here with Card Forge Studio">
    <figure aria-label="Card Forge Studio welcome artwork" style="max-width:760px;margin:0 auto 2rem;padding:.6rem;border:2px solid var(--border);border-radius:20px;background:var(--surface-raised);box-shadow:0 12px 32px rgba(0,0,0,.2)">
        <div style="position:relative;aspect-ratio:7 / 6;overflow:hidden;border-radius:12px;background:var(--page)">
            <img src="../Images/BG%20Welcome.png" alt="Glowing fantasy cards in the Card Forge Studio workspace" style="position:absolute;left:-14.4286%;top:0;width:128.8571%;height:100%;max-width:none">
            <img src="../Images/Card%20Forge.png" alt="Card Forge" style="position:absolute;left:26.5%;top:27.75%;width:47%;height:13.3333%">
            <img src="../Images/Studio.png" alt="Studio" style="position:absolute;left:35.7857%;top:41%;width:28.5%;height:11.5%">
        </div>
    </figure>
    <header style="padding:2rem;border:1px solid var(--border);border-radius:18px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem">
        <h1 style="margin:.5rem 0;font-size:clamp(1.8rem,4vw,2.8rem)">From an idea to a deck of cards.</h1>
        <p style="font-size:1.15rem;max-width:48rem;margin:.75rem 0">Welcome to the Studio guide and API reference. Learn how the pieces fit together, then explore the tools that bring your cards to life.</p>
        <a href="#CFS" style="display:inline-block;padding:.65rem 1rem;margin-top:1rem;border:1px solid var(--border);border-radius:10px;background:var(--accent-soft);font-weight:700">Explore Card Forge Studio →</a>
    </header>

    <h2>One project. A connected workflow.</h2>
    <p>A <strong>game</strong> holds the shared project settings and its card sets. A <strong>card set</strong> holds a collection's data and drawing instructions. Studio connects those ingredients so you can edit, inspect, and export your work.</p>
    <figure style="margin:1.5rem 0">
        <figcaption style="font-weight:700;margin-bottom:.75rem">The card-making journey</figcaption>
        <div role="img" aria-label="Choose a game, load a card set, edit source data, inspect final data, preview the artwork, and export images" style="display:flex;flex-wrap:wrap;align-items:center;gap:.65rem">
            <a href="#CFS.Classes.Game" style="padding:.8rem 1rem;border:1px solid var(--border);border-radius:10px;background:var(--surface-raised)">Game</a>
            <span aria-hidden="true">→</span>
            <a href="#CFS.Classes.CardSet" style="padding:.8rem 1rem;border:1px solid var(--border);border-radius:10px;background:var(--surface-raised)">Card Set</a>
            <span aria-hidden="true">→</span>
            <a href="#CFS.Windows.BaseData" style="padding:.8rem 1rem;border:1px solid var(--border);border-radius:10px;background:var(--surface-raised)">Edit</a>
            <span aria-hidden="true">→</span>
            <a href="#CFS.Windows.FinalData" style="padding:.8rem 1rem;border:1px solid var(--border);border-radius:10px;background:var(--surface-raised)">Inspect</a>
            <span aria-hidden="true">→</span>
            <a href="#CFS.Modules.Forge" style="padding:.8rem 1rem;border:1px solid var(--border);border-radius:10px;background:var(--surface-raised)">Preview</a>
            <span aria-hidden="true">→</span>
            <a href="#CFS.Modules.Exporter.Exporters.ExporterPNG" style="padding:.8rem 1rem;border:1px solid var(--border);border-radius:10px;background:var(--surface-raised)">Export</a>
        </div>
    </figure>

    <h2>Find your starting point</h2>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,250px),1fr));gap:1rem;margin:1rem 0">
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem">Understand the big picture</h3>
            <p>Start with the project overview. It introduces the parts without requiring you to read function signatures.</p>
            <a href="#CFS">Read the CFS overview →</a>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem">Follow your card data</h3>
            <p>See how source values become processed results, and how the two data windows stay connected.</p>
            <a href="#CFS.Modules.ProcSys">Meet the Processing System →</a>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem">Build the visual side</h3>
            <p>Learn what the drawing workspace does and how reusable text styles help cards feel consistent.</p>
            <a href="#CFS.Modules.Forge">Explore Forge →</a>
            <br><a href="#CFS.Classes.FontStyle">Explore Font Style →</a>
        </article>
        <article style="padding:1.3rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised)">
            <h3 style="margin:0 0 .6rem">Look up an API</h3>
            <p>Choose a topic from the navigation, then open its child entries for inputs, results, and technical details.</p>
            <a href="#CFS.UserEnv">See the script environment →</a>
        </article>
    </div>

    <aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);border-radius:0 10px 10px 0;background:var(--surface);margin-top:1.5rem">
        <strong>About this guide</strong>
        <p style="margin:.5rem 0 0">This is Studio's documentation, separate from the loaded game's Game Docs. Pages marked deferred, reserved, or legacy explain unfinished areas rather than promising available features.</p>
    </aside>
</section>
]];
