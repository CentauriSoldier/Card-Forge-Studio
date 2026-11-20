--[[!
@fqxn CardForgeEngine.Tests.GameDiscovery
@desc Exercises discovery against an isolated fixture tree, without changing
    the user's game library. Arguments are installation root and fixture root.
!]]
local pRoot, pFixture = assert(arg[1]), assert(arg[2]);
package.path = pRoot.."/?.lua;"..pRoot.."/?/init.lua;"
    ..pRoot.."/../Scripts/Plugins/?.lua;"..pRoot.."/../Scripts/Plugins/?/init.lua;"..pRoot.."/Scripts/Plugins/?.lua;"..pRoot.."/Scripts/Plugins/?/init.lua";
local Discovery = require("Scripts.Services.GameDiscovery");

local tGames, tIssues = Discovery.scan(pFixture);
assert(#tGames == 2, "Only two unambiguous direct child games should be discovered.");
assert(tGames[1].Title == "Alpha" and tGames[2].Title == "Zulu", "Games should be sorted by title.");
local Game = tGames[1];
assert(Game.UUID == "12345678-1234-1234-1234-123456789abc");
assert(Game.Archive:match("123456789abc%.cfa$"));
assert(#Game.Sets == 1 and Game.Sets[1].UUID == "87654321-4321-4321-4321-cba987654321");
assert(Game.Sets[1].Archive:gsub(string.char(92), "/"):match("/CardSets/[^/]+%.cfa$"));
assert(Game.Decks and Game.Overrides.UIO and Game.Overrides.GEO and Game.Overrides.AO);
assert(Game.Image == nil, "Discovery should not invent artwork metadata.");
assert(tGames[2].UUID == "abcdefab-abcd-abcd-abcd-abcdefabcdef");
assert(#tGames[2].Sets == 0 and tGames[2].Decks == nil);
assert(#tIssues == 2, "Ambiguous games and invalid set filenames should be reported.");

local tMissing, tMissingIssues = Discovery.scan(pFixture.."/Missing");
assert(#tMissing == 0 and #tMissingIssues == 0, "A missing library is a normal empty library.");
local tNotDirectory, tNotDirectoryIssues = Discovery.scan(Game.Archive);
assert(#tNotDirectory == 0 and #tNotDirectoryIssues == 1, "A file cannot be a library.");
local pExpected = io.getuserdir():gsub("[/"..string.char(92).."]+$", "").."/Card Forge Engine";
assert(Discovery.getLibraryPath() == pExpected, "Default library must use the home directory.");

-- A later scan should see newly installed packages, not a cached snapshot.
local pNewArchive = pFixture.."/WrongArchive/11111111-2222-3333-4444-555555555555.cfa";
local hFile = assert(io.open(pNewArchive, "wb"));
assert(hFile:write("opaque archive"));
assert(hFile:close());
local tUpdated = Discovery.scan(pFixture);
assert(#tUpdated == 3, "A fresh scan should detect the newly installed package.");
assert(io.delete(pNewArchive));
print("PASS: discovery, UUIDs, sorting, sets, overrides, non-recursion, missing library, diagnostics and fresh snapshots.");
