<details>
<summary><strong>[2025.306.14]</strong></summary>

### Added

- Lua- and CSV-based desktop workflow for card game development
- Two-grid editing pipeline:
   - Base Grid (source data)
   - Final Grid (processed, export-ready data)
- Per-row processor resolution, enabling game-specific logic.
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
