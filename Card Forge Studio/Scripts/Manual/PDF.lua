--[[!
@fqxn CFS.Manual.PDF
@desc Pure Lua 5.4 PDF 1.7 writer. Reads explicit font/image paths without OS APIs,
    browsers, subprocesses or native modules. Coordinates and measurements are in
    points, with page positions measured from the top left. This module writes
    positioned content; manual pagination and text shaping are separate concerns.
!]]

local assert         = assert;
local error          = error;
local ipairs         = ipairs;
local pairs          = pairs;
local rawtype        = rawtype or type;
local tostring       = tostring;
local io             = io;
local math           = math;
local string         = string;
local table          = table;
local utf8           = utf8;
local _tLengthBase   = {3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258};
local _tLengthBits   = {0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0};
local _tDistanceBase = {1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577};
local _tDistanceBits = {0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13};
local PDF            = {};

--[[!
@fqxn CFS.Manual.PDF.Private.Functions.read
@desc Reads binary input and closes the file before returning.
@param string pFile Explicit input path.
@return string sBytes Complete input bytes.
@vis private
!]]
local function read(pFile)
    local hFile  = assert(io.open(pFile, "rb"));
    local sBytes = assert(hFile:read("a"));

    assert(hFile:close());
    return sBytes;
end

--[[!
@fqxn CFS.Manual.PDF.Private.Functions.number
@desc Serializes a finite number using the PDF decimal separator regardless of locale.
@param number nValue Finite value.
@return string sNumber PDF number.
@vis private
!]]
local function number(nValue)
    assert(rawtype(nValue) == "number" and nValue == nValue and math.abs(nValue) < math.huge, "Expected a finite PDF number.");
    return (string.format("%.6f", nValue):gsub(",", "."):gsub("0+$", ""):gsub("%.$", ""));
end

