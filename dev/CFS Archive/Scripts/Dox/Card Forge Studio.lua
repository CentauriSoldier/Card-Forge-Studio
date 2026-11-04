--[[!
    @fqxn CFS
    @desc <h2>Card Forge Studio</h2>

    <div class="text-center my-5">
        <h3 class="fw-bold mb-3"><a href="#CFS.Getting Started">Getting Started</a></h3>
        <h3 class="fw-bold mb-3"><a href="#CFS.Data">Data</a></h3>
    </div>

    <h3 class="fw-bold">Overview</h3>
    <p>
      Card Forge Studio is a desktop tool for building, editing, and exporting card images for real production use.
      It is designed for card game developers who need speed, scale, and absolute control over their data and output.
      From a single prototype to thousands of cards, Card Forge Studio generates finished assets in seconds.
    </p>

    <p>
      Unlike web tools and drag-and-drop editors, Card Forge Studio runs locally on Windows and is built for performance and control.
      It's fast, deterministic, and free. More importantly, it's programmable—every layout, pipeline, and transform
      is defined in code.
    </p>

    <p>
      To support that power, Card Forge Studio exposes a well-documented API that makes every major system accessible and predictable.
      The engine is meant to be read, learned, and extended, not treated as a black box.
    </p>

    <h3>What it does</h3>
    <ul>
      <li><strong>Designs</strong> reusable card layouts.</li>
      <li><strong>Binds</strong> structured data to templates.</li>
      <li><strong>Generates</strong> large volumes of cards in bulk.</li>
      <li><strong>Exports</strong> high-resolution, print-ready images.</li>
    </ul>

    <h3>Why it’s different</h3>
    <p>
      Card Forge Studio is built on a real engine and expects you to think in data and logic.
      Layouts, rendering behavior, and generation rules are written in Lua.
      The result is a deterministic pipeline: the same input always produces the same output.
      Unlike other systems, Card Forge Studio is not only free but open source and local.
      By running on your machine, it can take advantage of your CPU and GPU power for rendering and data processing.
      In addition, the entire pipeline, while functional as-is, can be modified as needed.
      You cards are organized, desinged, and built with your code.
    </p>

    <h3>Features</h3>
    <ul>
      <li>Built-in Style Editor.</li>
      <li>Built-in, opinionated Mechanics viewer.</li>
      <li>Horizontal and Vertical card rendering.</li>
      <li>Unopinionated data model, meaning your cards are organzied and accessed by your dictate, not the engine's.</li>
      <li>Grid editor for card data (<em>loaded from CSV</em>).</li>
      <li>Per cell data processing option for data manipulation from Base to Final.</li>
      <li>Built-in lua editor with customizable environment for quick per-card coding.</li>
      <li>Uses LuaEx's class system and documentation generator for quickly and easily building custom API docs that are accessible at runtime.</li>
    </ul>

    <p>
      This is the trade:
    </p>
    <ul>
      <li>You bring logic.</li>
      <li>Card Forge Studio gives you raw power.</li>
    </ul>

    <p>
      If you can express your game in data, Card Forge Studio becomes a weapon for mass creation—capable of producing
      entire games with precision and repeatability.
    </p>

    <h3>Use cases</h3>
    <ul>
      <li>Tabletop and TCG design</li>
      <li>Board game prototyping</li>
      <li>Procedural card generation</li>
      <li>Rapid balance and layout iteration</li>
      <li>Print-on-demand pipelines</li>
    </ul>

    <p>
      Card Forge Studio is built on three principles:
    </p>
    <ul>
      <li><strong>Speed</strong> over ceremony</li>
      <li><strong>Power</strong> over prettiness</li>
      <li><strong>Creator control</strong> above all</li>
    </ul>

    <p>
      This is not a toy.
      It is a forge for builders.
    </p>
!]]
