--[[!
@fqxn CFA.Reader
@desc Opens plain CFA 1.0 archives and checks entry integrity before returning bytes.
!]]
local _Format = require("CFA.Format");
local _Index = require("CFA.Index");
local Reader = {};

--[[!
@fqxn CFA.Reader.open
@desc Validates the header and index and returns a handle that owns the open file.
@param string pArchive CFA file path.
@ret table|nil Archive handle.
@ret string|nil Failure category.
!]]
function Reader.open(pArchive)
    local hFile = io.open(pArchive, "rb");
    if (not hFile) then return nil, "I/O failure"; end

    local function fFail(sReason)
        hFile:close();
        return nil, sReason;
    end

    local nLength = hFile:seek("end");
    if (not nLength or not hFile:seek("set", 0)) then return fFail("I/O failure"); end
    if (nLength > _Format.nFileLimit) then return fFail("bounds exceeded"); end
    if (nLength < _Format.nHeaderSize) then return fFail("malformed header"); end

    local sHeader = hFile:read(_Format.nHeaderSize);
    if (not sHeader or #sHeader ~= _Format.nHeaderSize) then return fFail("I/O failure"); end

    local sMagic, nMajor, nMinor, nHeaderSize, nIndexSize, nPayload, nIndexCRC, sReserved =
        string.unpack(_Format.sHeader, sHeader);
    if (sMagic ~= _Format.sMagic or nMajor ~= 1 or nMinor ~= 0 or nHeaderSize ~= _Format.nHeaderSize
        or sReserved ~= string.rep("\0", 12)) then
        return fFail("unsupported format");
    end
    if (nIndexSize < 1 or nIndexSize > _Format.nIndexLimit or nPayload < 0
        or nPayload > _Format.nFileLimit) then
        return fFail("bounds exceeded");
    end
    if (nPayload ~= nLength - _Format.nHeaderSize - nIndexSize) then return fFail("malformed header"); end

    local sIndex = hFile:read(nIndexSize);
    if (not sIndex or #sIndex ~= nIndexSize) then return fFail("I/O failure"); end
    if (_Format.checksum(sIndex) ~= nIndexCRC) then return fFail("checksum mismatch"); end

    local tIndex = _Index.decode(sIndex);
    if (not tIndex) then return fFail("malformed index"); end
    local tPaths, sReason = _Format.validate(tIndex, pArchive, nPayload);
    if (not tPaths) then return fFail(sReason); end

    local Handle = {};

    --[[!
    @fqxn CFA.Reader.Handle.getMetadata
    @desc Returns a copy of validated package metadata.
    !]]
    function Handle.getMetadata()
        local tMetadata = {};
        for sName, vValue in pairs(tIndex) do
            if (sName ~= "Entries") then tMetadata[sName] = vValue; end
        end
        return tMetadata;
    end

    --[[!
    @fqxn CFA.Reader.Handle.list
    @desc Lists the virtual paths in index order.
    !]]
    function Handle.list()
        local tNames = {};
        for nOrdinal, tEntry in ipairs(tIndex.Entries) do tNames[nOrdinal] = tEntry.Path; end
        return tNames;
    end

    --[[!
    @fqxn CFA.Reader.Handle.read
    @desc Checks the requested entry checksum and returns its bytes in memory.
    !]]
    function Handle.read(sPath)
        if (not hFile) then return nil, "I/O failure"; end
        local nOrdinal = tPaths[sPath];
        if (not nOrdinal) then return nil, "missing entry"; end

        local tEntry = tIndex.Entries[nOrdinal];
        if (tEntry.Size == 0) then
            if (tEntry.CRC32 ~= 0) then return nil, "checksum mismatch"; end
            return "";
        end

        if (not hFile:seek("set", _Format.nHeaderSize + nIndexSize + tEntry.Offset)) then
            return nil, "I/O failure";
        end
        local sEntry = hFile:read(tEntry.Size);
        if (not sEntry or #sEntry ~= tEntry.Size) then return nil, "I/O failure"; end
        if (_Format.checksum(sEntry) ~= tEntry.CRC32) then return nil, "checksum mismatch"; end
        return sEntry;
    end

    --[[!
    @fqxn CFA.Reader.Handle.verify
    @desc Checks every entry without extracting anything to disk.
    !]]
    function Handle.verify()
        for _, tEntry in ipairs(tIndex.Entries) do
            local sEntry, sError = Handle.read(tEntry.Path);
            if (not sEntry) then return nil, sError; end
        end
        return true;
    end

    --[[!
    @fqxn CFA.Reader.Handle.close
    @desc Releases the archive file handle.
    !]]
    function Handle.close()
        if (hFile) then
            hFile:close();
            hFile = nil;
        end
    end

    return Handle;
end

return Reader;
