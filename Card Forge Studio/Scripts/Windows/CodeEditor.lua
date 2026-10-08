-- Modal Lua code-cell editor. The draft stays in memory until Apply.
local wx = require("wx");
local wxstc = wxstc;
local Base64 = require("Plugins.LuaEx.lib.base64");
local CodeEditor = {};
local WindowState = require("Windows.WindowState");
local _tWindowState = {
    savePosition = true,
    saveSize     = true,
    saveVisible  = false,
};
WindowState.register("CodeEditor", _tWindowState);

local _nTheme = 0;
local _aFontSizes = {8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 28, 32, 36,};
-- Background, text, comments, keywords, literals, strings, numbers, operators,
-- caret, selection, gutter text, current line.
local _tThemes = {
    {name = "Default", marginBackground = "#FFFFFF", marginForeground = "#555555", foldBackground = "#FFFFFF", foldForeground = "#555555", colors = {"#FFFFFF", "#000000", "#287832", "#2346B4", "#2346B4", "#963C28", "#000000", "#000000", "#000000", "#C0D8FF", "#555555", "#F5F5F5",},},
    {name = "Zenburn", marginBackground = "#454545", marginForeground = "#B8C8C8", foldBackground = "#494949", foldForeground = "#B8C8C8", colors = {"#3F3F3F", "#DCDCCC", "#7F9F7F", "#F0DFAF", "#DCA3A3", "#CC9393", "#8CD0D3", "#F0EFD0", "#DCDCCC", "#585858", "#9FAFAF", "#494949",},},
    {name = "Synthwave Protocol", marginBackground = "#100B27", marginForeground = "#3AA0FF", foldBackground = "#150F2E", foldForeground = "#3AA0FF", colors = {"#0B0620", "#D0D0F0", "#5F7A9A", "#00B7FF", "#FFF1A8", "#B98B6A", "#FF3B6A", "#FF3B6A", "#FF0000", "#2A1A62", "#3AA0FF", "#140B34",},},
};

