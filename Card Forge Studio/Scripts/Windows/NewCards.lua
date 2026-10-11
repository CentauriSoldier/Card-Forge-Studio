--[[!
@fqxn CFS.Windows.NewCards
@desc
<section aria-label="NewCards overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">NewCards</h2><p style="font-size:1.15rem;margin:0">New Cards collects the quantity for a batch of new source rows.</p></div>
<h3>How it fits into your work</h3><p>Enter a positive count. The calling grid creates editable unnamed cards with incremented placeholder names.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.DataGrid">Data Grid</a></h3><p style="margin:0">The common grid supplies table controls for both data windows.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.DataSession">Shared Data Session</a></h3><p style="margin:0">The shared session keeps both grids looking at the same underlying cards.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys.CSV">Card Data Processing</a></h3><p style="margin:0">The CSV processor connects entered values with the values used to draw a card.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Creating rows does not draw artwork by itself. The set's drawing script controls what appears.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

local wx       = require("wx");
local NewCards = {};


--[[!
@fqxn CFS.Windows.NewCards.Functions.Show
@pulsarlua function NewCards.Show
@desc Collects a positive quantity. Cancel leaves the card set unchanged.
@param wxWindow dParent Parent window.
@return number|nil Requested quantity, or nil after cancellation.
!]]
function NewCards.Show(dParent)
    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, "New Cards");
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oCount  = wx.wxSpinCtrl(dDialog, wx.wxID_ANY, "1", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxSP_ARROW_KEYS, 1, 10000, 1);
    local nCount;

    oLayout:Add(wx.wxStaticText(dDialog, wx.wxID_ANY, "Number of cards"), 0, wx.wxALL, 12);
    oLayout:Add(oCount, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 12);
    oLayout:Add(wx.wxStaticText(dDialog, wx.wxID_ANY, "New cards receive editable UNNAMED names."), 0, wx.wxALL, 12);
    oLayout:Add(dDialog:CreateButtonSizer(wx.wxOK + wx.wxCANCEL), 0, wx.wxALL, 12);
    dDialog:SetSizerAndFit(oLayout);
    dDialog:CentreOnParent();

    if (dDialog:ShowModal() == wx.wxID_OK) then
        nCount = oCount:GetValue();
    end
    dDialog:Destroy();

    return nCount;
end


return NewCards;
