-- Native UI integration check; run from Bin/Windows. Opens and closes a disposable test window.
local function main()
    local pRoot = assert(arg[1], "Supply the installation root.");
    package.path = pRoot.."/?.lua;"..pRoot.."/?/init.lua;"..pRoot.."/../Scripts/Plugins/?.lua;"..pRoot.."/../Scripts/Plugins/?/init.lua;"..pRoot.."/Scripts/Plugins/?.lua;"..pRoot.."/Scripts/Plugins/?/init.lua";
    require("LuaEx.init"); require("cog.load")();
    local wx = require("wx");
    local wxLuma = require("wxLuma")();
    local oFrame = require("Scripts.Windows.TestSuite").create(wx.NULL, wxLuma, pRoot);
    local oNotebook = oFrame:GetChildren():GetFirst():GetData():DynamicCast("wxNotebook");

    assert(oNotebook and oNotebook:GetPageCount() == 4, "Four test tabs expected.");
    oFrame:Show(true); oNotebook:SetSelection(1);
    local oTimer = wx.wxTimer(oFrame);
    local nTicks = 0;
    local sFailure;
    oFrame:Connect(oTimer:GetId(), wx.wxEVT_TIMER, function()
        local bOK, sError = xpcall(function()
            nTicks = nTicks + 1;
            local oCanvas = wx.wxWindow.FindWindowByName("Animated Card Table", oFrame);
            assert(oCanvas and oCanvas:IsShownOnScreen(), "GPU tab is not visible.");
            local oDraw = wx.wxWindow.FindWindowByLabel("Draw card  [D]", oFrame);
            assert(oDraw, "Draw button missing.");
            local oStatus = wx.wxWindow.FindWindowByName("Card Animation Status", oFrame);
            assert(oStatus and not oStatus:GetLabel():find('stopped', 1, true), 'Animation page reported a failure.');
            if (nTicks == 8) then
                local nBefore = assert(tonumber(oStatus:GetLabel():match('^(%d+)')));
                local oClick = wx.wxCommandEvent(wx.wxEVT_COMMAND_BUTTON_CLICKED, oDraw:GetId());
                oClick:SetEventObject(oDraw); oDraw:GetEventHandler():ProcessEvent(oClick); oClick:delete();
                assert(tonumber(oStatus:GetLabel():match('^(%d+)')) == nBefore + 1, 'Draw event did not add a card.');
            elseif (nTicks == 10) then
                local oDiscard = wx.wxWindow.FindWindowByLabel("Discard all  [R]", oFrame);
                local oClick = wx.wxCommandEvent(wx.wxEVT_COMMAND_BUTTON_CLICKED, oDiscard:GetId());
                oClick:SetEventObject(oDiscard); oDiscard:GetEventHandler():ProcessEvent(oClick); oClick:delete();
                assert(oStatus:GetLabel():match('^0 / 10'), 'Discard event did not clear the hand.');
            elseif (nTicks == 14) then
                oFrame:SetSize(800,560);
            end
        end, debug.traceback);
        if (not bOK) then sFailure = sError; end
        if (sFailure or nTicks >= 16) then oTimer:Stop(); oFrame:Close(); end
    end);
    oTimer:Start(150);
    wx.wxGetApp():MainLoop();
    oTimer:delete(); collectgarbage("collect");
    assert(not sFailure,sFailure);
    print("PASS: real Test Suite tab activation, timer/paint loop, native Draw/Discard button events, resize and close.");
end

main();
