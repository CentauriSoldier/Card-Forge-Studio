# Manual appearance

Open **Options → Manual Editor**, or **Appearance…** in the manual toolbar. Choose a target and edit its properties. Blank values inherit the saved base design. Apply saves the active game's settings and updates the open preview without reloading its text.

Settings belong to `Manual/Config/Appearance.lua`, a Lua configuration loaded with the existing serializer. The base design is `Manual/Styles/Appearance Base.css`. Artwork belongs to `Manual/Images/Appearance`. Paths in the property grid start with `Images/`; the base stylesheet uses `{{MANUAL_IMAGES}}` for portable artwork URLs. Web export packages these assets and writes `css/appearance.css`.

Targets cover the page, layout, title banner, title/subtitle, chapter container, navigation, tables, quotations, code, and each heading level's section, heading bar, content backing and connecting rail. Named text styles reference existing game styles. No named style definition is edited by these controls. Text styles keep the surrounding heading size unless Text size is set explicitly.

Examples:

- Background: `#202830` or `linear-gradient(#303840, #182028)`.
- Inner / outer spacing: `1rem`, `0.5rem 1rem`, or `0`.
- Background image: `Images/Appearance/Defaults/Panel.svg`; sizing: `cover` or `100% 100%`.
- Frame: the Panel SVG; slice: `12 fill`; width: `12px`; repeat: `stretch`.
- Corners: `Images/Appearance/Defaults/CornerTL.svg` (and TR, BL, BR); size: `24px 24px`.
- Connecting rail: `Images/Appearance/Defaults/Rail.svg`; width: `8px`; height: `1rem`; top: `-1rem`; left: `2rem`.
- Hide a decoration: Display `none`. Corner artwork belongs on sections/headings, not on rails.

App defaults live in `Images/Manual/Defaults` and `Docs/Templates/Manual`. Missing defaults are copied to the game's `Manual/Images/Appearance/Defaults`; existing files and the current design are retained.

The content toolbar adds heading levels 1–6, numbered lists, links, images, fenced code, separators and tables with selectable dimensions/alignment. Existing style and Markdown wrapping tools remain available. Content typing and insertion tools share the manual editor's Undo/Redo history.

Appearance applies to the manual preview and Web export. The existing pure-Lua PDF renderer does not consume this CSS theme. Runtime and visual verification remain for the user.
