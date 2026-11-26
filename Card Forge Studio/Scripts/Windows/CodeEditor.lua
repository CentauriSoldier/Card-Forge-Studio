--[[!
@fqxn CFS.Windows.CodeEditor
@desc
<section aria-label="CodeEditor overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">CodeEditor</h2><p style="font-size:1.15rem;margin:0">Code Editor is a focused editor for a code cell's stored script.</p></div>
<h3>How it fits into your work</h3><p>Open the cell, edit with shared preferences, and validate the draft before accepting it.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.DataGrid">Data Grid</a></h3><p style="margin:0">The common grid supplies table controls for both data windows.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys.CSV">Card Data Processing</a></h3><p style="margin:0">The CSV processor connects entered values with the values used to draw a card.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.EditorSettings">EditorSettings</a></h3><p style="margin:0">Shared settings keep the code editors consistent across projects.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Code-cell scripts are interpreted through the processing environment; the grid's display is not the raw encoded storage.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

-- Modal Lua code-cell editor. The draft stays in memory until Save.
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

--[[!
@fqxn CFS.Windows.CodeEditor.Functions.create
@pulsarlua function CodeEditor.create
@desc Creates a modal Lua code-cell editor from Base64 text. Save is enabled only for changed, valid source. Closing with a draft prompts to save, discard or cancel.
@param any dParent Parent window.
@param any sEncoded Base64-encoded Lua source.
@param any sTitle Display title.
@param function fSave Optional callback accepting saved Base64 source before the draft is marked saved.
!]]
function CodeEditor.create(dParent, sEncoded, sTitle, fSave)
    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, sTitle or "Code Editor",
        wx.wxDefaultPosition, wx.wxSize(800, 600), wx.wxDEFAULT_DIALOG_STYLE + wx.wxRESIZE_BORDER);
    local oWindowState = WindowState.bind(dDialog, "CodeEditor");
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oCode = wxstc.wxStyledTextCtrl(dDialog, wx.wxID_ANY);
    local oStatus = wx.wxStaticText(dDialog, wx.wxID_ANY, "");
    local oButtons = wx.wxBoxSizer(wx.wxHORIZONTAL);

    local oApply = wx.wxButton(dDialog, wx.wxID_SAVE, "Save");
    local oCancel = wx.wxButton(dDialog, wx.wxID_CANCEL, "Cancel");
    local oSyntaxTimer = wx.wxTimer(dDialog);
    local sResult;

    local tFindBar = EditorSettings.findBar(dDialog, function() return oCode; end);
    EditorSettings.configure(oCode, "lua", tFindBar.focus);
    require("Autocomplete").Attach(oCode);
    local oThemeBar, oTheme, oFontSize, unregister = EditorSettings.bar(dDialog, {oCode}, tFindBar);
    oCode:SetText(Base64.dec(sEncoded));
    oCode:EmptyUndoBuffer();
    local sSaved = oCode:GetText();

    --[[!
    @fqxn CFS.Windows.CodeEditor.Private.Functions.checkSyntax
    @desc Compiles the draft without running it, displays syntax errors, and enables Save only for changed, valid source.
    @vis private
    !]]
    local function checkSyntax()
        local fChunk, sError = load(oCode:GetText(), "Code cell", "t", {});
        oStatus:SetLabel(fChunk and "" or sError);
        oStatus:Show(fChunk == nil);
        oApply:Enable(fChunk ~= nil and oCode:GetText() ~= sSaved);
        dDialog:Layout();
        return fChunk ~= nil;
    end
    oStatus:SetForegroundColour(wx.wxColour(170, 25, 25));
    oStatus:Hide();
    oCode:Connect(wxstc.wxEVT_STC_CHANGE, function()
        -- Disable immediately; the deferred syntax check enables valid changed drafts.
        oApply:Enable(false);
        oSyntaxTimer:Start(250, true);
    end);
    dDialog:Connect(oSyntaxTimer:GetId(), wx.wxEVT_TIMER, checkSyntax);

    local function fFinish(nResult)
        oSyntaxTimer:Stop();
        unregister();
        dDialog:EndModal(nResult);
    end

    -- A failed callback leaves the draft unsaved and the dialog open.
    local function fSaveDraft()
        if (oCode:GetText() == sSaved) then return true; end
        EditorSettings.cleanControl(oCode);
        if (not checkSyntax()) then return false; end
        local sEncodedDraft = Base64.enc(oCode:GetText());
        if (fSave) then
            local bOK, sError = pcall(fSave, sEncodedDraft);
            if (not bOK) then
                oStatus:SetLabel(tostring(sError));
                oStatus:Show();
                dDialog:Layout();
                return false;
            end
        end
        sResult = sEncodedDraft;
        sSaved = oCode:GetText();
        oSyntaxTimer:Stop();
        checkSyntax();
        return true;
    end

    local function fSaveCommand()
        if (oCode:GetText() == sSaved) then return; end
        if (fSaveDraft() and EditorSettings.get().autoCloseCodeColumnEditor) then
            fFinish(wx.wxID_OK);
        end
    end

    local function fClose()
        if (oCode:GetText() ~= sSaved) then
            local nAnswer = wx.wxMessageBox("Save your code column changes? No discards the unsaved draft.",
                "Code Column Editor", wx.wxYES_NO + wx.wxCANCEL + wx.wxICON_QUESTION, dDialog);
            if (nAnswer == wx.wxCANCEL) then return false; end
            if (nAnswer == wx.wxYES and not fSaveDraft()) then return false; end
        end
        fFinish(sResult ~= nil and wx.wxID_OK or wx.wxID_CANCEL);
        return true;
    end

    dDialog:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        if (not fClose() and oEvent:CanVeto()) then oEvent:Veto(); end
    end);
    oApply:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, fSaveCommand);
    dDialog:Connect(wx.wxID_CANCEL, wx.wxEVT_COMMAND_BUTTON_CLICKED, fClose);
    dDialog:Connect(wx.wxID_SAVE, wx.wxEVT_COMMAND_MENU_SELECTED, fSaveCommand);
    dDialog:SetAcceleratorTable(wx.wxAcceleratorTable({
        wx.wxAcceleratorEntry(wx.wxACCEL_CTRL, string.byte("S"), wx.wxID_SAVE),
    }));
    dDialog:Connect(wx.wxEVT_CHAR_HOOK, function(oEvent)
        if (oEvent:GetKeyCode() == wx.WXK_ESCAPE) then fClose();
        else oEvent:Skip(); end
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
        findBar = tFindBar, theme = oTheme, fontSize = oFontSize, status = oStatus, syntaxTimer = oSyntaxTimer,
        windowState = oWindowState, getResult = function() return sResult; end};
end

--[[!
@fqxn CFS.Windows.CodeEditor.Functions.edit
@pulsarlua function CodeEditor.edit
@desc Runs the code-cell editor; returns the last saved Base64 text or nil if nothing was saved, then releases native state. Saves invoke the optional callback immediately.
@param any dParent Parent window.
@param any sEncoded Base64-encoded Lua source.
@param any sTitle Display title.
@param function fSave Optional callback accepting saved Base64 source.
!]]
function CodeEditor.edit(dParent, sEncoded, sTitle, fSave)
    local tEditor = CodeEditor.create(dParent, sEncoded, sTitle, fSave);
    local nResult = tEditor.dialog:ShowModal();
    local sResult = nResult == wx.wxID_OK and tEditor.getResult() or nil;
    tEditor.windowState.close();
    tEditor.dialog:Destroy();
    return sResult;
end

return CodeEditor;
