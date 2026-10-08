local wx = require("wx");
local About = {};

function About.show(dParent)
    local dDialog  = wx.wxDialog(dParent, wx.wxID_ANY, "About "..APP_NAME);
    local oLayout  = wx.wxBoxSizer(wx.wxVERTICAL);
    local oTitle   = wx.wxStaticText(dDialog, wx.wxID_ANY, APP_NAME);
    local oFont    = wx.wxFont(22, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, false, "CRYSTAL");
    local sVersion = INIFile.GetValue(FS.AppCFG, "Settings", "Version");

    oTitle:SetFont(oFont);
    oLayout:Add(oTitle, 0, wx.wxALL, 20);
    oLayout:Add(wx.wxStaticText(dDialog, wx.wxID_ANY, sVersion), 0, wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 20);
    oLayout:Add(wx.wxStaticText(dDialog, wx.wxID_ANY, "Create, process, and render your cards."), 0, wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 20);

    local tLinks = {
        {label = "Website", url = APP_WEBSITE,},
        {label = "GitHub", url = APP_GITHUB,},
        {label = "Patreon", url = APP_PATREON,},
    };

    for _, tLink in ipairs(tLinks) do
        oLayout:Add(wx.wxHyperlinkCtrl(dDialog, wx.wxID_ANY, tLink.label, tLink.url), 0, wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 20);
    end

    oLayout:Add(dDialog:CreateButtonSizer(wx.wxOK), 0, wx.wxEXPAND + wx.wxALL, 16);
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
