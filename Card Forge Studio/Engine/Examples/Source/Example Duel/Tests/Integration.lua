-- Run from Engine/Bin/Windows: & "../../../Bin/lua.exe" "../../Examples/Source/Example Duel/Tests/Integration.lua" ../..
local _pRoot = assert(arg[1]);
package.path = _pRoot.."/?.lua;".._pRoot.."/?/init.lua;".._pRoot.."/../Scripts/Plugins/?.lua;".._pRoot.."/../Scripts/Plugins/?/init.lua;".._pRoot.."/Scripts/Plugins/?.lua;".._pRoot.."/Scripts/Plugins/?/init.lua";
require("LuaEx.init"); require("cog.load")();
package.path = package.path..";".._pRoot.."/../Scripts/?.lua";
local _wx = require("wx");
local _wxLuma = require("wxLuma")();
local oFrame = require("Scripts.Windows.TestSuite").create(_wx.NULL, _wxLuma, _pRoot);
local oNotebook = oFrame:GetChildren():GetFirst():GetData():DynamicCast("wxNotebook");
assert(oNotebook:GetPageCount() == 4 and oNotebook:GetPageText(3) == "Example Duel");
oFrame:Show(true); oNotebook:SetSelection(3);
local oTimer = _wx.wxTimer(oFrame);
local nTicks, sFailure = 0, nil;
oFrame:Connect(oTimer:GetId(), _wx.wxEVT_TIMER, function()
    local bOK, sError = xpcall(function()
        nTicks = nTicks + 1;
        local oStatus = _wx.wxWindow.FindWindowByName("Example Duel Status", oFrame);
        assert(oStatus and not oStatus:GetLabel():find("stopped", 1, true), "Example page did not start cleanly.");
        local oCanvas = _wx.wxWindow.FindWindowByName("Example Duel Table", oFrame);
        assert(oCanvas and oCanvas:IsShownOnScreen());
        if (nTicks == 4 or nTicks == 9) then
            local sLabel = nTicks == 4 and "End turn [Enter]" or "New game [R]";
            local oButton = _wx.wxWindow.FindWindowByLabel(sLabel, oFrame);
            assert(oButton);
            local oClick = _wx.wxCommandEvent(_wx.wxEVT_COMMAND_BUTTON_CLICKED, oButton:GetId());
            oClick:SetEventObject(oButton); oButton:GetEventHandler():ProcessEvent(oClick); oClick:delete();
            assert(oStatus:GetLabel():find(nTicks == 4 and "COMPUTER TURN" or "YOUR TURN", 1, true));
        elseif (nTicks == 11) then oFrame:SetSize(900,700); end
    end, debug.traceback);
    if (not bOK) then sFailure = sError; end
    if (sFailure or nTicks >= 14) then oTimer:Stop(); oFrame:Close(); end
end);
oTimer:Start(150); _wx.wxGetApp():MainLoop(); oTimer:delete();
assert(not sFailure, sFailure);
print("PASS: CFA package loaded from Test Suite, native end-turn/restart events, timer, resize and close.");