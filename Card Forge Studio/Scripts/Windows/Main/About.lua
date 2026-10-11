--[[!
@fqxn CFS.Windows.Main.About
@desc
<section aria-label="Main.About overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Main.About</h2><p style="font-size:1.15rem;margin:0">About introduces the application and its dependencies.</p></div>
<h3>How it fits into your work</h3><p>Open the dialog to inspect project, license, and component information.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Main">Main</a></h3><p style="margin:0">The main Studio window connects your project, preview, and editing tools.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Constants">Constants</a></h3><p style="margin:0">Shared constants let Studio services agree on names, paths, and processing choices.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">This is the implemented About dialog; the separate reserved About file is not another active window.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

local wx = require("wx");
local About = {};

--[[!
@fqxn CFS.Windows.Main.About.Functions.show
@pulsarlua function About.show
@desc Shows the application About dialog and releases its native controls after closing.
@param any dParent Parent window.
!]]
function About.show(dParent)
    local dDialog  = wx.wxDialog(dParent, wx.wxID_ANY, "About");
    local oLayout  = wx.wxBoxSizer(wx.wxVERTICAL);
    local oTitle   = wx.wxStaticText(dDialog, wx.wxID_ANY, APP_NAME);
    local oFont    = wx.wxFont(22, wx.wxFONTFAMILY_ROMAN, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, false, "Times New Roman");
    local sVersion = INIFile.GetValue(FS.AppCFG, "Settings", "Version"):gsub("[Aa][Ll][Pp][Hh][Aa]", "Beta");
    if (not sVersion:lower():find("beta", 1, true)) then sVersion = "Beta "..sVersion; end

    local sSource = debug.getinfo(1, "S").source;
    local pRuntime = assert(sSource:match("^@(.+[/\\])")).."../../../";
    local oIcon = wx.wxIcon(pRuntime.."icon.ico", wx.wxBITMAP_TYPE_ICO);
    if (oIcon:IsOk()) then dDialog:SetIcon(oIcon); end
    local oImage = wx.wxImage(pRuntime.."Images/Logo.png", wx.wxBITMAP_TYPE_ANY);
    assert(oImage:IsOk(), "Cannot load About logo.");
    oLayout:Add(wx.wxStaticBitmap(dDialog, wx.wxID_ANY, wx.wxBitmap(oImage:Scale(120, 120, wx.wxIMAGE_QUALITY_HIGH))), 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxTOP, 20);
    oTitle:SetFont(oFont);
    oLayout:Add(oTitle, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 20);
    local oVersion = wx.wxStaticText(dDialog, wx.wxID_ANY, sVersion);
    oVersion:SetFont(wx.wxFont(14, wx.wxFONTFAMILY_ROMAN, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, false, "Times New Roman"));
    oLayout:Add(oVersion, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 20);

    oLayout:Add(dDialog:CreateButtonSizer(wx.wxOK), 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 16);
    dDialog:SetSizerAndFit(oLayout);

    local oSize    = dDialog:GetSize();
    local oDisplay = wx.wxDisplay(0);
    local oScreen  = oDisplay:GetClientArea();
    local nX, nY;

    if (not dParent:IsShown() or dParent:IsIconized()) then
        nX = oScreen:GetX() + (oScreen:GetWidth() - oSize:GetWidth()) / 2;
        nY = oScreen:GetY() + (oScreen:GetHeight() - oSize:GetHeight()) / 2;
    else
        local oPosition   = dParent:GetPosition();
        local oParentSize = dParent:GetSize();
        nX = oPosition:GetX() + (oParentSize:GetWidth() - oSize:GetWidth()) / 2;
        nY = oPosition:GetY() + (oParentSize:GetHeight() - oSize:GetHeight()) / 2;
    end

    dDialog:Move(math.floor(nX), math.floor(nY));
    oDisplay:delete();
    dDialog:ShowModal();
    dDialog:Destroy();
end

return About;
