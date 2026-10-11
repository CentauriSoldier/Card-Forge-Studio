local Exporter = require("Exporter");
local Settings = require("Exporters.Settings");
local Data     = require("Exporters.Data");
local JSON   = {};

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterJSON
@desc Exports finalized card values as JSON, preserving ordered columns and requested source-row order. Values remain text, including leading zeroes. Export All, Visible, and Selected use the same workflow. Existing destination files are never overwritten; this does not change the saved source CSV or include executable game scripts.
@note Final data follows the processor’s text contract. Code columns export their displayed COMPILED or ERROR status, not executable return values. JSON and Lua preserve values as strings and include source-row identifiers.
!]]

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterJSON.Functions.load
@pulsarlua function ExporterJSON.load
@desc Reads this card set's independent format settings.
@param string pInfo Card-set INI.
@return table tOptions Settings.
!]]
function JSON.load(pInfo) return Settings.load("JSON", pInfo); end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterJSON.Functions.model
@pulsarlua function ExporterJSON.model
@desc Creates settings with transactional saveOptions, preserving unrelated metadata.
@param string pInfo Card-set INI.
@return table tModel Draft options and save operation.
!]]
function JSON.model(pInfo) return Settings.model("JSON", pInfo); end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterJSON.Functions.plan
@pulsarlua function ExporterJSON.plan
@desc Snapshots finalized rows and produces one cards.json output record. Context supplies ordered headers and final rows; image arguments are unused.
@param table tRows Requested source rows.
@param table tOptions Settings.
@param table tNames Card names.
@param number nTotal Source-row count.
@param number nWidth Native card width.
@param number nHeight Native card height.
@param table tContext Finalized data context.
@return table tPlan Ordered output plan.
!]]
function JSON.plan(tRows, tOptions, tNames, nTotal, nWidth, nHeight, tContext)
    return {{name = "cards.json", bytes = Data.json(Data.snapshot(tRows, tContext), tOptions)}};
end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterJSON.Functions.run
@pulsarlua function ExporterJSON.run
@desc Writes the snapshotted text through staged output commits with collision protection and rollback. No artwork rendering is requested.
@param string pDirectory Destination.
@param table tPlan Output plan.
@param function|nil fRender Unused image callback.
@param function|nil fProgress Progress callback.
@return number nCount Committed file count.
!]]
function JSON.run(pDirectory, tPlan, fRender, fProgress)
    return Exporter.run(pDirectory, tPlan, function(tFile, pStage) Data.write(pStage, tFile.bytes); end, fProgress);
end
return JSON;
