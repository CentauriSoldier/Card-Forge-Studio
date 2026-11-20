--[[!
@fqxn CFA.Index
@desc Encodes and parses the data-only Lua syntax used by the CFA 1.0 index.
!]]
local Index = {};

--[[!
@fqxn CFA.Index.decode
@desc Parses one bounded UTF-8 table without compiling or executing Lua.
@param string sData Index bytes after the reader checks the header checksum.
@ret table|nil Parsed index on success.
@ret string|nil Diagnostic on malformed input.
!]]
function Index.decode(sData)
    if (#sData > 16777216 or not utf8.len(sData)) then
        return nil, "Invalid index size or UTF-8.";
    end

    local nPosition = 1;

    -- Match only at the current cursor, and consume the permitted whitespace.
    local function fMatch(sPattern)
        nPosition = sData:match("^[ \t\r\n]*()", nPosition);

        local sValue, nNext = sData:match("^("..sPattern..")()", nPosition);
        if (sValue) then nPosition = nNext; end
        return sValue;
    end

    local function fExpect(sPattern)
        assert(fMatch(sPattern), "Unexpected index token at byte "..nPosition..".");
    end

    -- Decode escapes explicitly so a string token is never handed to Lua's loader.
    local function fString()
        local tParts = {};
        local nBytes = 0;

        while true do
            local nSpecial = sData:find('[%z\1-\31\127"\\]', nPosition);
            assert(nSpecial, "Unterminated index string.");
            nBytes = nBytes + nSpecial - nPosition;
            assert(nBytes <= 4096, "Index string exceeds the schema limit.");
            tParts[#tParts + 1] = sData:sub(nPosition, nSpecial - 1);
            local sSpecial = sData:sub(nSpecial, nSpecial);
            nPosition = nSpecial + 1;

            if (sSpecial == '"') then return table.concat(tParts); end
            assert(sSpecial == "\\", "Unescaped control byte.");
            nBytes = nBytes + 1;
            assert(nBytes <= 4096, "Index string exceeds the schema limit.");
            local sEscape = sData:sub(nPosition, nPosition);

            if (sEscape == '"' or sEscape == "\\") then
                tParts[#tParts + 1] = sEscape;
                nPosition = nPosition + 1;
            else
                local sDigits = sData:match("^([0-9][0-9][0-9])", nPosition);
                local nByte = sDigits and tonumber(sDigits);
                assert(nByte and (nByte <= 31 or nByte == 127), "Invalid index escape.");
                tParts[#tParts + 1] = string.char(nByte);
                nPosition = nPosition + 3;
            end
        end
    end

    local fRecord;

    -- Each entry is a record; the count and depth are bounded before recursion.
    local function fArray(nDepth)
        local tValues = {};

        while not fMatch("}") do
            assert(#tValues < 65535 and nDepth < 16, "Index table limit exceeded.");
            fExpect("{");
            tValues[#tValues + 1] = fRecord(nDepth + 1);
            if (not fMatch(",")) then
                fExpect("}");
                break;
            end
        end

        return tValues;
    end

    fRecord = function(nDepth)
        local tFields = {};
        local nFields = 0;

        while not fMatch("}") do
            local sName = fMatch("[A-Za-z][A-Za-z0-9_]*");
            assert(sName and not tFields[sName] and nFields < 8, "Invalid or duplicate index field.");
            fExpect("=");

            if (fMatch('"')) then
                tFields[sName] = fString();
            elseif (fMatch("{")) then
                assert(nDepth < 16, "Index table limit exceeded.");
                tFields[sName] = fArray(nDepth + 1);
            else
                local sDigits = fMatch("[0-9]+");
                assert(sDigits and #sDigits <= 11 and (#sDigits == 1 or sDigits:sub(1, 1) ~= "0"),
                    "Invalid index integer.");
                tFields[sName] = tonumber(sDigits);
            end

            nFields = nFields + 1;
            if (not fMatch(",")) then
                fExpect("}");
                break;
            end
        end

        return tFields;
    end;

    local bOK, vResult = pcall(function()
        fExpect("{");
        local tIndex = fRecord(1);
        fMatch("");
        assert(nPosition == #sData + 1, "Trailing index content.");
        return tIndex;
    end);

    if (not bOK) then return nil, vResult; end
    return vResult;
end

--[[!
@fqxn CFA.Index.encode
@desc Serializes a validated index with stable field order and CFA string escapes.
@param table tIndex Validated index record.
@ret string Serialized index bytes.
!]]
function Index.encode(tIndex)
    -- Escapes are restricted to quotes, backslashes and ASCII control bytes.
    local function fQuote(sValue)
        return '"'..sValue:gsub('[%z\1-\31\127"\\]', function(sByte)
            if (sByte == '"' or sByte == "\\") then return "\\"..sByte; end
            return ("\\%03d"):format(sByte:byte());
        end)..'"';
    end

    local tParts = {"{ Schema = 1,"};

    for _, sName in ipairs({"Kind", "UUID", "Title", "GameUUID", "Thumbnail", "Description"}) do
        if (tIndex[sName] ~= nil) then
            tParts[#tParts + 1] = sName.." = "..fQuote(tIndex[sName])..",";
        end
    end

    tParts[#tParts + 1] = "Entries = {";
    for _, tEntry in ipairs(tIndex.Entries) do
        tParts[#tParts + 1] = ("{ Path = %s, Offset = %d, Size = %d, CRC32 = %d },"):format(
            fQuote(tEntry.Path), tEntry.Offset, tEntry.Size, tEntry.CRC32);
    end

    tParts[#tParts + 1] = "} }";
    return table.concat(tParts, "\n");
end

return Index;
