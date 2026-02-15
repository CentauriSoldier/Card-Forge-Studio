--[[!
    @fqxn CFS.Data
    @desc <h3>Data and CSV Input</h3>

    <p>
      Card Forge Studio Studio is <strong>data-driven</strong>. Your CSV input is the source of truth, and Card Forge Studio Studio builds everything
      from those rows in a deterministic pipeline.
    </p>

    <h4>Required hierarchy columns</h4>
    <p>
      Every CSV input <strong>must</strong> include the following columns <em>(named exactly as shown, case-sensitive)</em>:
    </p>
    <ul>
      <li><strong>Family</strong> &mdash; string</li>
      <li><strong>Class</strong> &mdash; string</li>
      <li><strong>Type</strong> &mdash; string</li>
    </ul>

    <p>
      These fields define the required card hierarchy used by Card Forge Studio Studio.
    </p>

    <h4>Class hierarchy model</h4>
    <p>
      Card Forge Studio Studio expects a descending class structure that mirrors the hierarchy in your CSV:
    </p>
    <ul>
      <li>Create a base <strong>Card</strong> class.</li>
      <li>Create a child class for each <strong>Family</strong>.</li>
      <li>Under each Family, create a child class for each <strong>Class</strong>.</li>
      <li>Under each Class, create a child class for each <strong>Type</strong>.</li>
    </ul>

    <h4>Type processors and the Type-Class map</h4>
    <p>
      To enable custom processing per card type, each Type that implements a static processor method must be registered
      in the global <strong>_tTypeClassMap</strong>.
    </p>

    <p>
      <strong>_tTypeClassMap</strong> is indexed by the Type string from your CSV, and its value is the class that contains
      the processor method. A Type class may reference parent behavior as needed.
    </p>

    <p>
      Example mapping:
    </p>

    <pre><code class="language-lua">
    --map the type files to their respective classes (for use with ProcSys.lua)
    local tTypeClassMapActual = { --actual
        --Creatures
        Orc = Orc,
        Human = Human,
        --Weapons
        Sword = Sword,
        Bow = Bow
    };
    local tTypeClassMeta = {
        __index = function(t, k) return tTypeClassMapActual[k] or nil end,
        __newindex = function(t, k, v) error("Attempt to write to read-only Type-Class map table."); end,
    }; --metatable
    _tTypeClassMap = {}; --decoy
    setmetatable(_tTypeClassMap, tTypeClassMeta);
    </code></pre>

    <p>
      This assumes your <strong>Orc</strong>, <strong>Human</strong>, <strong>Sword</strong>, and <strong>Bow</strong> classes
      have already been created and loaded.
    </p>

    <h4>Config table (recommended)</h4>
    <p>
      You can optionally provide a shared config table for stable project data using:
    </p>

    <pre><code class="language-lua">constant("CFG", require("Config"));</code></pre>

    <p>
      This loads your <strong>Config.lua</strong> table. It is not required, but it is recommended for data that does not
      change during runtime.
    </p>

    <h4>InitForge.lua (required entry point)</h4>
    <p>
      All game code must be bootstrapped from a file named <strong>InitForge.lua</strong>. This is the entry point where
      your project initializes its scripts, tables, mappings, and systems.
    </p>

    <h4>Game folder structure</h4>
    <p>
      Each game lives under:
    </p>

    <p>
      <strong>AppData/Local/Card Forge Studio Studio/Games/&lt;YOUR GAME NAME&gt;/</strong>
    </p>

    <p>
      The following folders and files are created automatically for you when you make a new game inside Card Forge Studio. This layout is fixed and expected by Card Forge Studio:
    </p>

    <pre><code>
    &lt;YOUR GAME NAME&gt;
    ├─ Cards
    ├─ CSV Backup
    ├─ CSV Export
    ├─ CSV Source
    ├─ Docs
    ├─ Scripts
    │  └─ InitForge.lua
    ├─ Symbols
    ├─ CardSets.ini
    ├─ Info.ini
    └─ Styles.ini
    </code></pre>

    <p>
      The <strong>Scripts</strong> directory is automatically added to the package path when the game is loaded.
      All of your scripts go there, including <strong>InitForge.lua</strong> at the Scripts root.
    </p><h3>Dox Documentation (Optional)</h3>

    <p>
      Card Forge Studio will <strong><em>automatically generate documentation</em></strong> if you choose to comment your code using <strong>Dox</strong>.
      When enabled, the generated documentation is placed in your game’s <strong>Docs</strong> folder and includes both the
      Card Forge Studio API and your game’s own API in one unified output.
    </p>

    <p>
      Dox comments are written in Lua block form. Example:
    </p>

    <pre><code class="language-lua">
    --\[\[!
        \@fqxn My Game.MyClass.MyFunction
        \@desc MyFunction does really neat stuff!
        \@param string sName The name of the stuff to do neat things to.
        \@ret string sModified The modified string.
    !\]\]
    </code></pre>

    <p>
      More information on documenting your code can be found in the Dox section here:
      <a href="https://centaurisoldier.github.io/LuaEx/" target="_blank">https://centaurisoldier.github.io/LuaEx/</a>
    </p>
!]]
