local assert  = assert;
local error   = error;
local ipairs  = ipairs;
local io      = io;
local string  = string;
local table   = table;
local xpcall  = xpcall;
local debug   = debug;
local Archive = {};
local tCRC    = {};
for nIndex = 0, 255 do
    local nValue = nIndex;
    for _ = 1, 8 do nValue = (nValue & 1) ~= 0 and ((nValue >> 1) ~ 0xedb88320) or (nValue >> 1); end
    tCRC[nIndex] = nValue;
end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterZip.Archive
@desc Streaming, dependency-free stored ZIP writer with CRC-32 and UTF-8 filenames. Images are already PNG-compressed. ZIP64 is not supported: archives must stay below 4 GiB with fewer than 65,535 entries. Oversized jobs fail before their output is committed.
@vis private
!]]

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterZip.Archive.Functions.write
@desc Writes local headers, file bytes, verified CRCs, a central directory, and an end record. Source callbacks return either bytes or a temporary file path. Every owned handle closes on failure.
@param string pArchive Staged archive path.
@param table tEntries Ordered records with safe flat filenames.
@param function fSource Returns bytes or nil plus a file path.
@param function|nil fProgress Packaging progress.
@vis private
!]]
function Archive.write(pArchive, tEntries, fSource, fProgress)
    assert(#tEntries > 0 and #tEntries < 65535, "ZIP entry count is outside the supported range.");
    local hArchive = assert(io.open(pArchive, "w+b"));
    local hSource, tCentral, tSeen = nil, {}, {};
    local bOK, sError = xpcall(function()
        --[[!
        @fqxn CFS.Modules.Exporter.Exporters.ExporterZip.Archive.Private.Functions.emit
        @desc Writes archive bytes and rejects unsupported total size.
        @vis private
        !]]
        local function emit(sBytes)
            assert(hArchive:write(sBytes));
            assert(hArchive:seek() < 0xffffffff, "ZIP exceeds the supported 4 GiB size limit.");
        end
        for nIndex, tEntry in ipairs(tEntries) do
            local sName = tEntry.name;
            assert(#sName > 0 and #sName <= 65535 and not sName:find('[%z\1-\31/\\:]') and sName ~= '.' and sName ~= '..' and not tSeen[sName:lower()], "Unsafe or duplicate ZIP filename.");
            tSeen[sName:lower()] = true;
            local nOffset = assert(hArchive:seek());
            --[[!
            @fqxn CFS.Modules.Exporter.Exporters.ExporterZip.Archive.Private.Functions.header
            @desc Encodes a stored-file local header.
            @vis private
            !]]
            local function header(nCRC, nSize)
                return string.pack("<I4I2I2I2I2I2I4I4I4I2I2", 0x04034b50, 20, 2048, 0, 0, 33, nCRC, nSize, nSize, #sName, 0);
            end
            emit(header(0, 0)..sName);
            local sBytes, pSource = fSource(tEntry);
            local nCRC, nSize = 0xffffffff, 0;
            --[[!
            @fqxn CFS.Modules.Exporter.Exporters.ExporterZip.Archive.Private.Functions.consume
            @desc Streams a chunk while accumulating byte count and CRC.
            @vis private
            !]]
            local function consume(sChunk)
                nSize = nSize + #sChunk; assert(nSize < 0xffffffff, "ZIP entry exceeds the supported size limit.");
                for nByte = 1, #sChunk do nCRC = (nCRC >> 8) ~ tCRC[(nCRC ~ sChunk:byte(nByte)) & 0xff]; end
                emit(sChunk);
            end
            if (sBytes) then consume(sBytes);
            else
                hSource = assert(io.open(pSource, "rb"));
                while true do
                    local sChunk, sReadError = hSource:read(1048576);
                    assert(not sReadError, sReadError);
                    if (not sChunk) then break; end; consume(sChunk);
                end
                local bClosed, sCloseError = hSource:close(); hSource = nil; assert(bClosed, sCloseError);
            end
            nCRC = (~nCRC) & 0xffffffff;
            local nEnd = assert(hArchive:seek()); assert(hArchive:seek("set", nOffset)); emit(header(nCRC, nSize)); assert(hArchive:seek("set", nEnd));
            tCentral[#tCentral + 1] = string.pack("<I4I2I2I2I2I2I2I4I4I4I2I2I2I2I2I4I4", 0x02014b50, 20, 20, 2048, 0, 0, 33, nCRC, nSize, nSize, #sName, 0, 0, 0, 0, 0, nOffset)..sName;
            if (fProgress) then fProgress("Packing", nIndex, #tEntries, tEntry); end
        end
        local nCentralOffset = assert(hArchive:seek()); local sCentral = table.concat(tCentral);
        emit(sCentral); emit(string.pack("<I4I2I2I2I2I4I4I2", 0x06054b50, 0, 0, #tEntries, #tEntries, #sCentral, nCentralOffset, 0));
    end, debug.traceback);
    if (hSource) then hSource:close(); end
    local bClosed, sCloseError = hArchive:close();
    if (not bOK) then error(sError, 0); end; assert(bClosed, sCloseError);
end
return Archive;
