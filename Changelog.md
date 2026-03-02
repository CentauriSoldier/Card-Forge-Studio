# Changelog

---

<details open>
<summary><strong>v2026.60.19</strong></summary>

### Added
- Live file monitoring system enabling a real-time editor workflow
- Copy card coordinates to clipboard
- Log system with Log window

### Changed
- Custom draw, cell processor, and other functions are now stored within a LiveFileRepo (held by CardSet)
- Class system removed in reference to basic, custom card data. Now purely CSV-drive
- Custom functions are now at the CardSet level rather than the class level
- Refactored Forge to be a Singelton helper class
- Removed draw overlay/border functions and options from utility. These are CardSet-specific and user-defined.

### Fixed
- Ruler drawing improperly

</details>

---

<details>
<summary><strong>v2026.53.19</strong></summary>

### Added
- Tutorial System and several turtorials
- File path system (**FS**) that updates with active game

### Changed
- Display card is now resizable
- Custom draw function is now retrieved from the active CardSet
- Menu system now uses AMS Menu plugin

### Fixed
- Grid window callbacks not set or operating correctly
- Menu not being configured correctly
- Window system not sizing, loading, or saving properly

</details>

---

<details>
<summary><strong>v2025.306.14</strong></summary>

### Added

- Lua- and CSV-based desktop workflow for card game development
- Two-grid editing pipeline:
   - Base Grid (source data)
   - Final Grid (processed, export-ready data)
- Per-row processor resolution, enabling game-specific logic
- Optional per-cell processing hooks for fine-grained transformations
- Immediate synchronization between Base and Final grids on edit
- Selection-driven card preview, using Final grid values only
- Exporter hook system, allowing custom export logic per target file
- Deterministic output paths to ensure stable asset generation
- Local-only execution — all data, rules, and output remain on the user’s machine
- Configurable grid theming, including alternate row coloring and tooltip styling
- Automatic CSV backup system with retention and minimum-interval rules
- Manual row reprocessing for user-initiated rebuilds
- INI-driven configuration for UI state, layout, and preferences
- Style Editor
- Line-by-line code editor access with customizable environment

</details>
