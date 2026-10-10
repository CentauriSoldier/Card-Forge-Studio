--[[!
@fqxn CFS.Windows.NewCardSet
@desc Collects card-set name and numeric dimensions and invokes the supplied creation callback.
!]]

local wx         = require("wx");
local NewCardSet = {};


--[[!
@fqxn CFS.Windows.NewCardSet.Show
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
