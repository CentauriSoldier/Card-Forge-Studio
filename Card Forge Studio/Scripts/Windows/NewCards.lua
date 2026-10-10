--[[!
@fqxn CFS.Windows.NewCards
@desc Collects a positive quantity for bulk creation of editable unnamed cards.
!]]

local wx       = require("wx");
local NewCards = {};


--[[!
@fqxn CFS.Windows.NewCards.Show
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
