local Common   = require("Windows.Editors.Common");
local Themes   = require("Exporters.HTML.Themes");
local INIFile  = INIFile;
local assert   = assert;
local ipairs   = ipairs;
local pairs    = pairs;
local math     = math;
local rawtype  = rawtype or type;
local table    = table;
local tonumber = tonumber;
local tostring = tostring;
local utf8     = utf8;
local Settings = {};

--[[!
@fqxn CFS.Modules.Exporter.Support.Settings
@desc Independent per-card-set settings for finalized-data, HTML, and ZIP exports. Writes use the editor transaction model to preserve unrelated INI sections and reject concurrent edits.
@vis private
!]]
local tFormats = {CSV = true, JSON = true, Lua = true, HTML = true, Zip = true};

--[[!
@fqxn CFS.Modules.Exporter.Support.Settings.Functions.defaults
@desc Defines saved fields for one supported format.
@param string sType Format.
@return table tDefaults Defaults.
@vis private
!]]
function Settings.defaults(sType)
    assert(tFormats[sType], "Unsupported export settings type.");
    local tDefaults = {type = sType, directory = ""};
    if (sType == "CSV") then tDefaults.headers, tDefaults.bom = true, false; end
    if (sType == "HTML" or sType == "Zip") then
        tDefaults.scale, tDefaults.sides, tDefaults.backs, tDefaults.backRow = 100, "both", "shared", 0;
        tDefaults.theme, tDefaults.title = "midnight_blue", "Card Gallery";
    end
    if (sType == "Zip") then tDefaults.images, tDefaults.data, tDefaults.gallery = true, true, true; end
    return tDefaults;
end

