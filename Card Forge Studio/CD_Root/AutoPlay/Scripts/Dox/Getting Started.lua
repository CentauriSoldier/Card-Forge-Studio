--[[!
    @fqxn CFS.Getting Started
    @desc <h3>Getting Started</h3>

    <p>
      This section walks you through the minimum setup needed to boot a new Card Forge Studio game, load your scripts,
      and connect your CSV card data to your class-based processors.
    </p>

    <h4>1) Create a new game</h4>
    <ul>
      <li>Create a new game inside Card Forge Studio.</li>
      <li>Your game folder is created automatically under:
        <em>AppData/Local/Card Forge Studio/Games/&lt;YOUR GAME NAME&gt;</em>
      </li>
      <li>All of your Lua code lives in your game’s <strong>Scripts</strong> folder.</li>
      <li>The <strong>Scripts</strong> folder is automatically added to the Lua package path when the game is loaded.</li>
    </ul>
    <em>You can read more about this in the <a href="#CFS.Data">Data<a/> section.</em>
    <br>
    <br>
    <h4>2) Add your required CSV columns</h4>
    <p>
      Every CSV you load into Card Forge Studio must include these columns (named exactly, case-sensitive):
    </p>
    <ul>
      <li><strong>Family</strong> (string)</li>
      <li><strong>Class</strong> (string)</li>
      <li><strong>Type</strong> (string)</li>
    </ul>

    <h4>3) Build your card class hierarchy</h4>
    <h5>Build Your Classes</h5>
    <em>For more info on how to make classes, see the <a href="https://centaurisoldier.github.io/LuaEx/" target=_blank>LuaEx->Class System</a> documentation.</em>
    <br>
    <em>You can view an example in the <a href="#CFS.Classes">Classes</a> section.</em>
    <br>
    <br>


    <h4>4) Create a Config.lua (recommended)</h4>
    <p>
      While not required, a Config.lua is recommended for static data that doesn’t change at runtime.
      If you use it, load it up front:
    </p>

    <pre><code class="language-lua">constant("CFG", require("Config"));</code></pre>

    <h4>5) Code Init.lua</h4>
    <p>
      All of your game bootstrapping code lives in <strong>Init.lua</strong>. This file is responsible for:
    </p>
    <ul>
      <li>Loading your Card base class and any derived Family/Class/Type classes.</li>
      <li>Creating your Forge instance.</li>
      <li>Defining the global <strong>_tTypeClassMap</strong> so Card Forge Studio can find your type processors.</li>
      <li>(Optional) Defining other maps your pipeline may use.</li>
    </ul>

    <h4>6) Map Types to their processor classes</h4>
    <p>
      To enable custom processing, each <strong>Type</strong> that has a static processor method must be mapped in a global table named
      <strong>_tTypeClassMap</strong>. The key is the Type string from your CSV, and the value is the class that implements the processor logic.
    </p>

    <p>
      Example: mapping four Types (<em>Orc</em>, <em>Human</em>, <em>Sword</em>, <em>Bow</em>) to their classes:
    </p>

    <pre><code class="language-lua">--map the type files to their respective classes (for use with ProcSys.lua)
    local tTypeClassMapActual = { --actual
        --Creatures
        Orc   = Orc,
        Human = Human,
        --Weapons
        Sword = Sword,
        Bow   = Bow
    };

    local tTypeClassMeta = {
        __index    = function(t, k) return tTypeClassMapActual[k] or nil end,
        __newindex = function(t, k, v) error("Attempt to write to read-only Type-Class map table."); end,
    };

    _tTypeClassMap = {}; --decoy
    setmetatable(_tTypeClassMap, tTypeClassMeta);</code></pre>

    <p>
      This assumes your Orc, Human, Sword, and Bow classes have been created and loaded before the map is built.
    </p>

    <h4>7) (Optional) Generate API documentation with Dox</h4>
    <p>
      If you comment your code using Dox, Card Forge Studio will <strong><em>automatically generate documentation</em></strong> and place it into your game’s
      <strong>Docs</strong> folder, combining the Card Forge Studio API with your game’s API output.
    </p>

    <pre><code class="language-lua">--\[\[!
        \@fqxn My Game.MyClass.MyFunction
        \@desc MyFunction does really neat stuff!
        \@param string sName The name of the stuff to do neat things to.
        \@ret string sModified The modified string.
    !\]\]</code></pre>

    <p>
      For more information, read the Dox section here:
      <a href="https://centaurisoldier.github.io/LuaEx/" target="_blank">https://centaurisoldier.github.io/LuaEx/</a>
    </p>

    <h4>8) Load your CSV and start iterating</h4>
    <p>
      Once your game is booted and your Type map is in place, you can load a CSV and begin editing rows,
      processing values, and generating/exporting card images through your pipeline.
    </p>
!]]
