local wx        = require("wx");
local Common    = require("Windows.Editors.Common");
local assert    = assert;
local ipairs    = ipairs;
local pairs     = pairs;
local math      = math;
local table     = table;
local tonumber  = tonumber;
local tostring  = tostring;
local type      = type;
local INIFile   = INIFile;
--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Settings
@desc Stores independent atlas options and the selected grid exporter in the card-set metadata. Saves preserve other sections and reject external changes.
@vis private
!]]
local Settings  = {};
local tFormats  = {PNG = true, Atlas = true, CSV = true, JSON = true, Lua = true, HTML = true, Zip = true};
local tDefaults = {
    type      = "Atlas",
    sides     = "fronts",
    backs     = "shared",
    backRow   = 0,
    scale     = 100,
    directory = "",
    target    = "Generic_1",
    pageWidth = 2048,
    pageHeight = 2048,
    padding   = 2,
    selected  = "PNG",
};
local tKeys = {
    type      = "Type",
    sides     = "Sides",
    backs     = "Backs",
    backRow   = "BackRow",
    scale     = "ScalePercent",
    directory = "LastExportFolder",
    target    = "Target",
    pageWidth = "PageWidth",
    pageHeight = "PageHeight",
    padding   = "Padding",
    selected  = "SelectedExporter",
};
--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Settings.Functions.load
@desc Reads this card set's atlas options and normalizes missing or invalid values.
@param string pInfo Card-set metadata INI path.
@return table tOptions Normalized atlas settings.
!]]
function Settings.load(pInfo)
    local tResult = {};
    for sKey, vDefault in pairs(tDefaults) do
        local sValue = INIFile.GetValue(pInfo, "Export.Atlas", tKeys[sKey]);
        tResult[sKey] = sValue ~= "" and sValue or vDefault;
    end
    tResult.type = "Atlas";
    if (tResult.sides ~= "fronts" and tResult.sides ~= "both" and tResult.sides ~= "backs") then tResult.sides = "fronts"; end
    if (tResult.backs ~= "shared" and tResult.backs ~= "individual") then tResult.backs = "shared"; end
    tResult.backRow = tonumber(tResult.backRow) or 0;
    if (tResult.backRow < 0 or tResult.backRow ~= math.floor(tResult.backRow)) then tResult.backRow = 0; end
    tResult.scale = tonumber(tResult.scale) or 100;
    if (tResult.scale < 1 or tResult.scale > 1000 or tResult.scale ~= math.floor(tResult.scale)) then tResult.scale = 100; end
    if (tResult.target ~= "Generic_1" and tResult.target ~= "Love_11_5") then tResult.target = "Generic_1"; end
    if (not tFormats[tResult.selected]) then tResult.selected = "PNG"; end
    for _, sKey in ipairs({"pageWidth", "pageHeight", "padding"}) do
        local nValue = tonumber(tResult[sKey]);
        local nMinimum, nMaximum = sKey == "padding" and 1 or 64, sKey == "padding" and 32 or 8192;
        tResult[sKey] = nValue and nValue == math.floor(nValue) and nValue >= nMinimum and nValue <= nMaximum and nValue or tDefaults[sKey];
    end
    if (tResult.pageWidth * tResult.pageHeight > 64000000) then
        tResult.pageWidth, tResult.pageHeight = tDefaults.pageWidth, tDefaults.pageHeight;
    end
    return tResult;
