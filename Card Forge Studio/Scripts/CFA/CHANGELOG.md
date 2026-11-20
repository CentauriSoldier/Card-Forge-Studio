# Changelog

This file tracks changes to the CFA library. Its structure follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Standalone Lua 5.4 reader and writer for the CFA 1.0 draft.
- CRC-32 checks for the index and entry data.
- Round-trip and rejection checks and an independent wire fixture.
- CFA 1.0 format specification and usage examples.

### Changed

- Use a 48-byte CFA header followed by a plain Lua index and raw entry bytes.
- Place UUID-named card-set archives directly in the game's `CardSets/` folder.
- Reject archives from the earlier encrypted draft.

### Removed

- Bundled crypto DLL, native build files, and key carriers.
