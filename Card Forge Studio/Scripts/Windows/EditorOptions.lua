--[[!
@fqxn CFS.Windows.EditorOptions
@desc Shared editor-preference dialog for editing, layout, and whitespace options.
!]]

-- Shared code-editor options. Changes remain staged until Apply or OK.
local wx = require("wx");
local EditorSettings = require("Windows.EditorSettings");
local EditorOptions = {};

--[[!
@fqxn CFS.Windows.EditorOptions.create
@pulsarlua function EditorOptions.create
@desc Creates controls for shared editor preferences with Apply, Save, and Cancel behavior.
@param any dParent Parent window.
!]]
function EditorOptions.create(dParent)
    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, "Editor Options", wx.wxDefaultPosition, wx.wxSize(610, 720),
        wx.wxDEFAULT_DIALOG_STYLE + wx.wxRESIZE_BORDER);
    dDialog:SetMinSize(wx.wxSize(540, 500));
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local dBody = wx.wxScrolledWindow(dDialog, wx.wxID_ANY); dBody:SetScrollRate(0, 12);
    local oBody = wx.wxBoxSizer(wx.wxVERTICAL);
    local tControls, tState = {}, EditorSettings.get();
    local oHelp = wx.wxStaticText(dBody, wx.wxID_ANY, "These settings apply to every code and source editor. Saving options can change text when you save. Wiki settings are separate.");
    oHelp:Wrap(520); oBody:Add(oHelp, 0, wx.wxALL, 12);
    --[[!
    @fqxn CFS.Windows.EditorOptions.Private.block
    @desc Creates a labeled group of editor options.
    @param any sName Name.
    @vis private
    !]]
    local function block(sName)
        local oBox = wx.wxStaticBox(dBody, wx.wxID_ANY, sName);
        local oBlock = wx.wxStaticBoxSizer(oBox, wx.wxVERTICAL);
        oBody:Add(oBlock, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 12);
        return oBlock;
    end
    --[[!
    @fqxn CFS.Windows.EditorOptions.Private.check
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
    @fqxn CFS.Windows.EditorOptions.Private.row
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
    oBlock = block("Saving");
    check(oBlock, "trimTrailing", "Remove trailing spaces and tabs on Save");
    check(oBlock, "finalNewline", "Ensure a final newline on Save");
    dBody:SetSizer(oBody);
    oLayout:Add(dBody, 1, wx.wxEXPAND);
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
    @fqxn CFS.Windows.EditorOptions.Private.apply
    @desc Collects option values and passes them to the shared validated settings setter.
    @vis private
    !]]
    local function apply()
        local tValues = {};
        for sKey, oControl in pairs(tControls) do
            if (sKey == "useTabs") then tValues[sKey] = tControls[sKey]:GetSelection() == 1;
            elseif (sKey == "theme") then tValues[sKey] = tControls[sKey]:GetSelection();
            elseif (sKey == "size") then tValues[sKey] = tonumber(tControls[sKey]:GetStringSelection());
            else tValues[sKey] = tControls[sKey]:GetValue(); end
        end
        EditorSettings.setMany(tValues);
        oStatus:Hide(); dDialog:Layout();
    end
    --[[!
    @fqxn CFS.Windows.EditorOptions.Private.save
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
    return {dialog = dDialog, body = dBody, controls = tControls, apply = apply};
end

--[[!
@fqxn CFS.Windows.EditorOptions.show
@pulsarlua function EditorOptions.show
@desc Runs and destroys the editor-options dialog.
@param any dParent Parent window.
!]]
function EditorOptions.show(dParent)
    local tWindow = EditorOptions.create(dParent);
    tWindow.dialog:ShowModal(); tWindow.dialog:Destroy();
end

return EditorOptions;
