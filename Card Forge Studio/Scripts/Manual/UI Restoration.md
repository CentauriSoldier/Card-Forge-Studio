# Native manual UI restoration

The preserved interface in `Scripts/Manual Backup` is the reference. That folder is read-only throughout the rebuild.

Restored in native wxLua:

- Original Dark and Light palette values, pane widths, section headers and vector tool icons.
- Single top toolbar, grouped left tool rail, themed scrollable Shapes flyout and object context menu.
- Masters, book-style page pairs, searchable style buttons, collapse controls.
- Nested layer rows with visibility and lock controls, inline renaming, fixed bottom action bar.
- Original inspector field grouping, color swatches, numeric arrows, descriptive choices and conditional frame links.
- Three-column Manual Options with original labels, paired measurements and no overflowing columns in the tested window.
- Separate read-only game and editable manual style lists, inheritance, optional font size, New/Delete and Save.

Verification uses a temporary copy of the 68-page game manual. Native window creation, painting, popups, numeric updates, style application, manual style creation/deletion, linked text/contents, nested scaling, themes, save/reopen and clean shutdown passed. The Windows common color dialog was constructed; its color commit was tested with modal acceptance simulated, rather than an automated click through the operating system dialog.

This records UI restoration, not pixel-identical equivalence of every platform widget. wxLua text fields, dropdown arrows and scrollbars retain native Windows rendering. Imported PDF text remains a best-effort conversion. CMYK and searchable PDF export are not implemented.
