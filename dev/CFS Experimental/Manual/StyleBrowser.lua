-- Read-only list, generated tag syntax, and a sample of each resolved game style.
local wx = require("wx");
local Styles = require("Manual.Styles");
local StyleBrowser = {};

function StyleBrowser.create(dParent, pStyles, tOptions)
    tOptions = tOptions or {};
    local sCSS, sOriginal, tItems = Styles.load(pStyles);
    local dFrame = wx.wxFrame(dParent, wx.wxID_ANY, "Manual Styles", wx.wxDefaultPosition, wx.wxSize(850, 560));
    dFrame:SetMinSize(wx.wxSize(600, 360));
    local dPanel = wx.wxPanel(dFrame, wx.wxID_ANY);
    local oLayout = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oList = wx.wxListBox(dPanel, wx.wxID_ANY);
    oList:SetMinSize(wx.wxSize(230, -1));
    local dDetails = wx.wxPanel(dPanel, wx.wxID_ANY);
    local oDetails = wx.wxBoxSizer(wx.wxVERTICAL);
    local oName = wx.wxStaticText(dDetails, wx.wxID_ANY, "");
    local oTag = wx.wxTextCtrl(dDetails, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_READONLY);
    local oInfo = wx.wxTextCtrl(dDetails, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize(-1, 120), wx.wxTE_MULTILINE + wx.wxTE_READONLY);
    local oPreview = wxwebview.wxWebView.New(dDetails, wx.wxID_ANY);
    oDetails:Add(oName, 0, wx.wxEXPAND + wx.wxALL, 8);
    oDetails:Add(oTag, 0, wx.wxEXPAND + wx.wxALL, 8);
    oDetails:Add(oInfo, 0, wx.wxEXPAND + wx.wxALL, 8);
    oDetails:Add(oPreview, 1, wx.wxEXPAND + wx.wxALL, 8);
    dDetails:SetSizer(oDetails);
    oLayout:Add(oList, 0, wx.wxEXPAND + wx.wxALL, 8); oLayout:Add(dDetails, 1, wx.wxEXPAND);
    dPanel:SetSizer(oLayout);
    local oFrame = wx.wxBoxSizer(wx.wxVERTICAL); oFrame:Add(dPanel, 1, wx.wxEXPAND); dFrame:SetSizer(oFrame);
    local bClosed = false;
    local oTimer = wx.wxTimer(dFrame, wx.wxNewId());

    local function select(nIndex)
        local tItem = tItems[nIndex + 1];
        if (not tItem) then oName:SetLabel("No styles"); oTag:ChangeValue(""); oInfo:ChangeValue(""); oPreview:SetPage("", ""); return; end
        oList:SetSelection(nIndex);
        oName:SetLabel(tItem.name);
        oTag:ChangeValue("<"..tItem.tag..">Your text</"..tItem.tag..">");
        local tStyle = tItem.style;
        local tFont = tStyle.FontOptions;
        oInfo:ChangeValue(string.format("Font: %s\nSize: %s pt\nBold: %s    Italic: %s\nUnderline: %s    Strikeout: %s\nLetter spacing: %s px\nBackground: %s    Shadow: %s", tStyle.FontFamily, tStyle.FontSize, tostring(tFont.Bold), tostring(tFont.Italic), tostring(tFont.Underline), tostring(tFont.StrikeOut), tStyle.LetterSpacing, tostring(tStyle.BackgroundEnabled), tostring(tStyle.ShadowEnabled)));
        oPreview:SetPage('<!doctype html><html><head><meta charset="utf-8"><style>body{padding:20px;background:#fff;color:#222}'..sCSS:gsub("<", "\\3c ")..'</style></head><body><'..tItem.tag..'>The quick brown fox jumps over the lazy dog.<br>0123456789</'..tItem.tag..'></body></html>', "");
    end

    local function fill(sSelected)
        oList:Clear(); local nSelected = 0;
        for nIndex, tItem in ipairs(tItems) do oList:Append(tItem.name); if (tItem.name == sSelected) then nSelected = nIndex - 1; end end
        select(nSelected);
    end
    oList:Connect(wx.wxEVT_COMMAND_LISTBOX_SELECTED, function() select(oList:GetSelection()); end);
    dFrame:Connect(oTimer:GetId(), wx.wxEVT_TIMER, function()
        local oFile = io.open(pStyles, "rb"); if (not oFile) then return; end
        local sCurrent = oFile:read("a"); oFile:close();
        if (sCurrent == sOriginal) then return; end
        local bOK, sNextCSS, sNextOriginal, tNextItems = pcall(Styles.load, pStyles);
        if (bOK) then
            local tSelected = tItems[oList:GetSelection() + 1];
            sCSS, sOriginal, tItems = sNextCSS, sNextOriginal, tNextItems;
            fill(tSelected and tSelected.name);
        end
    end);
    dFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        bClosed = true; oTimer:Stop(); oPreview:Stop();
        if (tOptions.onClose) then tOptions.onClose(); end
        oEvent:Skip();
    end);
    fill(); oTimer:Start(500); dFrame:Show(true);
    return {frame = dFrame, list = oList, tag = oTag, info = oInfo, preview = oPreview, select = select,
        show = function() dFrame:Show(true); dFrame:Raise(); end,
        close = function() if (bClosed) then return true; end return dFrame:Close(); end};
end

return StyleBrowser;
