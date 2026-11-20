# CFA · Card Forge Archive

🔵 **Lua 5.4** · 🟣 **CFA 1.0 draft** · 🟢 **Open format**

CFA stores Card Forge games, card sets, and overrides in a dedicated `.cfa`
container. A custom CFA header identifies the file. An index written as a
data-only Lua table locates raw entry bytes, and CRC-32 detects corruption.

[Format specification](CFA-1.0.md) · [Changelog](CHANGELOG.md) · [License](LICENSE)

## 🔵 Choose a module

| Module | What it does | Intended consumer |
| --- | --- | --- |
| `CFA.Reader` | Opens the archive, lists paths, and checks each entry before returning it | Card Forge Engine |
| `CFA.Writer` | Writes a fresh archive to a staging directory and verifies it | Card Forge Studio and build tools |

Both modules use standard Lua 5.4. Add the parent of the `CFA` directory to
`package.path`, or use the equivalent application plugin path.

```lua
local pPlugins = "path/to/plugins";
package.path = pPlugins.."/?.lua;"..package.path;
```

## 🟠 Write an archive

Create a staging directory that belongs exclusively to the current build.
Pass the writer a fresh archive path. Publish the completed staging directory
with your application's filesystem tools.

```lua
local Writer = require("CFA.Writer");
local sUUID = "11111111-2222-3333-4444-555555555555";

assert(Writer.write("staging/"..sUUID..".cfa", {
    Kind = "game",
    UUID = sUUID,
    Title = "Example Game",
}, {
    {Path = "rules.lua", Bytes = "return {};"},
}));
```

## 🟢 Read an archive

```lua
local Reader = require("CFA.Reader");
local sUUID = "11111111-2222-3333-4444-555555555555";
local Handle = assert(Reader.open("MyGame/"..sUUID..".cfa"));

local tMetadata = Handle.getMetadata();
local tPaths = Handle.list();
local sRules, sReason = Handle.read("rules.lua");
Handle.close();

assert(sRules, sReason);
```

`Handle.verify()` checks every entry. The index and entry data are publicly
readable. Checksums detect damage and can be recomputed by anyone. CFE decides
whether to trust and run a packaged script.

## 🟣 Installed layout

```text
MyGame/
    <game-uuid>.cfa
    CardSets/
        <set-uuid>.cfa
    Decks.lua
```

Each set archive sits directly under `CardSets/`. `Decks.lua` is editable.
The format specification also lists the optional override archives.

## 🔧 Verify

Run from the `CFA` directory with an existing empty fixture directory.

```powershell
lua -e 'package.path = "../?.lua;" .. package.path' ./tests/Verify.lua '<empty-fixture-directory>'
```

The suite checks all five kinds, malformed indexes, corrupted data, and an
independent wire fixture.
