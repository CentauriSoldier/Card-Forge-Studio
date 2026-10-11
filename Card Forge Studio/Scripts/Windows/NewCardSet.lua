--[[!
@fqxn CFS.Windows.NewCardSet
@desc
<section aria-label="NewCardSet overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">NewCardSet</h2><p style="font-size:1.15rem;margin:0">New Card Set collects a name and numeric card dimensions.</p></div>
<h3>How it fits into your work</h3><p>Submit the information and let the creation callback prepare starter files inside the active game.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.CardSet">Card Set</a></h3><p style="margin:0">A card set brings together one collection of cards, its dimensions, and the files that describe how those cards look and behave.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.FS">File System</a></h3><p style="margin:0">FS is Studio's map of where project files belong.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Main">Main</a></h3><p style="margin:0">The main Studio window connects your project, preview, and editing tools.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">A new CSV begins with Name alone. Additional columns can be added as needed.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

local wx         = require("wx");
local NewCardSet = {};


--[[!
@fqxn CFS.Windows.NewCardSet.Functions.Show
@pulsarlua function NewCardSet.Show
@desc Collects a card-set name and pixel dimensions. Cancel creates nothing; failed creation is logged and can be retried.
@param wxWindow dParent Parent window.
@param function fCreate Callback accepting name, width and height and returning the new card set.
@return CardSet|nil Created card set, or nil after cancellation.
!]]
function NewCardSet.Show(dParent, fCreate)
    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, "New Card Set", wx.wxDefaultPosition, wx.wxSize(490, 330), wx.wxDEFAULT_DIALOG_STYLE);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oName   = wx.wxTextCtrl(dDialog, wx.wxID_ANY, "");
    local oWidth  = wx.wxTextCtrl(dDialog, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0, wx.wxTextValidator(wx.wxFILTER_DIGITS));
    local oHeight = wx.wxTextCtrl(dDialog, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0, wx.wxTextValidator(wx.wxFILTER_DIGITS));
    local oHint   = wx.wxStaticText(dDialog, wx.wxID_ANY, "Creates an empty card set with drawing scripts and notes.");
    local oButtons = dDialog:CreateButtonSizer(wx.wxOK + wx.wxCANCEL);
    local oCardSet;

    oLayout:Add(wx.wxStaticText(dDialog, wx.wxID_ANY, "Card Set Name"), 0, wx.wxALL, 10);
    oLayout:Add(oName, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 10);
    oLayout:Add(wx.wxStaticText(dDialog, wx.wxID_ANY, "Card width (pixels)"), 0, wx.wxALL, 10);
    oLayout:Add(oWidth, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 10);
    oLayout:Add(wx.wxStaticText(dDialog, wx.wxID_ANY, "Card height (pixels)"), 0, wx.wxALL, 10);
    oLayout:Add(oHeight, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 10);
    oHint:Wrap(450);
    oLayout:Add(oHint, 0, wx.wxALL, 10);
    oLayout:Add(oButtons, 0, wx.wxALIGN_RIGHT + wx.wxALL, 10);
    dDialog:SetSizerAndFit(oLayout);
    dDialog:CentreOnParent();
    oName:SetFocus();

    dDialog:Connect(wx.wxID_OK, wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        local sName   = oName:GetValue():match("^%s*(.-)%s*$");
        local nWidth  = tonumber(oWidth:GetValue());
        local nHeight = tonumber(oHeight:GetValue());

        if (sName == "" or sName:find("[%c]")) then
            oHint:SetLabel("Enter a card-set name without control characters.");
            oName:SetFocus();

            return;
        end

        if (not nWidth or not nHeight or nWidth <= 0 or nHeight <= 0 or
            nWidth >= math.huge or nHeight >= math.huge or
            nWidth ~= math.floor(nWidth) or nHeight ~= math.floor(nHeight)) then
            oHint:SetLabel("Enter a positive whole number for each dimension.");
            oWidth:SetFocus();

            return;
        end

        local bOK, vResult = xpcall(function()
            return fCreate(sName, nWidth, nHeight);
        end, debug.traceback);

        if (not bOK) then
            require("Errors").report(vResult);
            oHint:SetLabel("Creation failed. See the log; correct the issue and retry.");
            oHint:Wrap(450);
            dDialog:Layout();

            return;
        end

        oCardSet = vResult;
        dDialog:EndModal(wx.wxID_OK);
    end);

    dDialog:ShowModal();
    dDialog:Destroy();

    return oCardSet;
end


return NewCardSet;
