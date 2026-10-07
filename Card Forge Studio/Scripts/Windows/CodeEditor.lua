-- Modal Lua code-cell editor. The draft stays in memory until Apply.
-- TODO Required window persistence: save position and size on move, resize, and
-- close; restore them when this dialog is reopened.
local wx = require("wx");
local wxstc = wxstc;
local Base64 = require("Plugins.LuaEx.lib.base64");
local CodeEditor = {};

function CodeEditor.create(dParent, sEncoded, sTitle)
    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, sTitle or "Code Editor",
        wx.wxDefaultPosition, wx.wxSize(800, 600), wx.wxDEFAULT_DIALOG_STYLE + wx.wxRESIZE_BORDER);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oCode = wxstc.wxStyledTextCtrl(dDialog, wx.wxID_ANY);
    local oStatus = wx.wxStaticText(dDialog, wx.wxID_ANY, "Syntax checking does not execute your code.");
    local oButtons = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oCheck = wx.wxButton(dDialog, wx.wxID_ANY, "Check Syntax");
    local oApply = wx.wxButton(dDialog, wx.wxID_OK, "Apply");
    local oCancel = wx.wxButton(dDialog, wx.wxID_CANCEL, "Cancel");
    local sResult;

    oCode:SetLexer(wxstc.wxSTC_LEX_LUA);
    oCode:SetKeyWords(0, "and break do else elseif end false for function goto if in local nil not or repeat return then true until while");
    oCode:StyleSetFont(wxstc.wxSTC_STYLE_DEFAULT,
        wx.wxFont(11, wx.wxFONTFAMILY_TELETYPE, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL));
    oCode:StyleClearAll();
    oCode:StyleSetForeground(wxstc.wxSTC_LUA_WORD, wx.wxColour(35, 70, 180));
    oCode:StyleSetForeground(wxstc.wxSTC_LUA_COMMENT, wx.wxColour(40, 120, 50));
    oCode:StyleSetForeground(wxstc.wxSTC_LUA_STRING, wx.wxColour(150, 60, 40));
    oCode:SetMarginType(0, wxstc.wxSTC_MARGIN_NUMBER);
    oCode:SetMarginWidth(0, 48);
    oCode:SetTabWidth(4);
    oCode:SetUseTabs(false);
    oCode:SetText(Base64.dec(sEncoded));
    oCode:EmptyUndoBuffer();

    local function checkSyntax()
        local sCode = oCode:GetText();
        local fChunk, sError = load(sCode, "Code cell", "t", {});
        oStatus:SetLabel(fChunk and "Syntax valid." or sError);

        return fChunk ~= nil;
    end

    oCheck:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, checkSyntax);
    oApply:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        if (checkSyntax()) then
            sResult = Base64.enc(oCode:GetText());
            dDialog:EndModal(wx.wxID_OK);
        end
    end);

    oButtons:Add(oCheck, 0, wx.wxALL, 4);
    oButtons:AddStretchSpacer(1);
    oButtons:Add(oApply, 0, wx.wxALL, 4);
    oButtons:Add(oCancel, 0, wx.wxALL, 4);
    oLayout:Add(oCode, 1, wx.wxEXPAND + wx.wxALL, 8);
    oLayout:Add(oStatus, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 8);
    oLayout:Add(oButtons, 0, wx.wxEXPAND + wx.wxALL, 4);
    dDialog:SetSizer(oLayout);

    return {dialog = dDialog, editor = oCode, apply = oApply, cancel = oCancel, checkSyntax = checkSyntax,
        getResult = function() return sResult; end};
end

function CodeEditor.edit(dParent, sEncoded, sTitle)
    local tEditor = CodeEditor.create(dParent, sEncoded, sTitle);
    local nResult = tEditor.dialog:ShowModal();
    local sResult = nResult == wx.wxID_OK and tEditor.getResult() or nil;
    tEditor.dialog:Destroy();

    return sResult;
end

return CodeEditor;
