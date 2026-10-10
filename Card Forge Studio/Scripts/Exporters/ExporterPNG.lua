--[[!
@fqxn CFS.Modules.ExporterPNG
@desc PNG options, percentage limits, face planning, remembered destinations, and rendering adapter.
!]]

-- PNG export settings, output planning, and rendering adapter.
local wx = require("wx");
local Common = require("Windows.Editors.Common");
local Exporter = require("Exporter");
local ExporterPNG  = {};
local tDefaults = {
    type      = "PNG",
    sides     = "fronts",
    backs     = "shared",
    backRow   = 0,
    scale     = 100,
    directory = "",
};
local tKeys = {
    type      = "Type",
    sides     = "Sides",
    backs     = "Backs",
    backRow   = "BackRow",
    scale     = "ScalePercent",
    directory = "LastExportFolder",
};
--[[!
@fqxn CFS.Modules.ExporterPNG.load
@pulsarlua function ExporterPNG.load
@desc Reads this card set's PNG options and normalizes missing or invalid values.
@param string pInfo Card-set metadata INI path.
@return table tOptions Normalized PNG settings.
!]]
function ExporterPNG.load(pInfo)
    local tResult = {};
    for sKey, vDefault in pairs(tDefaults) do
        local sValue = INIFile.GetValue(pInfo, "Export.PNG", tKeys[sKey]);
        tResult[sKey] = sValue ~= "" and sValue or vDefault;
    end
    tResult.type = "PNG";
    if (tResult.sides ~= "fronts" and tResult.sides ~= "both" and tResult.sides ~= "backs") then tResult.sides = "fronts"; end
    if (tResult.backs ~= "shared" and tResult.backs ~= "individual") then tResult.backs = "shared"; end
    tResult.backRow = tonumber(tResult.backRow) or 0;
    if (tResult.backRow < 0 or tResult.backRow ~= math.floor(tResult.backRow)) then tResult.backRow = 0; end
    tResult.scale = tonumber(tResult.scale) or 100;
    if (tResult.scale < 1 or tResult.scale > 1000 or tResult.scale ~= math.floor(tResult.scale)) then tResult.scale = 100; end
    return tResult;
