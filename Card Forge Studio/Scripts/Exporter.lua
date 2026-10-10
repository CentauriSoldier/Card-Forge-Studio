--[[!
@fqxn CFS.Modules.Exporter
@desc Format lookup and safe staged export commits; format-specific behavior belongs to individual exporters.
!]]

-- Format-independent export lookup and staged file commit.
local wx            = require("wx");
local Exporter = {};


--[[!
@fqxn CFS.Modules.Exporter.get
@pulsarlua function Exporter.get
@desc Loads the dedicated exporter module for a requested format.
@param string sType Export format identifier matching an Exporter module suffix.
@return table tExporter The format's implementation.
@note Missing exporter modules raise an error; unfinished targets are not enabled automatically.
!]]
function Exporter.get(sType)
    assert(type(sType) == "string" and sType:match("^[%w_]+$"), "Invalid exporter identifier.");
    return require("Exporters.Exporter"..sType);
end


--[[!
@fqxn CFS.Modules.Exporter.run
@pulsarlua function Exporter.run
@desc Stages all planned outputs before committing them without overwriting existing files. On failure, removes staged files and outputs created by this job.
@param string pDirectory Destination folder.
@param table tPlan Ordered output records, each with a name.
@param function fRender Receives an output record and staged path; writes the format-specific file.
@param function|nil fProgress Optional phase, completed count, total count, and current record callback.
@return number nCount Number of committed files.
@note Rendering belongs to the exporter. This service does not interpret card rows, faces, or formats.
!]]
function Exporter.run(pDirectory, tPlan, fRender, fProgress)
    assert(wx.wxDirExists(pDirectory), "Export destination does not exist.");
    for _, tFile in ipairs(tPlan) do assert(not wx.wxFileExists(pDirectory.."/"..tFile.name) and not wx.wxDirExists(pDirectory.."/"..tFile.name), "Export file already exists: "..tFile.name..". Choose an empty destination."); end
    local tStaged, tWritten = {}, {};
    local bOK, sError = xpcall(function()
        -- Produce every temporary output before exposing any final filenames.
        for nIndex, tFile in ipairs(tPlan) do
            if (fProgress) then fProgress("Rendering", nIndex - 1, #tPlan, tFile); end
            local oFile = wx.wxFile(); local pStage = wx.wxFileName.CreateTempFileName(pDirectory.."/.cfs-export-", oFile);
            if (oFile:IsOpened()) then oFile:Close(); end; oFile:delete();
            assert(pStage ~= "", "Could not stage export output.");
            local tStage = {path = pStage, destination = pDirectory.."/"..tFile.name}; tStaged[#tStaged + 1] = tStage;
            fRender(tFile, pStage);
            if (fProgress) then fProgress("Rendered", nIndex, #tPlan, tFile); end
        end
        -- Commit without overwrite; retain the destinations owned by this job for rollback.
        for nIndex, tStage in ipairs(tStaged) do
            if (fProgress) then fProgress("Writing", nIndex - 1, #tPlan); end
            assert(wx.wxRenameFile(tStage.path, tStage.destination, false), "Could not finish export."); tWritten[#tWritten + 1] = tStage.destination;
        end
    end, debug.traceback);
    for _, tStage in ipairs(tStaged) do if (wx.wxFileExists(tStage.path)) then wx.wxRemoveFile(tStage.path); end end
    -- On failure, delete only this job's outputs and propagate the original error.
    if (not bOK) then
        for _, pFile in ipairs(tWritten) do wx.wxRemoveFile(pFile); end
        error(sError, 0);
    end
    return #tPlan;
end

return Exporter;
