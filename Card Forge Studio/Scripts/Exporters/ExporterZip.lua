local wx       = require("wx");
local Exporter = require("Exporter");
local PNG      = require("Exporters.ExporterPNG");
local Settings = require("Exporters.Settings");
local Data     = require("Exporters.Data");
local Document = require("Exporters.HTML.Document");
local Archive  = require("Exporters.Zip.Archive");
local assert   = assert;
local error    = error;
local ipairs   = ipairs;
local os       = os;
local xpcall   = xpcall;
local debug    = debug;
local Zip      = {};

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterZip
@desc Packages selected cards into cards.zip. Choose PNG artwork, finalized CSV/JSON/Lua data, and a themed interactive HTML gallery. The gallery includes its required artwork. Only generated output is bundled: source scripts, personal game files, and machine paths are not collected. Extract the archive and open index.html when gallery content is selected. ZIP files use stored entries; PNG images are already compressed. ZIP64 and archives of 4 GiB or more are not supported.
@note Final data follows the processor’s text contract. Code columns export their displayed COMPILED or ERROR status, not executable return values. JSON and Lua preserve values as strings and include source-row identifiers.
!]]

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterZip.Functions.load
@pulsarlua function ExporterZip.load
@desc Reads independent package options for this card set.
@param string pInfo Card-set INI.
@return table tOptions Settings.
!]]
function Zip.load(pInfo) return Settings.load("Zip", pInfo); end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterZip.Functions.model
@pulsarlua function ExporterZip.model
@desc Creates a transactional package-settings model.
@param string pInfo Card-set INI.
@return table tModel Draft and saveOptions.
!]]
function Zip.model(pInfo) return Settings.model("Zip", pInfo); end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterZip.Functions.plan
@pulsarlua function ExporterZip.plan
@desc Snapshots selected final values and plans only the requested generated package contents. Gallery artwork is included once even when both images and gallery are selected.
@param table tRows Source rows.
@param table tOptions Package choices.
@param table tNames Card names.
@param number nTotal Source-row count.
@param number nWidth Native width.
@param number nHeight Native height.
@param table tContext Headers and final rows.
@return table tPlan One archive output record.
!]]
function Zip.plan(tRows, tOptions, tNames, nTotal, nWidth, nHeight, tContext)
    assert(tOptions.images or tOptions.data or tOptions.gallery, "Select at least one package content type.");
    local tData = Data.snapshot(tRows, tContext); local tEntries = {};
    if (tOptions.images or tOptions.gallery) then
        PNG.dimensions(nWidth, nHeight, tOptions.scale);
        for _, tFile in ipairs(PNG.plan(tRows, tOptions, tNames, nTotal)) do tEntries[#tEntries + 1] = tFile; end
    end
    if (tOptions.gallery) then
        local nOutputWidth, nOutputHeight = PNG.dimensions(nWidth, nHeight, tOptions.scale);
        for _, tFile in ipairs(Document.build(tData, tEntries, tOptions, tNames, nOutputWidth, nOutputHeight)) do tEntries[#tEntries + 1] = tFile; end
    end
    if (tOptions.data) then
        tEntries[#tEntries + 1] = {name = "cards.csv", bytes = Data.csv(tData, {headers = true})};
        tEntries[#tEntries + 1] = {name = "cards.json", bytes = Data.json(tData)};
        tEntries[#tEntries + 1] = {name = "cards.lua", bytes = Data.lua(tData)};
    end
    tEntries[#tEntries + 1] = {name = "README.txt", bytes = "Card Forge Studio card export\r\n\r\nExtract the archive before opening its files. If included, index.html is an offline interactive gallery; keep its PNG, CSS, and JavaScript files together.\r\nData files contain finalized text values in ordered columns and the requested card order. JSON and Lua use CFS Card Data format version 1 with source-row identifiers. CSV has a header.\r\nNo source scripts or original game files are included.\r\n"};
    return {{name = "cards.zip", entries = tEntries}};
end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterZip.Functions.render
@pulsarlua function ExporterZip.render
@desc Renders requested package artwork through the isolated PNG renderer.
@param string sFace Face.
@param string pFile Temporary PNG.
@param number nScale Percentage.
!]]
function Zip.render(sFace, pFile, nScale) PNG.render(sFace, pFile, nScale); end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterZip.Functions.run
@pulsarlua function ExporterZip.run
@desc Streams generated entries to one staged ZIP. Temporary artwork is removed on success and failure; final output is committed only after archive completion.
@param string pDirectory Destination.
@param table tPlan Archive plan.
@param function fRender Artwork callback.
@param function|nil fProgress Progress.
@return number nCount Committed archive count.
!]]
function Zip.run(pDirectory, tPlan, fRender, fProgress)
    return Exporter.run(pDirectory, tPlan, function(tFile, pStage)
        local pTemporary;
        local bOK, sError = xpcall(function()
            Archive.write(pStage, tFile.entries, function(tEntry)
                if (tEntry.bytes) then return tEntry.bytes; end
                if (not pTemporary) then
                    local oFile = wx.wxFile(); pTemporary = wx.wxFileName.CreateTempFileName(wx.wxFileName.GetTempDir().."/cfs-package-", oFile);
                    if (oFile:IsOpened()) then oFile:Close(); end; oFile:delete();
                    assert(pTemporary ~= "", "Could not stage package artwork.");
                end
                fRender(tEntry.row, tEntry.face, pTemporary);
                return nil, pTemporary;
            end, fProgress);
        end, debug.traceback);
        if (pTemporary) then os.remove(pTemporary); end
        if (not bOK) then error(sError, 0); end
    end, fProgress);
end
return Zip;
