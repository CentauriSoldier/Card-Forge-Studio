-- File-backed INI operations with per-value section inheritance.
-- Reads preserve references unless bInherit is true. Writes follow references
-- only when bRespectChain is true. Native WX objects are released per operation.
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

local function selectSection(oConfig, sSection)
    assert(type(sSection) == "string", "Section must be a string.");
    assert(not sSection:find("[/\\]"), "Section cannot contain path separators.");
    oConfig:SetPath("/"..sSection);
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

local function readValue(oConfig, sSection, sValue)
    selectSection(oConfig, sSection);

    local bFound, sRaw = oConfig:Read(sValue, "");

    return bFound and sRaw or "";
end

-- Return the resolved string and the visited reference sections, in order.
-- Missing values, empty references, and cycles resolve to an empty string.
function INI.GetValue(pFile, sSection, sValue, bInherit)
    validateName(sValue, "Value name");

    return withFile(pFile, function(oConfig)
        local tVisited = {};
        local tChain = nil;
        local sCurrent = sSection;

        while (true) do
            if (tVisited[sCurrent]) then
                return "", tChain;
            end

            tVisited[sCurrent] = true;

            local sRaw = readValue(oConfig, sCurrent, sValue);

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

function INI.GetValueBoolean(pFile, sSection, sValue, bInherit)
    local sRaw = INI.GetValue(pFile, sSection, sValue, bInherit);

    return sRaw:lower() == "true";
end

function INI.GetValueNumber(pFile, sSection, sValue, nDefault, bInherit)
    local sRaw = INI.GetValue(pFile, sSection, sValue, bInherit);
    local nFallback = type(nDefault) == "number" and nDefault or 0;

    return tonumber(sRaw) or nFallback;
end

-- On a cycle, match the archived extension: write at the repeated section.
function INI.SetValue(pFile, sSection, sValue, sData, bRespectChain)
    validateName(sValue, "Value name");
    assert(type(sData) == "string", "INI data must be a string.");

    return withFile(pFile, function(oConfig)
        local sCurrent = sSection;
        local tVisited = {};

        while (bRespectChain and sCurrent ~= "" and not tVisited[sCurrent]) do
            tVisited[sCurrent] = true;

            local sReference = reference(readValue(oConfig, sCurrent, sValue));

            if (sReference == nil or sReference == "") then
                break;
            end

            sCurrent = sReference;
        end

        selectSection(oConfig, sCurrent);
        assert(oConfig:Write(sValue, sData), "Could not write INI value.");
        assert(oConfig:Flush(), "Could not save INI file.");

        return true;
    end);
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

function INI.GetSectionNames(pFile)
    return withFile(pFile, function(oConfig)
        oConfig:SetPath("/");

        return enumerate(oConfig, true);
    end);
end

function INI.GetValueNames(pFile, sSection)
    return withFile(pFile, function(oConfig)
        selectSection(oConfig, sSection);

        return enumerate(oConfig, false);
    end);
end

function INI.DeleteValue(pFile, sSection, sValue)
    validateName(sValue, "Value name");

    return withFile(pFile, function(oConfig)
        selectSection(oConfig, sSection);

        local bDeleted = oConfig:DeleteEntry(sValue, false);
        assert(oConfig:Flush(), "Could not save INI file.");

        return bDeleted;
    end);
end

function INI.DeleteSection(pFile, sSection)
    validateName(sSection, "Section name");

    return withFile(pFile, function(oConfig)
        oConfig:SetPath("/");

        local bDeleted = oConfig:DeleteGroup(sSection);
        assert(oConfig:Flush(), "Could not save INI file.");

        return bDeleted;
    end);
end

return INI;
