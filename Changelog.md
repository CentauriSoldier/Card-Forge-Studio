# Changelog

---

<details open>
<summary><strong>Alpha 0.3 — 2026-10-10</strong></summary>

### Added

- Atlas export with shared sheet generation, Generic format 1 and LÖVE 11.5 targets, explicit target-version labels, and documented version-specific target functions.
- CSV, JSON, and Lua exports of finalized card data, preserving text values and source column order.
- One interactive HTML exporter with 20 selectable themes, search, filtering, enlarged card viewing, front/back switching, and embedded card data.
- ZIP export with selectable card artwork, finalized CSV/JSON/Lua data, and the same themed HTML gallery.
- Shared export selection and format-specific options, remembered per card set across PNG, Atlas, CSV, JSON, Lua, HTML, and ZIP.
- Game and standalone card-set packages using .cfsg and .cfscs extensions, ZIP contents, and a shared import/export format version with an explicit compatibility list.
- Staged package validation, Lua syntax checks without script execution, template repairs for missing required files, logged skipped invalid rows or card sets, overwrite confirmation, and replacement backups.
- Standalone card-set packages carrying their own assets and source-game dependencies for import into another game without replacing that game's setup.
- Shared FS-owned required-file manifests used by project creation, validation, and import repairs.
- Separate Import/Export sections in the Game and Card Set menus; imports install projects without activating them and reject matching active IDs.
- Close Game and Close Card Set actions at the bottom of their menus, with separators, active-state cleanup, preview/tool/file-watcher cleanup, logging, and unsaved-change cancellation.
- Util.BuildAPIDocs and a development-only Help command, with start/completion logging and build failures reported to the Log window with tracebacks.
- Development-only release ZIP building through Util, editable root-file/folder/exclusion tables, required runtime files, launcher-source exclusion, packaged development mode disabled, and a remembered destination folder.
- Native License window displaying the root license text beneath a third-party licensing explanation; the license is included in release packages.
- Help Feedback command opening GitHub Issues for bugs and feature requests.
- Game documentation rebuilding with per-game saved page and code-highlighting themes, optional Card Forge Studio API/plugin inclusion defaulting to off, and a bordered Docs options section with live palette previews.
- Native Tutorials window with separate Basic and Advanced lists, numbered steps across the top, larger instructional text, and adjacent Previous/Next navigation.
- Three basic tutorials with 13 steps and 12 advanced tutorials with 51 steps, practical examples, editable topic/step ordering, and screenshot slots using Missing.png until images are supplied.
- Dynamic autocomplete in Lua source editors and code-column editors, covering available built-ins, constants, namespaces, nested configuration, game-defined helpers, processing globals, styles, and active card-set column headers.
- Generated per-game autocomplete.lua snapshots containing completion names and types rather than card values; required-file repair creates missing caches for older games.
- Cache updates following environment/configuration changes and card-set/header changes, atomic writes, unchanged-content detection, and completion documentation from existing API comments.
- Automatic suggestions while typing with a configurable character threshold, highlighted-item documentation, and global enable/disable switches for autocomplete and its help panel.
- Live searchable Environment Reference window beside editor Options, with variable names, types, documentation, and updates as the current environment changes.
- Categorized global Editor Options with independent theme-color, suggestion/help font-size, and reference font-size inheritance switches, all enabled by default; retained custom colors and four independent font-size controls.
- Five visible autocomplete suggestion rows with a scrollable result list and a larger documentation area sized to its content within available editor space.
- Environment Reference size/position persistence and a live-resizing draggable divider with a globally remembered position.
- User-environment assert, error, pcall, and xpcall helpers; Exists now checks sanitized resource-relative paths through FS.
- UserEnv.Refresh restores built-ins and clears previous-game entries on game load while retaining user control of overrides during environment reloads.

### Changed

- Expanded system documentation to explain responsibilities, inputs, and connections in plain language; FS now explains its virtual path map, relative paths, validation, and safer file access.
- Added missing category/system landing pages, standardized Functions/Constants/Namespaces/Private organization, and grouped individual exporters beneath Exporter → Exporters.
- Clarified that private UserEnv entries are internal API reference material, unavailable to game scripts.
- Updated the documentation landing page with framed existing artwork and removed redundant headings and the intro-card label.
- Moved API documentation generation out of application startup into the manual development-only command.
- Consolidated HTML Static Gallery and HTML Preview into HTML with built-in interaction and selectable themes.
- Moved seven deferred print, tabletop, and Unity-package exporters into Exporters/Planned; these targets remain unavailable.
- Organized Game tools beneath New/Load/Browse, moved Wiki, Style Editor, Mechanics Viewer, Docs, and Rebuild Docs into Game, and separated maintenance actions.
- Removed the File Export placeholder, renamed Edit CSV to Open CSV, and added a separator above License.
- Replaced obsolete browser tutorials with ordered Lua topic files under Scripts/Tutorial and tutorial-image slots under Images/Tutorial.
- Style export now offers resolved values without inheritance, the complete recursive inheritance chain, or Cancel; style import validates into the editor draft and asks before replacing matching names.
- Removed unavailable legacy drawing exports/constants/color helpers and unused Card, ProcSys, and Session environment namespaces; retained active RGB/RGBA and internal environment-key trackers.
- Deferred export cancellation, recent games, and a Show export folder action.

### Fixed

- Exporter changes clearing the drawing row, styles, and numeric-conversion markers during metadata refresh, causing processing and renderer errors.
- Export options and repeat-export controls remaining usable during an active export; both grids now disable them and restore availability afterward.
- Rebuild Docs calling an uninitialized global; the menu now loads the builder directly and stays unavailable until a game is loaded.
- Broken or cyclic style-inheritance chains being accepted during export/import validation.
- Missing completion data on first game load and stale row/header suggestions after environment changes.
- Autocomplete immediately disappearing because focus checks compared different Lua wrappers for the same native editor control.
- Long environment names expanding the reference list until its description pane became unreadably narrow.
- Stale Refresh references and missing internal tracking declarations after removal of unused environment namespaces.

