--[[!
@fqxn CardForgeEngine.Windows.TestSuite
@desc Hosts the room preview and the application's built-in checks.
!]]
local _wx             = require("wx");
local _GameRoomCanvas = require("Scripts.Controls.GameRoomCanvas");
local _KeyBindings    = require("Scripts.Input.KeyBindings");
local _Runner         = require("Scripts.Test Suite.Runner");
local TestSuite       = {};

--[[!
@fqxn CardForgeEngine.Windows.TestSuite.create
@desc Creates a modeless test window with a sample card and fitted overhead view.
@param wxWindow oParent Application frame.
@param table tWxLuma Active framework borrowed from the application.
@param string pRoot Installation root for default room textures.
@param CardForgeEngine.GameRoom|nil oRoom Optional alternate room fixture.
@ret wxFrame The Test Suite frame.
!]]
function TestSuite.create(oParent, tWxLuma, pRoot, oRoom)
    local oFrame = _wx.wxFrame(oParent, _wx.wxID_ANY, "Test Suite",
        _wx.wxDefaultPosition, _wx.wxSize(1080, 700), _wx.wxDEFAULT_FRAME_STYLE);
    oFrame:SetMinClientSize(_wx.wxSize(640, 420));

    local oNotebook = _wx.wxNotebook(oFrame, _wx.wxID_ANY);
    local oRoomPage = _wx.wxPanel(oNotebook, _wx.wxID_ANY);
    oRoom = oRoom or CardForgeEngine.GameRoom();
    local tSurface  = oRoom.getTabletop();
    local nDepth    = tSurface.MaxZ - tSurface.MinZ;
    local nSize     = math.max(nDepth, tSurface.MaxX - tSurface.MinX);
    local tHome = {
        X = (tSurface.MinX + tSurface.MaxX) / 2,
        Y = tSurface.Y + 0.12,
        Z = (tSurface.MinZ + tSurface.MaxZ) / 2 - nDepth * 0.12,
        Yaw = math.rad(11), Pitch = math.rad(12), Distance = 0.72 * nSize,
    };
    local tView = clone(tHome);
    local Bindings, tBindingIssues = _KeyBindings.load();
    local nFov = 59;
    local nHalfPi = math.pi / 2;
    local oControl;
    local bFitTop = false;

    --[[!
    @fqxn CardForgeEngine.Windows.TestSuite.create.fitTop
    @desc Fits the complete outer tabletop, including its rails, in the current viewport.
    @ret number Center X, top Y, center Z, and camera distance.
    !]]
    local function fFitTop()
        local nMinX, nMinZ, nMaxX, nMaxZ, nTop = math.huge, math.huge, -math.huge, -math.huge, -math.huge;
        for _, tFace in ipairs(oRoom.getGeometry().Table) do
            for _, tVertex in ipairs(tFace.Vertices) do
                nMinX, nMaxX = math.min(nMinX, tVertex.X), math.max(nMaxX, tVertex.X);
                nMinZ, nMaxZ = math.min(nMinZ, tVertex.Z), math.max(nMaxZ, tVertex.Z);
                nTop = math.max(nTop, tVertex.Y);
            end
        end
        local nWidth, nHeight = oControl:GetClientSizeWH();
        local nAspect = math.max(1, nWidth) / math.max(1, nHeight);
        local nWorldHeight = math.max((nMaxX - nMinX) / nAspect, nMaxZ - nMinZ);
        local nDistance = nWorldHeight / (2 * math.tan(math.rad(nFov) / 2) * 0.86);
        return (nMinX + nMaxX) / 2, nTop, (nMinZ + nMaxZ) / 2, nDistance;
    end

    --[[!
    @fqxn CardForgeEngine.Windows.TestSuite.create.leaveFit
    @desc Keeps the current fitted pose as the starting point for manual camera movement.
    !]]
    local function fLeaveFit()
        if (bFitTop) then
            tView.X, tView.Y, tView.Z, tView.Distance = fFitTop();
            tView.Pitch, tView.Yaw = nHalfPi, 0;
            bFitTop = false;
        end
    end

    --[[!
    @fqxn CardForgeEngine.Windows.TestSuite.create.camera
    @desc Converts the preview's orbit state into a reusable perspective camera.
    !]]
    local function fCamera()
        if (bFitTop or tView.Pitch == nHalfPi) then
            local nX, nY, nZ, nDistance = tView.X, tView.Y, tView.Z, tView.Distance;
            if (bFitTop) then nX, nY, nZ, nDistance = fFitTop(); end

            -- Exact matching X/Z makes the camera select its vertical basis.
            return CardForgeEngine.PerspectiveCamera({
                Position = {X = nX, Y = nY + nDistance, Z = nZ},
                Target = {X = nX, Y = nY, Z = nZ},
                Fov = nFov, Near = 0.12,
            });
        end

        local nHorizontal = math.cos(tView.Pitch) * tView.Distance;
        return CardForgeEngine.PerspectiveCamera({
            Position = {
                X = tView.X + math.sin(tView.Yaw) * nHorizontal,
                Y = tView.Y + math.sin(tView.Pitch) * tView.Distance,
                Z = tView.Z + math.cos(tView.Yaw) * nHorizontal,
            },
            Target = {X = tView.X, Y = tView.Y, Z = tView.Z},
            Fov = nFov, Near = 0.12,
        });
    end

    local oPreview = _GameRoomCanvas.create(oRoomPage, tWxLuma, oRoom, fCamera(), pRoot);

    -- The test fixture supplies the card, artwork and placement. The room and
    -- canvas remain usable by games with different decks and table layouts.
    local oSampleCard = CardForgeEngine.Card("00000000-0000-0000-0000-000000000003", "Solar Courier");
    oSampleCard.reveal();
    local nSampleWidth = math.min(0.68, (tSurface.MaxX - tSurface.MinX) / 2, nDepth / 3);
    local oSampleMesh = CardForgeEngine.CardMesh(oSampleCard, {
        X = (tSurface.MinX + tSurface.MaxX) / 2,
        Y = tSurface.Y,
        Z = (tSurface.MinZ + tSurface.MaxZ) / 2,
        Width = nSampleWidth, Depth = nSampleWidth * 1.5,
        FrontTexture = "Examples/Source/Example Duel/Images/Cards/Fronts/solar-courier-front.png",
        BackTexture  = "Examples/Source/Example Duel/Images/Cards/Backs/midnight-back.png",
    });
    oPreview.setCardMeshes({oSampleMesh});

    local oReset = _wx.wxButton(oRoomPage, _wx.wxID_ANY, "Seated View");
    oReset:SetName("Reset Game Room View");
    local sTopShortcut = Bindings.getLabel("GameRoom", "TopView");
    local sHelp = "Drag to orbit   |   Right-drag to pan   |   Scroll to zoom";
    if (sTopShortcut ~= "") then sHelp = sHelp.."   |   "..sTopShortcut.." for overhead"; end
    if (#tBindingIssues > 0) then sHelp = sHelp.."   |   Shortcut warnings in Engine Checks"; end
    local oHelp = _wx.wxStaticText(oRoomPage, _wx.wxID_ANY, sHelp);
    local oToolbar = _wx.wxBoxSizer(_wx.wxHORIZONTAL);
    oToolbar:Add(oReset, 0, _wx.wxRIGHT, 12);
    oToolbar:Add(oHelp, 0, _wx.wxALIGN_CENTER_VERTICAL);
    local oRoomSizer = _wx.wxBoxSizer(_wx.wxVERTICAL);
    oRoomSizer:Add(oToolbar, 0, _wx.wxEXPAND + _wx.wxALL, 8);
    oRoomSizer:Add(oPreview.Control, 1, _wx.wxEXPAND);
    oRoomPage:SetSizer(oRoomSizer);
    oNotebook:AddPage(oRoomPage, "Game Room", true);

    local oTimer = _wx.wxTimer(oFrame);
    local nTimerID = oTimer:GetId();
    local tDrag;
    local bMoving = false;

    --[[!
    @fqxn CardForgeEngine.Windows.TestSuite.create.redraw
    @desc Updates the camera and resolves antialiasing when movement settles.
    !]]
    local function fRedraw(bInteractive)
        bMoving = bInteractive;
        oPreview.setCamera(fCamera(), bInteractive);
    end

    --[[!
    @fqxn CardForgeEngine.Windows.TestSuite.create.finishGesture
    @desc Clears drag state and replaces any interactive frame with an antialiased one.
    !]]
    local function fFinishGesture()
        tDrag = nil;
        oTimer:Stop();
        if (bMoving and not oPreview.Disposed) then fRedraw(false); end
    end

    --[[!
    @fqxn CardForgeEngine.Windows.TestSuite.create.pan
    @desc Translates the view target in the tabletop plane without changing its height.
    !]]
    local function fPan(nDX, nDY)
        fLeaveFit();
        local _, nHeight = oControl:GetClientSizeWH();
        local nSpeed = tView.Distance / math.max(1, nHeight);
        local nCos, nSin = math.cos(tView.Yaw), math.sin(tView.Yaw);
        tView.X = math.clamp(tView.X + (-nDX * nCos + nDY * nSin) * nSpeed, tSurface.MinX, tSurface.MaxX);
        tView.Z = math.clamp(tView.Z + ( nDX * nSin + nDY * nCos) * nSpeed, tSurface.MinZ, tSurface.MaxZ);
    end

    --[[!
    @fqxn CardForgeEngine.Windows.TestSuite.create.orbit
    @desc Rotates the camera about the current target.
    !]]
    local function fOrbit(nDX, nDY)
        fLeaveFit();
        tView.Yaw = (tView.Yaw - nDX * 0.008) % (2 * math.pi);
        tView.Pitch = math.clamp(tView.Pitch + nDY * 0.006, math.rad(7), math.rad(89));
    end

    --[[!
    @fqxn CardForgeEngine.Windows.TestSuite.create.queueCamera
    @desc Draws an interactive frame now and requests a higher-quality frame after input settles.
    !]]
    local function fQueueCamera()
        fRedraw(true);
        if (not tDrag and not oTimer:Start(120, true)) then fFinishGesture(); end
    end

    --[[!
    @fqxn CardForgeEngine.Windows.TestSuite.create.zoom
    @desc Changes camera distance while keeping its current target and orientation.
    !]]
    local function fZoom(nSteps)
        fLeaveFit();
        local nDistance = math.clamp(tView.Distance * math.exp(-nSteps * 0.12), 0.30 * nSize, 1.65 * nSize);
        if (nDistance ~= tView.Distance) then
            tView.Distance = nDistance;
            fQueueCamera();
        end
    end

    oPreview.onCancel = fFinishGesture;
    oFrame:Connect(nTimerID, _wx.wxEVT_TIMER, function()
        if (not tDrag) then fFinishGesture(); end
    end);

    oPreview.pointer = function(sEvent, nX, nY)
        if (sEvent == "down") then
            oTimer:Stop();
            tDrag = {X = nX, Y = nY, Pan = false};
        elseif (sEvent == "move" and tDrag) then
            local nDX, nDY = nX - tDrag.X, nY - tDrag.Y;
            tDrag.X, tDrag.Y = nX, nY;
            if (nDX == 0 and nDY == 0) then return; end

            if (tDrag.Pan) then
                fPan(nDX, nDY);
            else
                fOrbit(nDX, nDY);
            end
            fRedraw(true);
        end
    end;

    oControl = oPreview.Control;
    oControl:Connect(_wx.wxEVT_RIGHT_DOWN, function(jEvent)
        oTimer:Stop();
        oControl:SetFocus();
        if (not oControl:HasCapture()) then oControl:CaptureMouse(); end
        tDrag = {X = jEvent:GetX(), Y = jEvent:GetY(), Pan = true};
    end);
    oControl:Connect(_wx.wxEVT_RIGHT_UP, function()
        if (tDrag and tDrag.Pan) then oPreview.cancel(); end
    end);

    oPreview.wheel = fZoom;
    oControl:Connect(_wx.wxEVT_SIZE, function(jEvent)
        if (bFitTop and not oPreview.Disposed) then fRedraw(false); end
        jEvent:Skip();
    end);

    local tKeyboardMotion = {
        OrbitLeft = {fOrbit, -12, 0}, OrbitRight = {fOrbit, 12, 0},
        OrbitUp = {fOrbit, 0, -12}, OrbitDown = {fOrbit, 0, 12},
        PanLeft = {fPan, -22, 0}, PanRight = {fPan, 22, 0},
        PanUp = {fPan, 0, -22}, PanDown = {fPan, 0, 22},
    };
    oFrame:Connect(_wx.wxEVT_CHAR_HOOK, function(jEvent)
        local sAction = oNotebook:GetSelection() == 0 and Bindings.resolve("GameRoom", jEvent);

        if (sAction == "TopView") then
            oPreview.cancel();
            bFitTop = true;
            fRedraw(false);
        elseif (sAction == "ZoomIn" or sAction == "ZoomOut") then
            fZoom(sAction == "ZoomIn" and 1 or -1);
        elseif (sAction and tKeyboardMotion[sAction]) then
            local tMotion = tKeyboardMotion[sAction];
            tMotion[1](tMotion[2], tMotion[3]);
            fQueueCamera();
        else
            jEvent:Skip();
        end
    end);

    oReset:Connect(_wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        oPreview.cancel();
        bFitTop, tView = false, clone(tHome);
        fRedraw(false);
    end);

    -- Load the GPU page only when selected; unsupported drivers leave other tests usable.
    local oAnimations;
    local bAnimationAttempted = false;
    local oAnimationHost = _wx.wxPanel(oNotebook, _wx.wxID_ANY);
    local oAnimationSizer = _wx.wxBoxSizer(_wx.wxVERTICAL);
    oAnimationHost:SetSizer(oAnimationSizer);
    oNotebook:AddPage(oAnimationHost, "Card Animations", false);
    oNotebook:Connect(_wx.wxEVT_COMMAND_NOTEBOOK_PAGE_CHANGED, function(jEvent)
        if (jEvent:GetSelection() == 1 and not bAnimationAttempted) then
            bAnimationAttempted = true;
            local bOK, sFailure = xpcall(function()
                oAnimations = require("Scripts.Controls.CardAnimationPage").create(oAnimationHost, pRoot);
                oAnimationSizer:Add(oAnimations.Control, 1, _wx.wxEXPAND);
            end, debug.traceback);
            if (not bOK) then
                local oFailure = _wx.wxTextCtrl(oAnimationHost, _wx.wxID_ANY,
                    "Card animations could not start.\n\n"..sFailure,
                    _wx.wxDefaultPosition, _wx.wxDefaultSize, _wx.wxTE_MULTILINE + _wx.wxTE_READONLY);
                oAnimationSizer:Add(oFailure, 1, _wx.wxEXPAND + _wx.wxALL, 12);
            end
            oAnimationHost:Layout();
        end
        jEvent:Skip();
    end);
    local oChecks = _wx.wxPanel(oNotebook, _wx.wxID_ANY);
    local oRun = _wx.wxButton(oChecks, _wx.wxID_ANY, "Run engine checks");
    oRun:SetName("Run Engine Checks");
    local oReport = _wx.wxTextCtrl(oChecks, _wx.wxID_ANY, "",
        _wx.wxDefaultPosition, _wx.wxDefaultSize, _wx.wxTE_MULTILINE + _wx.wxTE_READONLY);
    oReport:SetName("Engine Test Results");
    local sBindingReport = #tBindingIssues > 0 and table.concat(tBindingIssues, "\n") or "";
    oReport:SetValue(sBindingReport);
    oRun:Connect(_wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        local _, sReport = _Runner.run();
        oReport:SetValue(sBindingReport ~= "" and sBindingReport.."\n\n"..sReport or sReport);
    end);

    local oChecksSizer = _wx.wxBoxSizer(_wx.wxVERTICAL);
    oChecksSizer:Add(oRun, 0, _wx.wxALL, 12);
    oChecksSizer:Add(oReport, 1, _wx.wxEXPAND + _wx.wxLEFT + _wx.wxRIGHT + _wx.wxBOTTOM, 12);
    oChecks:SetSizer(oChecksSizer);
    oNotebook:AddPage(oChecks, "Engine Checks", false);

    -- Launch the bundled CFA package when the Example Duel tab is first opened.
    local oDuel;
    local bDuelAttempted = false;
    local oDuelHost = _wx.wxPanel(oNotebook, _wx.wxID_ANY);
    local oDuelSizer = _wx.wxBoxSizer(_wx.wxVERTICAL);
    oDuelHost:SetSizer(oDuelSizer);
    oNotebook:AddPage(oDuelHost, "Example Duel", false);
    oNotebook:Connect(_wx.wxEVT_COMMAND_NOTEBOOK_PAGE_CHANGED, function(jEvent)
        if (jEvent:GetSelection() == 3 and not bDuelAttempted) then
            bDuelAttempted = true;
            local bOK, sError = xpcall(function()
                oDuel = require("Scripts.Services.ExampleDuel").create(oDuelHost, pRoot);
                oDuelSizer:Add(oDuel.Control, 1, _wx.wxEXPAND);
            end, debug.traceback);
            if (not bOK) then
                oDuelSizer:Add(_wx.wxTextCtrl(oDuelHost, _wx.wxID_ANY,
                    "Example Duel could not start.\n\n"..sError, _wx.wxDefaultPosition,
                    _wx.wxDefaultSize, _wx.wxTE_MULTILINE + _wx.wxTE_READONLY), 1, _wx.wxEXPAND);
            end
            oDuelHost:Layout();
        end
        jEvent:Skip();
    end);
    local oFrameSizer = _wx.wxBoxSizer(_wx.wxVERTICAL);
    oFrameSizer:Add(oNotebook, 1, _wx.wxEXPAND);
    oFrame:SetSizer(oFrameSizer);
    oFrame:Layout();
    bFitTop = true;
    fRedraw(false);
    oFrame:CentreOnParent();

    -- Dispose the viewport while its native child and owned timer are valid.
    oFrame:Connect(_wx.wxEVT_CLOSE_WINDOW, function(jEvent)
        if (oDuel) then oDuel.dispose(); end
        if (oAnimations) then oAnimations.dispose(); end
        if (not oPreview.Disposed) then
            bMoving = false;
            oPreview.destroy();
            oPreview.onCancel = nil;
            oTimer:Stop();
            oFrame:Disconnect(nTimerID, _wx.wxEVT_TIMER);
            oTimer:delete();
        end
        jEvent:Skip();
    end);
    return oFrame;
end

return TestSuite;