function CodeEditor.create(dParent, sEncoded, sTitle)
    local sSavedTheme = INIFile.GetValue(FS.AppCFG, "CodeEditor", "Theme");
    for nIndex, tTheme in ipairs(_tThemes) do
        if (tTheme.name == sSavedTheme) then
            _nTheme = nIndex - 1;
            break;
        end
    end
    local nFontSize = 11;
    local nFontSelection = 3;
    local nSavedFontSize = tonumber(INIFile.GetValue(FS.AppCFG, "CodeEditor", "FontSize"));
    local aFontNames = {};
    for nIndex, nSize in ipairs(_aFontSizes) do
        aFontNames[#aFontNames + 1] = tostring(nSize);
        if (nSize == nSavedFontSize) then
            nFontSize = nSize;
            nFontSelection = nIndex - 1;
        end
    end
    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, sTitle or "Code Editor",
        wx.wxDefaultPosition, wx.wxSize(800, 600), wx.wxDEFAULT_DIALOG_STYLE + wx.wxRESIZE_BORDER);
    local oWindowState = WindowState.bind(dDialog, "CodeEditor");
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oThemeBar = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local aNames = {};
    for _, tTheme in ipairs(_tThemes) do
        aNames[#aNames + 1] = tTheme.name;
    end
    local oTheme = wx.wxChoice(dDialog, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, aNames);
    local oFontSize = wx.wxChoice(dDialog, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, aFontNames);
    oFontSize:SetSelection(nFontSelection);
    local oCode = wxstc.wxStyledTextCtrl(dDialog, wx.wxID_ANY);
    local oStatus = wx.wxStaticText(dDialog, wx.wxID_ANY, "");
    local oButtons = wx.wxBoxSizer(wx.wxHORIZONTAL);

    local oApply = wx.wxButton(dDialog, wx.wxID_OK, "Apply");
    local oCancel = wx.wxButton(dDialog, wx.wxID_CANCEL, "Cancel");
    local oSyntaxTimer = wx.wxTimer(dDialog);
    local sResult;

    oCode:SetLexer(wxstc.wxSTC_LEX_LUA);
    oCode:SetKeyWords(0, "and break do else elseif end for function goto if in local not or repeat return then until while");
    oCode:SetKeyWords(1, "false nil true");
    oCode:StyleSetFont(wxstc.wxSTC_STYLE_DEFAULT,
        wx.wxFont(nFontSize, wx.wxFONTFAMILY_TELETYPE, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL));
    local function applyTheme()
        oCode:StyleSetFont(wxstc.wxSTC_STYLE_DEFAULT,
            wx.wxFont(nFontSize, wx.wxFONTFAMILY_TELETYPE, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL));
        local tTheme = _tThemes[_nTheme + 1];
        local aColors = tTheme.colors;
        oCode:StyleSetBackground(wxstc.wxSTC_STYLE_DEFAULT, wx.wxColour(aColors[1]));
        oCode:StyleSetForeground(wxstc.wxSTC_STYLE_DEFAULT, wx.wxColour(aColors[2]));
        oCode:StyleClearAll();
        local tStyles = {
            {wxstc.wxSTC_LUA_COMMENT, 3,}, {wxstc.wxSTC_LUA_COMMENTLINE, 3,},
            {wxstc.wxSTC_LUA_COMMENTDOC, 3,}, {wxstc.wxSTC_LUA_WORD, 4,},
            {wxstc.wxSTC_LUA_WORD2, 5,}, {wxstc.wxSTC_LUA_STRING, 6,},
            {wxstc.wxSTC_LUA_CHARACTER, 6,}, {wxstc.wxSTC_LUA_LITERALSTRING, 6,},
            {wxstc.wxSTC_LUA_NUMBER, 7,}, {wxstc.wxSTC_LUA_OPERATOR, 8,},
            {wxstc.wxSTC_STYLE_LINENUMBER, 11,},
        };
        for _, tStyle in ipairs(tStyles) do
            oCode:StyleSetForeground(tStyle[1], wx.wxColour(aColors[tStyle[2]]));
        end
        oCode:StyleSetForeground(wxstc.wxSTC_STYLE_LINENUMBER, wx.wxColour(tTheme.marginForeground));
        oCode:StyleSetBackground(wxstc.wxSTC_STYLE_LINENUMBER, wx.wxColour(tTheme.marginBackground));
        oCode:SetFoldMarginColour(true, wx.wxColour(tTheme.foldBackground));
        oCode:SetFoldMarginHiColour(true, wx.wxColour(tTheme.foldBackground));
        for nMarker = wxstc.wxSTC_MARKNUM_FOLDEREND, wxstc.wxSTC_MARKNUM_FOLDEROPEN do
            oCode:MarkerSetForeground(nMarker, wx.wxColour(tTheme.foldForeground));
            oCode:MarkerSetBackground(nMarker, wx.wxColour(tTheme.foldBackground));
        end
        oCode:SetCaretForeground(wx.wxColour(aColors[9]));
        oCode:SetSelBackground(true, wx.wxColour(aColors[10]));
        oCode:SetCaretLineBackground(wx.wxColour(aColors[12]));
        oCode:SetCaretLineVisible(true);
        oCode:SetMarginWidth(0, oCode:TextWidth(wxstc.wxSTC_STYLE_LINENUMBER, '9999') + 12);
        oCode:Colourise(0, -1);
        oCode:Refresh();
    end
    oTheme:SetSelection(_nTheme);
    applyTheme();
    oTheme:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, function()
        _nTheme = oTheme:GetSelection();
        local bSaved, sError = pcall(INIFile.SetValue, FS.AppCFG, "CodeEditor", "Theme", _tThemes[_nTheme + 1].name);
        if (not bSaved) then
            require("Errors").report(sError);
        end
        applyTheme();
    end);
    oFontSize:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, function()
        nFontSize = _aFontSizes[oFontSize:GetSelection() + 1];
        local bSaved, sError = pcall(INIFile.SetValue, FS.AppCFG, "CodeEditor", "FontSize", tostring(nFontSize));
        if (not bSaved) then
            require("Errors").report(sError);
        end
        applyTheme();
    end);
    oCode:SetMarginType(0, wxstc.wxSTC_MARGIN_NUMBER);
    oCode:SetMarginWidth(0, oCode:TextWidth(wxstc.wxSTC_STYLE_LINENUMBER, '9999') + 12);
    oCode:SetProperty("fold", "1");
    oCode:SetProperty("fold.comment", "1");
    oCode:SetMarginType(1, wxstc.wxSTC_MARGIN_SYMBOL);
    oCode:SetMarginMask(1, wxstc.wxSTC_MASK_FOLDERS);
    oCode:SetMarginSensitive(1, true);
    oCode:SetMarginWidth(1, 16);
    oCode:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDER, wxstc.wxSTC_MARK_BOXPLUS);
    oCode:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDEROPEN, wxstc.wxSTC_MARK_BOXMINUS);
    oCode:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDERSUB, wxstc.wxSTC_MARK_VLINE);
    oCode:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDERTAIL, wxstc.wxSTC_MARK_LCORNER);
    oCode:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDEREND, wxstc.wxSTC_MARK_BOXPLUSCONNECTED);
    oCode:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDEROPENMID, wxstc.wxSTC_MARK_BOXMINUSCONNECTED);
    oCode:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDERMIDTAIL, wxstc.wxSTC_MARK_TCORNER);
    oCode:Connect(wxstc.wxEVT_STC_MARGINCLICK, function(oEvent)
        if (oEvent:GetMargin() == 1) then
            oCode:ToggleFold(oCode:LineFromPosition(oEvent:GetPosition()));
        end
    end);
    oCode:SetTabWidth(4);
    oCode:SetUseTabs(false);
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
        oEvent:Skip();
    end);

    oApply:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        if (checkSyntax()) then
            oSyntaxTimer:Stop();
            sResult = Base64.enc(oCode:GetText());
            dDialog:EndModal(wx.wxID_OK);
        end
    end);
    oCancel:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        oSyntaxTimer:Stop();
        dDialog:EndModal(wx.wxID_CANCEL);
    end);

    oThemeBar:Add(wx.wxStaticText(dDialog, wx.wxID_ANY, "Theme:"), 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxRIGHT, 8);
    oThemeBar:Add(oTheme, 0, wx.wxALIGN_CENTER_VERTICAL, 0);
    oThemeBar:Add(wx.wxStaticText(dDialog, wx.wxID_ANY, "Font size:"), 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxLEFT + wx.wxRIGHT, 8);
    oThemeBar:Add(oFontSize, 0, wx.wxALIGN_CENTER_VERTICAL, 0);
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
