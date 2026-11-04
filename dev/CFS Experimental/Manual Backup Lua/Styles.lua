-- Read-only game styles and manual-only inheritance; game definitions remain authoritative.
local StyleEditor = require("Windows.StyleEditor");
local Styles = {};

local function copy(tValue)
    if (rawtype(tValue) ~= "table") then return tValue; end
    local tResult = {};
    for sKey, vValue in pairs(tValue) do tResult[sKey] = copy(vValue); end
    return tResult;
end
Styles.copy = copy;

function Styles.open(pFile)
    local tSource = StyleEditor.model(pFile);
    local tCache = {};
    local tReader = {names = copy(tSource.names), path = pFile};
    function tReader.game(sName)
        assert(tSource.sections[sName], "Unknown game style: "..tostring(sName));
        if (not tCache[sName]) then tCache[sName] = assert(tSource.parsed(sName), "Cannot resolve game style: "..sName); end
        return copy(tCache[sName]);
    end
    function tReader.resolve(sName, tManualStyles, nTextSize, tOverrides)
        local tSeen, tValues = {}, {};
        local function inherit(sCurrent)
            assert(rawtype(sCurrent) == "string", "A manual style needs an inheritance parent.");
            if (sCurrent:sub(1, 7) ~= "manual:") then return tReader.game(sCurrent); end
            assert(not tSeen[sCurrent], "Manual style inheritance is circular."); tSeen[sCurrent] = true;
            local tStyle;
            for _, tCandidate in ipairs(tManualStyles or {}) do if ("manual:"..tCandidate.name == sCurrent) then tStyle = tCandidate; break; end end
            assert(tStyle, "Unknown manual style: "..sCurrent);
            local tParsed = inherit(tStyle.parent);
            for _, sKey in ipairs({"size", "bold", "italic", "underline"}) do
                if (tStyle[sKey] ~= nil) then
                    if (sKey == "size") then assert(rawtype(tStyle[sKey]) == "number" and tStyle[sKey] > 0 and tStyle[sKey] < math.huge, "Manual font size must be positive.");
                    else assert(rawtype(tStyle[sKey]) == "boolean", "Invalid manual style override: "..sKey); end
                    tValues[sKey] = tStyle[sKey];
                end
            end
            return tParsed;
        end
        local tParsed = inherit(sName or "BASE");
        local nSize = tValues.size or nTextSize or tParsed.FontSize;
        assert(rawtype(nSize) == "number" and nSize > 0 and nSize < math.huge, "Text size must be positive.");
        for _, tFlag in ipairs({{"bold", "Bold"}, {"italic", "Italic"}, {"underline", "Underline"}}) do
            if (tValues[tFlag[1]] ~= nil) then tParsed.FontOptions[tFlag[2]] = tValues[tFlag[1]]; end
        end
        tOverrides = tOverrides or {};
        if (tOverrides.fontFamily) then tParsed.FontFamily = tOverrides.fontFamily; end
        if (tOverrides.color) then tParsed.FontColor = tOverrides.color; end
        for _, sKey in ipairs({"Bold", "Italic", "Underline", "StrikeOut"}) do if (tOverrides[sKey] ~= nil) then tParsed.FontOptions[sKey] = tOverrides[sKey]; end end
        return {parsed = tParsed, size = nSize, scale = nSize / tParsed.FontSize, name = sName};
    end
    function tReader.refresh()
        local oFile = assert(io.open(pFile, "rb")); local sText = oFile:read("a"); oFile:close();
        if (sText == tSource.original) then return false; end
        tSource = StyleEditor.model(pFile); tReader.names = copy(tSource.names); tCache = {}; return true;
    end
    return tReader;
end

return Styles;
