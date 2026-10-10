--[[!
@fqxn CFS.Windows.NewGame
@desc Collects new-game input and invokes the supplied creation callback, retaining the dialog after failure.
!]]

local wx      = require("wx");
local NewGame = {};


--[[!
@fqxn CFS.Windows.NewGame.Show
@pulsarlua function NewGame.Show
@desc Collects a new game name; Cancel creates nothing. Creation errors are logged and leave the dialog open for correction or retry.
@param wxWindow dParent Parent window.
@param function fCreate Callback that creates and returns the game.
@return Game|nil Created game, or nil after cancellation.
!]]
function NewGame.Show(dParent, fCreate)
    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, "New Game", wx.wxDefaultPosition, wx.wxSize(460, 220), wx.wxDEFAULT_DIALOG_STYLE);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oName   = wx.wxTextCtrl(dDialog, wx.wxID_ANY, "");
    local oHint   = wx.wxStaticText(dDialog, wx.wxID_ANY, "Creates an empty game in your configured Games folder.");
    local oButtons = dDialog:CreateButtonSizer(wx.wxOK + wx.wxCANCEL);
    local oGame;

    oHint:Wrap(430);

    oLayout:Add(wx.wxStaticText(dDialog, wx.wxID_ANY, "Game name"), 0, wx.wxALL, 12);
    oLayout:Add(oName, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 12);
    oLayout:Add(oHint, 0, wx.wxALL, 12);
    oLayout:AddStretchSpacer();
    oLayout:Add(oButtons, 0, wx.wxALIGN_RIGHT + wx.wxALL, 12);
    dDialog:SetSizer(oLayout);
    dDialog:CentreOnParent();
    oName:SetFocus();

    dDialog:Connect(wx.wxID_OK, wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        local sName = oName:GetValue():match("^%s*(.-)%s*$");
        if (sName == "" or sName:find("[%c]")) then
            oHint:SetLabel("Enter a game name without control characters.");
            oName:SetFocus();

            return;
        end

        local bOK, vResult = xpcall(function()
            return fCreate(sName);
        end, debug.traceback);

        if (not bOK) then
            require("Errors").report(vResult);
            oHint:SetLabel("Game creation failed. See the log; correct the issue and retry.");
            oHint:Wrap(430);
            dDialog:Layout();

            return;
        end

        oGame = vResult;
        dDialog:EndModal(wx.wxID_OK);
    end);

    dDialog:ShowModal();
    dDialog:Destroy();

    return oGame;
end


return NewGame;
