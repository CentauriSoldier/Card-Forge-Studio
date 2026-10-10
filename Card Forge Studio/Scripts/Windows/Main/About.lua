--[[!
@fqxn CFS.Windows.Main.About
@desc Application About dialog with project, license, and dependency information.
!]]

local wx = require("wx");
local About = {};

--[[!
@fqxn CFS.Windows.Main.About.show
@pulsarlua function About.show
@desc Shows the application About dialog and releases its native controls after closing.
@param any dParent Parent window.
!]]
function About.show(dParent)
    local dDialog  = wx.wxDialog(dParent, wx.wxID_ANY, "About "..APP_NAME);
    local oLayout  = wx.wxBoxSizer(wx.wxVERTICAL);
    local oTitle   = wx.wxStaticText(dDialog, wx.wxID_ANY, APP_NAME);
    local oFont    = wx.wxFont(22, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, false, "CRYSTAL");
    local sVersion = INIFile.GetValue(FS.AppCFG, "Settings", "Version");

    local sSource = debug.getinfo(1, "S").source;
    local pRuntime = assert(sSource:match("^@(.+[/\\])")).."../../../";
    local oIcon = wx.wxIcon(pRuntime.."icon.ico", wx.wxBITMAP_TYPE_ICO);
    if (oIcon:IsOk()) then
        dDialog:SetIcon(oIcon);
        local oBitmap = wx.wxBitmap(); oBitmap:CopyFromIcon(oIcon);
        local oImage = oBitmap:ConvertToImage();
        oLayout:Add(wx.wxStaticBitmap(dDialog, wx.wxID_ANY, wx.wxBitmap(oImage:Scale(80, 80, wx.wxIMAGE_QUALITY_HIGH))), 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxTOP, 20);
    end
    oTitle:SetFont(oFont);
    oLayout:Add(oTitle, 0, wx.wxALL, 20);
    oLayout:Add(wx.wxStaticText(dDialog, wx.wxID_ANY, sVersion), 0, wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 20);
    oLayout:Add(wx.wxStaticText(dDialog, wx.wxID_ANY, "Your data. Your code. Your cards."), 0, wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 20);
    oLayout:Add(wx.wxStaticLine(dDialog, wx.wxID_ANY), 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 20);

    local tLinks = {
        {label = "Website", url = APP_WEBSITE,},
        {label = "GitHub", url = APP_GITHUB,},
        {label = "Patreon", url = APP_PATREON,},
    };

    for _, tLink in ipairs(tLinks) do
        local oRow = wx.wxBoxSizer(wx.wxHORIZONTAL);
        local oBitmap;
        if (tLink.label == "Website") then
            oBitmap = wx.wxArtProvider.GetBitmap(wx.wxART_HELP, wx.wxART_OTHER, wx.wxSize(24, 24));
        else
            local oImage = wx.wxImage(pRuntime.."Images/Buttons/"..tLink.label:lower()..".png", wx.wxBITMAP_TYPE_ANY);
            assert(oImage:IsOk(), "Cannot load About link icon.");
            oBitmap = wx.wxBitmap(oImage:Scale(24, 24, wx.wxIMAGE_QUALITY_HIGH));
        end
        oRow:Add(wx.wxStaticBitmap(dDialog, wx.wxID_ANY, oBitmap), 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxRIGHT, 10);
        oRow:Add(wx.wxHyperlinkCtrl(dDialog, wx.wxID_ANY, tLink.label, tLink.url), 0, wx.wxALIGN_CENTER_VERTICAL);
        oLayout:Add(oRow, 0, wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 20);
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
