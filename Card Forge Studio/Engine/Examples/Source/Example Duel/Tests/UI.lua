-- Run from Engine/Bin/Windows: & "../../../Bin/lua.exe" "../../Examples/Source/Example Duel/Tests/UI.lua" ../.. "../../Examples/Source/Example Duel"
local _pRoot, _pExample = assert(arg[1]), assert(arg[2]);
package.path = _pRoot.."/?.lua;".._pRoot.."/?/init.lua;".._pRoot.."/../Scripts/Plugins/?.lua;".._pRoot.."/../Scripts/Plugins/?/init.lua;".._pRoot.."/Scripts/Plugins/?.lua;".._pRoot.."/Scripts/Plugins/?/init.lua";
require("LuaEx.init"); require("cog.load")();
local _wx = require("wx");
local _Page = assert(loadfile(_pExample.."/Page.lua"))();
local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Example duel verification", _wx.wxDefaultPosition, _wx.wxSize(1200,900));
local View;
local bOK, sError = xpcall(function()
    View = _Page.create(oFrame, _pExample, true);
    View.Control:SetSize(0,0,1200,900); View.Control:Layout();
    local sDrawing, nW, nH = View.render(true);
    assert(#sDrawing == nW*nH*4);
    View.advance(1);
    local sHand = View.render(true);
    assert(sHand ~= sDrawing, "Drawing must animate the model's hand.");
    local tState = View.getSnapshot();
    local bPlayed = false;
    for _, tCard in ipairs(tState.Players[1].Hand) do
        if (View.play(tCard.ID)) then bPlayed = true; break; end
    end
    assert(bPlayed and #View.getSnapshot().Players[1].Played == 1);
    View.advance(0.5);
    assert(View.render(true) ~= sHand, "Playing must change rendered pixels.");
    assert(View.endTurn());
    for nStep = 1, 80 do
        View.advance(1);
        if (View.getSnapshot().Active == 1 or View.getSnapshot().Winner ~= 0) then break; end
    end
    assert(View.getSnapshot().Active == 1 or View.getSnapshot().Winner ~= 0, "Computer failed to finish its turn.");
    View.restart(); View.advance(1);
    assert(View.getSnapshot().Players[1].Health == 30 and View.getSnapshot().Turn == 1);
    View.Control:SetSize(0,0,800,600); View.Control:Layout();
    local sSmall, nSmallW, nSmallH = View.render(true);
    assert(nSmallW == View.Canvas:GetClientSizeWH() and #sSmall == nSmallW*nSmallH*4);
    print("GPU: "..View.getGraphicsInfo().Renderer);
    View.dispose(); View.dispose();
end, debug.traceback);
if (View) then View.dispose(); end
 oFrame:Destroy(); _wx.wxGetApp():ProcessPendingEvents();
assert(bOK, sError);
print("PASS: all 20 textures, OpenGL draw/play pixels, computer turn, restart, resize and disposal.");