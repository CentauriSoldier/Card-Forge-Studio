--[[!
@fqxn CFS.Windows.Wiki
@desc Game wiki editor with page navigation, rich text, code highlighting, and protected saves.
!]]

-- Per-game wiki window. All page edits remain a draft until Save.
local wx = require("wx");
local Store = require("Wiki.Store");
local Document = require("Wiki.Document");
local Themes = require("Wiki.Themes");
local WindowState = require("Windows.WindowState");
local Wiki = {};
local _tWindowState = {savePosition = true, saveSize = true, saveVisible = false};
WindowState.register("Wiki", _tWindowState);

--[[!
@fqxn CFS.Windows.Wiki.create
@pulsarlua function Wiki.create
@desc Creates the game wiki editor with page navigation, rich-text formatting, draft storage, themes, and protected saving.
@param any dParent Parent window.
@param any pRoot Root folder.
@param any tOptions Options table.
!]]
function Wiki.create(dParent, pRoot, tOptions)
    tOptions = tOptions or {};

    local tStore = Store.open(pRoot);
    local dFrame = wx.wxFrame(dParent, wx.wxID_ANY, "Game Wiki", wx.wxDefaultPosition, wx.wxSize(1100, 780));
    dFrame:SetMinSize(wx.wxSize(740, 480));
    local oState = WindowState.bind(dFrame, "Wiki", tOptions.stateFile);
    local dPanel = wx.wxPanel(dFrame, wx.wxID_ANY);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local dToolbar = wx.wxPanel(dPanel, wx.wxID_ANY);
    dToolbar:SetBackgroundColour(wx.wxColour("#CDD5DF"));
    local oToolbar = wx.wxWrapSizer(wx.wxHORIZONTAL);
    local tGroupParents = {};
    --[[!
    @fqxn CFS.Windows.Wiki.Private.group
    @desc Creates a toolbar group with a shared background and horizontal controls.
    @vis private
    !]]
    local function group()
        local dGroup = wx.wxPanel(dToolbar, wx.wxID_ANY);
        dGroup:SetBackgroundColour(dToolbar:GetBackgroundColour());
        local oGroup = wx.wxBoxSizer(wx.wxHORIZONTAL);
        local oContents = wx.wxBoxSizer(wx.wxHORIZONTAL);
        oGroup:Add(oContents, 0, wx.wxALIGN_CENTER_VERTICAL);
        local oDivider = wx.wxStaticLine(dGroup, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(2, 30), wx.wxLI_VERTICAL);
        oGroup:Add(oDivider, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxLEFT + wx.wxRIGHT, 8);
        dGroup:SetSizer(oGroup); oToolbar:Add(dGroup, 0, wx.wxALL, 4);
        tGroupParents[oContents] = dGroup;
        return oContents;
    end
    local oPages, oPreferences = group(), group();
    local oFormat, oFontGroup, oColors, oParagraphs, oLists, oInsert, oLinks, oHistory = group(), group(), group(), group(), group(), group(), group(), group();
    --[[!
    @fqxn CFS.Windows.Wiki.Private.sizeControl
    @desc Sets a readable font and minimum size for a toolbar control.
    @param any oControl Control.
    @param any nWidth Width.
    @vis private
    !]]
    local function sizeControl(oControl, nWidth)
        local oFont = oControl:GetFont(); oFont:SetPointSize(12); oControl:SetFont(oFont);
        oControl:SetMinSize(wx.wxSize(math.max(nWidth or 52, oControl:GetBestSize():GetWidth()), 34));
    end
    local oBottom = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oSearch = wx.wxSearchCtrl(dPanel, wx.wxID_ANY, "");
    local oSplitter = wx.wxSplitterWindow(dPanel, wx.wxID_ANY);
    local oTree = wx.wxTreeCtrl(oSplitter, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTR_HAS_BUTTONS + wx.wxTR_LINES_AT_ROOT + wx.wxTR_SINGLE);
    local oEditor = wx.wxRichTextCtrl(oSplitter, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxRE_MULTILINE + wx.wxVSCROLL);
    local oLexer = wxstc.wxStyledTextCtrl(dPanel, wx.wxID_ANY); oLexer:Hide(); oLexer:SetCodePage(wxstc.wxSTC_CP_UTF8);
    local oHighlightTimer = wx.wxTimer(dFrame, wx.wxID_ANY);
    local bHighlighting = false;
    local oMessage = wx.wxStaticText(dPanel, wx.wxID_ANY, "");
    local nPage, bLoading, bClosed = nil, false, false;
    local oHeading, oLanguage;
    local tActions = {};
    local tItems, tButtons = {}, {};
    local nTheme = 1;
    local sPreference = INIFile.GetValue(FS.AppCFG, "Wiki", "Theme");
    for nIndex, tTheme in ipairs(Themes) do if (tTheme.name == sPreference) then nTheme = nIndex; end end
    --[[!
    @fqxn CFS.Windows.Wiki.Private.message
    @desc Updates the wiki status message and panel layout.
    @param any sText Text.
    @vis private
    !]]
    local function message(sText)
        oMessage:SetLabel(sText or ""); dPanel:Layout();
    end
    --[[!
    @fqxn CFS.Windows.Wiki.Private.protect
    @desc Wraps a wiki action and displays and logs failures.
    @param any fCallback Callback.
    @vis private
    !]]
    local function protect(fCallback)
        return function(...)
            local tArguments = table.pack(...);
            local bOK, sError = xpcall(function() fCallback(table.unpack(tArguments, 1, tArguments.n)); end, debug.traceback);
            if (not bOK) then require("Errors").report(sError); message(tostring(sError):match("^[^\n]+")); end
        end;
    end
    --[[!
    @fqxn CFS.Windows.Wiki.Private.title
    @desc Updates the frame title with the selected page and dirty indicator.
    @vis private
    !]]
    local function title()
        dFrame:SetTitle("Game Wiki"..(nPage and " - "..tStore.pages[nPage].title or "")..(tStore.dirty and " *" or ""));
    end
    --[[!
    @fqxn CFS.Windows.Wiki.Private.theme
    @desc Applies the selected wiki palette to the document and navigation tree.
    @vis private
    !]]
    local function theme()
        local tTheme = Themes[nTheme];
        Document.theme(oEditor, tTheme.background, tTheme.foreground);
        oTree:SetBackgroundColour(wx.wxColour(tTheme.background));
        oTree:SetForegroundColour(wx.wxColour(tTheme.foreground));
        oEditor:Refresh(); oTree:Refresh();
    end
    --[[!
    @fqxn CFS.Windows.Wiki.Private.capture
    @desc Copies a modified editor page into the wiki draft and clears the editor modified flag.
    @vis private
    !]]
    local function capture()
        if (nPage and oEditor:IsModified()) then
            tStore.update(nPage, Document.capture(oEditor));
            oEditor:GetBuffer():Modify(false);
        end
    end
    --[[!
    @fqxn CFS.Windows.Wiki.Private.load
    @desc Captures the previous page, loads the requested page, applies theme and highlighting, and optionally jumps to an anchor.
    @param any nID Id.
    @param any sAnchor Anchor.
    @vis private
    !]]
    local function load(nID, sAnchor)
        capture();
        bLoading = true; nPage = nID;
        Document.load(oEditor, nID and tStore.pages[nID].xml or "");
        theme(); Document.highlight(oEditor, oLexer); oEditor:Enable(nID ~= nil); bLoading = false;
        for sLabel, oButton in pairs(tButtons) do
            if (sLabel ~= "New" and sLabel ~= "Save" and sLabel ~= "Close") then oButton:Enable(nID ~= nil); end
        end
        if (oHeading) then oHeading:Enable(nID ~= nil); end
        title(); message("");
        if (sAnchor and sAnchor ~= "") then assert(Document.jump(oEditor, sAnchor), "The linked section no longer exists."); end
    end
    --[[!
    @fqxn CFS.Windows.Wiki.Private.rebuild
    @desc Rebuilds the filtered page tree while retaining page IDs for navigation.
    @vis private
    !]]
    local function rebuild()
        bLoading = true; oTree:DeleteAllItems(); tItems = {};
        local oRoot = oTree:AddRoot("Pages");
        local sSearch = oSearch:GetValue():lower();
        local tIncluded = {};
        for _, tPage in ipairs(tStore.list()) do
            local sText = tPage.xml:gsub("<image[^>]*>.-</image>", ""):gsub("<[^>]*>", "");
            sText = sText:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&amp;", "&");
            if (sSearch == "" or (tPage.title.." "..sText):lower():find(sSearch, 1, true)) then
                local nID = tPage.id;
                while (nID ~= 0) do tIncluded[nID] = true; nID = tStore.pages[nID].parent; end
            end
        end
        --[[!
        @fqxn CFS.Windows.Wiki.Private.children
        @desc Recursively adds included child pages to the navigation tree.
        @param any nParent Parent.
        @param any oParent Parent.
        @vis private
        !]]
        local function children(nParent, oParent)
            for _, tPage in ipairs(tStore.list()) do
                if (tPage.parent == nParent and tIncluded[tPage.id]) then
                    local oItem = oTree:AppendItem(oParent, tPage.title);
                    tItems[oItem:GetValue()] = tPage.id;
                    children(tPage.id, oItem);
                    if (tPage.id == nPage) then oTree:SelectItem(oItem); end
                end
            end
        end
        children(0, oRoot); oTree:ExpandAll(); bLoading = false;
    end
    --[[!
    @fqxn CFS.Windows.Wiki.Private.prompt
    @desc Returns entered text from a modal prompt or nil after cancellation.
    @param any sMessage Message.
    @param any sInitial Initial.
    @vis private
    !]]
    local function prompt(sMessage, sInitial)
        local dDialog = wx.wxTextEntryDialog(dFrame, sMessage, "Game Wiki", sInitial or "");
        local nAnswer = dDialog:ShowModal(); local sValue = dDialog:GetValue(); dDialog:Destroy();
        if (nAnswer == wx.wxID_OK) then return sValue; end
    end
    --[[!
    @fqxn CFS.Windows.Wiki.Private.choosePage
    @desc Prompts for a page ID, optionally including the top-level root.
    @param any sMessage Message.
    @param any bRoot Root.
    @vis private
    !]]
    local function choosePage(sMessage, bRoot)
        local tPages, tNames = tStore.list(), {};
        if (bRoot) then tNames[1] = "Top level"; end
        for _, tPage in ipairs(tPages) do tNames[#tNames + 1] = tPage.title.." ["..tPage.id.."]"; end
        if (#tNames == 0) then message("Create a page first."); return nil; end
        local dDialog = wx.wxSingleChoiceDialog(dFrame, sMessage, "Game Wiki", tNames);
        local nAnswer = dDialog:ShowModal(); local nChoice = dDialog:GetSelection(); dDialog:Destroy();
        if (nAnswer ~= wx.wxID_OK) then return nil; end
        if (bRoot and nChoice == 0) then return 0; end
        return tPages[nChoice + (bRoot and 0 or 1)].id;
    end
    --[[!
    @fqxn CFS.Windows.Wiki.Private.button
    @desc Creates a formatting toolbar button and connects a protected action.
    @param any oSizer Sizer.
    @param any sLabel Label.
    @param any fCallback Callback.
    @vis private
    !]]
    local function button(oSizer, sLabel, fCallback)
        local tLabels = {Bold = "B", Italic = "I", Underline = "U", Strike = "S", ["Text Color"] = "A ▾", Highlight = "▰ ▾", Bullets = "• ≡", Numbered = "1. ≡", ["No List"] = "≡", Checklist = "☐", Undo = "↶", Redo = "↷"};
        local oButton = wx.wxButton(tGroupParents[oSizer] or dPanel, wx.wxID_ANY, tLabels[sLabel] or sLabel, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxBU_EXACTFIT);
        oButton:SetToolTip(sLabel); sizeControl(oButton);
        local oFont = oButton:GetFont();
        if (sLabel == "Bold") then oFont:SetWeight(wx.wxFONTWEIGHT_BOLD); end
        if (sLabel == "Italic") then oFont:SetStyle(wx.wxFONTSTYLE_ITALIC); end
        if (sLabel == "Underline") then oFont:SetUnderlined(true); end
        if (sLabel == "Strike") then oFont:SetStrikethrough(true); end
        oButton:SetFont(oFont);
        tActions[sLabel] = protect(fCallback);
        tButtons[sLabel] = oButton;
        oSizer:Add(oButton, 0, wx.wxRIGHT + wx.wxBOTTOM, 4);
        oButton:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, tActions[sLabel]);
        return oButton;
    end
    --[[!
    @fqxn CFS.Windows.Wiki.Private.requirePage
    @desc Rejects formatting operations when no page is selected.
    @vis private
    !]]
    local function requirePage()
        assert(nPage, "Select or create a page first.");
    end
    button(oPages, "New", function()
        local sName = prompt("Page title:"); if (not sName) then return; end
        capture(); local tPage = tStore.add(sName, 0); load(tPage.id); rebuild();
    end);
    button(oPages, "Subpage", function()
        requirePage(); local sName = prompt("Subpage title:"); if (not sName) then return; end
        capture(); local tPage = tStore.add(sName, nPage); load(tPage.id); rebuild();
    end);
    button(oPages, "Duplicate", function()
        requirePage(); capture();
        local tPage = tStore.pages[nPage]; local sName = prompt("Copy title:", tPage.title.." Copy");
        if (sName) then local tCopy = tStore.add(sName, tPage.parent, tPage.xml); load(tCopy.id); rebuild(); end
    end);
    button(oPages, "Rename", function()
        requirePage(); local sName = prompt("Page title:", tStore.pages[nPage].title);
        if (sName) then tStore.rename(nPage, sName); rebuild(); title(); end
    end);
    button(oPages, "Move", function()
        requirePage(); local nParent = choosePage("Choose the new parent page.", true);
        if (nParent) then tStore.move(nPage, nParent); rebuild(); title(); end
    end);
    button(oPages, "Delete", function()
        requirePage(); capture();
        for _, tPage in pairs(tStore.pages) do
            if (tPage.parent == nPage) then message("Move or delete this page's subpages first."); return; end
        end
        local tLinks = {};
        for _, tPage in ipairs(tStore.list()) do
            if (tPage.id ~= nPage and tPage.xml:find('url="wiki:'..nPage..'["#]')) then tLinks[#tLinks + 1] = tPage.title; end
        end
        local sQuestion = "Delete '"..tStore.pages[nPage].title.."'?";
        if (#tLinks > 0) then sQuestion = sQuestion.."\n\nLinks from these pages will no longer work:\n"..table.concat(tLinks, "\n"); end
        if (wx.wxMessageBox(sQuestion, "Delete Page", wx.wxYES_NO + wx.wxICON_QUESTION, dFrame) == wx.wxYES) then
            tStore.remove(nPage); nPage = nil; load(nil); rebuild();
        end
    end);
    local tThemeNames = {}; for _, tTheme in ipairs(Themes) do tThemeNames[#tThemeNames + 1] = tTheme.name; end
    local oTheme = wx.wxChoice(tGroupParents[oPreferences], wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, tThemeNames);
    sizeControl(oTheme, 96); oTheme:SetSelection(nTheme - 1); oPreferences:Add(oTheme, 0, wx.wxLEFT, 12);
    oTheme:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, protect(function()
        local nSelected = oTheme:GetSelection() + 1;
        INIFile.SetValue(FS.AppCFG, "Wiki", "Theme", Themes[nSelected].name);
        nTheme = nSelected; theme();
    end));
    --[[!
    @fqxn CFS.Windows.Wiki.Private.style
    @desc Applies text or paragraph attributes as an undoable formatting operation.
    @param any fSet Set.
    @param any bParagraph Paragraph.
    @vis private
    !]]
    local function style(fSet, bParagraph)
        requirePage(); local oStyle = wx.wxRichTextAttr(); fSet(oStyle);
        local nFlags = wx.wxRICHTEXT_SETSTYLE_WITH_UNDO + (bParagraph and wx.wxRICHTEXT_SETSTYLE_PARAGRAPHS_ONLY or wx.wxRICHTEXT_SETSTYLE_CHARACTERS_ONLY);
        if (oEditor:HasSelection() or bParagraph) then
            local oRange = oEditor:GetSelectionRange();
            if (bParagraph and not oEditor:HasSelection()) then
                local oParagraph = oEditor:GetFocusObject():GetParagraphAtPosition(oEditor:GetInsertionPoint());
                local oParagraphRange = oParagraph:GetRange();
                oRange = wx.wxRichTextRange(oParagraphRange:GetStart(), oParagraphRange:GetEnd() + 1);
            end
            oEditor:SetStyleEx(oRange, oStyle, nFlags);
        else
            local oDefault = oEditor:GetDefaultStyleEx(); oDefault:Apply(oStyle);
            oEditor:SetDefaultStyle(oDefault);
        end
        oStyle:delete(); oEditor:SetFocus();
    end
    button(oFormat, "Bold", function() requirePage(); oEditor:ApplyBoldToSelection(); end);
    button(oFormat, "Italic", function() requirePage(); oEditor:ApplyItalicToSelection(); end);
    button(oFormat, "Underline", function() requirePage(); oEditor:ApplyUnderlineToSelection(); end);
    button(oFormat, "Strike", function()
        local oCurrent = wx.wxRichTextAttr(); oEditor:GetStyle(oEditor:GetInsertionPoint(), oCurrent);
        local bStrike = (oCurrent:GetTextEffects() & wx.wxTEXT_ATTR_EFFECT_STRIKETHROUGH) == 0;
        style(function(a)
            a:SetTextEffectFlags(wx.wxTEXT_ATTR_EFFECT_STRIKETHROUGH);
            a:SetTextEffects(bStrike and wx.wxTEXT_ATTR_EFFECT_STRIKETHROUGH or 0);
        end);
        oCurrent:delete();
    end);
    button(oFontGroup, "Reset Format", function()
        requirePage(); local oAttribute = wx.wxRichTextAttr(); oAttribute:SetFlags(wx.wxTEXT_ATTR_CHARACTER);
        oEditor:SetStyleEx(oEditor:GetSelectionRange(), oAttribute, wx.wxRICHTEXT_SETSTYLE_WITH_UNDO + wx.wxRICHTEXT_SETSTYLE_REMOVE + wx.wxRICHTEXT_SETSTYLE_CHARACTERS_ONLY);
        oEditor:SetDefaultStyle(wx.wxRichTextAttr()); oAttribute:delete();
    end);
    button(oFontGroup, "Font", function()
        requirePage(); local oData = wx.wxFontData(); local dDialog = wx.wxFontDialog(dFrame, oData);
        if (dDialog:ShowModal() == wx.wxID_OK) then
            local oFont = dDialog:GetFontData():GetChosenFont(); style(function(a) a:SetFont(oFont); end);
        end
        dDialog:Destroy(); oData:delete();
    end);
    --[[!
    @fqxn CFS.Windows.Wiki.Private.colorPalette
    @desc Presents color choices for text or highlight formatting.
    @param any sLabel Label.
    @param any bHighlight Highlight.
    @vis private
    !]]
    local function colorPalette(sLabel, bHighlight)
        requirePage();
        local oMenu = wx.wxMenu(); local tMenuIDs = {};
        local tColors = {{"Black", "#000000"}, {"White", "#FFFFFF"}, {"Gray", "#808080"}, {"Red", "#E53935"}, {"Orange", "#FB8C00"}, {"Yellow", "#FDD835"}, {"Green", "#43A047"}, {"Cyan", "#00ACC1"}, {"Blue", "#1E88E5"}, {"Purple", "#8E24AA"}, {"Pink", "#D81B60"}};
        --[[!
        @fqxn CFS.Windows.Wiki.Private.apply
        @desc Applies the chosen text or highlight color to the editor selection.
        @param any oColor Color.
        @vis private
        !]]
        local function apply(oColor)
            style(function(a) if (bHighlight) then a:SetBackgroundColour(oColor); else a:SetTextColour(oColor); end end);
        end
        for _, tColor in ipairs(tColors) do
            local nID = wx.wxNewId(); tMenuIDs[#tMenuIDs + 1] = nID;
            local oItem = wx.wxMenuItem(oMenu, nID, tColor[1]);
            local oBitmap = wx.wxBitmap(18, 18); local oDC = wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
            local oBrush = wx.wxBrush(wx.wxColour(tColor[2])); oDC:SetBackground(oBrush); oDC:Clear(); oDC:SelectObject(wx.wxNullBitmap); oDC:delete(); oBrush:delete();
            oItem:SetBitmap(oBitmap); oMenu:Append(oItem); oBitmap:delete();
            dPanel:Connect(nID, wx.wxEVT_COMMAND_MENU_SELECTED, protect(function() apply(wx.wxColour(tColor[2])); end));
        end
        oMenu:AppendSeparator(); local nMore = wx.wxNewId(); oMenu:Append(nMore, "More colors…");
        tMenuIDs[#tMenuIDs + 1] = nMore; dPanel:Connect(nMore, wx.wxEVT_COMMAND_MENU_SELECTED, protect(function()
            local oData = wx.wxColourData(); local dDialog = wx.wxColourDialog(dFrame, oData);
            if (dDialog:ShowModal() == wx.wxID_OK) then apply(dDialog:GetColourData():GetColour()); end
            dDialog:Destroy(); oData:delete();
        end));
        local oButton = tButtons[sLabel]; local oPosition = dPanel:ScreenToClient(oButton:ClientToScreen(wx.wxPoint(0, oButton:GetSize():GetHeight())));
        dPanel:PopupMenu(oMenu, oPosition); for _, nID in ipairs(tMenuIDs) do dPanel:Disconnect(nID, wx.wxEVT_COMMAND_MENU_SELECTED); end oMenu:delete();
    end
    button(oColors, "Text Color", function() colorPalette("Text Color", false); end);
    button(oColors, "Highlight", function() colorPalette("Highlight", true); end);
    oHeading = wx.wxChoice(tGroupParents[oParagraphs], wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, {"Paragraph", "Heading 1", "Heading 2", "Heading 3", "Heading 4", "Quote", "Code Block"});
    sizeControl(oHeading, 96); oHeading:SetSelection(0); oParagraphs:Add(oHeading, 0, wx.wxRIGHT + wx.wxBOTTOM, 4);
    oHeading:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, protect(function()
        requirePage();
        if (oHeading:GetSelection() == 6) then Document.code(oEditor, oLanguage:GetStringSelection());
        else Document.heading(oEditor, oHeading:GetSelection()); end
        oHighlightTimer:StartOnce(1);
    end));
    button(oLists, "Bullets", function() style(function(a) a:SetBulletStyle(wx.wxTEXT_ATTR_BULLET_STYLE_STANDARD); a:SetBulletName("standard/circle"); a:SetLeftIndent(60, 40); end, true); end);
    button(oLists, "Numbered", function()
        style(function(a) a:SetBulletStyle(wx.wxTEXT_ATTR_BULLET_STYLE_ARABIC + wx.wxTEXT_ATTR_BULLET_STYLE_PERIOD); a:SetBulletNumber(1); a:SetLeftIndent(60, 40); end, true);
        local oSelection = oEditor:GetSelectionRange();
        local nPosition = oEditor:HasSelection() and oSelection:GetStart() or oEditor:GetInsertionPoint();
        local nEnd = oEditor:HasSelection() and oSelection:GetEnd() or nPosition;
        local nNumber = 1;
        repeat
            local oParagraph = oEditor:GetFocusObject():GetParagraphAtPosition(nPosition);
            if (not oParagraph) then break; end
            local oRange = oParagraph:GetRange();
            local oAttribute = wx.wxRichTextAttr(); oAttribute:SetBulletNumber(nNumber);
            oEditor:SetStyleEx(wx.wxRichTextRange(oRange:GetStart(), oRange:GetEnd() + 1), oAttribute, wx.wxRICHTEXT_SETSTYLE_WITH_UNDO + wx.wxRICHTEXT_SETSTYLE_PARAGRAPHS_ONLY);
            oAttribute:delete(); nPosition = oRange:GetEnd() + 1; nNumber = nNumber + 1;
        until (nPosition >= nEnd)
    end);
    button(oLists, "No List", function()
        style(function(a) a:SetBulletStyle(wx.wxTEXT_ATTR_BULLET_STYLE_NONE); a:SetBulletName(""); a:SetBulletNumber(0); a:SetLeftIndent(0, 0); a:SetListStyleName(""); end, true);
    end);
    button(oLists, "Checklist", function() requirePage(); Document.checkbox(oEditor); end);
    button(oInsert, "Table", function()
        requirePage(); local sRows = prompt("Rows (1–30):", "3"); if (not sRows) then return; end
        local sColumns = prompt("Columns (1–12):", "3"); if (not sColumns) then return; end
        local nRows, nColumns = tonumber(sRows), tonumber(sColumns);
        assert(nRows and nRows % 1 == 0 and nRows >= 1 and nRows <= 30 and nColumns and nColumns % 1 == 0 and nColumns >= 1 and nColumns <= 12, "Choose valid table dimensions.");
        local oTable = oEditor:WriteTable(nRows, nColumns, wx.wxRichTextAttr());
        oEditor:SetFocusObject(oTable:GetCell(0, 0)); oEditor:SetInsertionPoint(0); oEditor:SetFocus();
    end);
    button(oInsert, "Image", function()
        requirePage();
        local pFolder = INIFile.GetValue(FS.AppCFG, "Wiki", "ImageFolder");
        if (not wx.wxDirExists(pFolder)) then pFolder = tOptions.gameRoot or FS.Game.Root; end
        local dDialog = wx.wxFileDialog(dFrame, "Insert Image", pFolder, "", "Images|*.png;*.jpg;*.jpeg;*.gif;*.bmp", wx.wxFD_OPEN + wx.wxFD_FILE_MUST_EXIST);
        if (dDialog:ShowModal() == wx.wxID_OK) then
            INIFile.SetValue(FS.AppCFG, "Wiki", "ImageFolder", dDialog:GetDirectory());
            local pImage = dDialog:GetPath(); local oImage = wx.wxImage(pImage);
            assert(oImage:IsOk(), "Could not load the selected image.");
            if (oImage:GetWidth() > 700) then oImage = oImage:Scale(700, math.max(1, math.floor(oImage:GetHeight() * 700 / oImage:GetWidth())), wx.wxIMAGE_QUALITY_HIGH); end
            assert(oEditor:WriteImage(oImage), "Could not insert the image."); tStore.image(pImage); oImage:delete();
        end
        dDialog:Destroy();
    end);
    button(oLinks, "Web Link", function()
        requirePage(); local sURL = prompt("Web address (http:// or https://):", "https://");
        if (not sURL) then return; end
        assert(sURL:match("^https?://[^%s]+$"), "Enter an HTTP or HTTPS web address.");
        if (oEditor:HasSelection()) then style(function(a) a:SetURL(sURL); a:SetFontUnderlined(true); end);
        else oEditor:BeginURL(sURL); oEditor:WriteText(sURL); oEditor:EndURL(); end
    end);
    button(oLinks, "Page Link", function()
        requirePage(); capture(); local nTarget = choosePage("Link to which page?", false); if (not nTarget) then return; end
        local sURL = "wiki:"..nTarget;
        local oHidden = wx.wxRichTextCtrl(dPanel, wx.wxID_ANY); oHidden:Hide(); Document.load(oHidden, tStore.pages[nTarget].xml);
        local tSections = Document.sections(oHidden); oHidden:Destroy();
        if (#tSections > 0) then
            local tNames = {"Whole page"}; for _, tSection in ipairs(tSections) do tNames[#tNames + 1] = tSection.title; end
            local dDialog = wx.wxSingleChoiceDialog(dFrame, "Link to the page or a section.", "Page Link", tNames);
            local nAnswer = dDialog:ShowModal(); local nChoice = dDialog:GetSelection(); dDialog:Destroy();
            if (nAnswer ~= wx.wxID_OK) then return; end
            if (nChoice > 0) then sURL = sURL.."#"..tSections[nChoice].anchor; end
        end
        if (oEditor:HasSelection()) then style(function(a) a:SetURL(sURL); a:SetFontUnderlined(true); end);
        else
            oEditor:BeginURL(sURL); oEditor:WriteText(tStore.pages[nTarget].title); oEditor:EndURL();
        end
    end);
    button(oHistory, "Undo", function() requirePage(); if (oEditor:CanUndo()) then oEditor:Undo(); end end);
    button(oHistory, "Redo", function() requirePage(); if (oEditor:CanRedo()) then oEditor:Redo(); end end);
    local oFont = wx.wxChoice(tGroupParents[oFontGroup], wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, {"Segoe UI", "Arial", "Times New Roman", "Consolas"});
    sizeControl(oFont, 96); oFont:SetSelection(0); oFont:SetToolTip("Font family; Font opens the full font chooser");
    oFontGroup:Insert(0, oFont, 0, wx.wxRIGHT + wx.wxBOTTOM, 4);
    oFont:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, protect(function() style(function(a) a:SetFontFaceName(oFont:GetStringSelection()); end); end));
    oLanguage = wx.wxChoice(tGroupParents[oParagraphs], wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, {"Plain Text", "Lua", "JavaScript", "Python", "HTML", "CSS", "SQL", "C", "C++"});
    sizeControl(oLanguage, 96); oLanguage:SetSelection(0);
    oLanguage:SetStringSelection(INIFile.GetValue(FS.AppCFG, "Wiki", "CodeLanguage")); oLanguage:SetToolTip("Code block language");
    oParagraphs:Add(oLanguage, 0, wx.wxRIGHT + wx.wxBOTTOM, 4);
    oLanguage:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, protect(function()
        INIFile.SetValue(FS.AppCFG, "Wiki", "CodeLanguage", oLanguage:GetStringSelection());
    end));
    button(oParagraphs, "Code", function() requirePage(); Document.code(oEditor, oLanguage:GetStringSelection()); oHighlightTimer:StartOnce(1); end);
    button(oParagraphs, "Exit Code", function() requirePage(); Document.exitCode(oEditor); end):SetToolTip("Continue outside the code block (Ctrl+Enter)");
    local oZoom = wx.wxChoice(tGroupParents[oPreferences], wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, {"50%", "75%", "100%", "125%", "150%", "175%", "200%"});
    local tZoom = {50, 75, 100, 125, 150, 175, 200};
    local nZoom = tonumber(INIFile.GetValue(FS.AppCFG, "Wiki", "Zoom")) or 100;
    sizeControl(oZoom, 96); oZoom:SetSelection(2);
    for nIndex, nValue in ipairs(tZoom) do if (nValue == nZoom) then oZoom:SetSelection(nIndex - 1); end end
    oEditor:SetScale(tZoom[oZoom:GetSelection() + 1] * 1.5 / 100, true);
    oZoom:SetToolTip("View zoom; font sizes are unchanged"); oPreferences:Add(oZoom, 0, wx.wxLEFT, 8);
    oZoom:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, protect(function()
        local nValue = tZoom[oZoom:GetSelection() + 1]; oEditor:SetScale(nValue * 1.5 / 100, true);
        INIFile.SetValue(FS.AppCFG, "Wiki", "Zoom", tostring(nValue));
    end));
    --[[!
    @fqxn CFS.Windows.Wiki.Private.save
    @desc Captures the current page, saves the store, and updates title and status.
    @vis private
    !]]
    local function save()
        capture(); tStore.save(); title(); message("Wiki saved."); require("Log").Note("Game wiki saved.");
    end
    button(oBottom, "Save", save);
    button(oBottom, "Close", function() dFrame:Close(); end);
    oBottom:Add(oMessage, 1, wx.wxALIGN_CENTER_VERTICAL + wx.wxLEFT, 12);
    dToolbar:SetSizer(oToolbar);
    oLayout:Add(dToolbar, 0, wx.wxEXPAND + wx.wxALL, 8);
    oLayout:Add(oSearch, 0, wx.wxEXPAND + wx.wxALL, 8);
    oLayout:Add(oSplitter, 1, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 8);
    oLayout:Add(oBottom, 0, wx.wxEXPAND + wx.wxALL, 8);
    dPanel:SetSizer(oLayout); oSplitter:SplitVertically(oTree, oEditor, 250); oSplitter:SetMinimumPaneSize(130);
    dPanel:Connect(wx.wxEVT_SIZE, function(oEvent)
        dToolbar:InvalidateBestSize(); dPanel:Layout(); oEvent:Skip();
    end);
    --[[!
    @fqxn CFS.Windows.Wiki.Private.checkboxHit
    @desc Maps the native click position to the rich-text position for checkbox interaction.
    @param any oPoint Point.
    @vis private
    !]]
    local function checkboxHit(oPoint)
        local oAdjusted = oEditor:GetPhysicalPoint(oEditor:GetUnscaledPoint(oEditor:GetLogicalPoint(oPoint)));
        local nResult, nRow, nColumn = oEditor:HitTest(oAdjusted);
        if (nResult ~= wx.wxTE_HT_ON_TEXT or not nPage) then return; end
        local nPosition = oEditor:XYToPosition(nColumn, nRow); if (nPosition < 0) then return; end
        local oParagraph = oEditor:GetFocusObject():GetParagraphAtPosition(nPosition); if (not oParagraph) then return; end
        local oRange = oParagraph:GetRange(); local sMark = oParagraph:GetTextForRange(oRange):sub(1, 3);
        if ((sMark == "☐" or sMark == "☑") and nPosition == oRange:GetStart()) then return nPosition; end
    end
    oEditor:Connect(wx.wxEVT_LEFT_UP, protect(function(oEvent)
        local nPosition = checkboxHit(oEvent:GetPosition());
        if (nPosition) then Document.toggleCheck(oEditor, nPosition, true); end
        oEvent:Skip();
    end));
    oEditor:Connect(wx.wxEVT_MOTION, protect(function(oEvent)
        oEvent:Skip();
        if (not oEvent:Dragging() and checkboxHit(oEvent:GetPosition())) then
            oEditor:SetCursor(wx.wxCursor(wx.wxCURSOR_HAND)); oEvent:Skip(false);
        end
    end));
    oEditor:Connect(wx.wxEVT_KEY_DOWN, function(oEvent)
        if (oEvent:ControlDown() and not oEvent:AltDown()) then
            if (oEvent:GetKeyCode() == wx.WXK_RETURN and nPage and Document.exitCode(oEditor)) then return; end
            local sAction = ({[66] = "Bold", [73] = "Italic", [85] = "Underline", [83] = "Save", [90] = "Undo", [89] = "Redo"})[oEvent:GetKeyCode()];
            if (sAction and (nPage or sAction == "Save")) then tActions[sAction](); return; end
        end
        if (nPage and not oEvent:ControlDown() and not oEvent:AltDown()) then
            if (oEvent:GetKeyCode() == wx.WXK_RETURN and not oEvent:ShiftDown() and Document.listEnter(oEditor)) then return; end
            if (oEvent:GetKeyCode() == wx.WXK_TAB and Document.listIndent(oEditor, oEvent:ShiftDown())) then return; end
        end
        oEvent:Skip();
    end);
    dFrame:Connect(oHighlightTimer:GetId(), wx.wxEVT_TIMER, protect(function()
        bHighlighting = true;
        local bOK, sError = pcall(Document.highlight, oEditor, oLexer);
        bHighlighting = false; assert(bOK, sError);
    end));
    oEditor:Connect(wx.wxEVT_TEXT, function()
        if (not bLoading and not bHighlighting and nPage) then tStore.dirty = true; title(); oHighlightTimer:StartOnce(250); end
    end);
    oTree:Connect(wx.wxEVT_COMMAND_TREE_SEL_CHANGED, protect(function(oEvent)
        if (not bLoading) then load(tItems[oEvent:GetItem():GetValue()]); end
    end));
    oSearch:Connect(wx.wxEVT_TEXT, protect(function() capture(); rebuild(); end));
    oEditor:Connect(wx.wxEVT_TEXT_URL, protect(function(oEvent)
        local sURL = oEvent:GetString(); local sID, sAnchor = sURL:match("^wiki:(%d+)#?(.*)$");
        if (sID) then assert(tStore.pages[tonumber(sID)], "The linked page no longer exists."); load(tonumber(sID), sAnchor); rebuild();
        elseif (sURL:match("^https?://")) then assert(wx.wxLaunchDefaultBrowser(sURL), "Could not open the link."); end
    end));
    --[[!
    @fqxn CFS.Windows.Wiki.Private.allowClose
    @desc Captures drafts and asks whether unsaved wiki changes should be saved or retained.
    @vis private
    !]]
    local function allowClose()
        capture();
        if (tStore.dirty) then
            local nAnswer = wx.wxMessageBox("Save your wiki changes before closing?", "Game Wiki", wx.wxYES_NO + wx.wxCANCEL + wx.wxICON_QUESTION, dFrame);
            if (nAnswer == wx.wxCANCEL) then return false; end
            if (nAnswer == wx.wxYES) then
                local bOK, sError = pcall(save);
                if (not bOK) then require("Errors").report(sError); message(tostring(sError):match("^[^\n]+")); return false; end
            end
        end
        return true;
    end
    dFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        local bOK, bAllow = pcall(allowClose);
        if (not bOK or not bAllow) then
            if (not bOK) then require("Errors").report(bAllow); message(tostring(bAllow):match("^[^\n]+")); end
            if (oEvent:CanVeto()) then oEvent:Veto(); end
            return;
        end
        bClosed = true; oHighlightTimer:Stop(); oState.close();
        if (tOptions.onClose) then tOptions.onClose(); end
        oEvent:Skip();
    end);
    rebuild(); local tInitial = tStore.list(); load(tInitial[1] and tInitial[1].id or nil);
    dFrame:Show(true); dPanel:Layout();
    return {frame = dFrame, editor = oEditor, tree = oTree, store = tStore, theme = oTheme, buttons = tButtons, heading = oHeading, search = oSearch, zoom = oZoom, language = oLanguage, font = oFont, toolbar = dToolbar,
        load = load, save = save, rebuild = rebuild,
        --[[!
        @fqxn CFS.Windows.Wiki.Private.show
        @desc Shows and raises the wiki window.
        @vis private
        !]]
        show = function() dFrame:Show(true); dFrame:Raise(); end,
        --[[!
        @fqxn CFS.Windows.Wiki.Private.close
        @desc Closes the wiki through its unsaved-draft protection.
        @vis private
        !]]
        close = function() if (bClosed) then return true; end return dFrame:Close(); end};
end
return Wiki;
