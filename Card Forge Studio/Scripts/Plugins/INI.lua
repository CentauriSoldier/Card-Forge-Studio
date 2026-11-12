-- File-backed INI operations with per-value section inheritance.
-- Reads preserve references unless bInherit is true. Writes follow references
-- only when bRespectChain is true. Native WX objects are released per operation.
-- Name-based operations accept a final bCaseSensitive option. Omit it to retain
-- native WX behavior; true requires exact spelling and false ignores name case.
-- Writes preserve existing spelling; native case-only name conflicts are rejected.
local wx = require("wx");
local INI = {};

local function trim(sText)
    return sText:match("^%s*(.-)%s*$");
end

local function reference(sText)
    local sTrimmed = trim(sText);

    if (sTrimmed:sub(1, 1) == "<" and sTrimmed:sub(-1) == ">") then
        return trim(sTrimmed:sub(2, -2));
    end

    return nil;
end

local function validateName(sName, sLabel)
    assert(type(sName) == "string" and sName ~= "", sLabel.." must be a nonempty string.");
    assert(not sName:find("[/\\]"), sLabel.." cannot contain path separators.");
end

local function enumerate(oConfig, bGroups)
    local tNames = {};
    local bFound, sName, nIndex;

    if (bGroups) then
        bFound, sName, nIndex = oConfig:GetFirstGroup();
    else
        bFound, sName, nIndex = oConfig:GetFirstEntry();
    end

    while (bFound) do
        tNames[#tNames + 1] = sName;

        if (bGroups) then
            bFound, sName, nIndex = oConfig:GetNextGroup(nIndex);
        else
            bFound, sName, nIndex = oConfig:GetNextEntry(nIndex);
        end
    end

    return tNames;
end

local function validateCaseOption(bCaseSensitive)
    assert(bCaseSensitive == nil or type(bCaseSensitive) == "boolean", "CaseSensitive must be a boolean.");
    return bCaseSensitive;
end

local function nameIndex(tNames, bCaseSensitive)
    local tLookup = {};

    for _, sName in ipairs(tNames) do
        local sKey = bCaseSensitive and sName or sName:upper();
        assert(not tLookup[sKey] or tLookup[sKey] == sName, "Ambiguous case-insensitive INI name: "..sName);
        tLookup[sKey] = sName;
    end

    return tLookup;
end

local function lookupName(tNames, sName, bCaseSensitive, tLookup)
    local sKey = bCaseSensitive and sName or sName:upper();
    return (tLookup or nameIndex(tNames, bCaseSensitive))[sKey];
end

local function selectSection(oConfig, sSection, bCaseSensitive, bCreate)
    assert(type(sSection) == "string", "Section must be a string.");
    assert(not sSection:find("[/\\]"), "Section cannot contain path separators.");
    if (bCaseSensitive == nil or sSection == "") then
        oConfig:SetPath("/"..sSection);
        return true;
    end

    oConfig:SetPath("/");
    local tNames		= enumerate(oConfig, true);
    local sStoredSection	= lookupName(tNames, sSection, bCaseSensitive);
    if (not sStoredSection) then
        if (not bCreate) then return false end
        assert(not lookupName(tNames, sSection, false), "INI section spelling conflicts with an existing section: "..sSection);
        sStoredSection = sSection;
    end
    oConfig:SetPath("/"..sStoredSection);
    return true;
end

local function withFile(pFile, fOperation)
    assert(type(pFile) == "string" and pFile ~= "", "INI file path must be a nonempty string.");

    local oConfig = wx.wxFileConfig("", "", pFile, "", wx.wxCONFIG_USE_LOCAL_FILE);
    oConfig:DisableAutoSave();
    oConfig:SetExpandEnvVars(false);

    local tResults = table.pack(xpcall(function()
        return fOperation(oConfig);
    end, debug.traceback));

    oConfig:delete();

    if (not tResults[1]) then
        error(tResults[2], 0);
    end

    return table.unpack(tResults, 2, tResults.n);
end

local function readValue(oConfig, sSection, sValue, bCaseSensitive)
    if (not selectSection(oConfig, sSection, bCaseSensitive, false)) then return "" end
    if (bCaseSensitive ~= nil) then
        sValue = lookupName(enumerate(oConfig, false), sValue, bCaseSensitive);
        if (not sValue) then return "" end
    end

    local bFound, sRaw = oConfig:Read(sValue, "");
    return bFound and sRaw or "";
end

-- Return the resolved string and the visited reference sections, in order.
-- Missing values, empty references, and cycles resolve to an empty string.
function INI.GetValue(pFile, sSection, sValue, bInherit, bCaseSensitive)
    validateName(sValue, "Value name");
    bCaseSensitive = validateCaseOption(bCaseSensitive);

    return withFile(pFile, function(oConfig)
        local tVisited = {};
        local tChain = nil;
        local sCurrent = sSection;

        while (true) do
            if (tVisited[sCurrent]) then
                return "", tChain;
            end

            tVisited[sCurrent] = true;

            local sRaw = readValue(oConfig, sCurrent, sValue, bCaseSensitive);

            if (bInherit ~= true) then
                return sRaw, nil;
            end

            local sReference = reference(sRaw);

            if (sReference == nil) then
                return sRaw, tChain;
            end

            if (sReference == "") then
                return "", tChain;
            end

            tChain = tChain or {};
            tChain[#tChain + 1] = sReference;
            sCurrent = sReference;
        end
    end);
end

function INI.GetValueBoolean(pFile, sSection, sValue, bInherit, bCaseSensitive)
    local sRaw = INI.GetValue(pFile, sSection, sValue, bInherit, bCaseSensitive);

    return sRaw:lower() == "true";
end

function INI.GetValueNumber(pFile, sSection, sValue, nDefault, bInherit, bCaseSensitive)
    local sRaw = INI.GetValue(pFile, sSection, sValue, bInherit, bCaseSensitive);
    local nFallback = type(nDefault) == "number" and nDefault or 0;

    return tonumber(sRaw) or nFallback;
end

-- On a cycle, match the archived extension: write at the repeated section.
function INI.SetValue(pFile, sSection, sValue, sData, bRespectChain, bCaseSensitive)
    validateName(sValue, "Value name");
    assert(type(sData) == "string", "INI data must be a string.");
    bCaseSensitive = validateCaseOption(bCaseSensitive);

    return withFile(pFile, function(oConfig)
        local sCurrent = sSection;
        local tVisited = {};

        while (bRespectChain and sCurrent ~= "") do
            if (tVisited[sCurrent]) then break end
            tVisited[sCurrent] = true;

            local sReference = reference(readValue(oConfig, sCurrent, sValue, bCaseSensitive));

            if (sReference == nil or sReference == "") then
                break;
            end

            sCurrent = sReference;
        end

        selectSection(oConfig, sCurrent, bCaseSensitive, true);
        local sStoredValue = sValue;
        if (bCaseSensitive ~= nil) then
            local tNames = enumerate(oConfig, false);
            sStoredValue = lookupName(tNames, sValue, bCaseSensitive);
            if (not sStoredValue) then
                assert(not lookupName(tNames, sValue, false), "INI key spelling conflicts with an existing key: "..sValue);
                sStoredValue = sValue;
            end
        end
        assert(oConfig:Write(sStoredValue, sData), "Could not write INI value.");
        assert(oConfig:Flush(), "Could not save INI file.");

        return true;
    end);
end

function INI.GetSectionNames(pFile)
    return withFile(pFile, function(oConfig)
        oConfig:SetPath("/");

        return enumerate(oConfig, true);
    end);
end

function INI.GetValueNames(pFile, sSection, bCaseSensitive)
    bCaseSensitive = validateCaseOption(bCaseSensitive);
    return withFile(pFile, function(oConfig)
        if (not selectSection(oConfig, sSection, bCaseSensitive, false)) then return {} end

        return enumerate(oConfig, false);
    end);
end

function INI.DeleteValue(pFile, sSection, sValue, bCaseSensitive)
    validateName(sValue, "Value name");
    bCaseSensitive = validateCaseOption(bCaseSensitive);

    return withFile(pFile, function(oConfig)
        if (not selectSection(oConfig, sSection, bCaseSensitive, false)) then return false end
        local sStoredValue = bCaseSensitive == nil and sValue or lookupName(enumerate(oConfig, false), sValue, bCaseSensitive);
        if (not sStoredValue) then return false end

        local bDeleted = oConfig:DeleteEntry(sStoredValue, false);
        assert(oConfig:Flush(), "Could not save INI file.");

        return bDeleted;
    end);
end

function INI.DeleteSection(pFile, sSection, bCaseSensitive)
    validateName(sSection, "Section name");
    bCaseSensitive = validateCaseOption(bCaseSensitive);

    return withFile(pFile, function(oConfig)
        oConfig:SetPath("/");

        local sStoredSection = bCaseSensitive == nil and sSection or lookupName(enumerate(oConfig, true), sSection, bCaseSensitive);
        if (not sStoredSection) then return false end
        local bDeleted = oConfig:DeleteGroup(sStoredSection);
        assert(oConfig:Flush(), "Could not save INI file.");

        return bDeleted;
    end);
end

-- Create a read-only snapshot. Its default is exact-case matching, preserving
-- the original FontStyle reader behavior; pass false to ignore name case.
-- Enumeration preserves spelling. Case-only duplicates are rejected in insensitive mode.
function INI.CreateReader(pFile, bCaseSensitive)
    bCaseSensitive = validateCaseOption(bCaseSensitive) ~= false;
    local tSections	= {};
    local tNames		= {};
    local tValueNames	= {};
    local tValueLookup	= {};

    withFile(pFile, function(oConfig)
        oConfig:SetPath("/");
        tNames = enumerate(oConfig, true);
        for _, sSection in ipairs(tNames) do
            oConfig:SetPath("/"..sSection);
            local tKeys	= enumerate(oConfig, false);
            local tValues	= {};
            table.sort(tKeys);
            for _, sKey in ipairs(tKeys) do
                local bFound, sValue = oConfig:Read(sKey, "");
                tValues[sKey] = bFound and sValue or "";
            end
            tSections[sSection]	= tValues;
            tValueNames[sSection]	= tKeys;
            tValueLookup[sSection]	= nameIndex(tKeys, bCaseSensitive);
            oConfig:SetPath("/");
        end
    end);
    local tSectionLookup = nameIndex(tNames, bCaseSensitive);

    return {
        CaseSensitive	= bCaseSensitive,
        GetValue		= function(sSection, sKey, bInherit)
            local tSeen = {};
            while (true) do
                sSection = lookupName(tNames, sSection, bCaseSensitive, tSectionLookup);
                if (not sSection or tSeen[sSection]) then return "" end
                tSeen[sSection] = true;
                local tValues	= tSections[sSection];
                local sStoredKey	= lookupName(tValueNames[sSection] or {}, sKey, bCaseSensitive, tValueLookup[sSection]);
                local sValue		= tValues and tValues[sStoredKey] or "";
                local sReference = reference(sValue);
                if (not bInherit or not sReference) then return sValue end
                sSection = sReference;
            end
        end,
        GetValueNames	= function(sSection)
            sSection = lookupName(tNames, sSection, bCaseSensitive, tSectionLookup);
            return {table.unpack(tValueNames[sSection] or {})};
        end,
        GetSectionNames	= function()
            return {table.unpack(tNames)};
        end,
    };
end

return INI;
