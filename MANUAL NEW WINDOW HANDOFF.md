# Manual new window handoff

## Status — November 27, 2026

The dedicated Manual Appearance window is implemented but **not ready to claim fully working**. Work stopped at the user's request before they left for work. Do not launch more native tests until resuming with the user.

The user wants Run Bun to demonstrate the built-in Appearance system, without requiring a custom stylesheet. Keep support for custom CSS. Preserve existing game content and artwork. Migration of Run Bun's theme has **not** happened.

## Current changes

- `Card Forge Studio/Scripts/Windows/ManualAppearance.lua`: replaces the old embedded property grid with a modeless window. Visual and Artwork tabs provide color pickers and choices for text, alignment, borders, spacing, backgrounds and frames. Advanced retains exact property values. Each field can inherit, and the selected section can reset. A temporary HTML sample uses the existing appearance renderer. Save writes through the existing conflict-checked settings API; closing is intended to discard unsaved drafts and restore saved appearance.
- `Card Forge Studio/Scripts/Manual/Adapter.lua`: the existing Appearance button opens/raises that window. Draft CSS is sent through the existing editor-options update channel and retained across document navigation. Editor close and draft reporting include the appearance window.
- `Card Forge Studio/Scripts/Windows/Options.lua`: removes the embedded appearance grid and points users to Appearance in the manual editor. Line-number settings remain.
- `Card Forge Studio/Scripts/Manual/Appearance.lua`: adds heading-accent targets and alignment/background/frame fields. Corrects selector splitting for commas inside functions and attributes. Heading text overrides target the actual heading elements. Explicit overrides receive priority, except legacy Container defaults. Missing override artwork falls back to bundled artwork with warnings; explicit `none` remains none.

The settings format remains `Manual/Config/Appearance.lua`, Version 1. Reset clears a target's overrides and inherits its configured base theme; it does not erase that base stylesheet. Existing custom CSS remains supported. The sample is generic, not a copy of the current document.

## Verification and browser crash

- Lua syntax passed for all four changed Lua files.
- Isolated renderer checks passed: grouped selectors, heading text properties, hidden accents, custom/missing artwork, explicit none, path traversal rejection and cleared overrides.
- Native bindings for color pickers, grid events, WebView and color accessors were checked.
- A hidden native-window test created the window, then the **test harness** failed while walking child widgets: a returned object had no `GetChildren` method. The test exited before exercising Save/Cancel. This is not evidence that those operations work.
- The user then saw an `msedgewebview2.exe` breakpoint exception dialog and said they would dismiss it. The test's abrupt exit may have caused the browser crash, but that is **unconfirmed**. Do not describe the crash as diagnosed or fixed.
- Application event-log/CIM inspection did not yield usable evidence. The final process listing had no `lua` test process. Do not terminate unrelated Edge/WebView processes.
- Temporary harness: `C:/Users/CS/AppData/Local/Temp/cfs-appearance-native-test.lua`. Its native child traversal needs proper wxLua object casting or a different approach, and it needs guaranteed cleanup on failure before reuse.

## Resume priorities

1. Review the new window and adapter lifecycle before another native run. Keep test data isolated and guarantee browser/window cleanup even on assertion failures.
2. Verify live preview, saved-versus-draft isolation, Save, reset of one target, Cancel, close veto, document switching, external settings conflicts, and game/editor shutdown.
3. Verify the visual layout and cues with the user. Native checks and the user's Studio acceptance are still outstanding.
4. Check override precedence against Run Bun's existing custom theme. Do not silently migrate or overwrite it.
5. Complete the requested removal of H2–H6 heading borders and centering through the appearance system where possible. That latest styling request remains pending; the earlier thin H2 header treatment is still present.
6. Discuss and authorize further additions separately: section-specific themes, responsive controls, glossary columns and layered cover artwork. They are not implemented in this first window.

## Other work completed in this session

- Manual file dropdown has previous/next arrow buttons in `Scripts/Manual/Web/Editor.html` and `Scripts/Manual/Web/js/admin.js`. They use its existing change handler and unsaved-edit prompt. JavaScript syntax and isolated navigation/endpoints/cancel checks passed; user visual acceptance remains pending.
- Run Bun manual heading levels were normalized. **Glossary is deliberately restored to H2 title/H3 entries:** its current parser requires that hierarchy. The normalization initially broke preview initialization; restoring the glossary fixed the incompatible input. No glossary parser code was changed.
- Run Bun CSS now uses actual `manual-heading-level-*` classes for H1 ornate versus inner thin frames, adds inner spacing, and has the earlier centered thin H2 heading treatment. User wants the lower-level borders removed next.
- All 23 Almanac artworks exist. Artwork chat reported installing the 19 missing CSV rows and verifying 295 total cards, 23 unique Almanac cards and valid artwork paths through Studio's CSV parser. Existing rows were preserved. User plans later art corrections.
- User cancelled the lowercase filename/CSV rename. Keep uppercase `Day of the` filenames and card names. The user is handling banner text/drawing adjustments themselves; preserve their concurrent edits.

## Boundaries

Read current project AI rules. Work in this chat unless the user authorizes delegation. Honor file-specific code permission, preserve unrelated changes and do not add unsolicited backups. This handoff is a status record, not authorization for deferred features. Nothing was committed or pushed by this work.
