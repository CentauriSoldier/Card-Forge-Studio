--[[!
@fqxn CFS.Windows.EnvironmentReference
@desc A searchable reference to the current generated user environment. Shows names, types and available documentation without executing the snapshot or showing card values.
!]]
local wx = require("wx");
local Autocomplete = require("Autocomplete");
local WindowState = require("Windows.WindowState");
local EnvironmentReference = {};

WindowState.register("EnvironmentReference", {savePosition = true, saveSize = true, saveVisible = false,});

function EnvironmentReference.create(dParent)
    local dWindow = wx.wxFrame(dParent, wx.wxID_ANY, "Environment Reference", wx.wxDefaultPosition, wx.wxSize(900, 620), wx.wxDEFAULT_FRAME_STYLE);
    dWindow:CentreOnParent();
    local oState = WindowState.bind(dWindow, "EnvironmentReference");
    local dBody = wx.wxPanel(dWindow, wx.wxID_ANY);
    local oSplitter = wx.wxSplitterWindow(dBody, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxSP_3D + wx.wxSP_LIVE_UPDATE);
    local dLeft = wx.wxPanel(oSplitter, wx.wxID_ANY);
    local dRight = wx.wxPanel(oSplitter, wx.wxID_ANY);
    local oSearch = wx.wxTextCtrl(dLeft, wx.wxID_ANY);
    oSearch:SetHint("Search environment names");
    local oList = wx.wxListBox(dLeft, wx.wxID_ANY);
    local oDescription = wx.wxTextCtrl(dRight, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE + wx.wxTE_READONLY);
    oSearch:SetMinSize(wx.wxSize(200, -1));
    oList:SetMinSize(wx.wxSize(200, -1));
    oDescription:SetMinSize(wx.wxSize(300, -1));
    local oLeft = wx.wxBoxSizer(wx.wxVERTICAL);
    oLeft:Add(oSearch, 0, wx.wxEXPAND + wx.wxBOTTOM, 8);
    oLeft:Add(oList, 1, wx.wxEXPAND);
    dLeft:SetSizer(oLeft);
    local oRight = wx.wxBoxSizer(wx.wxVERTICAL);
    oRight:Add(oDescription, 1, wx.wxEXPAND + wx.wxLEFT, 12);
    dRight:SetSizer(oRight);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    oLayout:Add(oSplitter, 1, wx.wxEXPAND + wx.wxALL, 12);
    dBody:SetSizer(oLayout);
    local oFrameLayout = wx.wxBoxSizer(wx.wxVERTICAL); oFrameLayout:Add(dBody, 1, wx.wxEXPAND); dWindow:SetSizer(oFrameLayout);
    dWindow:Layout();
    local nSash = tonumber(INIFile.GetValue(FS.AppCFG, "EnvironmentReference", "DividerPosition")) or 340;
    oSplitter:SetMinimumPaneSize(180);
    oSplitter:SplitVertically(dLeft, dRight, nSash);
    oSplitter:Connect(wx.wxEVT_COMMAND_SPLITTER_SASH_POS_CHANGED, function(oEvent)
        INIFile.SetValue(FS.AppCFG, "EnvironmentReference", "DividerPosition", tostring(oSplitter:GetSashPosition()));
        oEvent:Skip();
    end);
    local tItems, tDocs = {}, {};
    local sPrevious;
    local function describe()
        local tItem = tItems[oList:GetSelection() + 1];
        oDescription:SetValue(tItem and Autocomplete.Describe(tItem, tDocs) or "");
    end
    local function refresh(bForce)
        Autocomplete.Style(oList, "suggestion"); Autocomplete.Style(oDescription, "documentation");
        local tSettings = require("Windows.EditorSettings").get();
        oList:SetFont(wx.wxFont(tSettings.referenceUseEditorFontSize and tSettings.size or tSettings.referenceListFontSize, wx.wxFONTFAMILY_MODERN, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL));
        oDescription:SetFont(wx.wxFont(tSettings.referenceUseEditorFontSize and tSettings.size or tSettings.referenceDescriptionFontSize, wx.wxFONTFAMILY_MODERN, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL));
        local tAll = Autocomplete.Read();
        local tKeys = {};
        for _, tItem in ipairs(tAll) do tKeys[#tKeys + 1] = tItem.name..":"..tItem.kind; end
        local sFilter = oSearch:GetValue():lower();
        local sCurrent = table.concat(tKeys, "\n").."\n"..sFilter;
        if (not bForce and sCurrent == sPrevious) then return; end
        sPrevious = sCurrent;
        local sSelected = oList:GetStringSelection();
        tItems = {}; oList:Clear(); tDocs = Autocomplete.Documentation();
        local nSelected = 0;
        for _, tItem in ipairs(tAll) do
            if (tItem.name:lower():find(sFilter, 1, true)) then
                tItems[#tItems + 1] = tItem; oList:Append(tItem.name);
                if (tItem.name == sSelected) then nSelected = #tItems - 1; end
            end
        end
        if (#tItems > 0) then oList:SetSelection(nSelected); end
        describe();
    end
    oSearch:Connect(wx.wxEVT_COMMAND_TEXT_UPDATED, function() refresh(true); end);
    oList:Connect(wx.wxEVT_COMMAND_LISTBOX_SELECTED, describe);
    local oTimer = wx.wxTimer(dWindow);
    dWindow:Connect(oTimer:GetId(), wx.wxEVT_TIMER, function() refresh(false); end);
    dWindow:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent) oTimer:Stop(); INIFile.SetValue(FS.AppCFG, "EnvironmentReference", "DividerPosition", tostring(oSplitter:GetSashPosition())); oEvent:Skip(); end);
    dWindow:Connect(wx.wxEVT_DESTROY, function(oEvent) if (oEvent:GetId() == dWindow:GetId()) then oTimer:Stop(); oState.close(); end oEvent:Skip(); end);
    refresh(true); oTimer:Start(500);
    return {window = dWindow, search = oSearch, list = oList, description = oDescription, splitter = oSplitter, refresh = refresh};
end

function EnvironmentReference.show(dParent)
    local tWindow = EnvironmentReference.create(dParent);
    tWindow.window:Show();
    return tWindow;
end

return EnvironmentReference;
