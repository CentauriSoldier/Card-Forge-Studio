--[[!
@fqxn CFA.Tests
@desc Verifies the open CFA format with a standard Lua interpreter.
!]]
local _pFixture = assert(arg[1], "Specify an existing empty fixture directory.");
local _Reader = require("CFA.Reader");
assert(not package.loaded["CFA.Writer"]);
local _Writer = require("CFA.Writer");
local _Format = require("CFA.Format");
local _Index = require("CFA.Index");
local _sUUID = "11111111-2222-3333-4444-555555555555";

--[[!
@fqxn CFA.Tests.readBytes
@desc Returns fixture bytes without evaluating them.
!]]
local function readBytes(pFile)
    local hFile <close> = assert(io.open(pFile, "rb"));
    return assert(hFile:read("a"));
end

--[[!
@fqxn CFA.Tests.writeBytes
@desc Writes a synthetic or modified archive into the test fixture.
!]]
local function writeBytes(pFile, sBytes)
    local hFile <close> = assert(io.open(pFile, "wb"));
    assert(hFile:write(sBytes));
end

--[[!
@fqxn CFA.Tests.flip
@desc Changes a byte without altering the physical length.
!]]
local function flip(sBytes, nPosition)
    return sBytes:sub(1, nPosition - 1)..string.char(sBytes:byte(nPosition) ~ 1)..sBytes:sub(nPosition + 1);
end

--[[!
@fqxn CFA.Tests.roundTrip
@desc Tests export and reading for one package kind and checks rejected input.
!]]
local function roundTrip(sKind)
    local pFile = _pFixture.."/".._sUUID..".cfa";
    local tMeta = {Kind = sKind, UUID = _sUUID, Title = 'Café and "quotes"\\', Thumbnail = "art.png"};
    if (sKind ~= "game" and sKind ~= "set") then tMeta.GameUUID = _sUUID; end

    local sPNG = ("\137PNG\r\n\26\n\0\0\0\13IHDR\0\0\0\1\0\0\0\1\8\4\0\0\0\181\28\12\2"
        .."\0\0\0\11IDATx\218cd\248\15\0\1\5\1\1'\24\227f\0\0\0\0IEND\174B\96\130");
    local tEntries = {{Path = "empty.lua", Bytes = ""}, {Path = "art.png", Bytes = sPNG}};
    assert(_Writer.write(pFile, tMeta, tEntries));

    local Handle = assert(_Reader.open(pFile));
    assert(Handle.getMetadata().Title == tMeta.Title);
    assert(Handle.getMetadata().Thumbnail == "art.png");
    assert(Handle.list()[1] == "empty.lua");
    assert(Handle.read("empty.lua") == "");
    assert(Handle.read("art.png") == sPNG);
    local _, sMissing = Handle.read("missing");
    assert(sMissing == "missing entry");
    assert(Handle.verify());
    Handle.close();

    local sBytes = readBytes(pFile);
    local _, sExists = _Writer.write(pFile, tMeta, tEntries);
    assert(sExists == "destination exists" and readBytes(pFile) == sBytes);

    -- Header/index failures occur at open. Payload failure occurs at read.
    for _, tMutation in ipairs({
        {flip(sBytes, 9), "unsupported format"},
        {"PK\3\4"..sBytes:sub(5), "unsupported format"},
        {sBytes:sub(1, 12)..string.pack("<I4", 128)..sBytes:sub(17), "unsupported format"},
        {flip(sBytes, 49), "checksum mismatch"},
        {sBytes:sub(1, -2), "malformed header"},
        {sBytes:sub(1, 16)..string.rep("\255", 8)..sBytes:sub(25), "bounds exceeded"},
    }) do
        writeBytes(pFile, tMutation[1]);
        local _, sError = _Reader.open(pFile);
        assert(sError == tMutation[2], sError);
    end

    writeBytes(pFile, flip(sBytes, #sBytes));
    Handle = assert(_Reader.open(pFile));
    assert(Handle.read("empty.lua") == "");
    local _, sCorrupt = Handle.verify();
    assert(sCorrupt == "checksum mismatch");
    Handle.close();
    assert(os.remove(pFile));

    local _, sDuplicate = _Writer.write(pFile, tMeta, {
        {Path = "art.png", Bytes = ""}, {Path = "ART.PNG", Bytes = ""},
    });
    assert(sDuplicate == "malformed index");
    local _, sUnsafe = _Writer.write(pFile, tMeta, {{Path = "../art.png", Bytes = ""}});
    assert(sUnsafe == "malformed index");
end

assert(_Format.checksum("123456789") == 0xcbf43926 and _Format.checksum("") == 0);
for _, sKind in ipairs({"game", "set", "ui", "graphics", "animation"}) do
    roundTrip(sKind);
end

for _, sMalformed in ipairs({
    '{Schema=1, Schema=1}', '{Title=print("run")}', '{Schema=01}', '{Title="bad\\999"}',
    '{Entries={[1]={}}}', '{Schema=1} {}', '{Title="'..string.char(255)..'"}',
}) do
    assert(not _Index.decode(sMalformed), "Invalid index syntax was accepted.");
end

-- This fixture was assembled independently from the offset table and CRC parameters.
local Handle = assert(_Reader.open("./tests/vectors/".._sUUID..".cfa"));
assert(Handle.getMetadata().Title == "Interoperability");
assert(Handle.read("a.txt") == "123456789");
assert(Handle.verify());
Handle.close();

print("PASS: CFA round trips, format rejection, checksums and independent wire fixture.");