--[[!
@fqxn CFS.Modules.Exporter.Support.Settings.Functions.load
@desc Loads saved choices and substitutes defaults for invalid settings.
@param string sType Format.
@param string pInfo Card-set INI.
@return table tValues Settings.
@vis private
!]]
function Settings.load(sType, pInfo)
    local tValues = Settings.defaults(sType);
    for sKey, vDefault in pairs(tValues) do
        local sValue = INIFile.GetValue(pInfo, "Export."..sType, sKey);
        if (sValue ~= "") then
            if (rawtype(vDefault) == "boolean") then
                if (sValue == "true" or sValue == "false") then tValues[sKey] = sValue == "true"; end
            elseif (rawtype(vDefault) == "number") then tValues[sKey] = tonumber(sValue) or vDefault;
            else tValues[sKey] = sValue; end
        end
    end
    tValues.type = sType;
    if (tValues.scale and (tValues.scale < 1 or tValues.scale > 1000 or tValues.scale ~= math.floor(tValues.scale))) then tValues.scale = 100; end
    if (tValues.backRow and (tValues.backRow < 0 or tValues.backRow ~= math.floor(tValues.backRow))) then tValues.backRow = 0; end
    if (tValues.sides and tValues.sides ~= "fronts" and tValues.sides ~= "backs" and tValues.sides ~= "both") then tValues.sides = "both"; end
    if (tValues.backs and tValues.backs ~= "shared" and tValues.backs ~= "individual") then tValues.backs = "shared"; end
    if (tValues.theme and not Themes[tValues.theme]) then tValues.theme = "midnight_blue"; end
    if (tValues.title and (not utf8.len(tValues.title) or tValues.title:find("[%z\r\n]") or #tValues.title > 160 or tValues.title == "")) then tValues.title = "Card Gallery"; end
    if (tValues.directory:find("[%z\r\n]")) then tValues.directory = ""; end
    if (sType == "Zip" and not (tValues.images or tValues.data or tValues.gallery)) then tValues.images = true; end
    return tValues;
end

--[[!
@fqxn CFS.Modules.Exporter.Support.Settings.Functions.model
@desc Creates a transactional settings model. Missing fields retain the current draft; only fields owned by this format are written.
@param string sType Format.
@param string pInfo Card-set INI.
@return table tModel Settings and saveOptions operation.
@vis private
!]]
function Settings.model(sType, pInfo)
    local tModel = Common.model({{path = pInfo, name = "Card-set export options", kind = "ini"}});
    local tValues, tDefaults, tOrder = Settings.load(sType, pInfo), Settings.defaults(sType), {};
    for sKey in pairs(tDefaults) do tOrder[#tOrder + 1] = sKey; end; table.sort(tOrder);
    --[[!
    @fqxn CFS.Modules.Exporter.Support.Settings.Private.Functions.saveOptions
    @desc Validates the draft fields and commits only this format’s INI section through conflict-checked staged replacement.
    @vis private
    !]]
    function tModel.saveOptions(tInput)
        local tNew = {};
        for sKey, vDefault in pairs(tDefaults) do
            local vValue = tInput[sKey]; if (vValue == nil) then vValue = tValues[sKey]; end
            assert(rawtype(vValue) == rawtype(vDefault), "Invalid export setting: "..sKey);
            if (rawtype(vValue) == "string") then assert(not vValue:find("[%z\r\n]"), "Invalid export setting: "..sKey); end
            tNew[sKey] = vValue;
        end
        assert(tNew.type == sType, "Invalid export format.");
        if (tNew.scale) then
            assert(tNew.scale >= 1 and tNew.scale <= 1000 and tNew.scale == math.floor(tNew.scale), "Invalid output scale.");
            assert(tNew.backRow >= 0 and tNew.backRow == math.floor(tNew.backRow), "Invalid shared-back row.");
            assert(tNew.sides == "fronts" or tNew.sides == "backs" or tNew.sides == "both", "Invalid output sides.");
            assert(tNew.backs == "shared" or tNew.backs == "individual", "Invalid back mode.");
            assert(Themes[tNew.theme], "Invalid HTML theme.");
            assert(utf8.len(tNew.title) and tNew.title ~= "" and #tNew.title <= 160, "Gallery title must contain 1 to 160 bytes.");
        end
        if (sType == "Zip") then assert(tNew.images or tNew.data or tNew.gallery, "Select at least one package content type."); end
        local sText = tModel.files[1].original;
        local sNewline = sText:find("\r\n", 1, true) and "\r\n" or "\n";
        local tLines, tSeen, bSection, bFound = {}, {}, false, false;
        -- Complete only this exporter section; preserve metadata and other format sections.
        --[[!
        @fqxn CFS.Modules.Exporter.Support.Settings.Private.Functions.missing
        @desc Appends absent format export-setting keys to the current metadata section.
        @vis private
        !]]
        local function missing()
            for _, sKey in ipairs(tOrder) do
                if (not tSeen[sKey]) then tLines[#tLines + 1] = sKey.."="..tostring(tNew[sKey]); tSeen[sKey] = true; end
            end
        end
        local sSource = sText:gsub("\r\n", "\n");
        if (sSource:sub(-1) ~= "\n") then sSource = sSource.."\n"; end
        for sLine in sSource:gmatch("(.-)\n") do
            local sSection = sLine:match("^%s*%[([^%]]+)%]%s*$");
            if (sSection) then
                if (bSection) then missing(); end
                bSection = sSection:lower() == "export."..sType:lower(); bFound = bFound or bSection;
            end
            if (bSection) then
                local sName = sLine:match("^%s*([^=;#]+)%s*=");
                if (sName) then
                    sName = sName:match("^%s*(.-)%s*$"):lower();
                    for sKey in pairs(tDefaults) do
                        if (sName == sKey:lower()) then sLine = sKey.."="..tostring(tNew[sKey]); tSeen[sKey] = true; end
                    end
                end
            end
            tLines[#tLines + 1] = sLine;
        end
        if (not bFound) then tLines[#tLines + 1] = "[Export."..sType.."]"; bSection = true; end
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
