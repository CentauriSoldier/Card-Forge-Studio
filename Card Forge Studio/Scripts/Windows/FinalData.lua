--[[!
@fqxn CFS.Windows.FinalData
@desc
<section aria-label="FinalData overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">FinalData</h2><p style="font-size:1.15rem;margin:0">Final Data shows the results after card values and scripts have been processed.</p></div>
<h3>How it fits into your work</h3><p>Select a result to inspect its preview and the matching source row. Use it to understand what the drawing script receives.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.DataGrid">Data Grid</a></h3><p style="margin:0">The common grid supplies table controls for both data windows.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.DataSession">Shared Data Session</a></h3><p style="margin:0">The shared session keeps both grids looking at the same underlying cards.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys.CSV">Card Data Processing</a></h3><p style="margin:0">The CSV processor connects entered values with the values used to draw a card.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Forge">Forge</a></h3><p style="margin:0">Forge is the visual workbench that turns selected card data and drawing instructions into artwork.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Change original values in Base Data or change processing instructions instead of treating the result as a second source file.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

local DataGrid = require("Windows.DataGrid");
local FinalData = {};

--[[!
@fqxn CFS.Windows.FinalData.Functions.create
@pulsarlua function FinalData.create
@desc Creates the processed final-data grid for a shared data session.
@param any tSession Shared data session.
!]]
function FinalData.create(tSession)
    return DataGrid.create(tSession, true);
end

return FinalData;
