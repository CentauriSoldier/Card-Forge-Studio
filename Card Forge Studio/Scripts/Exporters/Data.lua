local assert   = assert;
local ipairs   = ipairs;
local io       = io;
local math     = math;
local rawtype  = rawtype or type;
local string   = string;
local table    = table;
local tostring = tostring;
local utf8     = utf8;
local Data     = {};

--[[!
@fqxn CFS.Modules.Exporter.Support.Data
@desc Shared finalized-text snapshots and CSV, JSON, and Lua encoders. Column and requested-row order are preserved. No source code, game files, or machine paths are collected.
@vis private
!]]

--[[!
@fqxn CFS.Modules.Exporter.Support.Data.Functions.snapshot
@desc Copies selected final text values and ordered headers, retaining source-row identifiers. Missing cells become empty strings; non-text values are rejected rather than guessed.
@param table tRows Requested source rows.
@param table tContext Ordered headers and final rows.
@return table tData Independent snapshot.
@vis private
!]]
function Data.snapshot(tRows, tContext)
    assert(tContext and tContext.headers and tContext.final, "Finalized export data is unavailable.");
    assert(#tRows > 0 and #tContext.headers > 0, "No card data to export.");
    local tData = {columns = {}, cards = {}};
    local tSeen, tHeaders = {}, {};
    for _, sHeader in ipairs(tContext.headers) do
        assert(rawtype(sHeader) == "string" and not tHeaders[sHeader], "Invalid or duplicate export column.");
        assert(utf8.len(sHeader), "Export column is not valid UTF-8.");
        tHeaders[sHeader] = true; tData.columns[#tData.columns + 1] = sHeader;
    end
    for _, nRow in ipairs(tRows) do
        assert(rawtype(nRow) == "number" and nRow == math.floor(nRow) and nRow >= 1 and tContext.final[nRow] and not tSeen[nRow], "Invalid or duplicate export row.");
        tSeen[nRow] = true;
        local tCard = {row = nRow, values = {}};
        for _, sHeader in ipairs(tData.columns) do
            local sValue = tContext.final[nRow][sHeader];
            if (sValue == nil) then sValue = ""; end
            assert(rawtype(sValue) == "string", "Final value must be text: row "..nRow..", "..sHeader);
            assert(utf8.len(sValue), "Final value is not valid UTF-8: row "..nRow..", "..sHeader);
            tCard.values[#tCard.values + 1] = sValue;
        end
        tData.cards[#tData.cards + 1] = tCard;
    end
    return tData;
end

--[[!
@fqxn CFS.Modules.Exporter.Support.Data.Functions.quote
@desc Encodes one UTF-8 JSON string including all control bytes.
@param string sValue Text.
@return string sJSON Quoted JSON.
@vis private
!]]
function Data.quote(sValue)
    return '"'..sValue:gsub('[%z\1-\31\\"]', function(sCharacter)
        if (sCharacter == '"' or sCharacter == '\\') then return '\\'..sCharacter; end
        return string.format('\\u%04x', sCharacter:byte());
    end)..'"';
end

--[[!
@fqxn CFS.Modules.Exporter.Support.Data.Functions.csv
@desc Writes comma-separated UTF-8 text with doubled quotes and CRLF records. Optional BOM improves spreadsheet encoding detection. Values are preserved, including leading zeroes and embedded line breaks.
@param table tData Snapshot.
@param table tOptions Header and BOM choices.
@return string sCSV CSV bytes.
@vis private
!]]
function Data.csv(tData, tOptions)
    local tLines = {};
    --[[!
    @fqxn CFS.Modules.Exporter.Support.Data.Private.Functions.encode
    @desc Quotes one CSV record and doubles embedded quotes.
    @vis private
    !]]
    local function encode(tValues)
        local tFields = {};
        for _, sValue in ipairs(tValues) do tFields[#tFields + 1] = '"'..sValue:gsub('"', '""')..'"'; end
        return table.concat(tFields, ',');
    end
    if (tOptions.headers ~= false) then tLines[#tLines + 1] = encode(tData.columns); end
    for _, tCard in ipairs(tData.cards) do tLines[#tLines + 1] = encode(tCard.values); end
    return (tOptions.bom and '\239\187\191' or '')..table.concat(tLines, '\r\n')..'\r\n';
end

--[[!
@fqxn CFS.Modules.Exporter.Support.Data.Functions.json
@desc Emits CFS Card Data version 1 JSON. Ordered columns pair with each card's ordered text values and original source-row number.
@param table tData Snapshot.
@return string sJSON JSON bytes.
@vis private
!]]
function Data.json(tData)
    local tColumns, tCards = {}, {};
    for _, sHeader in ipairs(tData.columns) do tColumns[#tColumns + 1] = Data.quote(sHeader); end
    for _, tCard in ipairs(tData.cards) do
        local tValues = {};
        for _, sValue in ipairs(tCard.values) do tValues[#tValues + 1] = Data.quote(sValue); end
        tCards[#tCards + 1] = '{"row":'..tCard.row..',"values":['..table.concat(tValues, ',')..']}';
    end
    return '{"format":"CFS Card Data","version":1,"columns":['..table.concat(tColumns, ',')..'],"cards":['..table.concat(tCards, ',')..']}\n';
end

--[[!
@fqxn CFS.Modules.Exporter.Support.Data.Functions.lua
@desc Returns an ordinary Lua data table with the same ordered schema as JSON. Final values are quoted text, never inserted as executable game code.
@param table tData Snapshot.
@return string sLua Lua source.
@vis private
!]]
function Data.lua(tData)
    local tColumns, tCards = {}, {};
    for _, sHeader in ipairs(tData.columns) do tColumns[#tColumns + 1] = string.format('%q', sHeader); end
    for _, tCard in ipairs(tData.cards) do
        local tValues = {};
        for _, sValue in ipairs(tCard.values) do tValues[#tValues + 1] = string.format('%q', sValue); end
        tCards[#tCards + 1] = '{row='..tCard.row..',values={'..table.concat(tValues, ',')..'}}';
    end
    return 'return {format="CFS Card Data",version=1,columns={'..table.concat(tColumns, ',')..'},cards={'..table.concat(tCards, ',')..'}};\n';
end

--[[!
@fqxn CFS.Modules.Exporter.Support.Data.Functions.write
@desc Checks both file writing and close success.
@param string pFile Staged output path.
@param string sBytes Encoded bytes.
@vis private
!]]
function Data.write(pFile, sBytes)
    local hFile = assert(io.open(pFile, "wb"));
    local bWritten, sError = hFile:write(sBytes); local bClosed, sCloseError = hFile:close();
    assert(bWritten, sError); assert(bClosed, sCloseError);
end
return Data;
