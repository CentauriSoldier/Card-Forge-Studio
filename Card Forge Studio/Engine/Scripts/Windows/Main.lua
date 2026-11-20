--[[!
@fqxn CardForgeEngine.Windows.Main
@desc Owns the single native application window and its welcome page.
!]]
local wx = require("wx");
local Welcome = require("Scripts.Pages.Welcome");
local GameDiscovery = require("Scripts.Services.GameDiscovery");
local Main = {};

--[[!
@fqxn CardForgeEngine.Windows.Main.create
@desc Creates the application shell, icon, page layout and page-resource cleanup.
@param string pRoot Installation root.
@param table wxLuma The loaded local widget framework.
@ret table Window Frame and Welcome page references.
!]]
function Main.create(pRoot, wxLuma)
    local oFrame = wx.wxFrame(wx.NULL, wx.wxID_ANY, "Card Forge Engine",
        wx.wxDefaultPosition, wx.wxSize(1400, 720), wx.wxDEFAULT_FRAME_STYLE);
    oFrame:SetMinClientSize(wx.wxSize(920, 620));
    local oIcon = wx.wxIcon(pRoot.."/Bin/Windows/Card Forge Engine.ico", wx.wxBITMAP_TYPE_ICO);
    assert(oIcon:IsOk(), "Cannot load the Card Forge Engine icon.");
    oFrame:SetIcon(oIcon);

    local oTestWindow;
    local oMenuBar = wx.wxMenuBar();
    local oTools = wx.wxMenu();
    local oTestSuite = oTools:Append(wx.wxID_ANY, "Test Suite");
    oMenuBar:Append(oTools, "&Tools");
    oFrame:SetMenuBar(oMenuBar);
    oFrame:Connect(oTestSuite:GetId(), wx.wxEVT_COMMAND_MENU_SELECTED, function()
        if (oTestWindow) then
            oTestWindow:Raise();
            return;
        end

        -- The window borrows the application's theme and can be reopened after closing.
        oTestWindow = require("Scripts.Windows.TestSuite").create(oFrame, wxLuma, pRoot);
        oTestWindow:Connect(wx.wxEVT_CLOSE_WINDOW, function(jEvent)
            oTestWindow = nil;
            jEvent:Skip();
        end);
        oTestWindow:Show(true);
    end);

    local Page = Welcome.create(oFrame, pRoot, wxLuma);
    -- Inventory packages without loading game code. Keep diagnostics available
    -- on the window so a later library UI can display individual scan failures.
    local tGames, tDiscoveryIssues = GameDiscovery.scan();
    Page.Games.setItems(tGames);
    local oSizer = wx.wxBoxSizer(wx.wxVERTICAL);
    oSizer:Add(Page.Control, 1, wx.wxEXPAND);
    oFrame:SetSizer(oSizer);
    oFrame:Centre();

    -- Dispose drawing resources while child controls are still valid.
    oFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        if (oTestWindow) then oTestWindow:Close(); end
        Page.dispose();
        oEvent:Skip();
    end);
    return {Frame = oFrame, Welcome = Page, DiscoveryIssues = tDiscoveryIssues};
end

return Main;