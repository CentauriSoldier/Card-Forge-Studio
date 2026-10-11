--[[!
@fqxn CFS.Windows.NewGame
@desc
<section aria-label="NewGame overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">NewGame</h2><p style="font-size:1.15rem;margin:0">New Game collects a project name for the creation flow.</p></div>
<h3>How it fits into your work</h3><p>Enter a name and request creation. Failure retains the dialog for correction or retry.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.Game">Game</a></h3><p style="margin:0">A game is the home for a whole project: its name, shared settings, and collection of card sets.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.FS">File System</a></h3><p style="margin:0">FS is Studio's map of where project files belong.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Main">Main</a></h3><p style="margin:0">The main Studio window connects your project, preview, and editing tools.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">The dialog collects input; Game and FS own creation and validation.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

local wx      = require("wx");
local NewGame = {};


--[[!
@fqxn CFS.Windows.NewGame.Functions.Show
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
