local Exporter = require("Exporter");
local Settings = require("Exporters.Settings");
local Data     = require("Exporters.Data");
local CSV   = {};

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterCSV
@desc Exports finalized card values as CSV, preserving ordered columns and requested source-row order. Values remain text, including leading zeroes. Export All, Visible, and Selected use the same workflow. Existing destination files are never overwritten; this does not change the saved source CSV or include executable game scripts.
@note CSV uses comma-separated, quoted UTF-8 fields with CRLF records. Final data follows the processor’s text contract. Code columns export their displayed COMPILED or ERROR status, not executable return values. JSON and Lua preserve values as strings and include source-row identifiers.
!]]

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterCSV.Functions.load
@pulsarlua function ExporterCSV.load
@desc Reads this card set's independent format settings.
@param string pInfo Card-set INI.
@return table tOptions Settings.
!]]
function CSV.load(pInfo) return Settings.load("CSV", pInfo); end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterCSV.Functions.model
@pulsarlua function ExporterCSV.model
@desc Creates settings with transactional saveOptions, preserving unrelated metadata.
@param string pInfo Card-set INI.
@return table tModel Draft options and save operation.
!]]
function CSV.model(pInfo) return Settings.model("CSV", pInfo); end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterCSV.Functions.plan
@pulsarlua function ExporterCSV.plan
@desc Snapshots finalized rows and produces one cards.csv output record. Context supplies ordered headers and final rows; image arguments are unused.
@param table tRows Requested source rows.
@param table tOptions Settings.
@param table tNames Card names.
@param number nTotal Source-row count.
@param number nWidth Native card width.
@param number nHeight Native card height.
@param table tContext Finalized data context.
@return table tPlan Ordered output plan.
!]]
function CSV.plan(tRows, tOptions, tNames, nTotal, nWidth, nHeight, tContext)
    return {{name = "cards.csv", bytes = Data.csv(Data.snapshot(tRows, tContext), tOptions)}};
end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterCSV.Functions.run
@pulsarlua function ExporterCSV.run
@desc Writes the snapshotted text through staged output commits with collision protection and rollback. No artwork rendering is requested.
@param string pDirectory Destination.
@param table tPlan Output plan.
@param function|nil fRender Unused image callback.
@param function|nil fProgress Progress callback.
@return number nCount Committed file count.
!]]
function CSV.run(pDirectory, tPlan, fRender, fProgress)
    return Exporter.run(pDirectory, tPlan, function(tFile, pStage) Data.write(pStage, tFile.bytes); end, fProgress);
end
return CSV;
