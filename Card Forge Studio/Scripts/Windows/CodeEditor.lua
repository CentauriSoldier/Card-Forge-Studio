-- Modal Lua code-cell editor. The draft stays in memory until Apply.
local wx = require("wx");
local wxstc = wxstc;
local Base64 = require("Plugins.LuaEx.lib.base64");
local CodeEditor = {};
local EditorSettings = require("Windows.EditorSettings");
local WindowState = require("Windows.WindowState");
local _tWindowState = {
    savePosition = true,
    saveSize     = true,
    saveVisible  = false,
};
WindowState.register("CodeEditor", _tWindowState);

function CodeEditor.create(dParent, sEncoded, sTitle)
    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, sTitle or "Code Editor",
        wx.wxDefaultPosition, wx.wxSize(800, 600), wx.wxDEFAULT_DIALOG_STYLE + wx.wxRESIZE_BORDER);
    local oWindowState = WindowState.bind(dDialog, "CodeEditor");
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oCode = wxstc.wxStyledTextCtrl(dDialog, wx.wxID_ANY);
    local oStatus = wx.wxStaticText(dDialog, wx.wxID_ANY, "");
    local oButtons = wx.wxBoxSizer(wx.wxHORIZONTAL);

    local oApply = wx.wxButton(dDialog, wx.wxID_OK, "Apply");
    local oCancel = wx.wxButton(dDialog, wx.wxID_CANCEL, "Cancel");
    local oSyntaxTimer = wx.wxTimer(dDialog);
    local sResult;

    EditorSettings.configure(oCode, "lua");
    local oThemeBar, oTheme, oFontSize, unregister = EditorSettings.bar(dDialog, {oCode});
    oCode:SetText(Base64.dec(sEncoded));
    oCode:EmptyUndoBuffer();

    local function checkSyntax()
        local fChunk, sError = load(oCode:GetText(), "Code cell", "t", {});
        oStatus:SetLabel(fChunk and "" or sError);
        oStatus:Show(fChunk == nil);
        oApply:Enable(fChunk ~= nil);
        dDialog:Layout();
        return fChunk ~= nil;
    end
    oStatus:SetForegroundColour(wx.wxColour(170, 25, 25));
    oStatus:Hide();
    oCode:Connect(wxstc.wxEVT_STC_CHANGE, function()
        oSyntaxTimer:Start(250, true);
    end);
    dDialog:Connect(oSyntaxTimer:GetId(), wx.wxEVT_TIMER, checkSyntax);
    dDialog:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        oSyntaxTimer:Stop();
        unregister();
        oEvent:Skip();
    end);

    oApply:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        if (checkSyntax()) then
            oSyntaxTimer:Stop();
            unregister();
            sResult = Base64.enc(oCode:GetText());
            dDialog:EndModal(wx.wxID_OK);
        end
    end);
    oCancel:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        oSyntaxTimer:Stop();
        unregister();
        dDialog:EndModal(wx.wxID_CANCEL);
    end);

    oLayout:Add(oThemeBar, 0, wx.wxEXPAND + wx.wxALL, 8);

    oButtons:AddStretchSpacer(1);
    oButtons:Add(oApply, 0, wx.wxALL, 4);
    oButtons:Add(oCancel, 0, wx.wxALL, 4);
    oLayout:Add(oCode, 1, wx.wxEXPAND + wx.wxALL, 8);
    oLayout:Add(oStatus, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 8);
    oLayout:Add(oButtons, 0, wx.wxEXPAND + wx.wxALL, 4);
    dDialog:SetSizer(oLayout);
    checkSyntax();
    return {dialog = dDialog, editor = oCode, apply = oApply, cancel = oCancel, checkSyntax = checkSyntax,
        theme = oTheme, fontSize = oFontSize, status = oStatus, syntaxTimer = oSyntaxTimer,
        windowState = oWindowState, getResult = function() return sResult; end};
end

function CodeEditor.edit(dParent, sEncoded, sTitle)
    local tEditor = CodeEditor.create(dParent, sEncoded, sTitle);
    local nResult = tEditor.dialog:ShowModal();
    local sResult = nResult == wx.wxID_OK and tEditor.getResult() or nil;
    tEditor.windowState.close();
    tEditor.dialog:Destroy();
    return sResult;
end

return CodeEditor;
