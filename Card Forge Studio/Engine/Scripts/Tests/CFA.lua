--[[!
@fqxn CardForgeEngine.Tests.CFA
@desc Checks the shipped Example Duel archives against their editable source.
    Run from the Engine folder with Studio's Lua interpreter.
!]]
package.path = "../Scripts/?.lua;"..package.path;
local _Reader = require("CFA.Reader");

--[[!
@fqxn CardForgeEngine.Tests.CFA.readBytes
@desc Returns source bytes without executing them.
!]]
local function readBytes(pFile)
    local hFile <close> = assert(io.open(pFile, "rb"));
    return assert(hFile:read("a"));
end

local pExample = "./Examples/Games/Example Duel/";
local tArchives = {
    "04cc1a33-f2c1-4fa7-985a-3bde6ff12f08.cfa",
    "CardSets/75c287a3-f3ef-4557-b252-eadbaf5935d8.cfa",
};

for nArchive, pArchive in ipairs(tArchives) do
    local Handle = assert(_Reader.open(pExample..pArchive));
    assert(#Handle.list() == (nArchive == 1 and 2 or 23));

    for _, sPath in ipairs(Handle.list()) do
        assert(Handle.read(sPath) == readBytes("./Examples/Source/Example Duel/"..sPath), sPath);
    end

    Handle.close();
end

assert(readBytes(pExample.."Decks.lua") == readBytes("./Examples/Source/Example Duel/Decks.lua"));
print("PASS: shipped Example Duel matches the editable source.");
