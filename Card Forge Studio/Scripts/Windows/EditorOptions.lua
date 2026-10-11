--[[!
@fqxn CFS.Windows.EditorOptions
@desc
<section aria-label="EditorOptions overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">EditorOptions</h2><p style="font-size:1.15rem;margin:0">Editor Options lets you tailor the editing experience where you work.</p></div>
<h3>How it fits into your work</h3><p>Adjust editing, layout, and whitespace preferences through the editor's own options window.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.EditorSettings">EditorSettings</a></h3><p style="margin:0">Shared settings keep the code editors consistent across projects.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.GameEditor">GameEditor</a></h3><p style="margin:0">Game Editor organizes the shared scripts used throughout a game.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.CardSetEditor">CardSetEditor</a></h3><p style="margin:0">Card Set Editor brings the active set's scripts and notes together.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">These preferences belong to editing, rather than the game's card dimensions or export options.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

-- Shared code-editor options. Changes remain staged until Apply or OK.
local wx = require("wx");
local EditorSettings = require("Windows.EditorSettings");
local EditorOptions = {};

--[[!
@fqxn CFS.Windows.EditorOptions.Functions.create
@pulsarlua function EditorOptions.create
@desc Creates controls for shared editor preferences with Apply, Save, and Cancel behavior.
@param any dParent Parent window.
!]]
function EditorOptions.create(dParent)
    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, "Editor Options", wx.wxDefaultPosition, wx.wxSize(900, 700),
        wx.wxDEFAULT_DIALOG_STYLE + wx.wxRESIZE_BORDER);
    dDialog:SetMinSize(wx.wxSize(800, 500));
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oNavigation = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oCategories = wx.wxListBox(dDialog, wx.wxID_ANY);
    oCategories:SetMinSize(wx.wxSize(200, -1));
    local dPages = wx.wxPanel(dDialog, wx.wxID_ANY);
    local oPages = wx.wxBoxSizer(wx.wxVERTICAL); dPages:SetSizer(oPages);
    oNavigation:Add(oCategories, 0, wx.wxEXPAND + wx.wxALL, 12);
    oNavigation:Add(dPages, 1, wx.wxEXPAND + wx.wxTOP + wx.wxBOTTOM + wx.wxRIGHT, 12);
    local tPages = {};
    local dBody, oBody;
    local tControls, tState = {}, EditorSettings.get();
    local oHelp = wx.wxStaticText(dDialog, wx.wxID_ANY, "These settings apply to every code and source editor. Saving options can change text when you save. Wiki settings are separate.");
    oHelp:Wrap(820); oLayout:Add(oHelp, 0, wx.wxEXPAND + wx.wxALL, 12);
    --[[!
    @fqxn CFS.Windows.EditorOptions.Private.Functions.block
    @desc Creates a labeled group of editor options.
    @param any sName Name.
    @vis private
    !]]
    local function block(sName)
        dBody = wx.wxScrolledWindow(dPages, wx.wxID_ANY); dBody:SetScrollRate(0, 12);
        oBody = wx.wxBoxSizer(wx.wxVERTICAL); dBody:SetSizer(oBody);
        tPages[#tPages + 1] = dBody; oCategories:Append(sName);
        oPages:Add(dBody, 1, wx.wxEXPAND); dBody:Hide();
        local oBox = wx.wxStaticBox(dBody, wx.wxID_ANY, sName);
        local oBlock = wx.wxStaticBoxSizer(oBox, wx.wxVERTICAL);
        oBody:Add(oBlock, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 12);
        return oBlock;
    end
    --[[!
    @fqxn CFS.Windows.EditorOptions.Private.Functions.check
    @desc Adds a checkbox initialized from current settings and registers it for saving.
    @param any oBlock Block.
    @param any sKey Key.
    @param any sLabel Label.
    @vis private
    !]]
    local function check(oBlock, sKey, sLabel)
        local oControl = wx.wxCheckBox(dBody, wx.wxID_ANY, sLabel);
        oControl:SetValue(tState[sKey]); tControls[sKey] = oControl;
        oBlock:Add(oControl, 0, wx.wxALL, 6);
    end
    --[[!
    @fqxn CFS.Windows.EditorOptions.Private.Functions.row
    @desc Adds a labeled control row to an options group.
    @param any oBlock Block.
    @param any sLabel Label.
    @param any oControl Control.
    @vis private
    !]]
    local function row(oBlock, sLabel, oControl)
        local oRow = wx.wxBoxSizer(wx.wxHORIZONTAL);
        oRow:Add(wx.wxStaticText(dBody, wx.wxID_ANY, sLabel), 1, wx.wxALIGN_CENTER_VERTICAL + wx.wxRIGHT, 12);
        oRow:Add(oControl, 0, wx.wxALIGN_CENTER_VERTICAL);
        oBlock:Add(oRow, 0, wx.wxEXPAND + wx.wxALL, 6);
    end
    local oBlock = block("Indentation");
    tControls.useTabs = wx.wxChoice(dBody, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, {"Soft tabs (spaces)", "Hard tabs (tab characters)"});
    tControls.useTabs:SetSelection(tState.useTabs and 1 or 0); row(oBlock, "Indent with", tControls.useTabs);
    tControls.tabWidth = wx.wxSpinCtrl(dBody, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize(90, -1), wx.wxSP_ARROW_KEYS, 1, 8, tState.tabWidth);
    row(oBlock, "Tab width / spaces per indent", tControls.tabWidth);
    check(oBlock, "autoIndent", "Copy the previous line's indentation on Enter");
    check(oBlock, "tabIndents", "Tab indents the current line or selection");
    check(oBlock, "backspaceUnindents", "Backspace removes one indentation level");
    oBlock = block("Display");
    check(oBlock, "scrollPastEnd", "Allow scrolling beyond the last line");
    check(oBlock, "wordWrap", "Wrap long lines to the editor width");
    check(oBlock, "lineNumbers", "Show line numbers");
    check(oBlock, "folding", "Show Lua block folding controls");
    check(oBlock, "currentLine", "Highlight the current line");
    oBlock = block("Whitespace and Guides");
    check(oBlock, "whitespace", "Show spaces and tabs");
    check(oBlock, "lineEndings", "Show line-ending markers");
    check(oBlock, "indentGuides", "Show indentation guides");
    check(oBlock, "columnGuide", "Show a preferred-column guide");
    tControls.column = wx.wxSpinCtrl(dBody, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize(90, -1), wx.wxSP_ARROW_KEYS, 20, 240, tState.column);
    row(oBlock, "Guide column", tControls.column);
    oBlock = block("Typing");
    check(oBlock, "autoClose", "Automatically insert closing brackets and quotes");
    oBlock = block("Autocomplete");
    check(oBlock, "autocompleteEnabled", "Enable autocomplete");
    check(oBlock, "autocompleteHelp", "Show documentation for the highlighted suggestion");
    check(oBlock, "autocompleteUseEditorTheme", "Use editor theme for colors");
    check(oBlock, "autocompleteUseEditorFontSize", "Use editor font size for suggestions and documentation");
    tControls.autocompleteCharacters = wx.wxSpinCtrl(dBody, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize(90, -1), wx.wxSP_ARROW_KEYS, 1, 10, tState.autocompleteCharacters);
    row(oBlock, "Show suggestions after this many characters", tControls.autocompleteCharacters);
    local tColorKeys = {};
    for _, tDefinition in ipairs({
        {"suggestionBackground", "Suggestion background"}, {"suggestionText", "Suggestion text"},
        {"documentationBackground", "Documentation background"}, {"documentationText", "Documentation text"},
    }) do
        local sKey, sLabel = tDefinition[1], tDefinition[2];
        local nColor = tState[sKey];
        tControls[sKey] = wx.wxColourPickerCtrl(dBody, wx.wxID_ANY, wx.wxColour(math.floor(nColor / 65536), math.floor(nColor / 256) % 256, nColor % 256));
        tColorKeys[sKey] = true; row(oBlock, sLabel, tControls[sKey]);
    end
    local function enableCustomColors()
        local bEnabled = not tControls.autocompleteUseEditorTheme:GetValue();
        for sKey in pairs(tColorKeys) do tControls[sKey]:Enable(bEnabled); end
    end
    tControls.autocompleteUseEditorTheme:Connect(wx.wxEVT_COMMAND_CHECKBOX_CLICKED, enableCustomColors);
    enableCustomColors();
    for _, tDefinition in ipairs({{"suggestionFontSize", "Suggestion font size"}, {"documentationFontSize", "Documentation font size"}}) do
        local sKey = tDefinition[1];
        tControls[sKey] = wx.wxSpinCtrl(dBody, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize(90, -1), wx.wxSP_ARROW_KEYS, 8, 24, tState[sKey]);
        row(oBlock, tDefinition[2], tControls[sKey]);
    end
    local function enableSuggestionFonts()
        local bEnabled = not tControls.autocompleteUseEditorFontSize:GetValue();
        tControls.suggestionFontSize:Enable(bEnabled); tControls.documentationFontSize:Enable(bEnabled);
    end
    tControls.autocompleteUseEditorFontSize:Connect(wx.wxEVT_COMMAND_CHECKBOX_CLICKED, enableSuggestionFonts);
    enableSuggestionFonts();
    oBlock = block("Environment Reference");
    check(oBlock, "referenceUseEditorFontSize", "Use editor font size for the list and description");
    for _, tDefinition in ipairs({{"referenceListFontSize", "Variable list font size"}, {"referenceDescriptionFontSize", "Description font size"}}) do
        local sKey = tDefinition[1];
        tControls[sKey] = wx.wxSpinCtrl(dBody, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize(90, -1), wx.wxSP_ARROW_KEYS, 8, 24, tState[sKey]);
        row(oBlock, tDefinition[2], tControls[sKey]);
    end
    local function enableReferenceFonts()
        local bEnabled = not tControls.referenceUseEditorFontSize:GetValue();
        tControls.referenceListFontSize:Enable(bEnabled); tControls.referenceDescriptionFontSize:Enable(bEnabled);
    end
    tControls.referenceUseEditorFontSize:Connect(wx.wxEVT_COMMAND_CHECKBOX_CLICKED, enableReferenceFonts);
    enableReferenceFonts();
    oBlock = block("Saving");
    check(oBlock, "trimTrailing", "Remove trailing spaces and tabs on Save");
    check(oBlock, "finalNewline", "Ensure a final newline on Save");
    for _, dPage in ipairs(tPages) do dPage:Layout(); dPage:FitInside(); end
    local function select(nIndex)
        for nPage, dPage in ipairs(tPages) do dPage:Show(nPage == nIndex); end
        oCategories:SetSelection(nIndex - 1); dPages:Layout();
        if (tPages[nIndex]) then tPages[nIndex]:FitInside(); end
    end
    oCategories:Connect(wx.wxEVT_COMMAND_LISTBOX_SELECTED, function() select(oCategories:GetSelection() + 1); end);
    select(1);
    oLayout:Add(oNavigation, 1, wx.wxEXPAND);
    local oStatus = wx.wxStaticText(dDialog, wx.wxID_ANY, ""); oStatus:Hide();
    oStatus:SetForegroundColour(wx.wxColour(170, 25, 25));
    oLayout:Add(oStatus, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 12);
    local oButtons = wx.wxBoxSizer(wx.wxHORIZONTAL); oButtons:AddStretchSpacer();
    for _, tButton in ipairs({{wx.wxID_OK, "OK"}, {wx.wxID_APPLY, "Apply"}, {wx.wxID_CANCEL, "Cancel"}}) do
        oButtons:Add(wx.wxButton(dDialog, tButton[1], tButton[2]), 0, wx.wxALL, 6);
    end
    oLayout:Add(oButtons, 0, wx.wxEXPAND + wx.wxALL, 6);
    dDialog:SetSizer(oLayout); dDialog:Layout(); dDialog:CentreOnParent();
    --[[!
    @fqxn CFS.Windows.EditorOptions.Private.Functions.apply
    @desc Collects option values and passes them to the shared validated settings setter.
    @vis private
    !]]
    local function apply()
        local tValues = {};
        for sKey, oControl in pairs(tControls) do
            if (tColorKeys[sKey]) then
                local oColor = oControl:GetColour();
                tValues[sKey] = oColor:Red() * 65536 + oColor:Green() * 256 + oColor:Blue();
            elseif (sKey == "useTabs") then tValues[sKey] = tControls[sKey]:GetSelection() == 1;
            elseif (sKey == "theme") then tValues[sKey] = tControls[sKey]:GetSelection();
            elseif (sKey == "size") then tValues[sKey] = tonumber(tControls[sKey]:GetStringSelection());
            else tValues[sKey] = tControls[sKey]:GetValue(); end
        end
        EditorSettings.setMany(tValues);
        oStatus:Hide(); dDialog:Layout();
    end
    --[[!
    @fqxn CFS.Windows.EditorOptions.Private.Functions.save
    @desc Applies requested changes and closes only on success when requested; otherwise displays the failure.
    @param any bClose Close.
    @vis private
    !]]
    local function save(bClose)
        local bOK, sError = pcall(apply);
        if (bOK) then
            if (bClose) then dDialog:EndModal(wx.wxID_OK); end
        else
            oStatus:SetLabel(tostring(sError)); oStatus:Wrap(510); oStatus:Show(); dDialog:Layout();
            require("Errors").report(sError);
        end
    end
    dDialog:Connect(wx.wxID_APPLY, wx.wxEVT_COMMAND_BUTTON_CLICKED, function() save(false); end);
    dDialog:Connect(wx.wxID_OK, wx.wxEVT_COMMAND_BUTTON_CLICKED, function() save(true); end);
    return {dialog = dDialog, body = dPages, categories = oCategories, pages = tPages, select = select, controls = tControls, apply = apply};
end

--[[!
@fqxn CFS.Windows.EditorOptions.Functions.show
@pulsarlua function EditorOptions.show
@desc Runs and destroys the editor-options dialog.
@param any dParent Parent window.
!]]
function EditorOptions.show(dParent)
    local tWindow = EditorOptions.create(dParent);
    tWindow.dialog:ShowModal(); tWindow.dialog:Destroy();
end

return EditorOptions;
