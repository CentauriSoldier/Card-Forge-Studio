# Card Forge Engine design

Updated: 2026-11-18.

This is the single CFE-owned architecture and design reference. It consolidates
application structure, engine components, rendering, native builds, archive
planning, and the decisions made during development. It replaces the former
Scripts, Engine, Animation and Src READMEs, development handoff, and CFA draft.
The repository README remains a short entry point. Plugin documentation remains
owned by its plugin and is not consolidated, edited, moved or deleted here.

Paths below are relative to the installation directory `Card Forge Engine/`
inside this repository, unless explicitly stated otherwise. This DESIGN.md lives
at the repository root, alongside README.md and LICENSE.

## Contents

- [Product boundaries and working conventions](#product-boundaries-and-working-conventions)
- [Decisions and implementation status](#decisions-and-implementation-status)
- [First complete game](#first-complete-game)
- [Application structure and discovery](#application-structure-and-discovery)
- [Engine components and API](#engine-components-and-api)
- [OpenGL presentation](#opengl-presentation)
- [Native builds and launcher](#native-builds-and-launcher)
- [CFA integration](#cfa-integration)
- [Verification and remaining work](#verification-and-remaining-work)

## Product boundaries and working conventions

- Card Forge Studio (CFS) designs cards and sets; it is not the gameplay engine.
- Card Forge Architect (CFA) authors games against the CFE API. The same acronym
  also names Card Forge Archive; distinguish the authoring tool from the container.
- Card Forge Engine (CFE), namespace CardForgeEngine, supplies generic runtime
  mechanisms. Each game defines its rules and chooses how to use those mechanisms.
- Gameplay declarations belong in Architect, not Studio. Preserve CFS set UUIDs
  in exported packages. A CFS exporter for this ecosystem remains future work.
- Assume Lua knowledge; Lua tutorials are outside the product scope.
- Commercial closed-source games and voluntary source sharing are both intended.
  Archive protection discourages casual inspection, not all client-side extraction.
- Application behavior lives in Lua/LuaEx. Native code hosts Lua and supplies
  runtime capabilities such as OpenGL. Use wxWidgets/wxLua/wxLuma for native UI,
  preferring wxLuma where its APIs fit.
- Root init.lua is the native launch entry. Scripts contains application code
  organized by purpose; Src contains native sources/builds; Bin/Windows, Bin/Mac
  and Bin/Linux contain platform runtimes. Preserve vendor-required layouts.
- LuaEx discovers native .lxc/.lxe declarations through package.path. Do not
  manually require class declarations or invent convenience class aliases.
- Follow LuaEx README conventions: PascalCase classes/exported modules, camelCase
  methods, typed variable prefixes, underscore-prefixed file locals, and `other`
  for class-instance parameters. Use dot calls for class methods. Only embedded
  local functions get an `f` prefix. Use meaningful DOx comments, explanatory
  comments and modular, readable code with the established formatting.
- Reuse and inspect LuaEx/CoG APIs before implementing replacements. LXC supplies
  serialization/deserialization infrastructure; add class validation and explicit
  clone policies where identity or custom state requires them.
- Expected class conveniences include cloning, string representation and, for
  containers, length and iteration. Follow the principle of least astonishment.
- Do not use JSON where Lua will work. Existing native build metadata is recorded
  below as it exists. The CFA draft uses a data-only Lua table index.
- The standing interaction rules still apply: obtain edit permission, preserve
  existing work, disclose consequences, stay within scope and report verification
  honestly. Work in this chat without delegation unless explicitly authorized.
  Use the real system for normal work and the sandbox for code tests. The user
  performs visual checks; automated native smoke tests are appropriate.
- Do not edit LuaEx without explicit authorization and the required framework
  understanding. A generalized reusable OpenGL bridge was authorized in its own
  plugin subfolder; that historical permission does not authorize arbitrary
  changes to other plugins. The current documentation task touches no plugins.
- Keep downloads, toolchains, caches and fixtures out of the repository; clean
  owned temporary staging after success. Do not invent unimplemented capabilities.

Scripts/Plugins/cog, LuaEx and wxLuma are junctions to their shared repositories.
Editing through those paths edits the shared upstream working trees used by other
projects. They are not independent bundled copies. The authorized CoG BaseDeck
ordering change is described below; CoGZone was not changed. Plugin files and
junction targets are outside this documentation consolidation.

## Decisions and implementation status

### Identity, zones and occupied slots

Every card in a game is a unique object, even when several cards share the same
card definition or artwork. Every registered card must occupy exactly one Zone.
Use the term zone, not pile. Zones can be empty or contain many cards.

A zone contains occupied slots represented by dense card indices. Index 1 is the
bottom; the last occupied index is the top. Top/Bottom access and explicit indices
are supported. Removing a card closes the gap. Empty slots are not model objects;
capacity is the permitted maximum number of occupants, not preallocated blanks.
The earlier idea of a hand containing one zone per card was superseded: a Hand
is one Zone with a configurable capacity and visual arrangement.

A game must move occupants before reducing capacity below occupancy or removing
an occupied zone/row. The engine must not silently discard, relocate or choose
replacement destinations for them. A Deck is a face-down stacked preset, a
Discard is a face-up stacked preset, and a Hand is a fan preset. These defaults
are configurable. A Playfield contains Rows, which contain Zones.

Visual arrangement does not determine game rules. Cards may fully overlap,
partially overlap (such as visible equipment behind another card), fan or use
another arrangement selected by the game. Describing an overlap layout does not
implement attachment rules. The current OpenGL fixture uses its own layout;
a generic renderer for every zone layout is not yet implemented.

Card IDs use LuaEx string.uuid and string.isuuid. Explicit IDs normalize to
lowercase. The authority creates new identities; clients/restores retain them.
Cloning creates new playable identities, while serialization/restoration retains
IDs and object sharing.

### Operations and rule boundaries

Provide basic, unambiguous system operations; each game owns legality, targeting,
turns, responses and fizzle policy. A game may query a card UUID for its current
zone/index. Whether an operation follows a moved card, rejects a changed position,
skips a portion of its work, or otherwise fizzles belongs to the game's rules for
that card. No universal expected-position or MTG-style rule is imposed.

Permit multiple independent resolution stacks. Select a stack explicitly and
consume one item at a time; the game decides what happens next. There is no
required automatic drain or universal scheduler. Current Stack inherits pop/peek
and the existing Game.resolveNext dispatches one callback Operation with declared
checks. That existing implementation is documented below; callbacks are not a
network command format or a completed general game-rules language.

### Rendering and multiplayer

The visual goal is a beautiful multiplayer card experience, with Monster Train
as an aspiration for graphics quality, not a claim of achieved parity. OpenGL
supplies rendering through a reusable bridge; Lua functions/classes own animation
behavior. Draw, hand arrangement/hover, play and discard basics exist in the demo.

Keep core state independent of rendering and transport. The planned flow is
client request -> authoritative host/server -> accepted changes to clients.
The authority can be a participating player-host or a dedicated server. Fully
symmetric peer-to-peer consensus has not been specified. Hidden information,
ordering/replay, reconnects and transport still require implementation/design;
matching UUIDs alone do not provide multiplayer synchronization.

### Deferred engine concepts

The participant is called Actor. Generic engine activities are Operations;
game-specific actions such as sacrifice compose generic mechanisms such as moving
cards. Modifier means a lasting change to properties, rules or permitted actions,
potentially on cards, Actors, zones or the game. Trigger/Effect/Pop terminology
was discussed but not finalized; do not treat proposed names as settled APIs.

Eight-direction rotation (N, NE, E, SE, S, SW, W, NW), 45-degree steps,
clockwise/counterclockwise changes and direct orientation were discussed.
Ownership versus control, temporary transfers/expiry, attachments, searching,
turn phases, response windows and transactional multi-card behavior remain to be
specified or implemented. CoG presentation flags alone are not permission-checked
gameplay operations. Standalone/client/server/hosting export profiles are plans,
not implemented export capabilities.

## First complete game

The editable duel source lives in `Examples/Source/Example Duel/`. Open **Tools >
Test Suite > Example Duel** after restarting CFE to play the shipped CFA package
in `Examples/Games/Example Duel/`. The source remains available for editing,
rebuilding, and developer tests. The older Card Animations fixture is separate.

The user authorized designing the card names, effects and starting values.
Current demo rules:

- Human versus computer. Each starts at 30 health and receives an independent
  20-card Starter deck containing one of each card design.
- Both receive five opening cards; the human goes first. Hand capacity is five.
- Each turn starts with three energy. Unspent energy expires at the next turn.
- Play as many affordable cards as desired, then end the turn. Cards apply their
  attack, shield, energy and draw effects through CFE's named action stack.
- Shields absorb damage before health and expire at the start of their owner's
  next turn. Reducing opposing health to zero ends the duel immediately.
- End turn moves the outgoing hand and played cards into that player's discard.
  The incoming player refills to five. An empty deck recycles/shuffles its discard;
  currently played cards remain out of the recycling pool until end turn.
- Draw effects respect hand capacity. There is no fatigue or alternate victory rule.
- The computer chooses affordable energy effects first, then favors damage and
  shielding. Its actions are paced in the UI and use the same rules API.
- Click a hand card or use 1-5 to play; hover for costs/effects, Enter to end turn,
  and R or New game to restart. Keyboard shortcuts apply while the table has focus.

Example contents (paths in this block are relative to the repository root):

    Examples/Source/Example Duel/
        Cards.lua                  20 card definitions and effects
        Decks.lua                  Starter deck composition
        Game.lua                   Local duel rules using CFE cards/zones/operations
        Page.lua                   OpenGL presentation, input and computer pacing
        ArtPrompts.lua             Final built-in image-generation prompts
        Images/Cards/Fronts/       20 fronts: three supplied, seventeen generated
        Images/Cards/Backs/        Both supplied backs, preserved
        Tests/Game.lua             Headless full-duel and invariant checks
        Tests/UI.lua               Texture/GPU/animation/lifecycle checks
        Tests/Integration.lua      Actual Test Suite launch and native events

The art follows the supplied retro science-fiction engraved print style, with
cream borders, prominent titles and type labels. The scenery includes space,
forests/waterfalls, lunar terrain, desert canyons, snowy mountains, icy auroras
and laboratory/reactor interiors. The supplied artwork is preserved; original
bottom labels such as Scout/Archive/Station are visual labels, while Cards.lua
specifies the demo's actual effects. Costs and rules appear in the hover detail
line rather than being baked into the images. These are demo balance values,
not universal engine rules or a claim of competitive balance.

Game.lua owns rules and card membership; Page.lua owns animated poses and GPU
resources. The page uses the existing OpenGL bridge and CardAnimator unchanged.
The computer hand is rendered face down. This is a local demo, not a networked
or adversarially hidden-information implementation. Its internal snapshots are
local presentation/debug data, not an approved network protocol.

The editable files and shipped archives have separate folders under Examples.
The Test Suite plays the shipped CFA package. General package entry points and
launching packages from the Games list remain pending.

From `Engine/Bin/Windows`:

```powershell
& "../../../Bin/lua.exe" "../../Examples/Source/Example Duel/Tests/Game.lua" ../.. "../../Examples/Source/Example Duel"
& "../../../Bin/lua.exe" "../../Examples/Source/Example Duel/Tests/UI.lua" ../.. "../../Examples/Source/Example Duel"
& "../../../Bin/lua.exe" "../../Examples/Source/Example Duel/Tests/Integration.lua" ../..
```

## Application structure and discovery

- Bootstrap.lua initializes LuaEx, wxLua and wxLuma, then runs the application.
- Windows/Main.lua owns the frame and populates its Games list.
- Pages/Welcome.lua owns the welcome content and layout.
- Controls/GamesList.lua configures wxLuma ListEx with image and title columns.
- Services/GameDiscovery.lua inventories installed games using LuaEx I/O.
- Plugins/LuaEx links to the shared LuaEx runtime, including native modules in
  its upstream bin layout. Historical UPSTREAM.json records are not a live pin
  for a junction checkout. Native build sources are under Src/Plugins/LuaEx/src.
- Tests/GameDiscovery.lua checks discovery against an isolated fixture library.

### Game discovery

The library is the user's home directory plus Card Forge Engine. Discovery does
not create it. Each game follows the agreed layout:

    ~/Card Forge Engine/
        MyGame/
            <game-uuid>.cfa
            CardSets/
                <set-uuid>.cfa
            Decks.lua
            UIO.cfa
            GEO.cfa
            AO.cfa

A game folder keeps its readable name. Exactly one UUID-named CFA at the root
identifies the game. CardSets is inventoried when present. Decks.lua and the UI,
graphical-effects and animation override archives are optional; discovery never
loads them or executes their code.

GameDiscovery.scan() returns games and a separate diagnostics array. An optional
library path supports isolated tests and future library selection. Only direct
child game folders and UUID-named archives directly under CardSets are
examined. Every call rescans disk.
Ambiguous game folders are excluded; invalid set archive names are reported.
A missing library is an empty result; other filesystem failures are diagnostics.
Window.DiscoveryIssues retains the startup diagnostics for a future library UI.

Returned records have UUID, Title (folder name), Directory, Archive, Sets, Decks
and Overrides. Archive contents are not inspected or validated yet. Image stays
unset until the package metadata/artwork contract is defined; GamesList already
accepts an Image path when that metadata becomes available.

Bootstrap adds Scripts/Plugins to package.path and requires LuaEx.init before
application widgets capture globals. LuaEx is unchanged; the shared CoG BaseDeck ordering change is documented in the engine section below. Windows
initialization, native filesystem I/O and application startup have been tested;
other platforms have not been tested here.

The discovery fixture test takes installation root and fixture-library root as
arguments. It expects Alpha (with one valid and one invalid set, Decks.lua and
all overrides), Zulu (uppercase UUID archive), Ambiguous (two UUID archives),
Unrelated/Nested (nested-only archive), and WrongArchive (Game.cfa). It adds and
removes one archive inside WrongArchive to check fresh snapshots.

### Application UI and bootstrap

The native launcher resolves the installation from its executable, then runs
init.lua. Bootstrap configures package.path, requires LuaEx.init, initializes
CoG with require("cog.load")(), loads wxLuma and opens the main window.
Windows/Main.lua owns the frame, Pages/Welcome.lua its welcome content, and
Controls/GamesList.lua the image/title list. The historical initial frame size
was 1400x720, with Games at the far right and no inner skinned window.

Images/Card Forge Engine.png supplies the welcome artwork. The multi-size icon
is Bin/Windows/Card Forge Engine.ico, embedded in the executable and set on the
Lua window. The root Card Forge Engine.lnk launches the executable. Discovered
game images remain unset until package metadata/artwork can be read; GamesList
already accepts an Image path. DiscoveryIssues is retained for a future diagnostics UI.

## Engine components and API

These are native LuaEx LXC classes in the CardForgeEngine namespace. LuaEx
discovers .lxc sources through the application package.path at initialization.
Do not require .lxc files as ordinary Lua modules or create short global aliases.

### Files

- Cards/Card.lxc: extends CoG.BaseCard with a stable, read-only instance ID.
- Operations/Operation.lxc: captures a callback and card requirements, then
  validates current state immediately before the engine invokes the callback.
- Stacks/Stack.lxc: extends LuaEx.Classes.Stack with validated push and fixed LIFO.
- Game/Game.lxc: exclusive zone membership, movement, named stacks and diagnostics.
- Zones/: Zone plus configurable Deck, Discard and Hand presets.
- Board/: Row groups zones; Playfield groups rows.

Bootstrap places Scripts/Plugins on package.path, initializes LuaEx, calls
require("cog.load")(), then creates the application window. Plugins/cog is a junction into the shared CoG repository. Its BaseDeck now uses
index one as bottom and the last occupied index as top, as authorized. LuaEx's class system discovers CoG and CFE
declarations together so inheritance dependencies are available.

### Basic use

After the frameworks initialize:

    local oGame = CardForgeEngine.Game();
    local oHand = CardForgeEngine.Hand(nil, {Capacity = 5});
    oGame.addZone(oHand);
    local oCard = CardForgeEngine.Card(nil, "Example");
    local sCardID = oCard.getInstanceID();
    oGame.addCard(oCard, oHand.getID());
    local oStack = oGame.createStack("main");

    oStack.push(CardForgeEngine.Operation("Reveal", function(other, tCards)
        tCards[sCardID].reveal();
    end, {
        {
            CardID = sCardID,
            Check = function(other)
                return not other.isFaceUp(), "Card is already face up.";
            end,
        },
    }));

    local tResult = oGame.resolveNext("main");

Class methods use dot calls. This Operation captures a function; its
requirements identify live cards by ID instead of retaining queued card objects.
The engine performs every check before entering the user function. Check must
return literal true to permit execution; false/nil returns Skipped automatically.
Requirements are copied when queued work is constructed. Predicates MUST be
synchronous and side-effect-free. They do not prompt a player.

Every card a callback depends on must be declared in its requirements. Lua
closures are not inspected to infer hidden card dependencies. Empty requirements
are valid for operations that do not reference cards. Do not yield from rules
or callbacks; this first resolver is synchronous and does not implement waits.

### Stack behavior

Games may create any number of independent named stacks. Game.resolveNext(name)
processes exactly one top item on the selected stack. There is no automatic
scheduler, hidden stack selection or response/priority window yet.

Stack.push accepts Operation instances, not bare functions. reverse is rejected.
Inherited peek, size, iteration, pop and clear retain LuaEx behavior; pop/clear
remove pending work without executing it. Execution is exclusively through
Game.resolveNext. A private per-dispatch permit prevents direct Operation.resolve
calls. Reentrant resolveNext is rejected across this game's stacks, but callbacks
may push later work. This is an engine API contract, not a sandbox against code
using debug access to attack the runtime.

An Operation is consumed on its first resolution attempt, even when skipped or
failed. Reusing that same object produces AlreadyResolved; construct a fresh
Operation for a deliberate retry. No whole-stack automatic drain is provided.

### Results and errors

Results have Status, Code, Stack and, for an actual Operation, Operation.
Reason is provided for skips/errors. Status is Resolved, Skipped, Failed or Empty.

- Completed: callback returned normally.
- CardMissing: required card no longer exists in this game.
- ConditionRejected: a declared condition did not return true.
- CardChanged: a predicate changed a required registry entry.
- ConditionError: condition raised an error; user callback was not run.
- CallbackError: user callback raised an error.
- AlreadyResolved: the same Operation has already been consumed.
- ResolverError: unexpected dispatch error.
- StackEmpty: selected stack has no work.

A normal callback return, including false, is not an engine failure. It must
raise an error to signal failure after validation. Failed callbacks may already
have changed state: this first foundation does not provide atomic transactions
or rollback. Game.getResults returns copies of the most recent 128 nonempty
resolution reports. Invalid API use, such as an unknown stack, fails explicitly.

Card IDs belong to one identity within a Game. Removing a card removes presence;
the same instance may return. Another instance cannot reuse that ID in the game.
The same ID may exist in separate game contexts. One actual card object cannot belong to two games simultaneously. IDs use
LuaEx string.uuid/string.isuuid and are normalized to lowercase. The authority
creates identities; restored/client copies retain the supplied UUID.

### Current scope

CoG already supplies generic card metadata, tags, presentation flags, deck,
shuffling and RNG foundations. CFE's Card adds UUID identity and an explicit clone policy. Game-specific card
subclasses must implement their own clone policy; inheriting CoG.BaseCard's
plain-card clone does not support cloning a subclass.

Actors, eight-direction rotation, ownership/control,
Modifiers, triggers/effects, turns, targeting and networking are not implemented.
The Test Suite has a loader for the bundled Example Duel. General game loading
from the Games list remains pending. CoG presentation mutators do not perform
the checks required of gameplay Operations.

### Zones, slots and movement

Every registered card occupies exactly one zone. Slots are the occupied indices
of its dense card list: bottom is 1, top is the last index. Removal closes the
gap; capacity is a limit, not a collection of empty slots. A Hand is one Zone.

Game.addCard(card, zoneID, position) requires an initial registered zone.
Game.moveCard(cardID, zoneID, position) moves the existing object. Position is
"Top" (also the default), "Bottom", or an insertion index evaluated AFTER
removing the source card. Invalid destinations, indices or capacity fail before
membership changes. Game.getCardLocation(cardID) returns {ZoneID, Index}.
Game.removeCard unregisters a card entirely; it is not an intermediate move.

Zone.setCapacity(nil) removes its limit. Shrinking below occupancy is rejected.
Game.removeZone, Row.removeZone and Playfield.removeRow reject occupied contents.
Rows and playfields group references; adding a zone to a Row does not register it
with a Game. Register it explicitly through Game.addZone.

Deck defaults to a face-down stack, Discard to a face-up stack, and Hand to a fan.
Layout is copied presentation data and does not change card flags or game rules.
The OpenGL demo is not yet connected to these new model objects.

Game.shuffleZone reuses CoG's shuffle on prepared storage and returns the final
UUID order. Movement returns a data-only record containing CardID, FromZoneID,
FromIndex, ToZoneID, ToIndex and Changed. The game defines legality and fizzle
conditions; movement imposes only the structural invariants above.

Shared CoG compatibility: BaseDeck.peek()/draw() now select the last card,
drawMany returns cards from that end, and addCard(card, true/nil) appends at the
top. addCard(card, false) inserts at bottom/index one. Consumers expecting the
old first-index top convention must migrate. CoGZone membership is unchanged.

### Copying, persistence and multiplayer boundary

Use LuaEx clone/serialize/deserialize. Card, Zone, Deck, Discard, Hand, Row and
Playfield clones get fresh UUIDs; saves preserve UUIDs and shared references.
Card cloning follows CoG's metadata/flags/tags policy with fresh callbacks and
affixes. Custom subclasses must define their own clone policy.

Game cloning requires empty stacks and an idle game. It copies current zones
and cards with new IDs and recreates stack names; removed identity history and
resolution diagnostics belong to the original game. Pending callback closures
cannot safely have captured IDs remapped. Native data snapshots are not a wire
format for executable callbacks; do not treat queued Operations as network commands.

The model supports separate authority/client copies with matching UUIDs. A
player-host or dedicated server can validate game rules and distribute accepted
changes. Transport, sequencing, hidden-information filtering, reconnects and
state synchronization are not implemented. Layout/animation remains local to
each presentation; rules remain with the game.
### Verification

From Bin/Windows (so native runtime dependencies are discoverable):

    & '../../../Bin/lua.exe' ../../Scripts/Tests/Framework.lua ../..
    & '../../../Bin/lua.exe' ../../Scripts/Tests/Zones.lua ../..
    & "./Card Forge Engine.exe" --smoke

Framework.lua uses in-memory games only; it does not edit the home game library.
## OpenGL presentation

Open CFE, then **Tools > Test Suite > Card Animations**. Restart an already-running
CFE instance after installing these files so LuaEx discovers the new classes.

Five cards are dealt automatically when the tab becomes visible. Click the deck
or **Draw card** (D while the canvas has focus) to draw; hover to inspect; click a
settled hand card to play. **Discard all** (R) gathers the hand and played cards.
The fixture allows ten cards in hand and five played cards. It uses the existing
sample artwork, shadows, hover illumination, and a short ring/particle impact.

The tab is loaded on demand. The existing software-rendered Game Room tab is
unchanged. If the GPU page cannot initialize, it reports the error within its tab.
This is a presentation demonstration: it does not implement card rules, network
synchronization, hidden-information policy, targeting rules or sound.

### Separation

- `Tween.lxc`: time-based numeric interpolation with exact endpoints.
- `CardAnimator.lxc`: interruptible pose movement and arcing motion.
- `CardAnimationScene.lxc`: demonstration hand layout, drawing, hover, play and
  discard state transitions. No gameplay-card state is changed.
- `Scripts/Controls/CardAnimationPage.lua`: native controls, monotonic timer,
  mouse/keyboard input, texture loading, GPU drawing, resize and disposal.
- `Scripts/Plugins/OpenGL`: independent native renderer and Lua wrapper.

Classes use LuaEx discovery and dot-call methods. There are no manual class
requires or convenience aliases. Animation durations/deltas are seconds; angles
are radians. The scene uses 1280x800 logical coordinates, letterboxed to preserve
card proportions. Rendering uses the full canvas viewport; textures retain their
source resolution and use GPU mipmaps when reduced. GPU resources are loaded
once per page and explicitly released before the window is destroyed.

### Verification

From `Bin/Windows`:

```powershell
& '../../../Bin/lua.exe' '../../Scripts/Tests/CardAnimations.lua' '../..'
& '../../../Bin/lua.exe' '../../Scripts/Tests/CardAnimationUI.lua' '../..'
& '../../../Bin/lua.exe' '../../Scripts/Plugins/OpenGL/tests/Verify.lua' '../../Scripts/Plugins'
```

An optional second argument to CardAnimations.lua is an existing directory for
PNG framebuffer captures. Tests check interruption, hand limits, hit testing,
repeated play rejection, 30 draw/play/discard cycles, real shader/texture drawing,
pixel changes across animation states, resize, and repeated renderer lifecycles.
A native Test Suite event-loop check also exercised tab activation, Draw/Discard
button events, timed painting, resizing and close. Existing engine, room geometry
and keyboard shortcut groups passed. Windows/RTX 3060 Ti is the verified platform;
other operating systems and GPU models are not verified.
## Native builds and launcher

The engine uses Card Forge Studio's shared runtime in the parent Bin directory.
The Windows launcher sources and build scripts live in Bin/Windows/Src.

### Windows application launcher

The Engine launcher is Bin/Windows/Card Forge Engine.exe and uses Studio's parent Bin directory.
The executable resolves the installation from its own location and executes root
init.lua. Scripts/Bootstrap.lua loads the bundled wxLuma and opens the initial
window. Application behavior stays in Lua; Bin/Windows/Src/main.c only hosts Lua,
forwards arguments, selects local DLLs and reports startup errors.

Bin/Windows/Src/CMakeLists.txt is the conventional native C build. With a Windows C compiler and generator available, configure
and build into an OS temporary directory, then copy Card Forge Engine.exe to Bin/Windows:

    cmake -S Bin/Windows/Src -B "$env:TEMP/CFE-launcher"
    cmake --build "$env:TEMP/CFE-launcher" --config Release

The executable may be under Release with a multi-configuration generator.
Remove that temporary build directory after copying the executable.

Alternatively, Bin/Windows/Src/Build.cmake supports an installed Zig C compiler:

    cmake "-DZIG_EXECUTABLE=C:/path/to/zig.exe" "-DSTAGING_DIR=$env:TEMP/CFE-launcher" -P Bin/Windows/Src/Build.cmake

Copy the resulting Card Forge Engine.exe to Bin/Windows and remove the temporary directory.
Neither route downloads a compiler or stores caches inside the project.

For a self-closing startup check, run & "./Bin/Windows/Card Forge Engine.exe" --smoke.
It opens the bundled wxLuma window, checks startup and forwarded arguments,
closes the window and writes Bin/Windows/launcher-check.txt on success.
Startup failures return a nonzero exit code and append card-forge-engine-error.log beside
the executable. Interactive failures also display a native error dialog.
Bin/Windows/Src/CardForgeEngine.rc embeds Bin/Windows/Card Forge Engine.ico in the EXE.
The Lua bootstrap also sets this icon on the native application window.

Application Lua modules live in Scripts: Bootstrap.lua owns startup, Windows/Main.lua owns the native frame, and Pages/Welcome.lua owns the welcome page. Root init.lua remains the launcher entry. Bundled wxLuma stays self-contained.

## CFA integration

The standalone CFA plugin maintains the
[format specification](../Scripts/CFA/CFA-1.0.md)
and [library documentation](../Scripts/CFA/README.md).

CFE uses `CFA.Reader` at runtime. The Example Duel build tool uses `CFA.Writer`.
CFE owns the runtime content contract. CFS supplies authored card content and
game and set UUIDs. The future Studio exporter will map Studio projects into
runtime metadata and entries for the CFA writer.

### Example Duel CFA build, read and launch

The editable source lives in `Examples/Source/Example Duel/`. The shipped game lives in
`Examples/Games/Example Duel/`. Its game archive contains Game.lua and Page.lua.
The UUID-named archive directly under `CardSets/` contains Cards.lua and the
artwork. Decks.lua stays beside the game archive.

Run the builder from the Studio/Engine folder. Pass an existing alternate library
path to rebuild into a fresh game folder.

    & '../Bin/lua.exe' ./Dev/BuildExampleCFA.lua

The builder verifies both archives against source and publishes the complete
game folder together. The game and set UUIDs are stable across builds.

**Tools > Test Suite > Example Duel** discovers the packaged game and selects
its card set by UUID. The loader validates the entries it reads, compiles the
trusted bundled scripts explicitly, loads Decks.lua from the game folder, and
decodes card PNGs in memory. It closes the archive handles after page creation.
Restart uses the loaded card and deck definitions. General Games-list launch
and its trust policy remain open.

See the [CFA README](../Scripts/CFA/README.md) for
the standalone checks. Verify the shipped example from the Engine folder:

    & '../Bin/lua.exe' './Scripts/Tests/CFA.lua'

## Verification and remaining work

### Example duel checks

The example's headless test completed twelve seeded duels, checking legal turns,
energy, win/stop behavior, detached snapshots and all forty card objects occupying
exactly one zone after every action. The GPU test loaded all twenty fronts and
checked draw/play framebuffer changes, computer turn completion, restart, resize
and disposal on the RTX 3060 Ti during earlier development. The packaged duel
passed Windows checks for Test Suite launch, native End turn/New game actions
and close. The packaged graphics check passed with loose script loading blocked,
covering rendering, play, computer turns, restart, resize and disposal. CFA
checks cover all five package kinds, unsupported headers, checksum failures,
the independent wire fixture, and byte-for-byte comparison with editable source.
The older Game Room/Card Animations tabs now also reference the organized Example
artwork; no duplicate asset copy is required inside the installation.
### Recorded checks

The zone-foundation work passed the four built-in groups: engine framework,
zones/movement, game-room geometry, and keyboard shortcuts. Zone coverage included
UUIDs, exclusive membership, dense indices, failed-move capacity preservation,
same-zone movement, shuffle failure recovery, layout copies, row/playfield removal,
cloning, and shared game/board snapshot restoration. Shared CoG ordering was
exercised by those focused tests; this is not a claim that every CoG consumer or
its full regression suite was tested.

Earlier OpenGL work recorded native shader/texture drawing, framebuffer changes,
hover/play checks, 30 animation cycles, resize, repeated renderer lifecycle and
native Test Suite events on Windows/RTX 3060 Ti. Earlier startup/discovery work
recorded the launcher smoke check and isolated discovery fixtures. These are
historical results, not fresh results from this documentation consolidation.

The older handoff's exact vendor revisions and byte-for-byte install comparisons
were historical installation records. They do not describe the current shared
junction checkouts and are not current dependency guarantees. Mac/Linux builds,
and complete multiplayer remain unverified.
The Example duel has separate current checks; historical results above do not verify it. Native callbacks are not automatically rollback-safe or secure
against arbitrary debug access. Pending executable closures are not an established
save/network format.

### Remaining work and open contracts

- Playtest and tune the example duel; its initial rules/content are implemented.
- Generalize the example's state/presentation integration only as future games need it; keep rules separate.
- Define the general runtime game and set content schemas and game entry points.
- Build the Studio export adapter against the CFE content contract.
- Connect CFA packages to the Games list launch flow and define package trust.
- Specify Actor, ownership/control, transfers, modifiers, targeting and timing as
  needed; keep game-specific policy outside generic engine operations.
- Design multiplayer transport/authority messages, private views, ordering and
  synchronization; retain stable UUIDs across authority/client copies.
- Determine transaction behavior before relying on complex multi-card operations.
- Maintain this document as implementation advances. Keep confirmed decisions,
  suggested terminology, historical verification and unfinished work distinct.

### Consolidation record

The following CFE-owned files were consolidated and removed in favor of this
repository-root DESIGN.md:

- Card Forge Engine/Scripts/README.md
- Card Forge Engine/Scripts/Engine/README.md
- Card Forge Engine/Scripts/Engine/Animation/README.md
- Card Forge Engine/Src/README.md
- Card Forge Engine/dev/HANDOFF.md

The application/discovery, engine, animation, build and archive material is
retained above. Older handoff statements that zones/movement were absent, vendor
folders were independent pinned copies, IDs were arbitrary nonempty strings or
index one was top have been superseded by the current contracts. Plugin files,
plugin documentation, junction targets and runtime code were not changed by this
consolidation.
