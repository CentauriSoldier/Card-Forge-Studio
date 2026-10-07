# Changelog

---

<details open>
<summary><strong>Alpha (Current)</strong></summary>

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
