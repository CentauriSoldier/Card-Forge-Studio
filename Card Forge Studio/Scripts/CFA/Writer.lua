--[[!
@fqxn CFA.Writer
@desc Creates and verifies plain CFA 1.0 archives in a caller-owned stage.
!]]
local _Format = require("CFA.Format");
local _Index = require("CFA.Index");
local _Reader = require("CFA.Reader");
local Writer = {};

--[[!
@fqxn CFA.Writer.write
@desc Writes to a new path in an exclusively owned staging directory, then
    reopens and verifies the archive. The caller publishes the completed stage.
@param string pArchive New archive filename in the caller's staging directory.
@param table tMetadata Package metadata excluding Schema and Entries.
@param table tFiles Dense ordered records with Path and Bytes.
@ret boolean|nil Success.
@ret string|nil Failure category.
!]]
function Writer.write(pArchive, tMetadata, tFiles)
    if (#tFiles > 65535) then return nil, "bounds exceeded"; end

    -- Check the destination before opening it for writing. Staging is exclusive
    -- to the caller so other exporters cannot race this existence check.
    local hExisting = io.open(pArchive, "rb");
    if (hExisting) then
        hExisting:close();
        return nil, "destination exists";
    end

    local tIndex = {Schema = 1, Entries = {}};
    local nPayload = 0;

    for sName, vValue in pairs(tMetadata) do
        if (sName == "Schema" or sName == "Entries") then return nil, "malformed index"; end
        tIndex[sName] = vValue;
    end

    for nOrdinal, tFile in ipairs(tFiles) do
        if (type(tFile) ~= "table" or type(tFile.Bytes) ~= "string") then
            return nil, "malformed index";
        end
        local nSize = #tFile.Bytes;
        if (nSize > _Format.nEntryLimit or nPayload + nSize > _Format.nFileLimit) then
            return nil, "bounds exceeded";
        end

        tIndex.Entries[nOrdinal] = {Path = tFile.Path, Offset = nPayload, Size = nSize,
            CRC32 = _Format.checksum(tFile.Bytes)};
        nPayload = nPayload + nSize;
    end

    local tPaths, sReason = _Format.validate(tIndex, pArchive, nPayload);
    if (not tPaths) then return nil, sReason; end

    local sIndex = _Index.encode(tIndex);
    if (#sIndex > _Format.nIndexLimit or _Format.nHeaderSize + #sIndex + nPayload > _Format.nFileLimit) then
        return nil, "bounds exceeded";
    end

    local sHeader = string.pack(_Format.sHeader, _Format.sMagic, 1, 0, _Format.nHeaderSize,
        #sIndex, nPayload, _Format.checksum(sIndex), "");

    -- Use a scoped file handle. Remove only the partial archive this write owns.
    local bWrote = pcall(function()
        local hOutput <close> = assert(io.open(pArchive, "wb"));
        assert(hOutput:write(sHeader, sIndex));

        for _, tFile in ipairs(tFiles) do
            assert(hOutput:write(tFile.Bytes));
        end

        assert(hOutput:close());
    end);

    if (bWrote) then
        local Handle, sOpenReason = _Reader.open(pArchive);
        if (Handle) then
            local bVerified, sVerifyReason = Handle.verify();
            Handle.close();
            if (bVerified) then return true; end
            sReason = sVerifyReason;
        else
            sReason = sOpenReason;
        end
    end

    os.remove(pArchive);
    return nil, sReason or "I/O failure";
end

return Writer;