</details>

---


<summary><strong>Alpha 0.2 — 2026-10-09</strong></summary>

### Added

- Native Windows launcher and Lua 5.4/wxLua desktop runtime.
- New Game and New Card Set creation with template files, defaults, validation, and rollback.
- Dedicated game/card-set source editors, new-file actions, persistent active tabs, and card-set notes.
- PNG export for all, visible, or selected cards, with progress, 1–1000% sizing, a 64-million-pixel limit, and a Default button.
- Bulk card creation and column management with add, rename, delete, save protection, and reload after changes.
- Styled game/card-set loaders with square logos, a No Logo fallback, and independent saved window sizes.
- Game and card-set Info interfaces; Forge background, Card Canvas, guides, and preview options.
- Configurable grid row, text, and index colors with a fixed, read-only live preview.
- Per-entry log copying and Copy All; missing-image fallback artwork.
- CFS API documentation and project-named Pulsar autocomplete packages, with development startup build/install support.
- Documentation page themes, independent Prism themes, custom banners, and parser-specific example highlighting.

### Changed

- Ported Studio from AutoPlay Media Studio to a native Lua/wxLua application, replacing its host-specific UI and runtime integration.
- Rebuilt native editing, wiki, logging, styling, and window-state interfaces around the existing Lua/CSV workflow.
- Separated the generic Exporter coordinator from the PNG exporter; other legacy export formats remain deferred.
- Export destinations are remembered per card set, initially defaulting to the game's Exports folder.
- Source-editor options live in their editors; Forge options and Preview share the main Options window.
- Documentation namespaces use consistent CFS names; generated game/card-set entries follow their names and update on rename.
- Expanded Studio documentation, public autocomplete tags, signatures, and verified generated accessors.
- Removed unused pane definitions, legacy processing scaffolding, and abandoned row-filter files while retaining active CSV processing.

### Fixed

- Game/card-set creation failures, invalid UUID/path handling, and failed-write cleanup.
- Empty Name-only CSV loading and trailing-newline phantom rows.
- Non-numeric card dimensions and column changes losing alignment with code-column definitions.
- Matching row highlighting between Base Data and Final Data, including sorted and filtered views.
- Grid color-picker painting and excess blank sample-grid canvas; canceled preview colors reset on reopening.
- Documentation import, tag iteration/validation, MIME preprocessing, wrapper handling, and LF/CRLF comment extraction.
- Lua documentation extraction matching template strings as comments.
- Documentation Back/Forward navigation, inherited-content chains and cycles, and output failure handling.
- Pulsar package generation, code-name mapping, callable-class members, and documented object-member completion.

</details>

---

<details open>
<summary><strong>Alpha 0.1</strong></summary>

### Added
- Vertical and horizontal guides on the canvas
- CSV Data LiveFileRepo
- Live file monitoring system enabling a real-time editor workflow
- Log system with Log window
- Copy card coordinates to clipboard
- Tutorial system and several tutorials
- File path system (**FS**) that updates automatically when the active game changes
- Lua- and CSV-based desktop workflow for card game development
- Two-grid editing pipeline:
   - Base Grid (source data)
   - Final Grid (processed, export-ready data)
- Per-row processors
- Optional per-cell processing hooks for fine-grained transformations
- Immediate synchronization between Base and Final grids when Base data is edited
- Selection-driven card preview using the processed Final grid row
- Automatic CSV backup system with configurable retention count and minimum time interval
- Optional manual row reprocessing
- INI-based configuration system for storing window layout, UI state, and preferences
- Style Editor for fancy card text
- Safe fallback handling when user `Draw`, `RowProc`, `CFG`, or `ENV` scripts fail during load or live reload
- Ability to draw back of card

### Changed
- **CellProc** system renamed to **RowProc**
- **RowProc** function now cached
- **Draw** function now cached
- Custom draw, cell processor, and other functions are now stored within a LiveFileRepo (managed by ProcSys)
- Custom functions are now at the CardSet level rather than the class level
- Class system removed in relation to basic, custom card data; system is now purely CSV-driven
- All **LiveFileRepo**s moved out of their respective classes (e.g., **CardSet**) and into **ProcSys**
- Cleaned up **ProcSys** and **Forge** modules
- Refactored Forge to be a Singleton helper class
- Refactored FontStyle to use LiveFileRepo system (managed by ProcSys) and integrated it into the live editor
- Custom draw function is now retrieved from the active CardSet directory
- Forge's utility image now redraws only when changes occur
- Display card is now resizable
- Menu system now uses AMS Menu plugin
- Stabilized and streamlined timer systems
- Dirty user code now logs errors without interrupting loading or configuration
- Systems relying on dirty user code now recover automatically and gracefully after the user fixes the code
- Removed draw overlay/border functions and options from utility (these are now CardSet-specific and user-defined)

### Fixed
- Ruler drawing improperly
- Grid window callbacks not set or operating correctly
- Menu not being configured correctly
- Window system not sizing, loading, or saving properly
- Invalid user `RowProc`, `Draw`, `CFG`, or `ENV` code could previously break loading
- Editor could become unstable when loading a CardSet containing invalid user scripts
- Live reload could enter unstable states when user code failed during rebuild
- Timer execution could become stuck or repeatedly retry failing user code
- Log window could spam repeated identical runtime errors
- Draw system could execute before row data was available

</details>
