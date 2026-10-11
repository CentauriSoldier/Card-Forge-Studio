--[[!
@fqxn CFS.Modules.Exporter
@desc
<section aria-label="Exporter overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Exporter</h2><p style="font-size:1.15rem;margin:0">The export coordinator turns a planned batch into finished output files.</p></div>
<h3>How it fits into your work</h3><p>A dedicated exporter decides what to produce. This coordinator stages the files first, then commits their final names while reporting progress.</p>
<figure style="margin:1.5rem 0"><figcaption style="font-weight:700;margin-bottom:.8rem">The big picture</figcaption><div role="img" aria-label="Output plan then Stage files then Commit names then Finished export" style="display:flex;flex-wrap:wrap;align-items:center;gap:.7rem"><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Output plan</span><span aria-hidden="true" style="color:var(--accent)">→</span><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Stage files</span><span aria-hidden="true" style="color:var(--accent)">→</span><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Commit names</span><span aria-hidden="true" style="color:var(--accent)">→</span><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Finished export</span></div></figure>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Exporter.Exporters.ExporterPNG">PNG Export</a></h3><p style="margin:0">The PNG exporter chooses faces, names, scale, and rendering instructions.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Forge">Forge</a></h3><p style="margin:0">Forge performs the card-image rendering used by PNG output.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.ExportOptions">ExportOptions</a></h3><p style="margin:0">The options dialog stores the active set’s output choices; the coordinator receives the resulting plan.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Existing destination files are not overwritten. Failure cleanup is limited to files created by the current job. Deferred exporter skeletons are not enabled formats.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

-- Format-independent export lookup and staged file commit.
local wx            = require("wx");
local Exporter = {};


--[[!
@fqxn CFS.Modules.Exporter.Functions.get
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
@fqxn CFS.Modules.Exporter.Functions.run
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