--[[!
@fqxn CFS.Manual.PDF.Private.Functions.unicode
@desc Encodes UTF-8 as UTF-16BE hexadecimal, including supplementary characters.
@param string sText Valid UTF-8.
@return string sHex UTF-16BE hexadecimal without a byte-order mark.
@vis private
!]]
local function unicode(sText)
    local tHex = {};

    for _, nCode in utf8.codes(sText) do
        if (nCode <= 0xFFFF) then
            assert(nCode < 0xD800 or nCode > 0xDFFF, "Invalid Unicode surrogate.");
            tHex[#tHex + 1] = string.format("%04X", nCode);
        else
            nCode = nCode - 0x10000;
            tHex[#tHex + 1] = string.format("%04X%04X", 0xD800 + (nCode >> 10), 0xDC00 + (nCode & 0x3FF));
        end
    end

    return table.concat(tHex);
end

--[[!
@fqxn CFS.Manual.PDF.Private.Functions.checksum
@desc Calculates the unsigned OpenType table checksum, padding with zero bytes.
@param string sBytes Table bytes.
@return number nChecksum Unsigned checksum.
@vis private
!]]
local function checksum(sBytes)
    local nSum = 0;

    sBytes = sBytes..string.rep("\0", (-#sBytes) % 4);
    for nOffset = 1, #sBytes, 4 do
        nSum = (nSum + string.unpack(">I4", sBytes, nOffset)) & 0xFFFFFFFF;
    end

    return nSum;
end

--[[!
@fqxn CFS.Manual.PDF.Private.Functions.fontNames
@desc Reads Unicode family/style names and OS/2 face flags from SFNT tables.
@param table tTables Font tables.
@return table tInfo Font names, aliases, weight and embedding capabilities.
@vis private
!]]
local function fontNames(tTables)
    local tInfo = {family = "", style = "Regular", postscript = "EmbeddedFont", aliases = {}, weight = 400};
    local tScores = {};
    local tAliases = {};
    local sNames = tTables.name;
    local sOS2 = tTables["OS/2"];
    local nFlags = tTables.head and string.unpack(">I2", tTables.head, 45) or 0;
    local nSelection = sOS2 and #sOS2 >= 64 and string.unpack(">I2", sOS2, 63) or 0;

    if (sNames) then
        local nNames = string.unpack(">I2", sNames, 3);
        local nStorage = string.unpack(">I2", sNames, 5);

        for nIndex = 0, nNames - 1 do
            local nPlatform, _, nLanguage, nName, nLength, nOffset = string.unpack(">I2I2I2I2I2I2", sNames, 7 + nIndex * 12);
            local sKey = ({[1] = "family", [2] = "style", [6] = "postscript", [16] = "family", [17] = "style"})[nName];

            if (sKey) then
                local sValue = sNames:sub(nStorage + nOffset + 1, nStorage + nOffset + nLength);
                local nScore = (nPlatform == 0 or nPlatform == 3) and 10 or 0;

                if (nPlatform == 0 or nPlatform == 3) then
                    local tText = {};
                    local nPosition = 1;

                    while (nPosition < #sValue) do
                        local nCode = string.unpack(">I2", sValue, nPosition);

                        nPosition = nPosition + 2;
                        if (nCode >= 0xD800 and nCode <= 0xDBFF) then
                            local nLow = string.unpack(">I2", sValue, nPosition);

                            assert(nLow >= 0xDC00 and nLow <= 0xDFFF, "Invalid font-name Unicode surrogate.");
                            nCode = 0x10000 + ((nCode - 0xD800) << 10) + nLow - 0xDC00;
                            nPosition = nPosition + 2;
                        end
                        tText[#tText + 1] = utf8.char(nCode);
                    end
                    sValue = table.concat(tText);
                elseif (sValue:find("[\128-\255]")) then sValue = ""; end
                if (nLanguage == 0x409 or nLanguage == 0) then nScore = nScore + 2; end
                if (nName == 16 or nName == 17) then nScore = nScore + 1; end
                if (#sValue > 0) then
                    if (sKey == "family" and not tAliases[sValue]) then
                        tInfo.aliases[#tInfo.aliases + 1] = sValue;
                        tAliases[sValue] = true;
                    end
                    if (not tScores[sKey] or nScore > tScores[sKey]) then tInfo[sKey], tScores[sKey] = sValue, nScore; end
                end
            end
        end
    end
    if (sOS2 and #sOS2 >= 10) then tInfo.weight = string.unpack(">I2", sOS2, 5); end
    tInfo.bold = (nFlags & 1) ~= 0 or (nSelection & 32) ~= 0 or tInfo.weight >= 600;
    tInfo.italic = (nFlags & 2) ~= 0 or (nSelection & 513) ~= 0;
    tInfo.embeddable = not sOS2 or (string.unpack(">I2", sOS2, 9) & 0x202) == 0;
    tInfo.supported = not tTables.fvar and not tTables.CFF2 and (tTables.glyf ~= nil or tTables["CFF "] ~= nil);
    tInfo.postscript = tInfo.postscript:gsub("[^A-Za-z0-9_.-]", "");
    return tInfo;
end

--[[!
@fqxn CFS.Manual.PDF.Functions.fontInfo
@desc Reads all SFNT faces for disk-based font discovery. Does not install fonts or
    use platform APIs. Unsupported/restricted faces are described, not embedded.
@param string pFile TTF, OTF, TTC or OTC path.
@return table tFaces One-based array of font metadata and explicit path/face values.
!]]
function PDF.fontInfo(pFile)
    local sBytes = read(pFile);
    local tOffsets = {0};
    local tFaces = {};

    if (sBytes:sub(1, 4) == "ttcf") then
        local nFaces = string.unpack(">I4", sBytes, 9);

        assert(nFaces > 0 and nFaces <= 1024, "Invalid font collection face count.");
        tOffsets = {};
        for nFace = 1, nFaces do tOffsets[nFace] = string.unpack(">I4", sBytes, 13 + (nFace - 1) * 4); end
    end
    for nFace, nOffset in ipairs(tOffsets) do
        local nStart = nOffset + 1;
        local sVersion = sBytes:sub(nStart, nStart + 3);
        local tTables = {};

        assert(sVersion == "\0\1\0\0" or sVersion == "OTTO" or sVersion == "true", "Unsupported font container.");
        for nIndex = 0, string.unpack(">I2", sBytes, nStart + 4) - 1 do
            local sTag, _, nTable, nLength = string.unpack(">c4I4I4I4", sBytes, nStart + 12 + nIndex * 16);

            assert(nTable + nLength <= #sBytes, "Truncated font table: "..sTag);
            tTables[sTag] = ({name = true, head = true, ["OS/2"] = true})[sTag] and sBytes:sub(nTable + 1, nTable + nLength) or true;
        end
        tFaces[nFace] = fontNames(tTables);
        tFaces[nFace].path, tFaces[nFace].face = pFile, nFace;
    end
    return tFaces;
end

--[[!
@fqxn CFS.Manual.PDF.Private.Functions.font
@desc Reads a static SFNT face, Unicode cmap and horizontal metrics. Collection
    faces are rebuilt as standalone fonts. Restricted/bitmap-only embedding and
    variable fonts are rejected. This performs glyph mapping, not script shaping.
@param string pFile TTF, OTF or SFNT collection path.
@param number nFace One-based collection face.
@return table tFont Parsed font and original/rebuilt embedded program.
@vis private
!]]
local function font(pFile, nFace)
    local sBytes    = read(pFile);
    local nStart    = 1;
    local tTables   = {};
    local tFont     = {used = {}, codes = {}, nextCode = 1};
    local sVersion;
    local nCount;
    local tMap;
    local nScore    = -1;
    local nUnits;
    local nGlyphs;
    local nMetrics;
    local sName     = "EmbeddedFont";
    local sHead;
    local sHhea;
    local sOS2;

    assert(math.type(nFace) == "integer" and nFace >= 1, "Font face must be a positive integer.");
    if (sBytes:sub(1, 4) == "ttcf") then
        nCount = string.unpack(">I4", sBytes, 9);
        assert(nFace <= nCount, "Font collection face is unavailable.");
        nStart = string.unpack(">I4", sBytes, 13 + (nFace - 1) * 4) + 1;
    else
        assert(nFace == 1, "A standalone font has only one face.");
    end

    sVersion = sBytes:sub(nStart, nStart + 3);
    assert(sVersion == "\0\1\0\0" or sVersion == "OTTO" or sVersion == "true", "Unsupported font container; use TTF, OTF, TTC or OTC.");
    nCount = string.unpack(">I2", sBytes, nStart + 4);
    for nIndex = 0, nCount - 1 do
        local nRecord = nStart + 12 + nIndex * 16;
        local sTag, _, nOffset, nLength = string.unpack(">c4I4I4I4", sBytes, nRecord);

        assert(nOffset + nLength <= #sBytes, "Truncated font table: "..sTag);
        tTables[sTag] = sBytes:sub(nOffset + 1, nOffset + nLength);
    end

    assert(not tTables.fvar, "Variable fonts require a static font instance before embedding.");
    assert(not tTables.CFF2, "CFF2 outlines are not supported.");
    assert(tTables.glyf or tTables["CFF "], "The font has no supported outlines.");
    sHead = assert(tTables.head, "Font is missing head.");
    sHhea = assert(tTables.hhea, "Font is missing hhea.");
    sOS2  = tTables["OS/2"];
    nUnits   = string.unpack(">I2", sHead, 19);
    nGlyphs  = string.unpack(">I2", assert(tTables.maxp, "Font is missing maxp."), 5);
    nMetrics = string.unpack(">I2", sHhea, 35);
    assert(nUnits > 0 and nMetrics > 0 and nMetrics <= nGlyphs, "Invalid font metrics.");
    if (sOS2) then
        local nEmbedding = string.unpack(">I2", sOS2, 9);

        assert((nEmbedding & 0x202) == 0, "Font embedding flags prohibit outline embedding: "..pFile);
    end

    do
        local tInfo = fontNames(tTables);

        sName = tInfo.postscript;
        tFont.family, tFont.style = tInfo.family, tInfo.style;
        tFont.bold, tFont.italic = tInfo.bold, tInfo.italic;
    end

    do
        local sCmap = assert(tTables.cmap, "Font is missing cmap.");
        local nMaps = string.unpack(">I2", sCmap, 3);

        for nIndex = 0, nMaps - 1 do
            local nPlatform, nEncoding, nOffset = string.unpack(">I2I2I4", sCmap, 5 + nIndex * 8);
            local nFormat = string.unpack(">I2", sCmap, nOffset + 1);
            local nRank = (nFormat == 12 and 20 or nFormat == 4 and 10 or -100);

            if (nPlatform == 3 and (nEncoding == 1 or nEncoding == 10)) then nRank = nRank + 2;
            elseif (nPlatform ~= 0) then nRank = -100; end
            if (nRank > nScore) then
                nScore = nRank;
                tMap = {bytes = sCmap, start = nOffset + 1, format = nFormat};
            end
        end
    end
    assert(tMap and nScore >= 0, "Font requires a Unicode cmap format 4 or 12.");

    -- Rebuild collections with table offsets relative to their standalone face.
    if (nStart ~= 1 or sBytes:sub(1, 4) == "ttcf") then
        local tTags, tRecords, tContents = {}, {}, {};
        local nPower, nSelector = 1, 0;
        local nOffset;

        tTables.DSIG = nil;
        tTables.head = sHead:sub(1, 8).."\0\0\0\0"..sHead:sub(13);
        for sTag in pairs(tTables) do tTags[#tTags + 1] = sTag; end
        table.sort(tTags);
        while (nPower * 2 <= #tTags) do nPower, nSelector = nPower * 2, nSelector + 1; end
        nOffset = 12 + #tTags * 16;
        for _, sTag in ipairs(tTags) do
            local sTable = tTables[sTag];

            tRecords[#tRecords + 1] = string.pack(">c4I4I4I4", sTag, checksum(sTable), nOffset, #sTable);
            tContents[#tContents + 1] = sTable..string.rep("\0", (-#sTable) % 4);
            nOffset = nOffset + #tContents[#tContents];
        end
        sBytes = string.pack(">c4I2I2I2I2", sVersion, #tTags, nPower * 16, nSelector, #tTags * 16 - nPower * 16)..table.concat(tRecords)..table.concat(tContents);
        for nIndex, sTag in ipairs(tTags) do
            if (sTag == "head") then
                local nOffsetHead = string.unpack(">I4", sBytes, 12 + (nIndex - 1) * 16 + 9);
                local nAdjustment = (0xB1B0AFBA - checksum(sBytes)) & 0xFFFFFFFF;

                sBytes = sBytes:sub(1, nOffsetHead + 8)..string.pack(">I4", nAdjustment)..sBytes:sub(nOffsetHead + 13);
            end
        end
    end

    tFont.bytes   = sBytes;
    tFont.name    = sName;
    tFont.cff     = tTables["CFF "] ~= nil;
    tFont.units   = nUnits;
    tFont.glyphs  = nGlyphs;
    tFont.metrics = nMetrics;
    tFont.hmtx    = assert(tTables.hmtx, "Font is missing hmtx.");
    tFont.map     = tMap;
    tFont.ascent  = string.unpack(">i2", sHhea, 5) * 1000 / nUnits;
    tFont.descent = string.unpack(">i2", sHhea, 7) * 1000 / nUnits;
    tFont.bounds  = {};
    for nIndex = 0, 3 do tFont.bounds[nIndex + 1] = string.unpack(">i2", sHead, 37 + nIndex * 2) * 1000 / nUnits; end
    return tFont;
end

--[[!
@fqxn CFS.Manual.PDF.Private.Functions.glyph
@desc Resolves one Unicode scalar through cmap format 4 or 12.
@param table tFont Parsed font.
@param number nCode Unicode scalar.
@return number nGlyph Glyph index, zero if absent.
@vis private
!]]
local function glyph(tFont, nCode)
    local tMap  = tFont.map;
    local sMap  = tMap.bytes;
    local nBase = tMap.start;

    if (tMap.format == 12) then
        local nLow, nHigh = 0, string.unpack(">I4", sMap, nBase + 12) - 1;

        while (nLow <= nHigh) do
            local nMiddle = (nLow + nHigh) // 2;
            local nFirst, nLast, nGlyph = string.unpack(">I4I4I4", sMap, nBase + 16 + nMiddle * 12);

            if (nCode < nFirst) then nHigh = nMiddle - 1;
            elseif (nCode > nLast) then nLow = nMiddle + 1;
            else return nGlyph + nCode - nFirst; end
        end
    elseif (nCode <= 0xFFFF) then
        local nSegments = string.unpack(">I2", sMap, nBase + 6) // 2;

        for nIndex = 0, nSegments - 1 do
            local nLast = string.unpack(">I2", sMap, nBase + 14 + nIndex * 2);

            if (nCode <= nLast) then
                local nFirst = string.unpack(">I2", sMap, nBase + 16 + nSegments * 2 + nIndex * 2);
                local nDelta = string.unpack(">i2", sMap, nBase + 16 + nSegments * 4 + nIndex * 2);
                local nPosition = nBase + 16 + nSegments * 6 + nIndex * 2;
                local nRange = string.unpack(">I2", sMap, nPosition);
                local nGlyph;

                if (nCode < nFirst) then return 0; end
                if (nRange == 0) then return (nCode + nDelta) & 0xFFFF; end
                nGlyph = string.unpack(">I2", sMap, nPosition + nRange + (nCode - nFirst) * 2);
                return nGlyph == 0 and 0 or (nGlyph + nDelta) & 0xFFFF;
            end
        end
    end

    return 0;
end

--[[!
@fqxn CFS.Manual.PDF.Private.Functions.width
@desc Returns a glyph advance in PDF font units.
@param table tFont Parsed font.
@param number nGlyph Glyph index.
@return number nWidth Advance normalized to 1000 units.
@vis private
!]]
local function width(tFont, nGlyph)
    assert(nGlyph < tFont.glyphs, "Font cmap references an invalid glyph.");
    return string.unpack(">I2", tFont.hmtx, math.min(nGlyph, tFont.metrics - 1) * 4 + 1) * 1000 / tFont.units;
end

--[[!
@fqxn CFS.Manual.PDF.Private.Functions.adler
@desc Calculates the zlib Adler-32 checksum.
@param string sBytes Uncompressed bytes.
@return number nChecksum Unsigned checksum.
@vis private
!]]
local function adler(sBytes)
    local nA, nB = 1, 0;

    for nIndex = 1, #sBytes do
        nA = (nA + sBytes:byte(nIndex)) % 65521;
        nB = (nB + nA) % 65521;
    end
    return (nB << 16) | nA;
end

--[[!
@fqxn CFS.Manual.PDF.Private.Functions.deflate
@desc Writes a portable zlib stream using uncompressed DEFLATE blocks.
@param string sBytes Raw image samples.
@return string sStream Valid zlib stream.
@vis private
!]]
local function deflate(sBytes)
    local tBlocks = {"\120\1"};
    local nOffset = 1;

    repeat
        local sBlock = sBytes:sub(nOffset, nOffset + 65534);
        local nSize = #sBlock;

        nOffset = nOffset + nSize;
        tBlocks[#tBlocks + 1] = string.pack("<I1I2I2", nOffset > #sBytes and 1 or 0, nSize, 0xFFFF ~ nSize)..sBlock;
    until nOffset > #sBytes;
    tBlocks[#tBlocks + 1] = string.pack(">I4", adler(sBytes));
    return table.concat(tBlocks);
end

--[[!
@fqxn CFS.Manual.PDF.Private.Functions.inflate
@desc Decodes bounded zlib/DEFLATE image data, including stored, fixed and dynamic
    Huffman blocks. Rejects invalid streams, dictionaries and checksum mismatches.
@param string sBytes Zlib stream.
@param number nLimit Maximum decompressed bytes determined by image dimensions.
@return string sRaw Decompressed image bytes.
@vis private
!]]
local function inflate(sBytes, nLimit)
    local nOffset, nBits, nBuffer = 3, 0, 0;
    local tOutput = {};
    local bFinal = false;
    local fBits;
    local fTree;
    local fSymbol;
    local fPut;

    assert(#sBytes >= 6 and (sBytes:byte(1) & 15) == 8 and (sBytes:byte(1) >> 4) <= 7
        and (sBytes:byte(1) * 256 + sBytes:byte(2)) % 31 == 0 and (sBytes:byte(2) & 32) == 0, "Invalid PNG zlib header.");
    fBits = function(nCount)
        local nValue;

        while (nBits < nCount) do
            assert(nOffset <= #sBytes - 4, "Truncated PNG DEFLATE stream.");
            nBuffer = nBuffer | (sBytes:byte(nOffset) << nBits);
            nOffset, nBits = nOffset + 1, nBits + 8;
        end
        nValue = nBuffer & ((1 << nCount) - 1);
        nBuffer, nBits = nBuffer >> nCount, nBits - nCount;
        return nValue;
    end;
    fTree = function(tLengths)
        local tCounts, tNext, tTree = {}, {}, {};
        local nCode = 0;

        for _, nLength in ipairs(tLengths) do
            assert(nLength >= 0 and nLength <= 15, "Invalid DEFLATE code length.");
            if (nLength > 0) then tCounts[nLength] = (tCounts[nLength] or 0) + 1; end
        end
        for nLength = 1, 15 do
            nCode = (nCode + (tCounts[nLength - 1] or 0)) << 1;
            assert(nCode + (tCounts[nLength] or 0) <= (1 << nLength), "Oversubscribed DEFLATE tree.");
            tNext[nLength] = nCode;
        end
        for nIndex, nLength in ipairs(tLengths) do
            if (nLength > 0) then
                local nForward = tNext[nLength];
                local nReverse = 0;

                for _ = 1, nLength do nReverse, nForward = (nReverse << 1) | (nForward & 1), nForward >> 1; end
                tTree[(1 << nLength) | nReverse] = nIndex - 1;
                tNext[nLength] = tNext[nLength] + 1;
            end
        end
        return tTree;
    end;
    fSymbol = function(tTree)
        local nCode = 0;

        for nLength = 1, 15 do
            local nSymbol;

            nCode = nCode | (fBits(1) << (nLength - 1));
            nSymbol = tTree[(1 << nLength) | nCode];
            if (nSymbol ~= nil) then return nSymbol; end
        end
        error("Invalid DEFLATE Huffman symbol.");
    end;
    fPut = function(nByte)
        assert(#tOutput < nLimit, "PNG decompression exceeds its dimensions.");
        tOutput[#tOutput + 1] = nByte;
    end;

    while (not bFinal) do
        local nKind;

        bFinal, nKind = fBits(1) == 1, fBits(2);
        if (nKind == 0) then
            local nSize, nInverse;

            nBits, nBuffer = 0, 0;
            nSize, nInverse = fBits(16), fBits(16);
            assert((nSize ~ nInverse) == 0xFFFF, "Invalid stored DEFLATE block.");
            for _ = 1, nSize do fPut(fBits(8)); end
        else
            local tLiteralLengths, tDistanceLengths = {}, {};
            local tLiteralTree, tDistanceTree;

            assert(nKind ~= 3, "Reserved DEFLATE block type.");
            if (nKind == 1) then
                for nSymbol = 0, 287 do tLiteralLengths[nSymbol + 1] = nSymbol <= 143 and 8 or nSymbol <= 255 and 9 or nSymbol <= 279 and 7 or 8; end
                for nSymbol = 1, 32 do tDistanceLengths[nSymbol] = 5; end
            else
                local nLiterals, nDistances, nCodes = fBits(5) + 257, fBits(5) + 1, fBits(4) + 4;
                local tOrder = {16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15};
                local tCodeLengths, tLengths = {}, {};
                local tCodeTree;

                for nIndex = 1, 19 do tCodeLengths[nIndex] = 0; end
                for nIndex = 1, nCodes do tCodeLengths[tOrder[nIndex] + 1] = fBits(3); end
                tCodeTree = fTree(tCodeLengths);
                while (#tLengths < nLiterals + nDistances) do
                    local nSymbol = fSymbol(tCodeTree);
                    local nRepeat, nValue;

                    if (nSymbol < 16) then nRepeat, nValue = 1, nSymbol;
                    elseif (nSymbol == 16) then nRepeat, nValue = fBits(2) + 3, assert(tLengths[#tLengths], "Missing repeated DEFLATE length.");
                    elseif (nSymbol == 17) then nRepeat, nValue = fBits(3) + 3, 0;
                    else nRepeat, nValue = fBits(7) + 11, 0; end
                    assert(#tLengths + nRepeat <= nLiterals + nDistances, "Excess DEFLATE code lengths.");
                    for _ = 1, nRepeat do tLengths[#tLengths + 1] = nValue; end
                end
                for nIndex = 1, nLiterals do tLiteralLengths[nIndex] = tLengths[nIndex]; end
                for nIndex = 1, nDistances do tDistanceLengths[nIndex] = tLengths[nLiterals + nIndex]; end
            end
            assert(tLiteralLengths[257] and tLiteralLengths[257] > 0, "DEFLATE tree has no end marker.");
            tLiteralTree, tDistanceTree = fTree(tLiteralLengths), fTree(tDistanceLengths);
            while (true) do
                local nSymbol = fSymbol(tLiteralTree);

                if (nSymbol == 256) then break;
                elseif (nSymbol < 256) then fPut(nSymbol);
                else
                    local nIndex = nSymbol - 256;
                    local nLength, nDistanceCode, nDistance;

                    assert(_tLengthBase[nIndex], "Invalid DEFLATE length symbol.");
                    nLength = _tLengthBase[nIndex] + fBits(_tLengthBits[nIndex]);
                    nDistanceCode = fSymbol(tDistanceTree) + 1;
                    assert(_tDistanceBase[nDistanceCode], "Invalid DEFLATE distance symbol.");
                    nDistance = _tDistanceBase[nDistanceCode] + fBits(_tDistanceBits[nDistanceCode]);
                    assert(nDistance <= #tOutput and nDistance <= 32768, "Invalid DEFLATE back reference.");
                    for _ = 1, nLength do fPut(tOutput[#tOutput - nDistance + 1]); end
                end
            end
        end
    end

    for nIndex, nByte in ipairs(tOutput) do tOutput[nIndex] = string.char(nByte); end
    nBuffer = string.unpack(">I4", sBytes, #sBytes - 3);
    sBytes = table.concat(tOutput);
    assert(adler(sBytes) == nBuffer, "PNG zlib checksum mismatch.");
    return sBytes;
end

--[[!
@fqxn CFS.Manual.PDF.Private.Functions.image
@desc Reads JPEG or noninterlaced 8-bit PNG images. PNG alpha becomes a PDF soft
    mask. Indexed PNGs support 1/2/4/8-bit palettes. Unsupported encodings fail.
@param string pFile Explicit image path.
@return table tImage Embedded color and optional alpha streams.
@vis private
!]]
local function image(pFile)
    local sBytes = read(pFile);
    local tImage = {sourceBytes = sBytes};

    if (sBytes:sub(1, 2) == "\255\216") then
        local nOffset = 3;

        while (nOffset <= #sBytes) do
            local nMarker, nLength;

            assert(sBytes:byte(nOffset) == 255, "Invalid JPEG marker.");
            while (sBytes:byte(nOffset) == 255) do nOffset = nOffset + 1; end
            nMarker = sBytes:byte(nOffset);
            nOffset = nOffset + 1;
            assert(nMarker ~= 0xDA and nMarker ~= 0xD9, "JPEG has no supported frame.");
            nLength = string.unpack(">I2", sBytes, nOffset);
            assert(nLength >= 2 and nOffset + nLength - 1 <= #sBytes, "Truncated JPEG segment.");
            if (nMarker == 0xC0 or nMarker == 0xC1 or nMarker == 0xC2) then
                local nBits, nHeight, nWidth, nColors = string.unpack(">I1I2I2I1", sBytes, nOffset + 2);

                assert(nWidth > 0 and nHeight > 0, "JPEG dimensions must be positive.");
                assert(nBits == 8 and (nColors == 1 or nColors == 3), "JPEG must be 8-bit grayscale or RGB; CMYK requires an explicit color policy.");
                tImage.width, tImage.height, tImage.colors = nWidth, nHeight, nColors;
                tImage.bytes, tImage.filter = sBytes, "/DCTDecode";
                return tImage;
            end
            nOffset = nOffset + nLength;
        end
        error("JPEG has no supported frame.");
    end

    assert(sBytes:sub(1, 8) == "\137PNG\13\10\26\10", "Only JPEG and PNG images are supported.");
    do
        local nOffset = 9;
        local tData, tColor, tAlpha = {}, {}, {};
        local sPalette, sTransparency;
        local nWidth, nHeight, nDepth, nKind, nChannels;
        local sRaw;
        local nStride;
        local tPrevious = {};
        local nRaw = 1;

        while (nOffset <= #sBytes) do
            local nLength, sKind = string.unpack(">I4c4", sBytes, nOffset);
            local sChunk = sBytes:sub(nOffset + 8, nOffset + 7 + nLength);

            assert(nOffset + nLength + 11 <= #sBytes, "Truncated PNG chunk.");
            if (sKind == "IHDR") then
                local nCompression, nFilter, nInterlace;

                nWidth, nHeight, nDepth, nKind, nCompression, nFilter, nInterlace = string.unpack(">I4I4I1I1I1I1I1", sChunk);
                assert(nWidth > 0 and nHeight > 0 and nWidth * nHeight <= 40000000, "PNG dimensions exceed the supported image size.");
                assert(nCompression == 0 and nFilter == 0 and nInterlace == 0, "PNG must be noninterlaced with standard compression/filtering.");
                assert((nKind == 3 and (nDepth == 1 or nDepth == 2 or nDepth == 4 or nDepth == 8)) or
                    (nDepth == 8 and (nKind == 0 or nKind == 2 or nKind == 4 or nKind == 6)), "Unsupported PNG color type or bit depth.");
            elseif (sKind == "PLTE") then sPalette = sChunk;
            elseif (sKind == "tRNS") then sTransparency = sChunk;
            elseif (sKind == "IDAT") then tData[#tData + 1] = sChunk;
            elseif (sKind == "IEND") then break; end
            nOffset = nOffset + nLength + 12;
        end
        assert(nWidth and #tData > 0, "PNG is missing its header or image data.");
        nChannels = ({[0] = 1, [2] = 3, [3] = 1, [4] = 2, [6] = 4})[nKind];
        nStride = (nWidth * nChannels * nDepth + 7) // 8;
        sRaw = inflate(table.concat(tData), (nStride + 1) * nHeight);
        assert(#sRaw == (nStride + 1) * nHeight, "PNG sample count does not match its dimensions.");
        for _ = 1, nHeight do
            local nFilter = sRaw:byte(nRaw);
            local tRow = {};
            local nPixelBytes = math.max(1, (nChannels * nDepth + 7) // 8);

            assert(nFilter <= 4, "Invalid PNG row filter.");
            nRaw = nRaw + 1;
            for nIndex = 1, nStride do
                local nLeft  = tRow[nIndex - nPixelBytes] or 0;
                local nAbove = tPrevious[nIndex] or 0;
                local nCorner = tPrevious[nIndex - nPixelBytes] or 0;
                local nPredictor = 0;

                if (nFilter == 1) then nPredictor = nLeft;
                elseif (nFilter == 2) then nPredictor = nAbove;
                elseif (nFilter == 3) then nPredictor = (nLeft + nAbove) // 2;
                elseif (nFilter == 4) then
                    local nEstimate = nLeft + nAbove - nCorner;
                    local nA, nB, nC = math.abs(nEstimate - nLeft), math.abs(nEstimate - nAbove), math.abs(nEstimate - nCorner);

                    nPredictor = nA <= nB and nA <= nC and nLeft or nB <= nC and nAbove or nCorner;
                end
                tRow[nIndex] = (sRaw:byte(nRaw) + nPredictor) & 255;
                nRaw = nRaw + 1;
            end
            for nX = 0, nWidth - 1 do
                local nIndex = nX * nChannels + 1;
                local nAlpha = 255;

                if (nKind == 3) then
                    local nPalette = (tRow[(nX * nDepth) // 8 + 1] >> (8 - nDepth - (nX * nDepth) % 8)) & ((1 << nDepth) - 1);

                    assert(sPalette and nPalette * 3 + 3 <= #sPalette, "PNG references an invalid palette entry.");
                    tColor[#tColor + 1] = sPalette:sub(nPalette * 3 + 1, nPalette * 3 + 3);
                    nAlpha = sTransparency and sTransparency:byte(nPalette + 1) or 255;
                elseif (nKind == 0 or nKind == 4) then
                    tColor[#tColor + 1] = string.char(tRow[nIndex]);
                    if (nKind == 4) then nAlpha = tRow[nIndex + 1];
                    elseif (sTransparency and tRow[nIndex] == string.unpack(">I2", sTransparency)) then nAlpha = 0; end
                else
                    tColor[#tColor + 1] = string.char(tRow[nIndex], tRow[nIndex + 1], tRow[nIndex + 2]);
                    if (nKind == 6) then nAlpha = tRow[nIndex + 3];
                    elseif (sTransparency) then
                        local nR, nG, nB = string.unpack(">I2I2I2", sTransparency);

                        if (tRow[nIndex] == nR and tRow[nIndex + 1] == nG and tRow[nIndex + 2] == nB) then nAlpha = 0; end
                    end
                end
                tAlpha[#tAlpha + 1] = string.char(nAlpha);
            end
            tPrevious = tRow;
        end
        tImage.width, tImage.height = nWidth, nHeight;
        tImage.colors = (nKind == 0 or nKind == 4) and 1 or 3;
        tImage.bytes, tImage.filter = deflate(table.concat(tColor)), "/FlateDecode";
        sRaw = table.concat(tAlpha);
        if (sRaw:find("[^\255]")) then tImage.alpha = deflate(sRaw); end
    end
    return tImage;
end

--[[!
@fqxn CFS.Manual.PDF.Functions.create
@desc Creates an independent document. Fonts are embedded in full, not subsetted.
    Unicode text is selectable/searchable. No OS-specific font discovery occurs.
@param table|nil tOptions Optional Title, Author and Subject metadata.
@return table oDocument Document with addFont, addImage, addPage, measureText,
    text, image, rectangle and save operations. Drawing methods take a page first.
!]]
function PDF.create(tOptions)
    local tFonts, tImages, tPages = {}, {}, {};
    local tDestinations, tOutlines, tOpacities = {}, {}, {};
    local oDocument = {};
    local fPage;
    local fFont;
    local fOpacity;

    tOptions = tOptions or {};
    fPage = function(tPage)
        assert(rawtype(tPage) == "table" and tPages[tPage.index] == tPage, "Page belongs to another document.");
    end;
    fFont = function(tFont)
        assert(rawtype(tFont) == "table" and tFonts[tFont.index] == tFont, "Font belongs to another document.");
    end;

    fOpacity = function(tPage, nOpacity)
        local sKey;
        local nIndex;

        nOpacity = nOpacity == nil and 1 or nOpacity;
        number(nOpacity);
        assert(nOpacity >= 0 and nOpacity <= 1, "Opacity must be between zero and one.");
        if (nOpacity == 1) then return ""; end
        sKey = number(nOpacity);
        nIndex = tOpacities[sKey];
        if (not nIndex) then
            nIndex = #tOpacities + 1;
            tOpacities[sKey], tOpacities[nIndex] = nIndex, nOpacity;
        end
        tPage.opacities = tPage.opacities or {};
        tPage.opacities[nIndex] = true;
        return "/GS"..nIndex.." gs ";
    end;

    --[[!
    @fqxn CFS.Manual.PDF.Document.addRawImage
    @desc Embeds RGB samples and optional alpha supplied by the existing native
        renderer. No temporary image file, browser or image encoder is required.
    @param number nWidth Positive pixel width.
    @param number nHeight Positive pixel height.
    @param string sRGB Three bytes per pixel.
    @param string|nil sAlpha Optional one-byte-per-pixel alpha.
    @return table tImage Document-owned image.
    !]]
    function oDocument.addRawImage(nWidth, nHeight, sRGB, sAlpha)
        local tImage;

        assert(math.type(nWidth) == "integer" and math.type(nHeight) == "integer" and nWidth > 0 and nHeight > 0, "Invalid raw image dimensions.");
        assert(#sRGB == nWidth * nHeight * 3 and (not sAlpha or #sAlpha == nWidth * nHeight), "Raw image sample count mismatch.");
        tImage = {width = nWidth, height = nHeight, colors = 3, filter = "/FlateDecode", bytes = deflate(sRGB), index = #tImages + 1};
        if (sAlpha) then tImage.alpha = deflate(sAlpha); end
        tImages[tImage.index] = tImage;
        return tImage;
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.withTransform
    @desc Applies a top-left-coordinate affine transform in a balanced graphics
        state. Restores the state even when the drawing callback fails.
    @param table tPage Page handle.
    @param table tMatrix Six affine values a/b/c/d/tx/ty.
    @param function fDraw Drawing callback.
    !]]
    function oDocument.withTransform(tPage, tMatrix, fDraw)
        local tValues;
        local bOK, vError;

        fPage(tPage);
        tValues = {tMatrix[1], -tMatrix[2], -tMatrix[3], tMatrix[4], tMatrix[5] + tMatrix[3] * tPage.height,
            tPage.height - tMatrix[6] - tMatrix[4] * tPage.height};
        for nIndex, nValue in ipairs(tValues) do tValues[nIndex] = number(nValue); end
        tPage.contents[#tPage.contents + 1] = "q "..table.concat(tValues, " ").." cm";
        bOK, vError = pcall(fDraw);
        tPage.contents[#tPage.contents + 1] = "Q";
        assert(bOK, vError);
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.withClip
    @desc Clips vector effect bands in top-left coordinates and restores state.
    @param table tPage Page handle.
    @param number nX Left.
    @param number nY Top.
    @param number nWidth Width.
    @param number nHeight Height.
    @param function fDraw Drawing callback.
    !]]
    function oDocument.withClip(tPage, nX, nY, nWidth, nHeight, fDraw)
        local bOK, vError;

        fPage(tPage);
        tPage.contents[#tPage.contents + 1] = "q "..number(nX).." "..number(tPage.height - nY - nHeight).." "..number(nWidth).." "..number(nHeight).." re W n";
        bOK, vError = pcall(fDraw);
        tPage.contents[#tPage.contents + 1] = "Q";
        assert(bOK, vError);
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.withActualText
    @desc Gives a styled group one searchable/copyable Unicode replacement, so
        repeated vector shadow/gradient passes do not repeat the logical text.
    @param table tPage Page handle.
    @param string sText Logical UTF-8 text.
    @param function fDraw Effect drawing callback.
    !]]
    function oDocument.withActualText(tPage, sText, fDraw)
        local bOK, vError;

        fPage(tPage);
        tPage.contents[#tPage.contents + 1] = "/Span << /ActualText <FEFF"..unicode(sText).."> >> BDC";
        bOK, vError = pcall(fDraw);
        tPage.contents[#tPage.contents + 1] = "EMC";
        assert(bOK, vError);
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.addFont
    @desc Loads a font by explicit path. Unsupported/missing glyphs produce errors.
    @param string pFile TTF, OTF, TTC or OTC file.
    @param number|nil nFace One-based face, defaults to one.
    @return table tFont Document-owned font handle.
    !]]
    function oDocument.addFont(pFile, nFace)
        local tFont = font(pFile, nFace or 1);

        tFont.path = pFile;
        tFont.index = #tFonts + 1;
        tFonts[tFont.index] = tFont;
        return tFont;
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.addImage
    @desc Embeds an image once for reuse across pages.
    @param string pFile PNG or JPEG file.
    @return table tImage Document-owned image handle with width/height in pixels.
    !]]
    function oDocument.addImage(pFile)
        local tImage = image(pFile);

        tImage.index = #tImages + 1;
        tImages[tImage.index] = tImage;
        return tImage;
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.addPage
    @desc Adds a page with explicit point dimensions.
    @param number nWidth Positive page width.
    @param number nHeight Positive page height.
    @return table tPage Document-owned page handle.
    !]]
    function oDocument.addPage(nWidth, nHeight)
        local tPage = {width = nWidth, height = nHeight, contents = {}, fonts = {}, images = {}, index = #tPages + 1};

        number(nWidth); number(nHeight);
        assert(nWidth > 0 and nHeight > 0, "PDF page dimensions must be positive.");
        tPages[tPage.index] = tPage;
        return tPage;
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.missingGlyphs
    @desc Returns unsupported Unicode code points without measuring or drawing text.
    @param table tFont Document-owned font handle.
    @param string sText UTF-8 text.
    @return table tMissing Distinct missing code points in encounter order.
    !]]
    local function glyphFont(tFont, nCode)
        if (glyph(tFont, nCode) ~= 0) then return tFont; end
        for _, tFallback in ipairs(tFont.fallbacks or {}) do
            fFont(tFallback);
            if (glyph(tFallback, nCode) ~= 0) then return tFallback; end
        end
        return tFont;
    end
    function oDocument.missingGlyphs(tFont, sText)
        fFont(tFont);
        local tMissing, tSeen = {}, {};
        for _, nCode in utf8.codes(sText) do
            if (not tSeen[nCode] and glyph(glyphFont(tFont, nCode), nCode) == 0) then
                tMissing[#tMissing + 1] = nCode;
            end
            tSeen[nCode] = true;
        end
        return tMissing;
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.measureText
    @desc Measures unshaped glyph advances; does not apply kerning, ligatures or bidi.
    @param table tFont Font handle.
    @param number nSize Positive font size in points.
    @param string sText Single-line UTF-8 text.
    @param number|nil nSpacing Extra character spacing in points.
    @return number nWidth Width in points.
    !]]
    function oDocument.measureText(tFont, nSize, sText, nSpacing)
        local nWidth = 0;

        fFont(tFont);
        number(nSize);
        assert(nSize > 0 and not sText:find("[%z\1-\31]"), "Text must be a single line with a positive font size.");
        for _, nCode in utf8.codes(sText) do
            local tSelected = glyphFont(tFont, nCode);
            local nGlyph = glyph(tSelected, nCode);

            assert(nGlyph ~= 0, string.format("Font %s has no glyph for U+%04X.", tFont.name, nCode));
            nWidth = nWidth + width(tSelected, nGlyph);
        end
        return nWidth * nSize / 1000 + utf8.len(sText) * (nSpacing or 0);
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.text
    @desc Draws a UTF-8 line with its baseline nY points below the page top.
    @param table tPage Page handle.
    @param table tFont Font handle.
    @param number nSize Font size in points.
    @param number nX Baseline x coordinate.
    @param number nY Baseline distance from page top.
    @param string sText UTF-8 text; complex scripts require a future shaping layer.
    @param table|nil tStyle Optional color (three zero-to-one RGB values) and spacing in points.
    @return number nWidth Unshaped advance in points.
    !]]
    function oDocument.text(tPage, tFont, nSize, nX, nY, sText, tStyle)
        local tCodes = {};
        local tColor = {};
        local nSpacing = tStyle and tStyle.spacing or 0;
        local nWidth = oDocument.measureText(tFont, nSize, sText, nSpacing);

        if (tFont.fallbacks) then
            local tSegments = {};
            local bFallback = false;
            for _, nCode in utf8.codes(sText) do
                local tSelected = glyphFont(tFont, nCode);
                local tLast = tSegments[#tSegments];
                bFallback = bFallback or tSelected ~= tFont;
                if (not tLast or tLast.font ~= tSelected) then
                    tLast = {font = tSelected, text = ""}; tSegments[#tSegments + 1] = tLast;
                end
                tLast.text = tLast.text..utf8.char(nCode);
            end
            if (bFallback) then
                local nOffset = 0;
                for _, tSegment in ipairs(tSegments) do
                    nOffset = nOffset + oDocument.text(tPage, tSegment.font, nSize, nX + nOffset, nY, tSegment.text, tStyle);
                end
                return nOffset;
            end
        end
        number(nSpacing);
        for nIndex = 1, 3 do
            local nValue = tStyle and tStyle.color and tStyle.color[nIndex] or 0;

            number(nValue);
            assert(nValue >= 0 and nValue <= 1, "Text RGB components must be between zero and one.");
            tColor[nIndex] = number(nValue);
        end

        fPage(tPage);
        for _, nCode in utf8.codes(sText) do
            local nCID = tFont.codes[nCode];

            if (not nCID) then
                local nGlyph = glyph(tFont, nCode);

                nCID = tFont.cff and nGlyph or tFont.nextCode;
                assert(nCID <= 65535, "The font exceeds the PDF character-code limit.");
                assert(not tFont.used[nCID] or tFont.used[nCID].unicode == nCode, "CFF glyph aliases require separate encoding support.");
                tFont.codes[nCode] = nCID;
                tFont.used[nCID] = {glyph = nGlyph, unicode = nCode, width = width(tFont, nGlyph)};
                tFont.nextCode = tFont.nextCode + 1;
            end
            tCodes[#tCodes + 1] = string.format("%04X", nCID);
        end
        tPage.fonts[tFont.index] = true;
        tPage.contents[#tPage.contents + 1] = "q "..fOpacity(tPage, tStyle and tStyle.opacity)..table.concat(tColor, " ").." rg BT /F"..tFont.index.." "..number(nSize).." Tf "..number(nSpacing).." Tc 1 0 0 1 "..number(nX).." "..number(tPage.height - nY).." Tm <"..table.concat(tCodes).."> Tj ET Q";
        return nWidth;
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.image
    @desc Draws an embedded image with its top-left corner at nX/nY.
    @param table tPage Page handle.
    @param table tImage Image handle.
    @param number nX Left coordinate.
    @param number nY Top coordinate.
    @param number nWidth Positive display width in points.
    @param number|nil nHeight Display height; defaults to the image aspect ratio.
    !]]
    function oDocument.image(tPage, tImage, nX, nY, nWidth, nHeight)
        fPage(tPage);
        assert(rawtype(tImage) == "table" and tImages[tImage.index] == tImage, "Image belongs to another document.");
        nHeight = nHeight or nWidth * tImage.height / tImage.width;
        number(nWidth); number(nHeight);
        assert(nWidth > 0 and nHeight > 0, "Image dimensions must be positive.");
        tPage.images[tImage.index] = true;
        tPage.contents[#tPage.contents + 1] = "q "..number(nWidth).." 0 0 "..number(nHeight).." "..number(nX).." "..number(tPage.height - nY - nHeight).." cm /Im"..tImage.index.." Do Q";
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.rectangle
    @desc Fills a rectangle with an RGB color; graphics state is restored afterwards.
    @param table tPage Page handle.
    @param number nX Left coordinate.
    @param number nY Top coordinate.
    @param number nWidth Positive width in points.
    @param number nHeight Positive height in points.
    @param table tRGB Three color components in the range zero to one.
    !]]
    function oDocument.rectangle(tPage, nX, nY, nWidth, nHeight, tRGB, nOpacity)
        local tColor = {};

        fPage(tPage);
        for nIndex = 1, 3 do
            local nValue = tRGB[nIndex];

            number(nValue);
            assert(nValue >= 0 and nValue <= 1, "RGB components must be between zero and one.");
            tColor[nIndex] = number(nValue);
        end
        assert(nWidth > 0 and nHeight > 0, "Rectangle dimensions must be positive.");
        tPage.contents[#tPage.contents + 1] = "q "..fOpacity(tPage, nOpacity)..table.concat(tColor, " ").." rg "..number(nX).." "..number(tPage.height - nY - nHeight).." "..number(nWidth).." "..number(nHeight).." re f Q";
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.setPageBoxes
    @desc Sets trim/bleed rectangles using PDF bottom-left coordinates in points.
    @param table tPage Page handle.
    @param table tTrim Four coordinates x0/y0/x1/y1 inside the media box.
    @param table|nil tBleed Bleed rectangle; defaults to the media box.
    !]]
    function oDocument.setPageBoxes(tPage, tTrim, tBleed)
        local fBox;

        fPage(tPage);
        fBox = function(tBox)
            local tCopy = {};

            for nIndex = 1, 4 do
                number(tBox[nIndex]);
                tCopy[nIndex] = tBox[nIndex];
            end
            assert(tCopy[1] >= 0 and tCopy[2] >= 0 and tCopy[3] <= tPage.width and tCopy[4] <= tPage.height
                and tCopy[3] > tCopy[1] and tCopy[4] > tCopy[2], "Page box must fit inside its media box.");
            return tCopy;
        end;
        tPage.trim = fBox(tTrim);
        tPage.bleed = fBox(tBleed or {0, 0, tPage.width, tPage.height});
        assert(tPage.trim[1] >= tPage.bleed[1] and tPage.trim[2] >= tPage.bleed[2]
            and tPage.trim[3] <= tPage.bleed[3] and tPage.trim[4] <= tPage.bleed[4], "Trim must fit inside bleed.");
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.destination
    @desc Registers a unique internal destination; duplicate names are rejected.
    @param string sName Nonempty anchor name.
    @param table tPage Target page.
    @param number nX Target x coordinate.
    @param number nY Target distance from page top.
    !]]
    function oDocument.destination(sName, tPage, nX, nY)
        fPage(tPage);
        number(nX); number(nY);
        assert(rawtype(sName) == "string" and sName ~= "" and not tDestinations[sName], "Duplicate or empty PDF destination: "..tostring(sName));
        tDestinations[sName] = {page = tPage, x = nX, y = nY};
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.link
    @desc Adds a clickable rectangle. Internal destinations start with #; external
        links must use http, https, mailto or ftp. Broken destinations fail at save.
    @param table tPage Page containing the link.
    @param number nX Left coordinate.
    @param number nY Top coordinate.
    @param number nWidth Positive width.
    @param number nHeight Positive height.
    @param string sTarget Internal anchor or supported external URI.
    !]]
    function oDocument.link(tPage, nX, nY, nWidth, nHeight, sTarget)
        local sScheme;

        fPage(tPage);
        number(nX); number(nY); number(nWidth); number(nHeight);
        assert(nWidth > 0 and nHeight > 0, "Link dimensions must be positive.");
        assert(rawtype(sTarget) == "string" and not sTarget:find("[%z\1-\32]"), "Invalid PDF link target.");
        sScheme = sTarget:match("^([%a][%w+.-]*):");
        assert(sTarget:sub(1, 1) == "#" or (sScheme and ({http = true, https = true, mailto = true, ftp = true})[sScheme:lower()]), "Unsupported PDF link target: "..sTarget);
        tPage.links = tPage.links or {};
        tPage.links[#tPage.links + 1] = {x = nX, y = nY, width = nWidth, height = nHeight, target = sTarget};
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.outline
    @desc Appends a bookmark. Heading levels determine the parent hierarchy.
    @param string sTitle UTF-8 bookmark title.
    @param string sDestination Existing destination name.
    @param number nLevel Positive integer heading level.
    !]]
    function oDocument.outline(sTitle, sDestination, nLevel)
        assert(rawtype(sTitle) == "string" and rawtype(sDestination) == "string", "Bookmark title and destination must be strings.");
        assert(math.type(nLevel) == "integer" and nLevel > 0, "Bookmark level must be a positive integer.");
        tOutlines[#tOutlines + 1] = {title = sTitle, destination = sDestination, level = nLevel, children = {}};
    end

    --[[!
    @fqxn CFS.Manual.PDF.Document.save
    @desc Serializes a complete PDF in binary mode, refusing to overwrite an existing
        file. The export coordinator must own staged publication. No input paths
        or font discovery information is stored in the PDF.
    @param string pFile New output path.
    @return number nBytes Bytes written.
    !]]
    function oDocument.save(pFile, fCheckpoint, fProgress)
        local tObjects, tFontRefs, tImageRefs, tPageRefs = {}, {}, {}, {};
        local tPageObjects, tOpacityRefs = {}, {};
        local nDestinationTree, nOutlineRoot;
        local tOutput, tOffsets = {"%PDF-1.7\n%\226\227\207\211\n"}, {};
        local nOffset = #tOutput[1];
        local nPages, nCatalog, nInfo;
        local fObject;
        local fStream;
        local hExisting;
        local hFile;
        local sOutput;

        assert(#tPages > 0, "Cannot save an empty PDF.");
        hExisting = io.open(pFile, "rb");
        if (hExisting) then hExisting:close(); error("Refusing to overwrite an existing PDF: "..pFile); end
        fObject = function(sObject)
            tObjects[#tObjects + 1] = sObject;
            return #tObjects;
        end;
        fStream = function(sDictionary, sBytes)
            return fObject("<< "..sDictionary.." /Length "..#sBytes.." >>\nstream\n"..sBytes.."\nendstream");
        end;
        nPages = fObject("");
        for nIndex, tFont in ipairs(tFonts) do
            if (fCheckpoint) then fCheckpoint(); end
            local nProgram = fStream(tFont.cff and "/Subtype /OpenType" or "/Length1 "..#tFont.bytes, tFont.bytes);
            local tBounds, tWidths, tMappings, tIDs = {}, {}, {}, {};
            local nDescriptor, nMap, nCIDMap, nDescendant;
            local tCIDBytes = {"\0\0"};

            for _, nBound in ipairs(tFont.bounds) do tBounds[#tBounds + 1] = number(nBound); end
            for nCID in pairs(tFont.used) do tIDs[#tIDs + 1] = nCID; end
            table.sort(tIDs);
            for _, nCID in ipairs(tIDs) do
                local tUsed = tFont.used[nCID];

                tWidths[#tWidths + 1] = nCID.." ["..number(tUsed.width).."]";
                tMappings[#tMappings + 1] = string.format("<%04X> <%s>", nCID, unicode(utf8.char(tUsed.unicode)));
                if (not tFont.cff) then tCIDBytes[nCID + 1] = string.pack(">I2", tUsed.glyph); end
            end
            nDescriptor = fObject("<< /Type /FontDescriptor /FontName /"..tFont.name.." /Flags 4 /FontBBox ["..table.concat(tBounds, " ").."] /ItalicAngle 0 /Ascent "..number(tFont.ascent).." /Descent "..number(tFont.descent).." /CapHeight "..number(tFont.ascent).." /StemV 80 /"..(tFont.cff and "FontFile3" or "FontFile2").." "..nProgram.." 0 R >>");
            do
                local tCmap = {"/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def\n/CMapName /Unicode def\n/CMapType 2 def\n1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange"};

                for nFirst = 1, #tMappings, 100 do
                    tCmap[#tCmap + 1] = math.min(100, #tMappings - nFirst + 1).." beginbfchar";
                    for nIndexMap = nFirst, math.min(nFirst + 99, #tMappings) do tCmap[#tCmap + 1] = tMappings[nIndexMap]; end
                    tCmap[#tCmap + 1] = "endbfchar";
                end
                tCmap[#tCmap + 1] = "endcmap\nCMapName currentdict /CMap defineresource pop\nend\nend";
                nMap = fStream("", table.concat(tCmap, "\n"));
            end
            if (not tFont.cff) then nCIDMap = fStream("", table.concat(tCIDBytes)); end
            nDescendant = fObject("<< /Type /Font /Subtype /"..(tFont.cff and "CIDFontType0" or "CIDFontType2").." /BaseFont /"..tFont.name.." /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor "..nDescriptor.." 0 R /DW 1000 /W ["..table.concat(tWidths, " ").."]"..(nCIDMap and " /CIDToGIDMap "..nCIDMap.." 0 R" or "").." >>");
            tFontRefs[nIndex] = fObject("<< /Type /Font /Subtype /Type0 /BaseFont /"..tFont.name.." /Encoding /Identity-H /DescendantFonts ["..nDescendant.." 0 R] /ToUnicode "..nMap.." 0 R >>");
        end
        for nIndex, tImage in ipairs(tImages) do
            if (fCheckpoint) then fCheckpoint(); end
            local sSize = "/Type /XObject /Subtype /Image /Width "..tImage.width.." /Height "..tImage.height.." /BitsPerComponent 8";
            local nMask;

            if (tImage.alpha) then nMask = fStream(sSize.." /ColorSpace /DeviceGray /Filter /FlateDecode", tImage.alpha); end
            tImageRefs[nIndex] = fStream(sSize.." /ColorSpace /"..(tImage.colors == 1 and "DeviceGray" or "DeviceRGB").." /Filter "..tImage.filter..(nMask and " /SMask "..nMask.." 0 R" or ""), tImage.bytes);
        end
        for nIndex, nOpacity in ipairs(tOpacities) do
            tOpacityRefs[nIndex] = fObject("<< /Type /ExtGState /ca "..number(nOpacity).." /CA "..number(nOpacity).." >>");
        end
        for nIndex in ipairs(tPages) do tPageObjects[nIndex] = fObject(""); end
        for nIndexPage, tPage in ipairs(tPages) do
            if (fProgress) then fProgress("writing", "Serializing PDF page "..nIndexPage.." of "..#tPages, nIndexPage); end
            if (fCheckpoint) then fCheckpoint(); end
            local tFontResources, tImageResources, tAnnotations, tOpacityResources = {}, {}, {}, {};
            local nContent = fStream("", table.concat(tPage.contents, "\n"));
            local sBoxes = "";

            for nIndex in pairs(tPage.fonts) do tFontResources[#tFontResources + 1] = "/F"..nIndex.." "..tFontRefs[nIndex].." 0 R"; end
            for nIndex in pairs(tPage.images) do tImageResources[#tImageResources + 1] = "/Im"..nIndex.." "..tImageRefs[nIndex].." 0 R"; end
            for nIndex in pairs(tPage.opacities or {}) do tOpacityResources[#tOpacityResources + 1] = "/GS"..nIndex.." "..tOpacityRefs[nIndex].." 0 R"; end
            for _, tLink in ipairs(tPage.links or {}) do
                local sAction;
                local sRectangle = number(tLink.x).." "..number(tPage.height - tLink.y - tLink.height).." "..number(tLink.x + tLink.width).." "..number(tPage.height - tLink.y);

                if (tLink.target:sub(1, 1) == "#") then
                    local sName = tLink.target:sub(2);

                    assert(tDestinations[sName], "Unresolved PDF link: "..tLink.target);
                    sAction = "/Dest <FEFF"..unicode(sName)..">";
                else
                    local sURI = tLink.target:gsub("[\128-\255]", function(sByte) return string.format("%%%02X", sByte:byte()); end);

                    sURI = sURI:gsub("([\\()])", "\\%1");
                    sAction = "/A << /S /URI /URI ("..sURI..") >>";
                end
                tAnnotations[#tAnnotations + 1] = fObject("<< /Type /Annot /Subtype /Link /Rect ["..sRectangle.."] /Border [0 0 0] "..sAction.." >>").." 0 R";
            end
            for _, sName in ipairs({"trim", "bleed"}) do
                if (tPage[sName]) then
                    local tBox = {};

                    for _, nValue in ipairs(tPage[sName]) do tBox[#tBox + 1] = number(nValue); end
                    sBoxes = sBoxes..(sName == "trim" and " /TrimBox [" or " /BleedBox [")..table.concat(tBox, " ").."]";
                end
            end
            tObjects[tPageObjects[nIndexPage]] = "<< /Type /Page /Parent "..nPages.." 0 R /MediaBox [0 0 "..number(tPage.width).." "..number(tPage.height).."]"..sBoxes
                .." /Resources << /Font << "..table.concat(tFontResources, " ").." >> /XObject << "..table.concat(tImageResources, " ").." >> /ExtGState << "..table.concat(tOpacityResources, " ").." >> >> /Contents "..nContent.." 0 R"
                ..(#tAnnotations > 0 and " /Annots ["..table.concat(tAnnotations, " ").."]" or "").." >>";
            tPageRefs[#tPageRefs + 1] = tPageObjects[nIndexPage].." 0 R";
        end
        do
            local tNames, tEntries = {}, {};

            for sName in pairs(tDestinations) do tNames[#tNames + 1] = sName; end
            table.sort(tNames, function(sLeft, sRight) return unicode(sLeft) < unicode(sRight); end);
            for _, sName in ipairs(tNames) do
                local tDestination = tDestinations[sName];

                tEntries[#tEntries + 1] = "<FEFF"..unicode(sName).."> ["..tPageObjects[tDestination.page.index].." 0 R /XYZ "..number(tDestination.x).." "..number(tDestination.page.height - tDestination.y).." null]";
            end
            if (#tEntries > 0) then nDestinationTree = fObject("<< /Names ["..table.concat(tEntries, " ").."] >>"); end
        end
        if (#tOutlines > 0) then
            local tRoot = {children = {}};
            local tStack = {tRoot};
            local fWriteOutline;

            nOutlineRoot = fObject("");
            tRoot.reference = nOutlineRoot;
            for _, tItem in ipairs(tOutlines) do
                local tParent;

                assert(tDestinations[tItem.destination], "Unresolved PDF bookmark: "..tItem.destination);
                while (#tStack > 1 and tStack[#tStack].level >= tItem.level) do tStack[#tStack] = nil; end
                tParent = tStack[#tStack];
                tItem.parent, tItem.reference, tItem.children = tParent, fObject(""), {};
                tParent.children[#tParent.children + 1] = tItem;
                tStack[#tStack + 1] = tItem;
            end
            fWriteOutline = function(tParent)
                local nCount = 0;

                for nIndex, tItem in ipairs(tParent.children) do
                    local nDescendants = fWriteOutline(tItem);
                    local sChildren = #tItem.children > 0 and " /First "..tItem.children[1].reference.." 0 R /Last "..tItem.children[#tItem.children].reference.." 0 R /Count "..nDescendants or "";
                    local sPrevious = nIndex > 1 and " /Prev "..tParent.children[nIndex - 1].reference.." 0 R" or "";
                    local sNext = nIndex < #tParent.children and " /Next "..tParent.children[nIndex + 1].reference.." 0 R" or "";

                    tObjects[tItem.reference] = "<< /Title <FEFF"..unicode(tItem.title).."> /Parent "..tParent.reference.." 0 R /Dest <FEFF"..unicode(tItem.destination)..">"..sPrevious..sNext..sChildren.." >>";
                    nCount = nCount + nDescendants + 1;
                end
                return nCount;
            end;
            tObjects[nOutlineRoot] = "<< /Type /Outlines /First "..tRoot.children[1].reference.." 0 R /Last "..tRoot.children[#tRoot.children].reference.." 0 R /Count "..fWriteOutline(tRoot).." >>";
        end
        tObjects[nPages] = "<< /Type /Pages /Kids ["..table.concat(tPageRefs, " ").."] /Count "..#tPages.." >>";
        nCatalog = fObject("<< /Type /Catalog /Pages "..nPages.." 0 R"
            ..(nDestinationTree and " /Names << /Dests "..nDestinationTree.." 0 R >>" or "")
            ..(nOutlineRoot and " /Outlines "..nOutlineRoot.." 0 R /PageMode /UseOutlines" or "").." >>");
        nInfo = fObject("<< /Title <FEFF"..unicode(tOptions.Title or "").."> /Author <FEFF"..unicode(tOptions.Author or "").."> /Subject <FEFF"..unicode(tOptions.Subject or "").."> /Producer (Card Forge Studio - Lua PDF) >>");
        for nIndex, sObject in ipairs(tObjects) do
            if (fCheckpoint) then fCheckpoint(); end
            local sSerialized = nIndex.." 0 obj\n"..sObject.."\nendobj\n";

            tOffsets[nIndex] = nOffset;
            tOutput[#tOutput + 1] = sSerialized;
            nOffset = nOffset + #sSerialized;
        end
        tOutput[#tOutput + 1] = "xref\n0 "..(#tObjects + 1).."\n0000000000 65535 f \n";
        for _, nObjectOffset in ipairs(tOffsets) do
            assert(nObjectOffset < 10000000000, "PDF exceeds the classic cross-reference offset limit.");
            tOutput[#tOutput + 1] = string.format("%010d 00000 n \n", nObjectOffset);
        end
        tOutput[#tOutput + 1] = "trailer\n<< /Size "..(#tObjects + 1).." /Root "..nCatalog.." 0 R /Info "..nInfo.." 0 R >>\nstartxref\n"..nOffset.."\n%%EOF\n";
        if (fCheckpoint) then fCheckpoint(); end
        sOutput = table.concat(tOutput);
        if (fCheckpoint) then fCheckpoint(); end
        hFile = assert(io.open(pFile, "wb"));
        do
            local bWritten, sError = hFile:write(sOutput);
            local bClosed, sCloseError = hFile:close();

            assert(bWritten, sError);
            assert(bClosed, sCloseError);
        end
        return #sOutput;
    end

    return oDocument;
end

return PDF;
