# Bugs

## Studio preferences are split across AppDir configuration files

Consolidated on 2026-11-17. WindowState now uses FS.AppCFG and opens the current file for each save. Manual Editor state uses [ManualEditor]. Existing values were migrated and compared before deleting WindowState.cfg and Card Forge Studio.cfg.manual.ini. The unused legacy EditorTheme setting was removed at the user's direction. Source wiring and saved data were checked. Runtime verification remains with the user.

Studio exposes the main configuration path as `FS.AppCFG`. Two additional files were found in AppDir on 2026-11-17.

- `WindowState.cfg` is active. `WindowState.isOpen` and `WindowState.bind` in `Card Forge Studio/Scripts/Windows/WindowState.lua` default to this separate file for window geometry and visibility. The same module already uses `FS.AppCFG` for `RaiseAllWindows`.
- `Card Forge Studio.cfg.manual.ini` contained `[Manual] EditorTheme=Dark`. The backed-up manual editor in `dev/CFS Experimental/Manual Backup Lua/Editor.lua` writes that preference to a path formed by appending `.manual.ini`. No reference to this filename was found in the active manual editor.

Expected behavior is for application preferences to use `FS.AppCFG`. A fix should preserve existing saved window state and account for the legacy theme preference.

## Manual PDF export reports missing font glyphs

On 2026-11-17 at 08:28:32, Studio logged this error during manual PDF export:

```text
Font ControlFreak-Bold has no glyph for U+21D2.
```

U+21D2 is the rightwards double arrow (⇒). The error references `Card Forge Studio/Scripts/Manual/PDF.lua` at lines 836, 798, and 902. Additional errors were reported. Their messages, fonts, and code points have not been recorded here.