end
--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Settings.Functions.model
@desc Creates a transactional atlas settings model which preserves unrelated INI metadata.
@param string pInfo Card-set metadata INI path.
@return table tModel Draft settings and saveOptions method.
!]]
function Settings.model(pInfo)
    local tModel = Common.model({{path = pInfo, name = "Card-set export options", kind = "ini"}});
    local tValues = Settings.load(pInfo);
    --[[!
    @fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Settings.Functions.model.saveOptions
    @desc Validates atlas options and saves only their INI section, retaining metadata and the remembered export folder.
    @param table tNew atlas options to persist.
    @note Rejects external file changes and uses staged replacement with rollback.
    !]]
    function tModel.saveOptions(tNew)
        tNew.directory = tNew.directory or tValues.directory;
        assert(type(tNew.directory) == "string" and not tNew.directory:find("[\r\n]"), "Invalid export folder.");
        tNew.scale = tNew.scale or 100;
        assert(type(tNew.scale) == "number" and tNew.scale >= 1 and tNew.scale <= 1000 and tNew.scale == math.floor(tNew.scale), "Export size must be a whole percentage from 1 to 1000.");
        assert(tNew.type == "Atlas" and (tNew.sides == "fronts" or tNew.sides == "both" or tNew.sides == "backs"), "Invalid export format or sides.");
        assert(tNew.backs == "shared" or tNew.backs == "individual", "Invalid back mode.");
        assert(type(tNew.backRow) == "number" and tNew.backRow >= 0 and tNew.backRow == math.floor(tNew.backRow), "Invalid shared-back row.");
        assert(tNew.target == "Generic_1" or tNew.target == "Love_11_5", "Unsupported atlas target version.");
        assert(tFormats[tNew.selected], "Invalid selected exporter.");
        for _, sKey in ipairs({"pageWidth", "pageHeight", "padding"}) do
            local nValue = tNew[sKey];
            local nMinimum, nMaximum = sKey == "padding" and 1 or 64, sKey == "padding" and 32 or 8192;
            assert(type(nValue) == "number" and nValue == math.floor(nValue) and nValue >= nMinimum and nValue <= nMaximum, "Invalid atlas "..sKey..".");
        end
        assert(tNew.pageWidth * tNew.pageHeight <= 64000000, "Atlas page exceeds 64 million pixels.");
        local sText = tModel.files[1].original;
        local sNewline = sText:find("\r\n", 1, true) and "\r\n" or "\n";
        local tLines, tSeen, bSection, bFound = {}, {}, false, false;
        -- Complete only this exporter section; preserve metadata and other format sections.
        --[[!
        @fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Settings.Private.Functions.missing
        @desc Appends absent atlas export-setting keys to the current metadata section.
        @vis private
        !]]
        local function missing()
            for _, sKey in ipairs({"type", "sides", "backs", "backRow", "scale", "directory", "target", "pageWidth", "pageHeight", "padding", "selected"}) do
                if (not tSeen[sKey]) then tLines[#tLines + 1] = tKeys[sKey].."="..tostring(tNew[sKey]); tSeen[sKey] = true; end
            end
        end
        local sSource = sText:gsub("\r\n", "\n");
        if (sSource:sub(-1) ~= "\n") then sSource = sSource.."\n"; end
        for sLine in sSource:gmatch("(.-)\n") do
            local sSection = sLine:match("^%s*%[([^%]]+)%]%s*$");
            if (sSection) then
                if (bSection) then missing(); end
                bSection = sSection:lower() == "export.atlas"; bFound = bFound or bSection;
            end
            if (bSection) then
                local sName = sLine:match("^%s*([^=;#]+)%s*=");
                if (sName) then
                    sName = sName:match("^%s*(.-)%s*$"):lower();
                    for sKey, sINIKey in pairs(tKeys) do
                        if (sName == sINIKey:lower()) then sLine = sINIKey.."="..tostring(tNew[sKey]); tSeen[sKey] = true; end
                    end
                end
            end
            tLines[#tLines + 1] = sLine;
        end
        if (not bFound) then tLines[#tLines + 1] = "[Export.Atlas]"; bSection = true; end
        if (bSection) then missing(); end
        -- Commit through the shared source model for conflict checks and rollback.
        tModel.files[1].text = table.concat(tLines, sNewline)..sNewline;
        tModel.save();
        for sKey, vValue in pairs(tNew) do tValues[sKey] = vValue; end
    end
    tModel.options = tValues;
    return tModel;
end

return Settings;
