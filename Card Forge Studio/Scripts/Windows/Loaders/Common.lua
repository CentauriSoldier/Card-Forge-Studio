--[[!
@fqxn CFS.Windows.Loaders.Common
@desc Styled game and card-set chooser with square-logo validation and independent window dimensions.
!]]

local wx          = require("wx");
local WindowState = require("Windows.WindowState");
local Common      = {};


--[[!
@fqxn CFS.Windows.Loaders.Common.Private.logo
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
@fqxn CFS.Windows.Loaders.Common.Show
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
    @fqxn CFS.Windows.Loaders.Common.Private.select
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
