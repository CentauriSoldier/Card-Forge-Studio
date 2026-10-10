--[[!
@fqxn CFS.Windows.EditorSettings
@desc Shared code-editor preferences, palettes, controls, and save-time whitespace policies.
!]]

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

-- Adapted palettes; token mappings and readable gutters are specific to this editor.
-- Sources: github.com/dracula/dracula-theme, nordtheme/nord, morhetz/gruvbox,
-- catppuccin/catppuccin, rose-pine/palette, altercation/solarized, folke/tokyonight.nvim.
_tThemes[#_tThemes + 1] = {name = "Dracula", marginBackground = "#44475A", marginForeground = "#F8F8F2", foldBackground = "#44475A", foldForeground = "#6272A4", colors = {"#282A36", "#F8F8F2", "#6272A4", "#FF79C6", "#BD93F9", "#F1FA8C", "#BD93F9", "#F8F8F2", "#F8F8F2", "#44475A", "#6272A4", "#44475A",},};
_tThemes[#_tThemes + 1] = {name = "Alucard", marginBackground = "#CFCFDE", marginForeground = "#1F1F1F", foldBackground = "#CFCFDE", foldForeground = "#6C664B", colors = {"#FFFBEB", "#1F1F1F", "#6C664B", "#A3144D", "#644AC9", "#14710A", "#A34D14", "#036A96", "#1F1F1F", "#CFCFDE", "#6C664B", "#CFCFDE",},};
_tThemes[#_tThemes + 1] = {name = "Nord", marginBackground = "#3B4252", marginForeground = "#D8DEE9", foldBackground = "#3B4252", foldForeground = "#81A1C1", colors = {"#2E3440", "#D8DEE9", "#81A1C1", "#81A1C1", "#B48EAD", "#A3BE8C", "#B48EAD", "#88C0D0", "#D8DEE9", "#3B4252", "#81A1C1", "#3B4252",},};
_tThemes[#_tThemes + 1] = {name = "Gruvbox Dark", marginBackground = "#3C3836", marginForeground = "#EBDBB2", foldBackground = "#3C3836", foldForeground = "#928374", colors = {"#282828", "#EBDBB2", "#928374", "#FB4934", "#D3869B", "#B8BB26", "#D3869B", "#FE8019", "#EBDBB2", "#3C3836", "#928374", "#3C3836",},};
_tThemes[#_tThemes + 1] = {name = "Gruvbox Light", marginBackground = "#EBDBB2", marginForeground = "#3C3836", foldBackground = "#EBDBB2", foldForeground = "#928374", colors = {"#FBF1C7", "#3C3836", "#928374", "#9D0006", "#8F3F71", "#79740E", "#8F3F71", "#AF3A03", "#3C3836", "#EBDBB2", "#928374", "#EBDBB2",},};
_tThemes[#_tThemes + 1] = {name = "Catppuccin Mocha", marginBackground = "#313244", marginForeground = "#CDD6F4", foldBackground = "#313244", foldForeground = "#9399B2", colors = {"#1E1E2E", "#CDD6F4", "#9399B2", "#CBA6F7", "#FAB387", "#A6E3A1", "#FAB387", "#89DCEB", "#CDD6F4", "#313244", "#9399B2", "#313244",},};
_tThemes[#_tThemes + 1] = {name = "Catppuccin Macchiato", marginBackground = "#363A4F", marginForeground = "#CAD3F5", foldBackground = "#363A4F", foldForeground = "#939AB7", colors = {"#24273A", "#CAD3F5", "#939AB7", "#C6A0F6", "#F5A97F", "#A6DA95", "#F5A97F", "#8BD5CA", "#CAD3F5", "#363A4F", "#939AB7", "#363A4F",},};
_tThemes[#_tThemes + 1] = {name = "Catppuccin Frappe", marginBackground = "#414559", marginForeground = "#C6D0F5", foldBackground = "#414559", foldForeground = "#949CBB", colors = {"#303446", "#C6D0F5", "#949CBB", "#CA9EE6", "#EF9F76", "#A6D189", "#EF9F76", "#81C8BE", "#C6D0F5", "#414559", "#949CBB", "#414559",},};
_tThemes[#_tThemes + 1] = {name = "Catppuccin Latte", marginBackground = "#CCD0DA", marginForeground = "#4C4F69", foldBackground = "#CCD0DA", foldForeground = "#7C7F93", colors = {"#EFF1F5", "#4C4F69", "#7C7F93", "#8839EF", "#FE640B", "#40A02B", "#FE640B", "#179299", "#4C4F69", "#CCD0DA", "#7C7F93", "#CCD0DA",},};
_tThemes[#_tThemes + 1] = {name = "Rose Pine", marginBackground = "#26233A", marginForeground = "#E0DEF4", foldBackground = "#26233A", foldForeground = "#908CAA", colors = {"#191724", "#E0DEF4", "#908CAA", "#C4A7E7", "#EB6F92", "#F6C177", "#EBBCBA", "#9CCFD8", "#E0DEF4", "#26233A", "#908CAA", "#26233A",},};
_tThemes[#_tThemes + 1] = {name = "Rose Pine Moon", marginBackground = "#393552", marginForeground = "#E0DEF4", foldBackground = "#393552", foldForeground = "#908CAA", colors = {"#232136", "#E0DEF4", "#908CAA", "#C4A7E7", "#EB6F92", "#F6C177", "#EA9A97", "#9CCFD8", "#E0DEF4", "#393552", "#908CAA", "#393552",},};
_tThemes[#_tThemes + 1] = {name = "Rose Pine Dawn", marginBackground = "#F2E9E1", marginForeground = "#464261", foldBackground = "#F2E9E1", foldForeground = "#797593", colors = {"#FAF4ED", "#464261", "#797593", "#907AA9", "#B4637A", "#EA9D34", "#D7827E", "#286983", "#464261", "#F2E9E1", "#797593", "#F2E9E1",},};
_tThemes[#_tThemes + 1] = {name = "Solarized Dark", marginBackground = "#073642", marginForeground = "#839496", foldBackground = "#073642", foldForeground = "#657B83", colors = {"#002B36", "#839496", "#657B83", "#859900", "#CB4B16", "#2AA198", "#D33682", "#268BD2", "#839496", "#073642", "#657B83", "#073642",},};
_tThemes[#_tThemes + 1] = {name = "Solarized Light", marginBackground = "#EEE8D5", marginForeground = "#657B83", foldBackground = "#EEE8D5", foldForeground = "#839496", colors = {"#FDF6E3", "#657B83", "#839496", "#859900", "#CB4B16", "#2AA198", "#D33682", "#268BD2", "#657B83", "#EEE8D5", "#839496", "#EEE8D5",},};
_tThemes[#_tThemes + 1] = {name = "Tokyo Night", marginBackground = "#292E42", marginForeground = "#C0CAF5", foldBackground = "#292E42", foldForeground = "#737AA2", colors = {"#1A1B26", "#C0CAF5", "#737AA2", "#BB9AF7", "#FF9E64", "#9ECE6A", "#FF9E64", "#7DCFFF", "#C0CAF5", "#292E42", "#737AA2", "#292E42",},};
_tThemes[#_tThemes + 1] = {name = "Tokyo Night Storm", marginBackground = "#292E42", marginForeground = "#C0CAF5", foldBackground = "#292E42", foldForeground = "#737AA2", colors = {"#24283B", "#C0CAF5", "#737AA2", "#BB9AF7", "#FF9E64", "#9ECE6A", "#FF9E64", "#7DCFFF", "#C0CAF5", "#292E42", "#737AA2", "#292E42",},};
_tThemes[#_tThemes + 1] = {name = "Tokyo Night Moon", marginBackground = "#2F334D", marginForeground = "#C8D3F5", foldBackground = "#2F334D", foldForeground = "#828BB8", colors = {"#222436", "#C8D3F5", "#828BB8", "#C099FF", "#FF966C", "#C3E88D", "#FF966C", "#86E1FC", "#C8D3F5", "#2F334D", "#828BB8", "#2F334D",},};

--[[!
@fqxn CFS.Windows.EditorSettings.themes
@pulsarlua function EditorSettings.themes
@desc Returns the registered editor palettes, including token, gutter, and folding colors.
!]]
function EditorSettings.themes()
    return _tThemes;
end

local _tDefinitions = {
    trimTrailing = {setting = "TrimTrailingWhitespace", default = false},
    finalNewline = {setting = "FinalNewline", default = false},
    autoClose = {setting = "AutoClose", default = false},
    scrollPastEnd = {setting = "ScrollPastEnd", default = false},
    useTabs = {setting = "UseTabs", default = false},
    tabWidth = {setting = "TabWidth", default = 4, min = 1, max = 8},
    autoIndent = {setting = "AutoIndent", default = false},
    tabIndents = {setting = "TabIndents", default = true},
    backspaceUnindents = {setting = "BackspaceUnindents", default = false},
    wordWrap = {setting = "WordWrap", default = false},
    whitespace = {setting = "ShowWhitespace", default = false},
    lineEndings = {setting = "ShowLineEndings", default = false},
    indentGuides = {setting = "IndentGuides", default = false},
    lineNumbers = {setting = "LineNumbers", default = true},
    folding = {setting = "Folding", default = true},
    currentLine = {setting = "HighlightCurrentLine", default = true},
    columnGuide = {setting = "ColumnGuide", default = false},
    column = {setting = "GuideColumn", default = 80, min = 20, max = 240},
};
local _tCurrent;
local _tEditors = {};
--[[!
@fqxn CFS.Windows.EditorSettings.Private.current
@desc Loads validated editor preferences once, using built-in defaults for missing or unsupported values.
@vis private
!]]
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
    for sKey, tDefinition in pairs(_tDefinitions) do
        local sValue = INIFile.GetValue(FS.AppCFG, "CodeEditor", tDefinition.setting);
        local vValue = tDefinition.default;
        if (type(vValue) == "boolean") then
            if (sValue == "1" or sValue == "0") then vValue = sValue == "1"; end
        else
            local nValue = tonumber(sValue);
            if (nValue and nValue == math.floor(nValue) and nValue >= tDefinition.min and nValue <= tDefinition.max) then vValue = nValue; end
        end
        _tCurrent[sKey] = vValue;
    end
    return _tCurrent;
end
--[[!
@fqxn CFS.Windows.EditorSettings.get
@pulsarlua function EditorSettings.get
@desc Returns a copy of current editor preferences.
!]]
function EditorSettings.get()
    local tCopy = {};
    for sKey, vValue in pairs(current()) do tCopy[sKey] = vValue; end
    return tCopy;
end
--[[!
@fqxn CFS.Windows.EditorSettings.sizes
@pulsarlua function EditorSettings.sizes
@desc Returns a copy of supported editor font sizes.
!]]
function EditorSettings.sizes()
    local tCopy = {};
    for nIndex, nSize in ipairs(_aFontSizes) do tCopy[nIndex] = nSize; end
    return tCopy;
end
--[[!
@fqxn CFS.Windows.EditorSettings.Private.matchBrackets
@desc Highlights a matched or unmatched bracket at or immediately before the caret.
@vis private
@param any oCode Code.
!]]
local function matchBrackets(oCode)
    local nPosition, nBrace = oCode:GetCurrentPos(), -1;
    for _, nCandidate in ipairs({nPosition, nPosition - 1}) do
        if (nCandidate >= 0 and nCandidate < oCode:GetLength()) then
            local nChar = oCode:GetCharAt(nCandidate);
            if (nChar == 40 or nChar == 41 or nChar == 91 or nChar == 93 or nChar == 123 or nChar == 125 or nChar == 60 or nChar == 62) then
                nBrace = nCandidate; break;
            end
        end
    end
    local nMatch = nBrace >= 0 and oCode:BraceMatch(nBrace) or -1;
    if (nBrace < 0) then oCode:BraceHighlight(-1, -1);
    elseif (nMatch < 0) then oCode:BraceBadLight(nBrace);
    else oCode:BraceHighlight(nBrace, nMatch); end
    return nBrace, nMatch;
end
--[[!
@fqxn CFS.Windows.EditorSettings.apply
@pulsarlua function EditorSettings.apply
@desc Applies current font, palette, margins, indentation, wrapping, and visibility preferences to an editor control.
@param any oCode Code.
!]]
function EditorSettings.apply(oCode)
        current();
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
        oCode:StyleSetForeground(wxstc.wxSTC_STYLE_BRACELIGHT, wx.wxColour(aColors[4]));
        oCode:StyleSetUnderline(wxstc.wxSTC_STYLE_BRACELIGHT, true);
        oCode:StyleSetBold(wxstc.wxSTC_STYLE_BRACELIGHT, true);
        oCode:StyleSetForeground(wxstc.wxSTC_STYLE_BRACEBAD, wx.wxColour("#E05C65"));
        oCode:StyleSetUnderline(wxstc.wxSTC_STYLE_BRACEBAD, true);
        oCode:SetCaretForeground(wx.wxColour(aColors[9]));
        oCode:SetSelBackground(true, wx.wxColour(aColors[10]));
        oCode:SetCaretLineBackground(wx.wxColour(aColors[12]));
        oCode:SetCaretLineVisible(_tCurrent.currentLine);
        oCode:SetMarginWidth(0, _tCurrent.lineNumbers and (oCode:TextWidth(wxstc.wxSTC_STYLE_LINENUMBER, '9999') + 12) or 0);
        oCode:SetMarginWidth(1, _tCurrent.folding and oCode:GetLexer() == wxstc.wxSTC_LEX_LUA and 16 or 0);
        oCode:SetTabWidth(_tCurrent.tabWidth); oCode:SetIndent(_tCurrent.tabWidth); oCode:SetUseTabs(_tCurrent.useTabs);
        oCode:SetTabIndents(_tCurrent.tabIndents); oCode:SetBackSpaceUnIndents(_tCurrent.backspaceUnindents);
        oCode:SetWrapMode(_tCurrent.wordWrap and wxstc.wxSTC_WRAP_WORD or wxstc.wxSTC_WRAP_NONE);
        oCode:SetViewWhiteSpace(_tCurrent.whitespace and wxstc.wxSTC_WS_VISIBLEALWAYS or wxstc.wxSTC_WS_INVISIBLE);
        oCode:SetViewEOL(_tCurrent.lineEndings);
        oCode:SetEndAtLastLine(not _tCurrent.scrollPastEnd);
        oCode:SetIndentationGuides(_tCurrent.indentGuides and wxstc.wxSTC_IV_LOOKBOTH or wxstc.wxSTC_IV_NONE);
        oCode:SetEdgeMode(_tCurrent.columnGuide and wxstc.wxSTC_EDGE_LINE or wxstc.wxSTC_EDGE_NONE);
        oCode:SetEdgeColumn(_tCurrent.column); oCode:SetEdgeColour(wx.wxColour(tTheme.marginForeground));
        oCode:Colourise(0, -1);
        matchBrackets(oCode);
        oCode:Refresh();
    end
--[[!
@fqxn CFS.Windows.EditorSettings.register
@pulsarlua function EditorSettings.register
@desc Registers controls for shared preference updates and returns an unregister callback.
@param any dWindow Window.
@param any tControls Controls.
@param any fUpdated Updated.
!]]
function EditorSettings.register(dWindow, tControls, fUpdated)
    current();
    local tEntry = {window = dWindow, controls = tControls, update = fUpdated};
    _tEditors[tEntry] = true;
    --[[!
    @fqxn CFS.Windows.EditorSettings.Private.update
    @desc Applies current settings to registered controls and invokes the optional toolbar update callback.
    @vis private
    !]]
    local function update()
        for _, oCode in ipairs(tControls) do EditorSettings.apply(oCode); end
        if (fUpdated) then fUpdated(_tCurrent); end
    end
    tEntry.refresh = update;
    update();
    local bRegistered = true;
    --[[!
    @fqxn CFS.Windows.EditorSettings.Private.unregister
    @desc Removes this editor registration so destroyed controls stop receiving updates.
    @vis private
    !]]
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
--[[!
@fqxn CFS.Windows.EditorSettings.setMany
@pulsarlua function EditorSettings.setMany
@desc Validates all requested preferences before persisting them and refreshing registered editors.
@param any tValues Requested setting values.
!]]
function EditorSettings.setMany(tValues)
    current();
    for sKey, vValue in pairs(tValues) do
        local bValid = false;
        if (sKey == "theme") then bValid = type(vValue) == "number" and vValue == math.floor(vValue) and _tThemes[vValue + 1] ~= nil;
        elseif (sKey == "size") then
            for _, nSize in ipairs(_aFontSizes) do if (nSize == vValue) then bValid = true; end end
        else
            local tDefinition = _tDefinitions[sKey];
            if (tDefinition) then
                bValid = type(tDefinition.default) == "boolean" and type(vValue) == "boolean";
                if (type(tDefinition.default) == "number") then
                    bValid = type(vValue) == "number" and vValue == math.floor(vValue) and vValue >= tDefinition.min and vValue <= tDefinition.max;
                end
            end
        end
        assert(bValid, "Invalid editor option: "..tostring(sKey));
    end
    for sKey, vValue in pairs(tValues) do
        local sSetting, sValue;
        if (sKey == "theme") then sSetting, sValue = "Theme", _tThemes[vValue + 1].name;
        elseif (sKey == "size") then sSetting, sValue = "FontSize", tostring(vValue);
        else
            sSetting = _tDefinitions[sKey].setting;
            sValue = type(vValue) == "boolean" and (vValue and "1" or "0") or tostring(vValue);
        end
        INIFile.SetValue(FS.AppCFG, "CodeEditor", sSetting, sValue);
    end
    for sKey, vValue in pairs(tValues) do _tCurrent[sKey] = vValue; end
    for tEntry in pairs(_tEditors) do tEntry.refresh(); end
end
--[[!
@fqxn CFS.Windows.EditorSettings.set
@pulsarlua function EditorSettings.set
@desc Updates one preference through the validated batch setter.
@param any sKey Setting or field key.
@param any vValue Value.
!]]
function EditorSettings.set(sKey, vValue)
    EditorSettings.setMany({[sKey] = vValue});
end
--[[!
@fqxn CFS.Windows.EditorSettings.bar
@pulsarlua function EditorSettings.bar
@desc Builds the theme, font-size, and Options toolbar; returns its controls and unregister callback.
@param any dParent Parent window.
@param any tControls Controls.
!]]
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
    --[[!
    @fqxn CFS.Windows.EditorSettings.Private.set
    @desc Applies a toolbar preference change and reports any failure.
    @vis private
    @param any sKey Setting or field key.
    @param any nValue Value.
    !]]
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
    oBar:AddStretchSpacer();
    local oOptions = wx.wxButton(dParent, wx.wxID_ANY, "Options...");
    oOptions:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        local bOK, sError = pcall(function() require("Windows.EditorOptions").show(dParent); end);
        if (not bOK) then require("Errors").report(sError); end
    end);
    oBar:Add(oOptions, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxLEFT, 12);
    return oBar, oTheme, oSize, unregister;
end
--[[!
@fqxn CFS.Windows.EditorSettings.prepareSave
@pulsarlua function EditorSettings.prepareSave
@desc Applies configured trailing-whitespace trimming and final-newline insertion to text.
@param any sText Text content.
!]]
function EditorSettings.prepareSave(sText)
    local tState = current();
    if (tState.trimTrailing) then
        sText = sText:gsub("[ \t]+(\r?\n)", "%1"):gsub("[ \t]+$", "");
    end
    if (tState.finalNewline and sText ~= "" and not sText:match("[\r\n]$")) then
        sText = sText..(sText:find("\r\n", 1, true) and "\r\n" or "\n");
    end
    return sText;
end
--[[!
@fqxn CFS.Windows.EditorSettings.cleanControl
@pulsarlua function EditorSettings.cleanControl
@desc Cleans source whitespace as one undo action and returns the resulting editor text.
@param any oCode Code.
!]]
function EditorSettings.cleanControl(oCode)
    local sBefore = oCode:GetText();
    local sAfter = EditorSettings.prepareSave(sBefore);
    if (sBefore == sAfter) then return sAfter; end
    oCode:BeginUndoAction();
    if (current().trimTrailing) then
        for nLine = oCode:GetLineCount() - 1, 0, -1 do
            local nEnd = oCode:GetLineEndPosition(nLine);
            local nStart = nEnd;
            while (nStart > oCode:PositionFromLine(nLine)) do
                local nChar = oCode:GetCharAt(nStart - 1);
                if (nChar ~= 32 and nChar ~= 9) then break; end
                nStart = nStart - 1;
            end
            if (nStart < nEnd) then oCode:SetTargetStart(nStart); oCode:SetTargetEnd(nEnd); oCode:ReplaceTarget(""); end
        end
    end
    local sText = oCode:GetText();
    local sFinal = EditorSettings.prepareSave(sText);
    if (#sFinal > #sText) then oCode:InsertText(oCode:GetLength(), sFinal:sub(#sText + 1)); end
    oCode:EndUndoAction();
    return oCode:GetText();
end
--[[!
@fqxn CFS.Windows.EditorSettings.configure
@pulsarlua function EditorSettings.configure
@desc Configures language lexing, folding, bracket matching, auto-close, auto-indent, and shared preferences.
@param any oCode Code.
@param any sKind Kind.
!]]
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
    oCode:Connect(wxstc.wxEVT_STC_CHARADDED, function(oEvent)
        local nKey = oEvent:GetKey();
        local tPairs = {[40] = ")", [91] = "]", [123] = "}", [34] = '"', [39] = "'"};
        if (current().autoClose and tPairs[nKey]) then
            local nPosition = oCode:GetCurrentPos();
            oCode:Colourise(0, nPosition);
            local nStyle = oCode:GetStyleAt(math.max(0, nPosition - 2));
            local bLiteral = sKind == "lua" and (nStyle == wxstc.wxSTC_LUA_COMMENT or nStyle == wxstc.wxSTC_LUA_COMMENTLINE or nStyle == wxstc.wxSTC_LUA_COMMENTDOC or nStyle == wxstc.wxSTC_LUA_STRING or nStyle == wxstc.wxSTC_LUA_CHARACTER or nStyle == wxstc.wxSTC_LUA_LITERALSTRING);
            if (not bLiteral and (nPosition < 2 or oCode:GetCharAt(nPosition - 2) ~= 92)) then oCode:InsertText(nPosition, tPairs[nKey]); end
        end
        if (current().autoIndent and nKey == 10) then
            local nLine = oCode:LineFromPosition(oCode:GetCurrentPos());
            if (nLine > 0) then
                oCode:SetLineIndentation(nLine, oCode:GetLineIndentation(nLine - 1));
                oCode:GotoPos(oCode:GetLineIndentPosition(nLine));
            end
        end
        oEvent:Skip();
    end);
    oCode:Connect(wxstc.wxEVT_STC_UPDATEUI, function(oEvent)
        local bOK, sError = pcall(matchBrackets, oCode);
        if (not bOK) then require("Errors").report(sError); end
        oEvent:Skip();
    end);
    EditorSettings.apply(oCode);
end
--[[!
@fqxn CFS.Windows.EditorSettings.count
@pulsarlua function EditorSettings.count
@desc Counts active editor registrations.
!]]
function EditorSettings.count()
    local nCount = 0;
    for _ in pairs(_tEditors) do nCount = nCount + 1; end
    return nCount;
end
return EditorSettings;