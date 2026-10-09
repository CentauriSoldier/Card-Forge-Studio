-- Shared preferences and registered editor controls. Manual changes notify all editors.
local wx = require("wx");
local wxstc = wxstc;
local EditorSettings = {};
local _aFontSizes = {8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 28, 32, 36,};
-- Background, text, comments, keywords, literals, strings, numbers, operators,
-- caret, selection, gutter text, current line.
local _tThemes = {
    {name = "Default", marginBackground = "#FFFFFF", marginForeground = "#555555", foldBackground = "#FFFFFF", foldForeground = "#555555", colors = {"#FFFFFF", "#000000", "#287832", "#2346B4", "#2346B4", "#963C28", "#000000", "#000000", "#000000", "#C0D8FF", "#555555", "#F5F5F5",},},
    {name = "Zenburn", marginBackground = "#454545", marginForeground = "#B8C8C8", foldBackground = "#494949", foldForeground = "#B8C8C8", colors = {"#3F3F3F", "#DCDCCC", "#7F9F7F", "#F0DFAF", "#DCA3A3", "#CC9393", "#8CD0D3", "#F0EFD0", "#DCDCCC", "#585858", "#9FAFAF", "#494949",},},
    {name = "Synthwave Protocol", marginBackground = "#100B27", marginForeground = "#3AA0FF", foldBackground = "#150F2E", foldForeground = "#3AA0FF", colors = {"#0B0620", "#D0D0F0", "#5F7A9A", "#00B7FF", "#FFF1A8", "#B98B6A", "#FF3B6A", "#FF3B6A", "#FF0000", "#2A1A62", "#3AA0FF", "#140B34",},},
};

local _tCurrent;
local _tEditors = {};
local function current()
    if (_tCurrent) then return _tCurrent; end
    _tCurrent = {theme = 0, size = 11};
    local sTheme = INIFile.GetValue(FS.AppCFG, "CodeEditor", "Theme");
    for nIndex, tTheme in ipairs(_tThemes) do
        if (tTheme.name == sTheme) then _tCurrent.theme = nIndex - 1; end
    end
    local nSize = tonumber(INIFile.GetValue(FS.AppCFG, "CodeEditor", "FontSize"));
    for _, nValue in ipairs(_aFontSizes) do
        if (nValue == nSize) then _tCurrent.size = nSize; end
    end
    return _tCurrent;
end
function EditorSettings.apply(oCode)
        oCode:StyleSetFont(wxstc.wxSTC_STYLE_DEFAULT,
            wx.wxFont(_tCurrent.size, wx.wxFONTFAMILY_TELETYPE, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL));
        local tTheme = _tThemes[_tCurrent.theme + 1];
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
function EditorSettings.register(dWindow, tControls, fUpdated)
    current();
    local tEntry = {window = dWindow, controls = tControls, update = fUpdated};
    _tEditors[tEntry] = true;
    local function update()
        for _, oCode in ipairs(tControls) do EditorSettings.apply(oCode); end
        if (fUpdated) then fUpdated(_tCurrent); end
    end
    tEntry.refresh = update;
    update();
    local bRegistered = true;
    local function unregister()
        if (bRegistered) then _tEditors[tEntry] = nil; bRegistered = false; end
    end
    local nWindowID = dWindow:GetId();
    dWindow:Connect(wx.wxEVT_DESTROY, function(oEvent)
        if (oEvent:GetId() == nWindowID) then unregister(); end
        oEvent:Skip();
    end);
    return unregister;
end
function EditorSettings.set(sKey, nValue)
    current();
    local bValid = sKey == "theme" and _tThemes[nValue + 1] ~= nil;
    if (sKey == "size") then
        for _, nSize in ipairs(_aFontSizes) do if (nSize == nValue) then bValid = true; end end
    end
    assert(bValid, "Invalid editor preference.");
    INIFile.SetValue(FS.AppCFG, "CodeEditor", sKey == "theme" and "Theme" or "FontSize",
        sKey == "theme" and _tThemes[nValue + 1].name or tostring(nValue));
    _tCurrent[sKey] = nValue;
    for tEntry in pairs(_tEditors) do tEntry.refresh(); end
