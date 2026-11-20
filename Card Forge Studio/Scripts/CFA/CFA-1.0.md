# Card Forge Archive (CFA) 1.0

**Status:** Draft wire format for an open, uncompressed archive. Extension `.cfa`.

CFA is a dedicated Card Forge container. Its header identifies it independently
of its filename. Contents are readable by any implementation of this format.
CRC-32 detects accidental corruption. Publisher identity and script trust are
application policies. A reader treats the index and entry contents as data.

MUST and SHOULD describe format requirements. Offsets are zero-based and all
binary integers are unsigned and little-endian. A byte means eight bits.

## 1. Game layout

```text
MyGame/
    <game-uuid>.cfa
    CardSets/
        <set-uuid>.cfa
    Decks.lua
    UIO.cfa
    GEO.cfa
    AO.cfa
```

A readable folder name identifies the game to users. The game archive filename
uses the game UUID. Card-set archives sit directly in `CardSets/`, using the
card-set UUID in each filename. Card Forge Studio exporters MUST preserve game
and card-set UUIDs. Game rules belong inside the game archive. `Decks.lua` is
user-editable and stays beside it. The override archives are optional.

## 2. Wire format

The file consists of a 48-byte header, the UTF-8 index, then the raw entry bytes
in index order. It contains no compression, encryption, padding, or trailing
bytes. The physical length MUST equal `48 + IndexSize + PayloadSize` exactly.

| Offset | Bytes | Field | Value |
| --- | ---: | --- | --- |
| 0 | 8 | Magic | Hex `43 46 41 0D 0A 1A 0A 00` |
| 8 | 2 | Major | 1 |
| 10 | 2 | Minor | 0 |
| 12 | 4 | HeaderSize | 48 |
| 16 | 8 | IndexSize | Index length in bytes |
| 24 | 8 | PayloadSize | Total raw entry length in bytes |
| 32 | 4 | IndexCRC32 | CRC-32 of the exact index bytes |
| 36 | 12 | Reserved | All zero |

Check all fixed fields, lengths and the index checksum before parsing.
Readers MUST reject other versions and header sizes. An archive from the
earlier encrypted draft has a different header size and is unsupported.

Every checksum uses CRC-32/ISO-HDLC, with reflected polynomial `0xEDB88320`,
initial state `0xFFFFFFFF`, and final XOR `0xFFFFFFFF`. The ASCII test string
`123456789` produces `0xCBF43926`. The empty string produces zero.

## 3. Index

The index is one UTF-8 Lua table constructor in this data-only grammar.

```text
index   = record EOF
record  = "{" [ field { "," field } [ "," ] ] "}"
field   = name "=" ( string | uint | array )
array   = "{" [ record { "," record } [ "," ] ] "}"
name    = ASCII letter { ASCII letter | ASCII digit | "_" }
uint    = "0" | nonzero ASCII digit { ASCII digit }
```

Space, tab, CR and LF may separate tokens. Strings use double quotes. Literal
UTF-8 is allowed inside strings except for ASCII control bytes, quotes and
backslashes. Escape quotes as `\"`, backslashes as `\\` and control bytes as
exactly three decimal digits preceded by a backslash (`\000` through `\031`
or `\127`). An index MUST reject invalid UTF-8, a BOM, duplicate keys, trailing
content, comments and executable syntax. Use a bounded data parser.

| Field | Type | Meaning |
| --- | --- | --- |
| Schema | Integer | 1 |
| Kind | String | `game`, `set`, `ui`, `graphics` or `animation` |
| UUID | String | Logical UUID in lowercase canonical form |
| Title | String | Display name, 1–256 UTF-8 bytes |
| Entries | Array | Entry records in physical order |
| GameUUID | String, optional | Required target UUID for overrides |
| Thumbnail | String, optional | Exact path of an embedded PNG |
| Description | String, optional | At most 4096 UTF-8 bytes |

Unknown properties are invalid. UUIDs use canonical 8-4-4-4-12 hex groups.
Version bits are unrestricted. The UUID of a game or set MUST match the
archive filename, ignoring ASCII case. Array positions are implicit and
consecutive. Every entry record has exactly these fields.

| Field | Type | Meaning |
| --- | --- | --- |
| Path | String | Unique relative virtual path |
| Offset | Integer | Start relative to the payload |
| Size | Integer | Number of bytes stored |
| CRC32 | Integer | CRC-32 of these bytes, 0–4294967295 |

The first offset is zero. Each next offset is the prior offset plus its size.
The last offset plus size equals `PayloadSize`. Empty entries are allowed.
Readers MUST reject gaps, overlap, out-of-range regions and unreferenced bytes.
Verify a requested entry’s checksum before returning it. Verifying an index
alone does not verify any entry. Check PNG dimensions and memory limits before
decoding a thumbnail.

## 4. Virtual paths

Paths are relative and case-insensitively unique. They use ASCII letters,
digits, underscores, hyphens, dots and forward slashes. Reject leading or
trailing slashes, empty components, `.`, `..`, trailing dots, and Windows
device basenames `CON`, `PRN`, `AUX`, `NUL`, `COM1` through `COM9` and
`LPT1` through `LPT9`, including before an extension. A component can use up
to 128 bytes and a complete path up to 1024 bytes. Archive paths are virtual
and have no filesystem meaning. Entries represent file bytes only. Reading
MUST NOT automatically extract or execute entry contents.

## 5. Limits and failure behavior

- File size is at most 64 GiB (68,719,476,736 bytes).
- Index size is 1–16,777,216 bytes.
- Entry count is 1–65,535, and a single entry is at most 256 MiB (268,435,456 bytes).
- Table nesting is at most 16 levels, including the outermost table.
- Thumbnails are at most 2048 × 2048 pixels and 16 MiB decoded RGBA.

Bound work and memory before allocation or seeking. Use separate failures for
unsupported formats, malformed headers or indexes, exceeded bounds, checksum
mismatches, missing entries and I/O problems. Reject a corrupt archive without
falling back to another format. A package loader should report the affected
game so other games remain discoverable.

## 6. Reader and writer

A reader opens and validates the index, lists metadata and paths, reads one
entry with its checksum check, verifies all entries on request, and closes its
handle. The Lua writer takes package metadata and an ordered array of entry
bytes. It writes to a fresh path in a caller-owned staging directory, closes
the file, and verifies it through the reader. The application publishes the
completed stage without silently overwriting an existing package.

The Example Duel is one consumer. Its scripts and card data follow a separate
content contract. Future editors and exporters can implement this same wire
format independently.

