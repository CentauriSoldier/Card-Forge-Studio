--[[!
@fqxn CFS.Windows.BaseData
@desc
<section aria-label="BaseData overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">BaseData</h2><p style="font-size:1.15rem;margin:0">Base Data is the table of values you actually edit.</p></div>
<h3>How it fits into your work</h3><p>Change source cells, create cards, manage columns, and compare the resulting values with Final Data.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.DataGrid">Data Grid</a></h3><p style="margin:0">The common grid supplies table controls for both data windows.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.DataSession">Shared Data Session</a></h3><p style="margin:0">The shared session keeps both grids looking at the same underlying cards.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys.CSV">Card Data Processing</a></h3><p style="margin:0">The CSV processor connects entered values with the values used to draw a card.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Columns">Columns</a></h3><p style="margin:0">Column Management changes the source table structure with a focused interface.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">This is the source view. The processed view is a separate result, not a second source CSV.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

local DataGrid = require("Windows.DataGrid");
local BaseData = {};

--[[!
@fqxn CFS.Windows.BaseData.Functions.create
@pulsarlua function BaseData.create
@desc Creates the editable base-data grid for a shared data session.
@param any tSession Shared data session.
!]]
function BaseData.create(tSession)
    return DataGrid.create(tSession, false);
end

return BaseData;