end
function EditorSettings.bar(dParent, tControls)
    local oBar = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local tNames, tSizes = {}, {};
    for _, tTheme in ipairs(_tThemes) do tNames[#tNames + 1] = tTheme.name; end
    for _, nSize in ipairs(_aFontSizes) do tSizes[#tSizes + 1] = tostring(nSize); end
    local oTheme = wx.wxChoice(dParent, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, tNames);
    local oSize = wx.wxChoice(dParent, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, tSizes);
    local unregister = EditorSettings.register(dParent, tControls, function(tState)
        oTheme:SetSelection(tState.theme);
        oSize:SetStringSelection(tostring(tState.size));
    end);
    local function set(sKey, nValue)
        local bOK, sError = pcall(EditorSettings.set, sKey, nValue);
        if (not bOK) then require("Errors").report(sError); end
    end
    oTheme:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, function() set("theme", oTheme:GetSelection()); end);
    oSize:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, function() set("size", tonumber(oSize:GetStringSelection())); end);
    oBar:Add(wx.wxStaticText(dParent, wx.wxID_ANY, "Theme:"), 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxRIGHT, 8);
    oBar:Add(oTheme, 0, wx.wxALIGN_CENTER_VERTICAL);
    oBar:Add(wx.wxStaticText(dParent, wx.wxID_ANY, "Font size:"), 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxLEFT + wx.wxRIGHT, 8);
    oBar:Add(oSize, 0, wx.wxALIGN_CENTER_VERTICAL);
    return oBar, oTheme, oSize, unregister;
end
function EditorSettings.configure(oCode, sKind)
    oCode:SetLexer(sKind == "lua" and wxstc.wxSTC_LEX_LUA or sKind == "ini" and wxstc.wxSTC_LEX_PROPERTIES or wxstc.wxSTC_LEX_NULL);
    oCode:SetKeyWords(0, "and break do else elseif end for function goto if in local not or repeat return then until while");
    oCode:SetKeyWords(1, "false nil true");
    oCode:SetMarginType(0, wxstc.wxSTC_MARGIN_NUMBER);
    oCode:SetProperty("fold", "1"); oCode:SetProperty("fold.comment", "1");
    oCode:SetMarginType(1, wxstc.wxSTC_MARGIN_SYMBOL);
    oCode:SetMarginMask(1, wxstc.wxSTC_MASK_FOLDERS);
    oCode:SetMarginSensitive(1, true); oCode:SetMarginWidth(1, sKind == "lua" and 16 or 0);
    local tMarkers = {
        {wxstc.wxSTC_MARKNUM_FOLDER, wxstc.wxSTC_MARK_BOXPLUS},
        {wxstc.wxSTC_MARKNUM_FOLDEROPEN, wxstc.wxSTC_MARK_BOXMINUS},
        {wxstc.wxSTC_MARKNUM_FOLDERSUB, wxstc.wxSTC_MARK_VLINE},
        {wxstc.wxSTC_MARKNUM_FOLDERTAIL, wxstc.wxSTC_MARK_LCORNER},
        {wxstc.wxSTC_MARKNUM_FOLDEREND, wxstc.wxSTC_MARK_BOXPLUSCONNECTED},
        {wxstc.wxSTC_MARKNUM_FOLDEROPENMID, wxstc.wxSTC_MARK_BOXMINUSCONNECTED},
        {wxstc.wxSTC_MARKNUM_FOLDERMIDTAIL, wxstc.wxSTC_MARK_TCORNER},
    };
    for _, tMarker in ipairs(tMarkers) do oCode:MarkerDefine(tMarker[1], tMarker[2]); end
    oCode:Connect(wxstc.wxEVT_STC_MARGINCLICK, function(oEvent)
        if (oEvent:GetMargin() == 1) then oCode:ToggleFold(oCode:LineFromPosition(oEvent:GetPosition())); end
    end);
    oCode:SetTabWidth(4); oCode:SetUseTabs(false);
end
function EditorSettings.count()
    local nCount = 0;
    for _ in pairs(_tEditors) do nCount = nCount + 1; end
    return nCount;
end
return EditorSettings;