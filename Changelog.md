# Changelog

---

<details open>
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
