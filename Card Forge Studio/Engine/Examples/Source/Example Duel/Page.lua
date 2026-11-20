--[[!
@fqxn Example.Page
@desc Playable local duel rendered through the engine OpenGL bridge.
!]]
local _wx = require("wx");
local _OpenGL = require("OpenGL");
local Page = {};

--[[!
@fqxn Example.Page.create
@desc Creates a playable duel using a content provider or a development directory.
@param wxWindow oParent Page parent.
@param string|table vContent Development directory or bundled content provider.
@param boolean|nil bManual Disables the timer for step-driven tests.
@ret table Duel view with its panel and canvas.
!]]
function Page.create(oParent, vContent, bManual)
    local bSource = type(vContent) == "string";
    local Game, tDefinitions;

    if (bSource) then
        Game = assert(loadfile(vContent.."/Game.lua", "t"))();
        tDefinitions = assert(loadfile(vContent.."/Cards.lua", "t"))();
    else
        Game = vContent.load("Game.lua");
        tDefinitions = vContent.load("Cards.lua");
    end

    local Duel = Game.create(vContent);
    local oPage = _wx.wxPanel(oParent, _wx.wxID_ANY);
    oPage:SetBackgroundColour(_wx.wxColour(12, 24, 33));
    oPage:SetForegroundColour(_wx.wxColour(238, 223, 185));
    local oStatus = _wx.wxStaticText(oPage, _wx.wxID_ANY, "");
    oStatus:SetName("Example Duel Status");
    local oEnd = _wx.wxButton(oPage, _wx.wxID_ANY, "End turn [Enter]");
    local oRestart = _wx.wxButton(oPage, _wx.wxID_ANY, "New game [R]");
    local oToolbar = _wx.wxBoxSizer(_wx.wxHORIZONTAL);
    oToolbar:Add(oStatus, 1, _wx.wxALIGN_CENTER_VERTICAL + _wx.wxRIGHT, 12);
    oToolbar:Add(oEnd, 0, _wx.wxRIGHT, 8); oToolbar:Add(oRestart, 0);
    local oCanvas = _wx.wxPanel(oPage, _wx.wxID_ANY, _wx.wxDefaultPosition, _wx.wxDefaultSize,
        _wx.wxBORDER_NONE + _wx.wxWANTS_CHARS);
    oCanvas:SetName("Example Duel Table"); oCanvas:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
    local oDetails = _wx.wxStaticText(oPage, _wx.wxID_ANY, "Hover to inspect a card. Click or press 1-5 to play.");
    local oLog = _wx.wxStaticText(oPage, _wx.wxID_ANY, "30 health | 3 energy each turn | Shields expire at your next turn | Refill to 5 cards");
    local oSizer = _wx.wxBoxSizer(_wx.wxVERTICAL);
    oSizer:Add(oToolbar, 0, _wx.wxEXPAND + _wx.wxALL, 10);
    oSizer:Add(oCanvas, 1, _wx.wxEXPAND);
    oSizer:Add(oDetails, 0, _wx.wxEXPAND + _wx.wxALL, 8);
    oSizer:Add(oLog, 0, _wx.wxEXPAND + _wx.wxLEFT + _wx.wxRIGHT + _wx.wxBOTTOM, 8);
    oPage:SetSizer(oSizer);
    local oRenderer, oProgram, uWhite, uBack;
    local tTextures, tSprites, tEffects = {}, {}, {};
    local tSnapshot = Duel.getSnapshot();
    local sHover = "";
    local bDisposed, bFailed = false, false;
    local nComputerElapsed, nLast = 0, _OpenGL.clock();
    local oTimer;
    local View = {Control = oPage, Canvas = oCanvas};

    local function fTexture(pPath)
        local oImage;
        if (bSource) then
            oImage = _wx.wxImage(vContent.."/"..pPath, _wx.wxBITMAP_TYPE_PNG);
        else
            oImage = vContent.loadImage(pPath);
        end

        if (not oImage:IsOk()) then oImage:delete(); error("Cannot load "..pPath); end
        local bOK, vResult = pcall(function()
            return oRenderer:createTexture(oImage:GetWidth(), oImage:GetHeight(), oImage:GetData(),
                oImage:HasAlpha() and oImage:GetAlpha() or nil);
        end);
        oImage:delete(); assert(bOK, vResult); return vResult;
    end
    local bReady, sFailure = xpcall(function()
        oRenderer = _OpenGL.create(oCanvas:GetHandle());
        oProgram = oRenderer:createProgram(_OpenGL.VertexShader, _OpenGL.FragmentShader);
        uWhite = oRenderer:createTexture(1, 1, string.char(255, 255, 255, 255));
        uBack = fTexture("Images/Cards/Backs/midnight-back.png");
        for _, tCard in ipairs(tDefinitions) do
            tTextures[tCard.Key] = fTexture("Images/Cards/Fronts/"..tCard.Key.."-front.png");
        end
    end, debug.traceback);
    if (not bReady) then
        if (oRenderer) then oRenderer:close(); end
        oPage:Destroy(); error(sFailure);
    end

    local function fStatus()
        local tYou, tEnemy = tSnapshot.Players[1], tSnapshot.Players[2];
        local sTurn = tSnapshot.Winner == 1 and "YOU WIN" or tSnapshot.Winner == 2 and "COMPUTER WINS"
            or tSnapshot.Active == 1 and "YOUR TURN" or "COMPUTER TURN";
        oStatus:SetLabel(sTurn.."  |  You: "..tYou.Health.." HP / "..tYou.Shield.." shield / "..tYou.Energy
            .." energy\nEnemy: "..tEnemy.Health.." HP / "..tEnemy.Shield.." shield / "..tEnemy.Energy.." energy");
        oEnd:Enable(tSnapshot.Active == 1 and tSnapshot.Winner == 0);
        local sDetails = "Hover a card for its effects. Click or press 1-5 to play. Deck: "..tYou.DeckCount
            .." | Discard: "..tYou.DiscardCount;
        for _, tCard in ipairs(tYou.Hand) do
            if (tCard.ID == sHover) then sDetails = tCard.Name.." — "..tCard.Text; break; end
        end
        oDetails:SetLabel(sDetails);
    end
    local function fSync()
        tSnapshot = Duel.getSnapshot();
        local tPresent = {};
        for nPlayer, tPlayer in ipairs(tSnapshot.Players) do
            for _, sPlace in ipairs({"Hand", "Played"}) do
                local tCards = tPlayer[sPlace];
                for nIndex, tCard in ipairs(tCards) do
                    tPresent[tCard.ID] = true;
                    local tEntry = tSprites[tCard.ID];
                    if (not tEntry) then
                        tEntry = {ID = tCard.ID, Key = tCard.Key, Player = nPlayer,
                            Animator = CardForgeEngine.CardAnimator({X = nPlayer == 1 and 110 or 1170,
                                Y = nPlayer == 1 and 580 or 130, Scale = 0.48, Flip = math.pi, Alpha = 1})};
                        tSprites[tCard.ID] = tEntry;
                    end
                    local nX, nY, nScale, nAngle;
                    if (sPlace == "Hand") then
                        local nOffset = nIndex - (#tCards + 1) / 2;
                        nX = 640 + nOffset * (nPlayer == 1 and 165 or 105);
                        nY = nPlayer == 1 and (tCard.ID == sHover and 590 or 630 + math.abs(nOffset) * 7) or 115;
                        nScale = nPlayer == 1 and (tCard.ID == sHover and 1.03 or 0.88) or 0.47;
                        nAngle = nPlayer == 1 and nOffset * 0.045 or 0;
                    else
                        nX = 640 + (nIndex - (#tCards + 1) / 2) * math.min(100, 600 / math.max(1, #tCards));
                        nY, nScale, nAngle = nPlayer == 1 and 405 or 265, 0.48, 0;
                    end
                    local sTarget = sPlace..":"..nX..":"..nY..":"..nScale;
                    if (tEntry.Target ~= sTarget) then
                        tEntry.Animator.moveTo({X = nX, Y = nY, Scale = nScale, Angle = nAngle,
                            Flip = nPlayer == 2 and sPlace == "Hand" and math.pi or 0, Alpha = 1}, 0.42, 60);
                        tEntry.Target = sTarget;
                    end
                    tEntry.Place, tEntry.Index = sPlace, nIndex;
                end
            end
        end
        for sID, tEntry in pairs(tSprites) do
            if (not tPresent[sID] and tEntry.Place ~= "Discard") then
                tEntry.Place = "Discard";
                tEntry.Animator.moveTo({X = tEntry.Player == 1 and 1170 or 110,
                    Y = tEntry.Player == 1 and 580 or 130, Scale = 0.40, Alpha = 0, Angle = 0.15}, 0.5, 50);
            end
        end
        for _, tEvent in ipairs(Duel.takeEvents()) do
            if (tEvent.Kind == "Play") then
                oLog:SetLabel((tEvent.Player == 1 and "You played " or "Computer played ")..tEvent.Name..": "..tEvent.Text);
                tEffects[#tEffects + 1] = {Age = 0, Y = tEvent.Player == 1 and 265 or 405, Type = tEvent.Type};
            end
        end
        fStatus();
    end
    local function fViewport()
        local nW, nH = oCanvas:GetClientSizeWH();
        local nScale = math.min(nW / 1280, nH / 800);
        return nW, nH, nScale, (nW - 1280 * nScale) / 2, (nH - 800 * nScale) / 2;
    end
    function View.render(bReadback)
        if (bDisposed or bFailed) then return; end
        local nW, nH, nScale, nOX, nOY = fViewport();
        if (nW <= 0 or nH <= 0) then return; end
        oRenderer:beginFrame(nW, nH, 0.025, 0.045, 0.06);
        local function fQuad(uTexture, nX, nY, nWidth, nHeight, nAngle, nFlip, tTint, tEffect)
            oRenderer:draw(oProgram, uTexture, _OpenGL.transform(nOX + nX * nScale, nOY + nY * nScale,
                nWidth * nScale, nHeight * nScale, nAngle or 0, nFlip or 0, nW, nH), tTint or {1, 1, 1, 1}, tEffect);
        end
        fQuad(uWhite, 640, 400, 1230, 750, 0, 0, {0.65, 0.54, 0.28, 0.32});
        fQuad(uWhite, 640, 400, 1224, 744, 0, 0, {0.025, 0.065, 0.075, 1});
        fQuad(uWhite, 640, 355, 950, 2, 0, 0, {0.8, 0.68, 0.4, 0.45});
        fQuad(uWhite, 640, 650, 1000, 280, 0, 0, {0.12, 0.40, 0.40, 0.25}, {1, 0, 0, 0});
        for nPlayer, tPlayer in ipairs(tSnapshot.Players) do
            for nIndex = 1, math.min(5, tPlayer.DeckCount) do
                fQuad(uBack, (nPlayer == 1 and 110 or 1170) - nIndex * 1.2,
                    (nPlayer == 1 and 580 or 130) + nIndex * 2, 82, 123, 0, 0);
            end
        end
        local tOrdered = {};
        for _, tEntry in pairs(tSprites) do tOrdered[#tOrdered + 1] = tEntry; end
        table.sort(tOrdered, function(tLeft, tRight)
            if (tLeft.ID == sHover) then return false; end
            if (tRight.ID == sHover) then return true; end
            if (tLeft.Player ~= tRight.Player) then return tLeft.Player > tRight.Player; end
            return tLeft.ID < tRight.ID;
        end);
        for _, tEntry in ipairs(tOrdered) do
            local tPose = tEntry.Animator.getPose();
            local bBack = math.cos(tPose.Flip) < 0;
            local nFlip = bBack and math.pi - tPose.Flip or tPose.Flip;
            fQuad(uWhite, tPose.X + 6, tPose.Y + 10, 180 * tPose.Scale + 16, 270 * tPose.Scale + 16, tPose.Angle, nFlip,
                {0, 0, 0, 0.55 * tPose.Alpha}, {1, 0, 0, 0});
            if (tEntry.ID == sHover) then
                fQuad(uWhite, tPose.X, tPose.Y, 180 * tPose.Scale + 12, 270 * tPose.Scale + 12, tPose.Angle, 0, {0.8, 0.72, 0.4, 0.85});
            end
            fQuad(bBack and uBack or tTextures[tEntry.Key], tPose.X, tPose.Y, 180 * tPose.Scale, 270 * tPose.Scale,
                tPose.Angle, nFlip, {1, 1, 1, tPose.Alpha});
        end
        for _, tEffect in ipairs(tEffects) do
            local nProgress = tEffect.Age / 0.65;
            local tTint = tEffect.Type == "Attack" and {1, 0.45, 0.15, 1 - nProgress}
                or tEffect.Type == "Shield" and {0.3, 0.9, 0.65, 1 - nProgress} or {0.65, 0.45, 1, 1 - nProgress};
            fQuad(uWhite, 640, tEffect.Y, 100 + nProgress * 330, 100 + nProgress * 330, 0, 0, tTint, {2, 0.8, 0, 0});
        end
        local sPixels = bReadback and oRenderer:readPixels(nW, nH) or nil;
        oRenderer:present(); return sPixels, nW, nH;
    end
    function View.getSnapshot() return Duel.getSnapshot(); end
    function View.getGraphicsInfo() return oRenderer:info(); end
    function View.play(sID)
        if (bDisposed or bFailed or tSnapshot.Active ~= 1) then return false; end
        local bPlayed = Duel.play(sID);
        if (not bPlayed and sID ~= "") then
            oLog:SetLabel(tSnapshot.Winner ~= 0 and "Duel complete. Choose New game to play again."
                or "Not enough energy for that card. Play an energy card or end your turn.");
        end
        sHover = ""; fSync(); oCanvas:Refresh(false); return bPlayed;
    end
    function View.endTurn()
        if (bDisposed or bFailed or tSnapshot.Active ~= 1) then return false; end
        local bEnded = Duel.endTurn(); sHover = ""; nComputerElapsed = 0; fSync(); oCanvas:Refresh(false); return bEnded;
    end
    function View.restart()
        if (bDisposed or bFailed) then return; end
        Duel = Game.create(vContent); tSprites = {}; tEffects = {}; sHover = ""; nComputerElapsed = 0;
        oLog:SetLabel("New duel. Click a card to play; end your turn when ready."); fSync();
    end
    function View.advance(nDelta)
        if (bDisposed or bFailed) then return; end
        assert(rawtype(nDelta) == "number" and nDelta >= 0 and nDelta < math.huge);
        for sID, tEntry in pairs(tSprites) do
            tEntry.Animator.update(nDelta);
            if (tEntry.Place == "Discard" and not tEntry.Animator.isMoving()) then tSprites[sID] = nil; end
        end
        for nIndex = #tEffects, 1,  - 1 do
            tEffects[nIndex].Age = tEffects[nIndex].Age + nDelta;
            if (tEffects[nIndex].Age >= 0.65) then table.remove(tEffects, nIndex); end
        end
        if (tSnapshot.Active == 2 and tSnapshot.Winner == 0) then
            nComputerElapsed = nComputerElapsed + nDelta;
            if (nComputerElapsed >= 0.9) then
                nComputerElapsed = 0; Duel.stepComputer(); fSync();
            end
        end
    end
    function View.dispose()
        if (bDisposed) then return; end
        bDisposed = true;
        if (oTimer) then oTimer:Stop(); oPage:Disconnect(oTimer:GetId(), _wx.wxEVT_TIMER); oTimer:delete(); oTimer = nil; end
        oRenderer:close();
    end
    local function fGuard(fWork)
        if (bDisposed or bFailed) then return; end
        local bOK, sError = xpcall(fWork, debug.traceback);
        if (not bOK) then
            bFailed = true; if (oTimer) then oTimer:Stop(); end
            oStatus:SetLabel("Demo stopped: "..tostring(sError)); oEnd:Enable(false); oRestart:Enable(false);
        end
    end
    local function fHit(nX, nY)
        for nIndex = #tSnapshot.Players[1].Hand, 1,  - 1 do
            local tCard = tSnapshot.Players[1].Hand[nIndex]; local tEntry = tSprites[tCard.ID];
            if (tEntry) then
                local tPose = tEntry.Animator.getPose(); local nDX, nDY = nX - tPose.X, nY - tPose.Y;
                local nCos, nSin = math.cos(tPose.Angle), math.sin(tPose.Angle);
                if (math.abs(nDX * nCos + nDY * nSin) <= 90 * tPose.Scale and math.abs( - nDX * nSin + nDY * nCos) <= 135 * tPose.Scale) then return tCard.ID; end
            end
        end
        return "";
    end
    oCanvas:Connect(_wx.wxEVT_PAINT, function()
        local oPaint = _wx.wxPaintDC(oCanvas); fGuard(function() View.render(); end); oPaint:delete();
    end);
    oCanvas:Connect(_wx.wxEVT_ERASE_BACKGROUND, function() end);
    oCanvas:Connect(_wx.wxEVT_SIZE, function(jEvent) oCanvas:Refresh(false); jEvent:Skip(); end);
    oCanvas:Connect(_wx.wxEVT_MOTION, function(jEvent)
        fGuard(function()
            local _, _, nScale, nOX, nOY = fViewport(); if (nScale <= 0) then return; end
            local sID = fHit((jEvent:GetX() - nOX) / nScale, (jEvent:GetY() - nOY) / nScale);
            if (sID ~= sHover) then sHover = sID; fSync(); end
        end);
    end);
    oCanvas:Connect(_wx.wxEVT_LEAVE_WINDOW, function() fGuard(function() sHover = ""; fSync(); end); end);
    oCanvas:Connect(_wx.wxEVT_LEFT_UP, function(jEvent)
        fGuard(function()
            oCanvas:SetFocus(); local _, _, nScale, nOX, nOY = fViewport(); if (nScale <= 0) then return; end
            View.play(fHit((jEvent:GetX() - nOX) / nScale, (jEvent:GetY() - nOY) / nScale));
        end);
    end);
    oCanvas:Connect(_wx.wxEVT_KEY_DOWN, function(jEvent)
        local nKey = jEvent:GetKeyCode();
        fGuard(function()
            if (nKey >= 49 and nKey <= 53) then
                local tCard = tSnapshot.Players[1].Hand[nKey - 48]; if (tCard) then View.play(tCard.ID); end
            elseif (nKey == _wx.WXK_RETURN) then View.endTurn();
            elseif (nKey == 82) then View.restart(); else jEvent:Skip(); end
        end);
    end);
    oEnd:Connect(_wx.wxEVT_COMMAND_BUTTON_CLICKED, function() fGuard(View.endTurn); oCanvas:SetFocus(); end);
    oRestart:Connect(_wx.wxEVT_COMMAND_BUTTON_CLICKED, function() fGuard(View.restart); oCanvas:SetFocus(); end);
    oCanvas:Connect(_wx.wxEVT_DESTROY, function(jEvent)
        if (jEvent:GetEventObject() == oCanvas) then View.dispose(); end; jEvent:Skip();
    end);
    fSync();
    if (not bManual) then
        oTimer = _wx.wxTimer(oPage);
        oPage:Connect(oTimer:GetId(), _wx.wxEVT_TIMER, function()
            local nNow = _OpenGL.clock(); local nDelta = math.max(0, nNow - nLast); nLast = nNow;
            if (oCanvas:IsShownOnScreen()) then fGuard(function() View.advance(nDelta); oCanvas:Refresh(false); end); end
        end);
        assert(oTimer:Start(16), "Cannot start duel timer.");
    end
    return View;
end

return Page;