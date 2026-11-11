--[[!
@fqxn CFS.Windows.Loaders.Common
@desc
<section aria-label="Loaders.Common overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Loaders.Common</h2><p style="font-size:1.15rem;margin:0">The shared chooser supplies the same visual language for games and card sets.</p></div>
<h3>How it fits into your work</h3><p>It builds logo cards, validates square images, and preserves each chooser's independent size settings.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.LoadGame">LoadGame</a></h3><p style="margin:0">The game chooser presents projects as easy-to-scan logo cards.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.LoadCardSet">LoadCardSet</a></h3><p style="margin:0">The card-set chooser presents the active game's sets as logo cards.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.WindowState">WindowState</a></h3><p style="margin:0">WindowState remembers useful native-window choices outside game folders.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Invalid logos use the shared fallback without rewriting project files.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

local wx          = require("wx");
local WindowState = require("Windows.WindowState");
local Common      = {};


--[[!
@fqxn CFS.Windows.Loaders.Common.Private.Functions.logo
@desc Loads a square PNG from the game root, or the shared placeholder. Never changes game files.
@param string pRoot Game folder.
@return wxBitmap Square thumbnail bitmap.
!]]
local function logo(pRoot)
    local pLogo = pRoot.."/Logo.png";
    local oImage;

    if (wx.wxFileExists(pLogo)) then
        -- Invalid user artwork must not open a native decoding error dialog.
        local oQuiet = wx.wxLogNull();
        local bOK, oCandidate = pcall(wx.wxImage, pLogo, wx.wxBITMAP_TYPE_PNG);

        oQuiet:delete();

        if (bOK and oCandidate:IsOk() and oCandidate:GetWidth() == oCandidate:GetHeight()) then
            oImage = oCandidate;
        elseif (bOK) then
            oCandidate:delete();
        end
    end

    if (not oImage) then
        oImage = wx.wxImage(APP_PATH.."/Images/NoLogo.png", wx.wxBITMAP_TYPE_PNG);
    end

    local oScaled = oImage:Scale(88, 88, wx.wxIMAGE_QUALITY_HIGH);
    local oBitmap = wx.wxBitmap(oScaled);

    oScaled:delete();
    oImage:delete();

    return oBitmap;
end


--[[!
@fqxn CFS.Windows.Loaders.Common.Functions.Show
@pulsarlua function Common.Show
@desc Presents game cards with square artwork, keyboard navigation, and an explicit selected state.
@param wxWindow dParent Parent window.
@param table tGames Discovered games in display order.
@return number Zero-based selected game index, or -1 after cancellation.
@note Missing, invalid, and non-square logos use the shared NoLogo image.
@param any tOptions t Options.
!]]
function Common.Show(dParent, tGames, tOptions)
    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, tOptions.title, wx.wxDefaultPosition, wx.wxSize(680, 640), wx.wxDEFAULT_DIALOG_STYLE + wx.wxRESIZE_BORDER);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local dHeader = wx.wxPanel(dDialog, wx.wxID_ANY);
    local oHeader = wx.wxBoxSizer(wx.wxVERTICAL);
    local oTitle  = wx.wxStaticText(dHeader, wx.wxID_ANY, tOptions.heading);
    local oFont   = oTitle:GetFont();
    local dList   = wx.wxScrolledWindow(dDialog, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxVSCROLL);
    local oCards  = wx.wxBoxSizer(wx.wxVERTICAL);
    local tCards  = {};
    local nSelected = #tGames > 0 and 1 or nil;
    local oState;

    dDialog:SetMinSize(wx.wxSize(480, 380));
    WindowState.register(tOptions.state, {savePosition = false, saveSize = true, saveVisible = false});
    oState = WindowState.bind(dDialog, tOptions.state);
    dHeader:SetBackgroundColour(wx.wxColour("#172943"));
    oFont:SetPointSize(20);
    oFont:SetWeight(wx.wxFONTWEIGHT_BOLD);
    oTitle:SetFont(oFont);
    oTitle:SetForegroundColour(wx.wxColour("#FFFFFF"));
    oHeader:Add(oTitle, 0, wx.wxLEFT + wx.wxRIGHT + wx.wxTOP, 20);

    local oSubtitle = wx.wxStaticText(dHeader, wx.wxID_ANY, tOptions.description);

    oSubtitle:SetForegroundColour(wx.wxColour("#C8D8EB"));
    oHeader:Add(oSubtitle, 0, wx.wxALL, 20);
    dHeader:SetSizer(oHeader);
    oLayout:Add(dHeader, 0, wx.wxEXPAND);
    dList:SetBackgroundColour(wx.wxColour("#EDF1F6"));
    dList:SetScrollRate(0, 10);
    dList:SetSizer(oCards);
    oLayout:Add(dList, 1, wx.wxEXPAND);

    --[[!
    @fqxn CFS.Windows.Loaders.Common.Private.Functions.select
    @desc Marks the selected logo card and updates selection visuals and confirmation enablement.
    @param any nIndex Index.
    @vis private
    !]]
    local function select(nIndex)
        nSelected = nIndex;

        for nCard, tCard in ipairs(tCards) do
            local bSelected = nCard == nSelected;
            local oColour = wx.wxColour(bSelected and "#DCEBFF" or "#FFFFFF");

            tCard.panel:SetBackgroundColour(oColour);
            tCard.name:SetBackgroundColour(oColour);
            tCard.hint:SetBackgroundColour(oColour);
            tCard.hint:SetLabel(bSelected and "SELECTED  •  Enter to load" or "Click to select  •  Double-click to load");
            tCard.panel:Refresh();
        end
    end

    for nIndex, oGame in ipairs(tGames) do
        local nCard = nIndex;
        local dCard = wx.wxPanel(dList, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxBORDER_SIMPLE);
        local oRow  = wx.wxBoxSizer(wx.wxHORIZONTAL);
        local oText = wx.wxBoxSizer(wx.wxVERTICAL);
        local oLogo = wx.wxStaticBitmap(dCard, wx.wxID_ANY, logo(tOptions.root(oGame)));
        local oName = wx.wxStaticText(dCard, wx.wxID_ANY, oGame.GetName());
        local oHint = wx.wxStaticText(dCard, wx.wxID_ANY, "");
        local oNameFont = oName:GetFont();

        oNameFont:SetPointSize(14);
        oNameFont:SetWeight(wx.wxFONTWEIGHT_BOLD);
        oName:SetFont(oNameFont);
        oName:SetForegroundColour(wx.wxColour("#172943"));
        oHint:SetForegroundColour(wx.wxColour("#4C6480"));
        oText:Add(oName, 0, wx.wxBOTTOM, 10);
        oText:Add(oHint, 0);
        oRow:Add(oLogo, 0, wx.wxALL, 12);
        oRow:Add(oText, 1, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 12);
        dCard:SetSizer(oRow);
        oCards:Add(dCard, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT + wx.wxTOP, 12);
        tCards[nIndex] = {panel = dCard, name = oName, hint = oHint};

        for _, dTarget in ipairs({dCard, oLogo, oName, oHint}) do
            dTarget:Connect(wx.wxEVT_LEFT_DOWN, function()
                select(nCard);
                dList:SetFocus();
            end);
            dTarget:Connect(wx.wxEVT_LEFT_DCLICK, function()
                select(nCard);
                dDialog:EndModal(wx.wxID_OK);
            end);
        end
    end

    oCards:AddSpacer(12);
    oLayout:Add(dDialog:CreateButtonSizer(wx.wxOK + wx.wxCANCEL), 0, wx.wxALIGN_RIGHT + wx.wxALL, 14);
    dDialog:FindWindow(wx.wxID_OK):SetLabel(tOptions.title);
    dDialog:FindWindow(wx.wxID_OK):Enable(nSelected ~= nil);
    dDialog:Connect(wx.wxEVT_CHAR_HOOK, function(oEvent)
        local nKey = oEvent:GetKeyCode();

        if ((nKey == wx.WXK_UP or nKey == wx.WXK_DOWN) and nSelected) then
            select(math.max(1, math.min(#tCards, nSelected + (nKey == wx.WXK_UP and -1 or 1))));
            dList:Scroll(0, math.floor(tCards[nSelected].panel:GetPosition():GetY() / 10));
        else
            oEvent:Skip();
        end
    end);

    dDialog:SetSizer(oLayout);
    dDialog:Layout();
    dList:FitInside();
    select(nSelected);
    dDialog:CentreOnParent();
    local nResult = dDialog:ShowModal();
    local nReturn = nResult == wx.wxID_OK and nSelected and nSelected - 1 or -1;

    oState.close();
    dDialog:Destroy();

    return nReturn;
end


return Common;
