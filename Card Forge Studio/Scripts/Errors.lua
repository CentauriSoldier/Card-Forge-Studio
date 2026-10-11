--[[!
@fqxn CFS.Modules.Errors
@desc
<section aria-label="Errors overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Errors</h2><p style="font-size:1.15rem;margin:0">Error reporting gives services a shared way to record failures without opening modal windows.</p></div>
<h3>How it fits into your work</h3><p>Reports go through Log, with disk fallback if normal logging is unavailable or reporting recurses.</p>
<h3>Follow the handoffs</h3><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,260px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">Where a problem goes</h3><p style="margin:0">An operation reports its failure here so Studio can record it without making every caller build its own reporting window. The normal route uses Log. A fallback reporting path is available if logging itself fails, helping avoid a second logging failure hiding the original problem.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">What the caller still decides</h3><p style="margin:0">This service reports the problem; it does not fix the file or complete the failed operation. Saving, importing, processing, and exporting keep their own success and failure decisions. Read the reported operation before choosing whether to correct an input or retry.</p></article>
</div>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.Log">Log</a></h3><p style="margin:0">Logging records Studio activity and preserves useful context when something goes wrong.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Log">Log</a></h3><p style="margin:0">The log window displays recorded messages as readable cards.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Reporting is separate from recovery. The caller decides whether an operation should stop, remain open, or retry.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual functions, inputs, and results.</p>
</section>
!]]

-- Error reporting never opens or raises a window.
local Errors = {};
local _bReporting = false;

--[[!
@fqxn CFS.Modules.Errors.Functions.report
@pulsarlua function Errors.report
@desc Reports an error through Log and falls back to the disk log when logging fails or reporting recurses. Never opens a window.
@param any vError Error.
@param any bRenderer Renderer.
!]]
function Errors.report(vError, bRenderer)
    local sError = tostring(vError);
    local pFile = APP_PATH.."/log.log";
    if (bRenderer) then sError = "Renderer: "..sError; end
    if (_bReporting) then
        local hFile = io.open(pFile, "a");
        if (hFile) then hFile:write(sError.."\n"); hFile:close(); end
        return;
    end
    _bReporting = true;
    local bLogged = false;
    if (Log) then bLogged = pcall(Log.Error, sError); end
    if (not bLogged) then
        local hFile = io.open(pFile, "a");
        if (hFile) then hFile:write(sError.."\n"); hFile:close(); end
    end
    _bReporting = false;
end

return Errors;
