--[[!
@fqxn CardForgeEngine.Controls.CardAnimationPage
@desc GPU card presentation playground. The page owns its timer and renderer;
    the scene owns animation state. Uses the existing sample card artwork.
!]]
local _wx     = require("wx");
local _OpenGL = require("OpenGL");
local _nWidth, _nHeight = 1280, 800;
local CardAnimationPage = {};

local _sBackground = [[#version 330 core
in vec2 vUV;
uniform vec4 uTint;
out vec4 outColour;
void main() {
    vec2 p = vUV - vec2(0.5, 0.45);
    float light = exp(-dot(p * vec2(1.0, 1.4), p * vec2(1.0, 1.4)) * 5.0);
    vec3 base = mix(vec3(0.018,0.025,0.055), vec3(0.055,0.12,0.16), light);
    float oval = length(p * vec2(1.10,1.85));
    float rim = 1.0 - smoothstep(0.002,0.006,abs(oval-0.44));
    base += vec3(0.10,0.35,0.38) * rim * 0.40;
    float grain = fract(sin(dot(vUV,vec2(127.1,311.7))) * 43758.5453);
    base += (grain - 0.5) * 0.009;
    outColour = vec4(base,1.0) * uTint;
}
]];

--[[!
@fqxn CardForgeEngine.Controls.CardAnimationPage.create
@desc Creates a native page with draw/discard controls and an OpenGL canvas.
@param wxWindow oParent Native parent.
@param string pRoot Installation root containing sample artwork.
@param boolean|nil bManual True disables the timer and opening deal for verification.
!]]
function CardAnimationPage.create(oParent, pRoot, bManual)
    local oPage = _wx.wxPanel(oParent, _wx.wxID_ANY);
    local oDraw = _wx.wxButton(oPage, _wx.wxID_ANY, "Draw card  [D]");
    local oDiscard = _wx.wxButton(oPage, _wx.wxID_ANY, "Discard all  [R]");
    local oStatus = _wx.wxStaticText(oPage, _wx.wxID_ANY, "Hover a card to inspect it. Click to play.");
    oStatus:SetName("Card Animation Status");
    local oToolbar = _wx.wxBoxSizer(_wx.wxHORIZONTAL);
    oToolbar:Add(oDraw, 0, _wx.wxRIGHT, 8);
    oToolbar:Add(oDiscard, 0, _wx.wxRIGHT, 16);
    oToolbar:Add(oStatus, 1, _wx.wxALIGN_CENTER_VERTICAL);
    local oCanvas = _wx.wxPanel(oPage, _wx.wxID_ANY, _wx.wxDefaultPosition,
        _wx.wxDefaultSize, _wx.wxBORDER_NONE + _wx.wxWANTS_CHARS);
    oCanvas:SetName("Animated Card Table");
    oCanvas:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
    local oSizer = _wx.wxBoxSizer(_wx.wxVERTICAL);
    oSizer:Add(oToolbar, 0, _wx.wxEXPAND + _wx.wxALL, 8);
    oSizer:Add(oCanvas, 1, _wx.wxEXPAND);
    oPage:SetSizer(oSizer);

    local oRenderer;
    local bReady, sError = xpcall(function()
        oRenderer = _OpenGL.create(oCanvas:GetHandle());
    end, debug.traceback);
    if (not bReady) then
        if (oRenderer) then oRenderer:close(); end
        oPage:Destroy();
        error(sError);
    end
    local oScene = CardForgeEngine.CardAnimationScene();
    local oProgram, oBackground, uWhite, uBack, tFronts;
    local oTimer;
    local bDisposed, bFailed = false, false;
    local nLastTime = _OpenGL.clock();
    local nDealRemaining, nDealElapsed = bManual and 0 or 5, 0;
    local Page = {Control = oPage, Canvas = oCanvas, Scene = oScene};

    local function fLoadTexture(pPath)
        local oImage = _wx.wxImage(pPath, _wx.wxBITMAP_TYPE_PNG);
        if (not oImage:IsOk()) then oImage:delete(); error("Cannot load card artwork: "..pPath); end
        local bOK, vTexture = pcall(function()
            return oRenderer:createTexture(oImage:GetWidth(), oImage:GetHeight(), oImage:GetData(),
                oImage:HasAlpha() and oImage:GetAlpha() or nil);
        end);
        oImage:delete();
        if (not bOK) then error(vTexture); end
        return vTexture;
    end
    local bLoaded, sLoadError = xpcall(function()
        oProgram = oRenderer:createProgram(_OpenGL.VertexShader, _OpenGL.FragmentShader);
        oBackground = oRenderer:createProgram(_OpenGL.VertexShader, _sBackground);
        uWhite = oRenderer:createTexture(1, 1, string.char(255,255,255,255));
        uBack = fLoadTexture(pRoot.."/Examples/Source/Example Duel/Images/Cards/Backs/midnight-back.png");
        tFronts = {
            fLoadTexture(pRoot.."/Examples/Source/Example Duel/Images/Cards/Fronts/solar-courier-front.png"),
            fLoadTexture(pRoot.."/Examples/Source/Example Duel/Images/Cards/Fronts/moss-vault-front.png"),
            fLoadTexture(pRoot.."/Examples/Source/Example Duel/Images/Cards/Fronts/tidal-array-front.png"),
        };
    end, debug.traceback);
    if (not bLoaded) then oRenderer:close(); oPage:Destroy(); error(sLoadError); end

    local function fViewport()
        local nW, nH = oCanvas:GetClientSizeWH();
        local nScale = math.min(nW / _nWidth, nH / _nHeight);
        return nW, nH, nScale, (nW - _nWidth * nScale) / 2, (nH - _nHeight * nScale) / 2;
    end

    --[[!
    @fqxn CardForgeEngine.Controls.CardAnimationPage.render
    @desc Draws a full-resolution GPU frame. Optional readback is for verification only.
    !]]
    function Page.render(bReadback)
        if (bDisposed or bFailed) then return; end
        local nW, nH, nScale, nOX, nOY = fViewport();
        if (nW <= 0 or nH <= 0) then return; end
        oRenderer:beginFrame(nW, nH, 0.018, 0.025, 0.055);
        local function fQuad(uTexture, nX, nY, nWidth, nHeight, nAngle, nFlip, tTint, tEffect, uProgram)
            oRenderer:draw(uProgram or oProgram, uTexture,
                _OpenGL.transform(nOX + nX * nScale, nOY + nY * nScale,
                    nWidth * nScale, nHeight * nScale, nAngle or 0, nFlip or 0, nW, nH),
                tTint or {1,1,1,1}, tEffect);
        end
        fQuad(uWhite, 640, 400, 1280, 800, 0, 0, nil, nil, oBackground);
        -- Play slots and hand illumination establish a stable visual destination.
        fQuad(uWhite, 640, 742, 860, 230, 0, 0, {0.15,0.38,0.65,0.19}, {1,0,0,0});
        for nIndex = 1, 5 do
            fQuad(uWhite, 410 + (nIndex - 1) * 114, 310, 111, 170, 0, 0, {0.30,0.63,0.66,0.09});
            fQuad(uWhite, 410 + (nIndex - 1) * 114, 310, 107, 166, 0, 0, {0.025,0.06,0.08,0.9});
        end
        for nIndex = 5, 1, -1 do
            fQuad(uBack, 147 - nIndex * 1.5, 422 + nIndex * 2.2, 130, 195, -0.12, 0,
                {0.82,0.88,1,1});
        end
        fQuad(uWhite, 1130, 422, 138, 203, 0.12, 0, {0.36,0.26,0.56,0.25});
        fQuad(uWhite, 1130, 422, 132, 197, 0.12, 0, {0.025,0.025,0.055,1});
        local tSnapshot = oScene.getSnapshot();
        for _, tEntry in ipairs(tSnapshot.Cards) do
            local tPose = tEntry.Pose;
            local nWidth, nHeight = 180 * tPose.Scale, 270 * tPose.Scale;
            local nFlip = math.cos(tPose.Flip) < 0 and math.pi - tPose.Flip or tPose.Flip;
            local uTexture = math.cos(tPose.Flip) < 0 and uBack or tFronts[tEntry.Artwork];
            fQuad(uWhite, tPose.X + 7, tPose.Y + 16, nWidth + 34, nHeight + 34,
                tPose.Angle, nFlip, {0,0,0,0.60 * tPose.Alpha}, {1,0,0,0});
            if (tEntry.ID == tSnapshot.Hover) then
                fQuad(uWhite, tPose.X, tPose.Y, nWidth + 34, nHeight + 34, tPose.Angle, 0,
                    {0.25,0.8,1,0.55}, {1,0,0,0});
                fQuad(uWhite, tPose.X, tPose.Y, nWidth + 5, nHeight + 5, 0, 0, {0.65,0.94,1,0.85});
            end
            fQuad(uTexture, tPose.X, tPose.Y, nWidth, nHeight, tPose.Angle, nFlip, {1,1,1,tPose.Alpha});
        end
        for _, tEffect in ipairs(tSnapshot.Effects) do
            local nProgress = tEffect.Age / 0.7;
            local nRadius = 100 + nProgress * 200;
            fQuad(uWhite, tEffect.X, tEffect.Y, nRadius, nRadius, 0, 0,
                {0.3,0.85,1,(1 - nProgress) * 0.75}, {2,0.8,0,0});
            for nIndex = 1, 14 do
                local nAngle = nIndex * math.pi * 2 / 14;
                local nDistance = 30 + nProgress * (90 + nIndex % 3 * 17);
                fQuad(uWhite, tEffect.X + math.cos(nAngle) * nDistance,
                    tEffect.Y + math.sin(nAngle) * nDistance, 12 * (1 - nProgress), 12 * (1 - nProgress),
                    nAngle, 0, {0.45,0.9,1,1 - nProgress}, {3,0,0,0});
            end
        end
        local sPixels = bReadback and oRenderer:readPixels(nW, nH) or nil;
        oRenderer:present();
        return sPixels, nW, nH;
    end

    local function fStatus()
        local tSnapshot = oScene.getSnapshot();
        oStatus:SetLabel(tSnapshot.HandCount.." / 10 in hand    |    "..tSnapshot.PlayedCount
            .." / 5 played    |    Hover to inspect · click to play");
        oDraw:Enable(tSnapshot.HandCount < 10);
    end

    function Page.drawCard()
        if (bDisposed or bFailed) then return false; end
        local vResult = oScene.draw(); fStatus(); oCanvas:Refresh(false); return vResult;
    end

    function Page.playCard(nID)
        if (bDisposed or bFailed) then return false; end
        local bPlayed = oScene.play(nID); fStatus(); oCanvas:Refresh(false); return bPlayed;
    end

    function Page.discard()
        if (bDisposed or bFailed) then return; end
        nDealRemaining = 0; oScene.discard(); fStatus(); oCanvas:Refresh(false);
    end

    function Page.advance(nDelta)
        if (bDisposed or bFailed) then return; end
        oScene.update(nDelta);
        if (nDealRemaining > 0) then
            nDealElapsed = nDealElapsed + nDelta;
            if (nDealElapsed >= 0.20) then
                nDealElapsed = nDealElapsed - 0.20; nDealRemaining = nDealRemaining - 1;
                Page.drawCard();
            end
        end
    end

    function Page.getGraphicsInfo() return oRenderer:info(); end

    --[[!
    @fqxn CardForgeEngine.Controls.CardAnimationPage.dispose
    @desc Stops callbacks and releases all GPU resources before destroying the host window.
    !]]
    function Page.dispose()
        if (bDisposed) then return; end
        bDisposed = true;
        if (oTimer) then
            oTimer:Stop(); oPage:Disconnect(oTimer:GetId(), _wx.wxEVT_TIMER);
            oTimer:delete(); oTimer = nil;
        end
        oRenderer:close();
    end

    local function fGuard(fWork)
        if (bDisposed or bFailed) then return; end
        local bOK, sFailure = xpcall(fWork, debug.traceback);
        if (not bOK) then
            bFailed = true;
            if (oTimer) then oTimer:Stop(); end
            oStatus:SetLabel("Rendering stopped: "..tostring(sFailure));
            oDraw:Enable(false); oDiscard:Enable(false);
        end
    end

    oCanvas:Connect(_wx.wxEVT_PAINT, function()
        local oPaint = _wx.wxPaintDC(oCanvas);
        fGuard(function() Page.render(); end);
        oPaint:delete();
    end);
    oCanvas:Connect(_wx.wxEVT_ERASE_BACKGROUND, function() end);
    oCanvas:Connect(_wx.wxEVT_SIZE, function(jEvent) oCanvas:Refresh(false); jEvent:Skip(); end);
    oCanvas:Connect(_wx.wxEVT_MOTION, function(jEvent)
        fGuard(function()
            local _, _, nScale, nOX, nOY = fViewport();
            if (nScale > 0) then
                oScene.hover(oScene.hitTest((jEvent:GetX() - nOX) / nScale, (jEvent:GetY() - nOY) / nScale));
            end
        end);
    end);
    oCanvas:Connect(_wx.wxEVT_LEAVE_WINDOW, function() fGuard(function() oScene.hover(0); end); end);
    oCanvas:Connect(_wx.wxEVT_LEFT_UP, function(jEvent)
        fGuard(function()
            oCanvas:SetFocus();
            local _, _, nScale, nOX, nOY = fViewport();
            if (nScale <= 0) then return; end
            local nX, nY = (jEvent:GetX() - nOX) / nScale, (jEvent:GetY() - nOY) / nScale;
            local nID = oScene.hitTest(nX, nY);
            if (nID ~= 0) then Page.playCard(nID);
            elseif (math.abs(nX - 147) < 80 and math.abs(nY - 422) < 115) then Page.drawCard(); end
        end);
    end);
    oCanvas:Connect(_wx.wxEVT_KEY_DOWN, function(jEvent)
        local nKey = jEvent:GetKeyCode();
        if (nKey == string.byte("D")) then fGuard(Page.drawCard);
        elseif (nKey == string.byte("R")) then fGuard(Page.discard);
        else jEvent:Skip(); end
    end);
    oDraw:Connect(_wx.wxEVT_COMMAND_BUTTON_CLICKED, function() fGuard(Page.drawCard); oCanvas:SetFocus(); end);
    oDiscard:Connect(_wx.wxEVT_COMMAND_BUTTON_CLICKED, function() fGuard(Page.discard); oCanvas:SetFocus(); end);
    oCanvas:Connect(_wx.wxEVT_DESTROY, function(jEvent)
        if (jEvent:GetEventObject() == oCanvas) then Page.dispose(); end
        jEvent:Skip();
    end);
    if (not bManual) then
        oTimer = _wx.wxTimer(oPage);
        oPage:Connect(oTimer:GetId(), _wx.wxEVT_TIMER, function()
            local nNow = _OpenGL.clock();
            local nDelta = math.max(0, nNow - nLastTime); nLastTime = nNow;
            if (oCanvas:IsShownOnScreen()) then
                fGuard(function() Page.advance(nDelta); oCanvas:Refresh(false); end);
            end
        end);
        assert(oTimer:Start(16), "Cannot start the card animation timer.");
    end
    fStatus();
    return Page;
end

return CardAnimationPage;