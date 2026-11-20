--[[!
@fqxn CFA.Format
@desc Defines the shared CFA 1.0 header, path validation and checksums.
!]]
local _tKinds = {game = true, set = true, ui = true, graphics = true, animation = true};
local _tDevices = {CON = true, PRN = true, AUX = true, NUL = true};
local Format = {};
Format.sHeader = "<!1c8I2I2I4I8I8I4c12";
Format.sMagic = "CFA\r\n\26\n\0";
Format.nFileLimit = 68719476736;
Format.nIndexLimit = 16777216;
Format.nEntryLimit = 268435456;
Format.nHeaderSize = string.packsize(Format.sHeader);


--[[!
@fqxn CFA.Format.isUUID
@desc Checks the exact lowercase logical UUID spelling used in the index.
!]]
local function isUUID(vValue)
    if (type(vValue) ~= "string" or #vValue ~= 36) then return false; end
    return vValue:match("^[0-9a-f]+%-[0-9a-f]+%-[0-9a-f]+%-[0-9a-f]+%-[0-9a-f]+$")
        and vValue:sub(9, 9) == "-" and vValue:sub(14, 14) == "-"
        and vValue:sub(19, 19) == "-" and vValue:sub(24, 24) == "-";
end

--[[!
@fqxn CFA.Format.isPath
@desc Validates a relative virtual entry path before associating bytes with it.
!]]
local function isPath(vPath)
    if (type(vPath) ~= "string" or #vPath == 0 or #vPath > 1024 or vPath:find("[^A-Za-z0-9_./%-]")
        or vPath:sub(1, 1) == "/" or vPath:sub(-1) == "/" or vPath:find("//", 1, true)) then
        return false;
    end

    for sPart in vPath:gmatch("[^/]+") do
        local sDevice = sPart:upper():match("^[^.]+");
        if (#sPart > 128 or sPart:sub(-1) == "." or _tDevices[sDevice]
            or (sDevice and (sDevice:match("^COM[1-9]$") or sDevice:match("^LPT[1-9]$")))) then
            return false;
        end
    end

    return true;
end

--[[!
@fqxn CFA.Format.isText
@desc Checks that a metadata value is well-formed UTF-8 within its byte limit.
!]]
local function isText(vValue, nMin, nMax)
    return type(vValue) == "string" and #vValue >= nMin and #vValue <= nMax and utf8.len(vValue);
end

-- Precompute the reflected CRC-32/ISO-HDLC polynomial for byte-wise checks.
local _tCRC = {};
for nByte = 0, 255 do
    local nWord = nByte;
    for _ = 1, 8 do
        nWord = (nWord >> 1) ~ ((nWord & 1) == 1 and 0xedb88320 or 0);
    end
    _tCRC[nByte] = nWord;
end

--[[!
@fqxn CFA.Format.checksum
@desc Computes the unsigned CRC-32/ISO-HDLC of the supplied bytes.
!]]
function Format.checksum(sBytes)
    local nCRC = 0xffffffff;
    for nIndex = 1, #sBytes do
        nCRC = (nCRC >> 8) ~ _tCRC[(nCRC ~ sBytes:byte(nIndex)) & 0xff];
    end
    return nCRC ~ 0xffffffff;
end

--[[!
@fqxn CFA.Format.validate
@desc Checks metadata, entry ranges, names and checksum fields before returning an entry map.
!]]
function Format.validate(tIndex, pArchive, nPayload)
    local sKind = tIndex.Kind;
    local sLeaf = pArchive:match("[^/\\]+$");
    if (not sLeaf) then return nil, "malformed index"; end
    sLeaf = sLeaf:lower();

    if (tIndex.Schema ~= 1 or not _tKinds[sKind] or not isUUID(tIndex.UUID)
        or not isText(tIndex.Title, 1, 256)
        or (tIndex.Description ~= nil and not isText(tIndex.Description, 0, 4096))
        or (tIndex.GameUUID ~= nil and not isUUID(tIndex.GameUUID))
        or (tIndex.Thumbnail ~= nil and not isPath(tIndex.Thumbnail))) then
        return nil, "malformed index";
    end

    if (sKind == "game" or sKind == "set") then
        if (sLeaf ~= tIndex.UUID..".cfa") then return nil, "malformed index"; end
    elseif (not tIndex.GameUUID) then
        return nil, "malformed index";
    end

    for sName in pairs(tIndex) do
        if (sName ~= "Schema" and sName ~= "Kind" and sName ~= "UUID" and sName ~= "Title"
            and sName ~= "Entries" and sName ~= "GameUUID" and sName ~= "Thumbnail" and sName ~= "Description") then
            return nil, "malformed index";
        end
    end

    if (type(tIndex.Entries) ~= "table" or #tIndex.Entries == 0) then return nil, "malformed index"; end
    if (#tIndex.Entries > 65535) then return nil, "bounds exceeded"; end

    local tPaths, tNames = {}, {};
    local nOffset = 0;

    for nOrdinal, tEntry in ipairs(tIndex.Entries) do
        local sPath, nSize, nCRC = tEntry.Path, tEntry.Size, tEntry.CRC32;

        if (math.type(nSize) == "integer" and nSize > Format.nEntryLimit) then return nil, "bounds exceeded"; end
        if (not isPath(sPath) or math.type(nSize) ~= "integer" or nSize < 0
            or tEntry.Offset ~= nOffset or nSize > nPayload - nOffset
            or math.type(nCRC) ~= "integer" or nCRC < 0 or nCRC > 0xffffffff
            or tNames[sPath:lower()]) then
            return nil, "malformed index";
        end

        for sName in pairs(tEntry) do
            if (sName ~= "Path" and sName ~= "Size" and sName ~= "Offset"
                and sName ~= "CRC32") then
                return nil, "malformed index";
            end
        end

        tPaths[sPath], tNames[sPath:lower()] = nOrdinal, true;
        nOffset = nOffset + nSize;
    end

    if (nOffset ~= nPayload or (tIndex.Thumbnail and not tPaths[tIndex.Thumbnail])) then
        return nil, "malformed index";
    end

    return tPaths;
end

return Format;