end
--[[!
@fqxn CFS.Modules.ExporterPNG.model
@pulsarlua function ExporterPNG.model
@desc Creates a transactional PNG settings model which preserves unrelated INI metadata.
@param string pInfo Card-set metadata INI path.
@return table tModel Draft settings and saveOptions method.
!]]
function ExporterPNG.model(pInfo)
    local tModel = Common.model({{path = pInfo, name = "Card-set export options", kind = "ini"}});
    local tValues = ExporterPNG.load(pInfo);
    --[[!
    @fqxn CFS.Modules.ExporterPNG.model.saveOptions
    @desc Validates PNG options and saves only their INI section, retaining metadata and the remembered export folder.
    @param table tNew PNG options to persist.
    @note Rejects external file changes and uses staged replacement with rollback.
    !]]
    function tModel.saveOptions(tNew)
        tNew.directory = tNew.directory or tValues.directory;
        assert(type(tNew.directory) == "string" and not tNew.directory:find("[\r\n]"), "Invalid export folder.");
        tNew.scale = tNew.scale or 100;
        assert(type(tNew.scale) == "number" and tNew.scale >= 1 and tNew.scale <= 1000 and tNew.scale == math.floor(tNew.scale), "Export size must be a whole percentage from 1 to 1000.");
        assert(tNew.type == "PNG" and (tNew.sides == "fronts" or tNew.sides == "both" or tNew.sides == "backs"), "Invalid export format or sides.");
        assert(tNew.backs == "shared" or tNew.backs == "individual", "Invalid back mode.");
        assert(type(tNew.backRow) == "number" and tNew.backRow >= 0 and tNew.backRow == math.floor(tNew.backRow), "Invalid shared-back row.");
        local sText = tModel.files[1].original;
        local sNewline = sText:find("\r\n", 1, true) and "\r\n" or "\n";
        local tLines, tSeen, bSection, bFound = {}, {}, false, false;
        -- Complete only this exporter section; preserve metadata and other format sections.
        --[[!
        @fqxn CFS.Modules.Exporters.ExporterPNG.Private.missing
        @desc Appends absent PNG export-setting keys to the current metadata section.
        @vis private
        !]]
        local function missing()
            for _, sKey in ipairs({"type", "sides", "backs", "backRow", "scale", "directory"}) do
                if (not tSeen[sKey]) then tLines[#tLines + 1] = tKeys[sKey].."="..tostring(tNew[sKey]); tSeen[sKey] = true; end
            end
        end
        local sSource = sText:gsub("\r\n", "\n");
        if (sSource:sub(-1) ~= "\n") then sSource = sSource.."\n"; end
        for sLine in sSource:gmatch("(.-)\n") do
            local sSection = sLine:match("^%s*%[([^%]]+)%]%s*$");
            if (sSection) then
                if (bSection) then missing(); end
                bSection = sSection:lower() == "export.png"; bFound = bFound or bSection;
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
        if (not bFound) then tLines[#tLines + 1] = "[Export.PNG]"; bSection = true; end
        if (bSection) then missing(); end
        -- Commit through the shared source model for conflict checks and rollback.
        tModel.files[1].text = table.concat(tLines, sNewline)..sNewline;
        tModel.save();
        for sKey, vValue in pairs(tNew) do tValues[sKey] = vValue; end
    end
    tModel.options = tValues;
    return tModel;
end
--[[!
@fqxn CFS.Modules.ExporterPNG.dimensions
@pulsarlua function ExporterPNG.dimensions
@desc Calculates scaled raster dimensions and enforces the percentage and pixel limits.
@param number nWidth Native card width.
@param number nHeight Native card height.
@param number nPercent Integer scale percentage from 1 through 1000.
@return number nWidth Output width.
@return number nHeight Output height.
!]]
function ExporterPNG.dimensions(nWidth, nHeight, nPercent)
    assert(type(nPercent) == "number" and nPercent >= 1 and nPercent <= 1000 and nPercent == math.floor(nPercent), "Export size must be a whole percentage from 1 to 1000.");
    local nOutputWidth = math.max(1, math.floor(nWidth * nPercent / 100 + 0.5));
    local nOutputHeight = math.max(1, math.floor(nHeight * nPercent / 100 + 0.5));
    assert(nOutputWidth * nOutputHeight <= 64000000, "Export exceeds 64 million pixels. Choose a smaller percentage.");
    return nOutputWidth, nOutputHeight;
end
--[[!
@fqxn CFS.Modules.ExporterPNG.plan
@pulsarlua function ExporterPNG.plan
@desc Builds ordered PNG filenames for selected fronts and shared or individual backs.
@param table tRows Source row identifiers.
@param table tOptions PNG settings.
@param table tNames Card names indexed by source row.
@param number nTotal Available source row count.
@return table tPlan Output records.
!]]
function ExporterPNG.plan(tRows, tOptions, tNames, nTotal)
    assert(#tRows > 0, "No cards to export.");
    local tPlan, tSeen = {}, {};
    --[[!
    @fqxn CFS.Modules.Exporters.ExporterPNG.Private.add
    @desc Validates a source row and appends its requested face to the PNG output plan.
    @param any nRow Row.
    @param any sFace Face.
    @param any bShared Shared.
    @vis private
    !]]
    local function add(nRow, sFace, bShared)
        assert(nRow >= 1 and nRow <= nTotal and nRow == math.floor(nRow), "Shared-back card is unavailable. Choose another row in Export Options.");
        local sName = tostring(tNames[nRow] or "Card"):gsub('[<>:"/\\|?*%c]', "_"):gsub('[ .]+$', "");
        if (#sName > 80) then sName = "Card"; end
        local sFile = bShared and "Shared_Back.png" or string.format("%04d_%s_%s.png", nRow, sName, sFace);
        tPlan[#tPlan + 1] = {row = nRow, face = sFace, name = sFile};
    end
    for _, nRow in ipairs(tRows) do
        assert(not tSeen[nRow], "Duplicate export row."); tSeen[nRow] = true;
        if (tOptions.sides ~= "backs") then add(nRow, "front"); end
        if (tOptions.sides ~= "fronts" and tOptions.backs == "individual") then add(nRow, "back"); end
    end
    if (tOptions.sides ~= "fronts" and tOptions.backs == "shared") then add(tOptions.backRow == 0 and tRows[1] or tOptions.backRow, "back", true); end
    return tPlan;
end
--[[!
@fqxn CFS.Modules.ExporterPNG.render
@pulsarlua function ExporterPNG.render
@desc Renders one card face as a PNG using Forge's isolated export drawing context.
@param string sFace Front or back.
@param string pFile Staged output path.
@param number nPercent Output scale percentage.
@note Forge redraws text and shapes at output resolution; source image detail remains unchanged.
!]]
function ExporterPNG.render(sFace, pFile, nPercent)
    require("Forge").ExportPNG(sFace, pFile, nPercent);
end

--[[!
@fqxn CFS.Modules.ExporterPNG.run
@pulsarlua function ExporterPNG.run
@desc Adapts PNG row and face records to the generic service's staged export job.
@param string pDirectory Destination folder.
@param table tPlan PNG output records.
@param function fRender Callback receiving row, face, and staged path.
@param function|nil fProgress Optional job progress callback.
@return number nCount Number of completed PNG files.
!]]
function ExporterPNG.run(pDirectory, tPlan, fRender, fProgress)
    return Exporter.run(pDirectory, tPlan, function(tFile, pStage)
        fRender(tFile.row, tFile.face, pStage);
    end, fProgress);
end

return ExporterPNG;
