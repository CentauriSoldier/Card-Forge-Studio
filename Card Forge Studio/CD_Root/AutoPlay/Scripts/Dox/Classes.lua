--[[!
    @fqxn CFS.Classes
    @desc <p>
      This section contains the core classes that make up the system.
      Each class represents a focused, self-contained piece of functionality, designed to be composed into larger workflows.
    </p>

    <p>
      The classes here form the backbone of the project: data handling, processing, rendering, coordination, and tooling.
      They are written to be deterministic, scriptable, and explicit in behavior.
    </p>

    <p>
      Together, these classes define how data flows through the system, how it is transformed, and how final output is produced.
      Each entry documents purpose, responsibilities, and public behavior so the system can be understood, extended, and maintained with confidence.
    </p>

    <p>
      Card Forge Studio expects a descending hierarchy that matches your CSV structure:
    </p>
    <ul>
      <li><strong>Card</strong> (base class)</li>
      <li><strong>Family</strong> (child of Card)</li>
      <li><strong>Class</strong> (child of Family)</li>
      <li><strong>Type</strong> (child of Class)</li>
    </ul>

    <p>
      Example hierarchy:
    </p>
    <ul>
      <li>Card</li>
      <li>Creature (Family)</li>
      <li>Humanoid (Class)</li>
      <li>Orc (Type)</li>
    </ul>

    <pre><code class="language-lua">--\[\[!
    \@fqxn My Game.Classes.Card
    \@desc &lt;h2&gt;Card&lt;/h2&gt;
    &lt;p&gt;
      Base card behavior shared by all cards in the pipeline. In Card Forge Studio, game-specific cards
      are built by extending this class using the required hierarchy:
      &lt;strong&gt;Card → Family → Class → Type&lt;/strong&gt;.
    &lt;/p&gt;
    &lt;p&gt;
      See: &lt;a href="#My Game.Cards.Creature"&gt;Creature&lt;/a&gt; → &lt;a href="#My Game.Cards.Creature.Orc"&gt;Orc&lt;/a&gt; → &lt;a href="#My Game.Cards.Creature.Orc.Warrior"&gt;Warrior&lt;/a&gt;
    &lt;/p&gt;
    !\]\]

    return class("Card",
      {},
      {--STATIC PUBLIC
        -- Override these in children as needed.
        OnSelectionChanged = function(nRow, nColumn, sColumn, tRow)
          return nil, nil;
        end,

        -- Optional hook used by ProcSys-style pipelines to transform a single cell.
        ProcessCell = function(nRow, nColumn, sColumn, tRow, sText, GetFinalValue)
          return nil; -- return nil to "copy as-is"
        end,
      },
      {},
      {--PROTECTED
        Family = "",
        Class  = "",
        Type   = "",

        Card = function(this, cdat, sFamily, sClass, sType)
          -- store hierarchy identity (used by your pipeline if desired)
          local pro = cdat.pro;
          pro.Family = sFamily;
          pro.Class  = sClass;
          pro.Type   = sType;
        end,
      },
      {},
      nil,
      false,
      nil
    );</code></pre>

      <pre><code class="language-lua">--\[\[!
    \@fqxn My Game.Cards.Creature
    \@desc &lt;h2&gt;Creature (Family)&lt;/h2&gt;
    &lt;p&gt;
      A &lt;strong&gt;Family&lt;/strong&gt; class: common logic shared by all Creature cards.
      This sits directly under &lt;a href="#My Game.Classes.Card"&gt;Card&lt;/a&gt;.
    &lt;/p&gt;
    &lt;p&gt;
      Next level: &lt;a href="#My Game.Cards.Creature.Orc"&gt;Orc&lt;/a&gt;.
    &lt;/p&gt;
    !\]\]

    Card = Card or require("Card");

    return class("Creature",
      {},
      {--STATIC PUBLIC
        -- Example: Family-wide processing hook (optional)
        ProcessCell = function(nRow, nColumn, sColumn, tRow, sText, GetFinalValue)
          return nil;
        end,
      },
      {},
      {--PROTECTED
        Creature = function(this, cdat, sClass, sType)
          -- enforce the Family name at this tier
          local pro = cdat.pro;
          pro.Family = "Creature";
          pro.Class  = sClass;
          pro.Type   = sType;
        end,
      },
      {},
      Card,
      false,
      nil
    );</code></pre>

      <pre><code class="language-lua">--\[\[!
    \@fqxn My Game.Cards.Creature.Orc
    \@desc &lt;h2&gt;Orc (Class)&lt;/h2&gt;
    &lt;p&gt;
      A &lt;strong&gt;Class&lt;/strong&gt; under the &lt;a href="#My Game.Cards.Creature"&gt;Creature&lt;/a&gt; family.
      Shared behavior for all Orc types belongs here.
    &lt;/p&gt;
    &lt;p&gt;
      Next level: &lt;a href="#My Game.Cards.Creature.Orc.Warrior"&gt;Warrior&lt;/a&gt;.
    &lt;/p&gt;
    !\]\]

    Creature = Creature or require("Creature");

    return class("Orc",
      {},
      {--STATIC PUBLIC
        -- Example: Orc-wide customization (optional)
        ProcessCell = function(nRow, nColumn, sColumn, tRow, sText, GetFinalValue)
          return nil;
        end,
      },
      {},
      {--PROTECTED
        Orc = function(this, cdat, sType)
          local pro = cdat.pro;
          pro.Family = "Creature";
          pro.Class  = "Orc";
          pro.Type   = sType;
        end,
      },
      {},
      Creature,
      false,
      nil
    );</code></pre>

      <pre><code class="language-lua">--\[\[!
    \@fqxn My Game.Cards.Creature.Orc.Warrior
    \@desc &lt;h2&gt;Warrior (Type)&lt;/h2&gt;
    &lt;p&gt;
      A concrete &lt;strong&gt;Type&lt;/strong&gt; class under &lt;a href="#My Game.Cards.Creature.Orc"&gt;Orc&lt;/a&gt;.
      This is the class you map in &lt;strong&gt;_tTypeClassMap&lt;/strong&gt; so the pipeline can call its processors.
    &lt;/p&gt;
    !\]\]

    Orc = Orc or require("Orc");

    return class("Warrior",
      {},
      {--STATIC PUBLIC
        -- This is the "Type processor" tier typically used by ProcSys.
        ProcessCell = function(nRow, nColumn, sColumn, tRow, sText, GetFinalValue)
          -- return nil to keep the cell unchanged
          return nil;
        end,
      },
      {},
      {--PROTECTED
        Warrior = function(this, cdat)
          local pro = cdat.pro;
          pro.Family = "Creature";
          pro.Class  = "Orc";
          pro.Type   = "Warrior";
        end,
      },
      {},
      Orc,
      false,
      nil
    );</code></pre>

      <pre><code class="language-lua">--\[\[!
    \@fqxn My Game.Init.TypeMapExample
    \@desc &lt;p&gt;Example mapping: register the Type string to the Type class (read-only pattern optional).&lt;/p&gt;
    !\]\]

    -- Type → Class map used by the pipeline (example)
    local tTypeClassMapActual = {
      Warrior = Warrior,
    };

    local tTypeClassMeta = {
      __index    = function(t, k) return tTypeClassMapActual[k] or nil end,
      __newindex = function(t, k, v) error("Attempt to write to read-only Type-Class map table."); end,
    };

    _tTypeClassMap = {};
    setmetatable(_tTypeClassMap, tTypeClassMeta);</code></pre>
!]]
