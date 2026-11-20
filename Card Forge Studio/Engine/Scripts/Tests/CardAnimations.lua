local function main()
    --[[!
    @fqxn CardForgeEngine.Tests.CardAnimations
    @desc Verifies animation state, interruption, hand bounds and GPU rendering.
        Run from Bin/Windows so the host native runtime dependencies are discoverable.
        Optional second argument is an output directory for rendered verification frames.
    !]]
    local _pRoot = assert(arg[1], "Supply the installation root.");
    package.path = _pRoot.."/?.lua;".._pRoot.."/?/init.lua;"
        .._pRoot.."/../Scripts/Plugins/?.lua;".._pRoot.."/../Scripts/Plugins/?/init.lua;".._pRoot.."/Scripts/Plugins/?.lua;".._pRoot.."/Scripts/Plugins/?/init.lua";
    require("LuaEx.init");
    require("cog.load")();
    local _wx = require("wx");
    local _OpenGL = require("OpenGL");

    local oTween = CardForgeEngine.Tween({X = 0}, {X = 10}, 1);
    local tHalf, nHalf = oTween.advance(0.5);
    assert(nHalf == 0.5 and tHalf.X > 5 and tHalf.X < 10);
    assert(oTween.advance(0.5).X == 10 and oTween.isComplete());
    assert(not pcall(function() oTween.advance(-1); end));
    local oAnimator = CardForgeEngine.CardAnimator({X = 0, Y = 0});
    oAnimator.moveTo({X = 100, Y = 100}, 1, 50);
    oAnimator.update(0.25);
    local tBefore = oAnimator.getPose();
    oAnimator.moveTo({X = 25, Y = 50}, 0.2);
    local tAfter = oAnimator.getPose();
    assert(tBefore.X == tAfter.X and tBefore.Y == tAfter.Y);
    oAnimator.update(1);
    assert(not oAnimator.isMoving() and oAnimator.getPose().X == 25);

    local oScene = CardForgeEngine.CardAnimationScene();
    for nIndex = 1, 10 do assert(oScene.draw()); end
    assert(not oScene.draw());
    oScene.update(1);
    local tHand = oScene.getSnapshot();
    assert(#tHand.Cards == 10 and tHand.HandCount == 10);
    local nHover = tHand.Cards[5].ID;
    assert(oScene.hover(nHover)); oScene.update(0.3);
    local tHovered = oScene.getSnapshot().Cards[10];
    assert(tHovered.ID == nHover and tHovered.Pose.Scale == 1.18);
    assert(oScene.hitTest(tHovered.Pose.X, tHovered.Pose.Y) == nHover);
    assert(oScene.play(nHover) and not oScene.play(nHover));
    oScene.update(1);
    assert(oScene.getSnapshot().PlayedCount == 1 and #oScene.getSnapshot().Effects == 1);
    oScene.discard(); oScene.update(1);
    assert(#oScene.getSnapshot().Cards == 0);
    for nCycle = 1, 30 do
        for nIndex = 1, 5 do oScene.draw(); end
        oScene.update(1);
        for _, tCard in ipairs(oScene.getSnapshot().Cards) do assert(oScene.play(tCard.ID)); end
        oScene.update(0.5); oScene.discard(); oScene.update(1);
        assert(#oScene.getSnapshot().Cards == 0);
    end
    print("PASS: interpolation, interruption, hand limit, hover hit testing, play guard and 30 animation cycles.");

    local function fSaveFrame(sName, sPixels, nWidth, nHeight)
        if (not arg[2]) then return; end
        local tRows = {};
        for nY = nHeight - 1, 0, -1 do
            local tRow = {};
            for nX = 0, nWidth - 1 do
                local nOffset = (nY * nWidth + nX) * 4 + 1;
                tRow[#tRow + 1] = sPixels:sub(nOffset, nOffset + 2);
            end
            tRows[#tRows + 1] = table.concat(tRow);
        end
        local oImage = _wx.wxImage(nWidth, nHeight);
        oImage:SetData(table.concat(tRows));
        assert(oImage:SaveFile(arg[2].."/"..sName..".png", _wx.wxBITMAP_TYPE_PNG));
        oImage:delete();
    end

    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "CFE OpenGL verification",
        _wx.wxDefaultPosition, _wx.wxSize(1100,760));
    local Page;
    local bOK, sFailure = xpcall(function()
        for nCycle = 1, 3 do
            Page = require("Scripts.Controls.CardAnimationPage").create(oFrame, _pRoot, true);
            Page.Control:SetSize(0,0,1100,760); Page.Control:Layout();
            local tInfo = Page.getGraphicsInfo();
            if (nCycle == 1) then print("GPU: "..tInfo.Renderer.." | "..tInfo.Version); end
            for nIndex = 1, 5 do Page.drawCard(); end
            Page.advance(0.3);
            local sDrawing, nW, nH = Page.render(true);
            assert(#sDrawing == nW * nH * 4);
            if (nCycle == 1) then fSaveFrame("drawing", sDrawing, nW, nH); end
            Page.advance(1);
            local sHand = Page.render(true);
            assert(sDrawing ~= sHand, "Draw animation did not change rendered pixels.");
            local tCards = Page.Scene.getSnapshot().Cards;
            Page.Scene.hover(tCards[3].ID); Page.advance(0.3);
            local sHover = Page.render(true);
            assert(sHover ~= sHand, "Hover animation did not change rendered pixels.");
            if (nCycle == 1) then fSaveFrame("hand", sHover, nW, nH); end
            assert(Page.playCard(tCards[3].ID)); Page.advance(0.48);
            local sPlayed = Page.render(true);
            assert(sPlayed ~= sHover, "Play animation did not change rendered pixels.");
            if (nCycle == 1) then fSaveFrame("played", sPlayed, nW, nH); end
            Page.Control:SetSize(0,0,640,420); Page.Control:Layout();
            local sSmall, nSmallW, nSmallH = Page.render(true);
            assert(nSmallW == 640 and #sSmall == nSmallW * nSmallH * 4);
            Page.discard(); Page.advance(1);
            assert(#Page.Scene.getSnapshot().Cards == 0);
            Page.dispose(); Page.dispose(); Page.Control:Destroy(); Page = nil;
            _wx.wxGetApp():ProcessPendingEvents(); collectgarbage("collect");
        end
    end, debug.traceback);
    if (Page) then Page.dispose(); end
    oFrame:Destroy(); _wx.wxGetApp():ProcessPendingEvents();
    assert(bOK, sFailure);
    print("PASS: shader compilation, sample textures, draw/hover/play pixel changes, resize and three open/close cycles.");
end

main();
