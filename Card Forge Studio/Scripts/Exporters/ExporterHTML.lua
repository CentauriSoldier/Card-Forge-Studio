local Exporter = require("Exporter");
local PNG      = require("Exporters.ExporterPNG");
local Settings = require("Exporters.Settings");
local Data     = require("Exporters.Data");
local Document = require("Exporters.HTML.Document");
local ipairs   = ipairs;
local HTML     = {};

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterHTML
@desc Exports a themed, offline card gallery with search, column/value filters, name sorting, front/back switching, enlarged viewing, and finalized card details. Twenty output themes are selectable independently of API documentation. The output is index.html, gallery.css, gallery.js, and local PNG artwork; keep those files together. Faces, scale, theme, title, and destination save per card set. Existing files are never overwritten.
@note Final data follows the processor’s text contract. Code columns export their displayed COMPILED or ERROR status, not executable return values. JSON and Lua preserve values as strings and include source-row identifiers.
!]]

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterHTML.Functions.load
@pulsarlua function ExporterHTML.load
@desc Reads the card set's gallery options.
@param string pInfo Card-set INI.
@return table tOptions Settings.
!]]
function HTML.load(pInfo) return Settings.load("HTML", pInfo); end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterHTML.Functions.model
@pulsarlua function ExporterHTML.model
@desc Creates a transactional gallery-settings model.
@param string pInfo Card-set INI.
@return table tModel Draft and saveOptions.
!]]
function HTML.model(pInfo) return Settings.model("HTML", pInfo); end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterHTML.Functions.plan
@pulsarlua function ExporterHTML.plan
@desc Plans selected PNG faces plus a themed gallery using an independent snapshot of finalized values.
@param table tRows Source rows.
@param table tOptions Settings.
@param table tNames Card names.
@param number nTotal Source-row count.
@param number nWidth Native width.
@param number nHeight Native height.
@param table tContext Ordered headers and final data.
@return table tPlan Output records.
!]]
function HTML.plan(tRows, tOptions, tNames, nTotal, nWidth, nHeight, tContext)
    local tData = Data.snapshot(tRows, tContext);
    local nOutputWidth, nOutputHeight = PNG.dimensions(nWidth, nHeight, tOptions.scale);
    local tPlan = PNG.plan(tRows, tOptions, tNames, nTotal);
    for _, tFile in ipairs(Document.build(tData, tPlan, tOptions, tNames, nOutputWidth, nOutputHeight)) do tPlan[#tPlan + 1] = tFile; end
    return tPlan;
end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterHTML.Functions.render
@pulsarlua function ExporterHTML.render
@desc Delegates artwork to the existing isolated PNG renderer.
@param string sFace Card face.
@param string pFile Staged PNG.
@param number nScale Percentage.
!]]
function HTML.render(sFace, pFile, nScale) PNG.render(sFace, pFile, nScale); end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterHTML.Functions.run
@pulsarlua function ExporterHTML.run
@desc Produces all assets through the shared transaction coordinator. A failure removes this job's files and never overwrites existing output.
@param string pDirectory Destination.
@param table tPlan Output plan.
@param function fRender Row/face renderer.
@param function|nil fProgress Progress callback.
@return number nCount Committed file count.
!]]
function HTML.run(pDirectory, tPlan, fRender, fProgress)
    return Exporter.run(pDirectory, tPlan, function(tFile, pStage)
        if (tFile.bytes) then Data.write(pStage, tFile.bytes);
        else fRender(tFile.row, tFile.face, pStage); end
    end, fProgress);
end
return HTML;
