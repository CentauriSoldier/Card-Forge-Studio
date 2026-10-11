--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterPNG
@desc
<section aria-label="PNG Export overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">PNG Export</h2><p style="font-size:1.15rem;margin:0">PNG export turns your finished card artwork into individual image files.</p></div>
<h3>How it fits into your work</h3><p>Choose the faces, percentage scale, destination, and export scope. The exporter plans the images and asks Forge to render them through the shared export coordinator.</p>
<h3>Follow the handoffs</h3><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,260px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">From cards to image files</h3><p style="margin:0">The PNG exporter plans the images needed for the selected cards, including the configured front and back behavior. It uses Forge to render the artwork at the requested size. The export coordinator handles the destination and staged file handoff; this format-specific component supplies the PNG work.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">Preview settings and output settings</h3><p style="margin:0">Export size changes the rendered image dimensions. Card-canvas preview colors are viewing aids and do not become the exported card background. Output naming and destination choices belong to the export workflow, while the drawing scripts determine the artwork itself. A collision or rendering error is a reason to stop the export, not silently replace an existing image.</p></article>
</div>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Exporter">Exporter</a></h3><p style="margin:0">The export coordinator turns a planned batch into finished output files.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Forge">Forge</a></h3><p style="margin:0">Forge is the visual workbench that turns selected card data and drawing instructions into artwork.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.ExportOptions">ExportOptions</a></h3><p style="margin:0">Export Options describes how the active set becomes PNG images.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.DataGrid">Data Grid</a></h3><p style="margin:0">The common grid supplies table controls for both data windows.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Options belong to the card set. The first destination defaults to the game's Exports folder; a saved destination takes precedence.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual functions, inputs, and results.</p>
</section>
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
@fqxn CFS.Modules.Exporter.Exporters.ExporterPNG.Functions.load
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
@fqxn CFS.Modules.Exporter.Exporters.ExporterPNG.Functions.model
@pulsarlua function ExporterPNG.model
@desc Creates a transactional PNG settings model which preserves unrelated INI metadata.
@param string pInfo Card-set metadata INI path.
@return table tModel Draft settings and saveOptions method.
!]]
function ExporterPNG.model(pInfo)
    local tModel = Common.model({{path = pInfo, name = "Card-set export options", kind = "ini"}});
    local tValues = ExporterPNG.load(pInfo);
    --[[!
    @fqxn CFS.Modules.Exporter.Exporters.ExporterPNG.Functions.model.saveOptions
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
        @fqxn CFS.Modules.Exporter.Exporters.ExporterPNG.Private.Functions.missing
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
@fqxn CFS.Modules.Exporter.Exporters.ExporterPNG.Functions.dimensions
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
@fqxn CFS.Modules.Exporter.Exporters.ExporterPNG.Functions.plan
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
    @fqxn CFS.Modules.Exporter.Exporters.ExporterPNG.Private.Functions.add
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
@fqxn CFS.Modules.Exporter.Exporters.ExporterPNG.Functions.render
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
@fqxn CFS.Modules.Exporter.Exporters.ExporterPNG.Functions.run
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
