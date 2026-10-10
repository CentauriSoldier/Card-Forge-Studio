--[[!
@fqxn CFS.Windows.Columns
@desc Column-management dialog with save-before-open and save/reload-after-change behavior.
!]]

local wx      = require("wx");
local Columns = {};


--[[!
@fqxn CFS.Windows.Columns.Show
@pulsarlua function Columns.Show
@desc Manages source headers. Existing drafts must be saved first; closing saves structural changes, and failures leave the dialog open.
@param wxWindow dParent Parent window.
@param table tSession Shared Base and Final Data session.
@note Name values remain editable, but the required Name header is protected. Script references are not rewritten.
!]]
function Columns.Show(dParent, tSession)
    if (tSession.editing) then error("Finish code editing before managing columns.", 2); end

    if (tSession.dirty) then
        local dPrompt = wx.wxMessageDialog(dParent, "There are unsaved changes. Save them before managing columns?", "Columns", wx.wxOK + wx.wxCANCEL + wx.wxICON_QUESTION);

        dPrompt:SetOKCancelLabels("Save", "Cancel");
        local nAnswer = dPrompt:ShowModal();

        dPrompt:Destroy();
        if (nAnswer ~= wx.wxID_OK) then return; end
        tSession.save();
    end

    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, "Columns", wx.wxDefaultPosition, wx.wxSize(470, 440), wx.wxDEFAULT_DIALOG_STYLE + wx.wxRESIZE_BORDER);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oList   = wx.wxListBox(dDialog, wx.wxID_ANY);
    local oName   = wx.wxTextCtrl(dDialog, wx.wxID_ANY, "");
    local oActions = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local tButtons = {};
    local bChanged = false;

    oLayout:Add(oList, 1, wx.wxEXPAND + wx.wxALL, 12);
    oLayout:Add(oName, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 12);

    for _, sLabel in ipairs({"Add", "Rename", "Delete"}) do
        local oButton = wx.wxButton(dDialog, wx.wxID_ANY, sLabel);

        tButtons[sLabel] = oButton;
        oActions:Add(oButton, 0, wx.wxALL, 6);
    end
    oLayout:Add(oActions, 0, wx.wxALIGN_CENTER + wx.wxALL, 6);
    oLayout:Add(wx.wxStaticText(dDialog, wx.wxID_ANY, "Name is required. Update renamed column references in your scripts manually. Changes save when this window closes."), 0, wx.wxEXPAND + wx.wxALL, 12);
    oLayout:Add(dDialog:CreateButtonSizer(wx.wxOK), 0, wx.wxALIGN_RIGHT + wx.wxALL, 12);
    dDialog:SetSizer(oLayout);
    dDialog:CentreOnParent();

    -- Declare local helpers together so their definitions remain alphabetical.
    local close;
    local refresh;
    local run;


    --[[!
    @fqxn CFS.Windows.Columns.Private.close
    @desc Saves and reloads the set only after structural changes; failed saves keep the dialog open.
    @vis private
    !]]
    close = function()
        run(function()
            if (bChanged) then
                tSession.save();
                tSession.options.onReloadStructure();
            end
            dDialog:EndModal(wx.wxID_OK);
        end);
    end


    --[[!
    @fqxn CFS.Windows.Columns.Private.refresh
    @desc Repopulates column headers and updates available column actions.
    @vis private
    !]]
    refresh = function()
        oList:Clear();

        for _, sHeader in ipairs(tSession.headers) do
            oList:Append(sHeader);
        end
        tButtons.Rename:Enable(false);
        tButtons.Delete:Enable(false);
    end


    --[[!
    @fqxn CFS.Windows.Columns.Private.run
    @desc Executes a column-management action and reports failures without dismissing the dialog.
    @param any fAction Action.
    @vis private
    !]]
    run = function(fAction)
        local bOK, sError = xpcall(fAction, debug.traceback);

        if (not bOK) then
            require("Errors").report(sError);
        end
    end

    oList:Connect(wx.wxEVT_COMMAND_LISTBOX_SELECTED, function()
        local sHeader = oList:GetStringSelection();
        local bEditable = sHeader ~= "" and sHeader:upper() ~= "NAME";

        oName:SetValue(sHeader);
        tButtons.Rename:Enable(bEditable);
        tButtons.Delete:Enable(bEditable);
    end);

    for _, sAction in ipairs({"Add", "Rename", "Delete"}) do
        local sOperation = sAction;

        tButtons[sAction]:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
            run(function()
                local sHeader = oList:GetStringSelection();
                local sNew    = oName:GetValue():match("^%s*(.-)%s*$");

                if (sOperation == "Delete" and wx.wxMessageBox("Delete column '"..sHeader.."' and all its data?", "Delete Column", wx.wxYES_NO + wx.wxICON_WARNING, dDialog) ~= wx.wxYES) then
                    return;
                end
                tSession.changeColumn(sOperation:lower(), sOperation == "Add" and sNew or sHeader, sNew);
                bChanged = true;
                refresh();
            end);
        end);
    end

    dDialog:Connect(wx.wxID_OK, wx.wxEVT_COMMAND_BUTTON_CLICKED, close);
    dDialog:Connect(wx.wxID_CANCEL, wx.wxEVT_COMMAND_BUTTON_CLICKED, close);
    dDialog:Connect(wx.wxEVT_CLOSE_WINDOW, close);
    refresh();
    dDialog:ShowModal();
    dDialog:Destroy();
end


return Columns;
