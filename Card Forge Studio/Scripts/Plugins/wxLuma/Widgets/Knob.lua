local _Border = require("wxLuma.Core.ControlBorder");
local _Theme = require("wxLuma.Core.ControlTheme");
local _wx = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events = require("wxLuma.Core.ControlEvents");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local _finite = require("wxLuma.Core.ControlNumeric").finite;
local Knob = {};
local _tModes = {none = true, revolve = true, alternate = true};

--[[!
@fqxn wxLuma.UI.Knob.create
@desc Creates a skinned rotary numeric input guided by LuaEx Potentiometer.
    none clamps; revolve uses inclusive Max-Min+1; alternate reflects overshoot
    and reverses logical movement. Exact endpoints do not reverse until crossed.
    increase/decrease follow that direction; adjust is an absolute signed delta.
    Drag up/down, use wheel/arrows/Page/Home/End; Escape cancels a pointer drag.
    One owned timer groups wheel input into a gesture; no LuaEx dependency is used.
    Needle state images are transparent squares pointing right from their center;
    artwork defines their complete appearance and rotates with the dial value.
@param wxWindow oParent Native owner.
@param table tOptions Skin, optional Min (0), Max (100), Value (Min), Rate (1),
    Continuity (none/revolve/alternate), Artwork (Knob), Enabled, OnChange,
    OnChangeComplete(value, component). Completion follows a changed drag release,
    last adjustment-key release or 200 ms wheel idle. Cancellation never completes.
@ret table oComponent Numeric value/range/rate/continuity/direction APIs and shared events.
!]]
function Knob.create(oParent, tOptions)
    tOptions = _Theme.options(tOptions, oParent);
    tOptions = _Border.withDefault(tOptions, _wx.wxBORDER_NONE);
    local nMin, nMax = tOptions.Min or 0, tOptions.Max or 100;
    local nRate, sMode = tOptions.Rate or 1, tOptions.Continuity or "none";

    --[[!
    @fqxn wxLuma.UI.Knob.bounds
    @desc Requires a finite range whose inclusive wrapping and doubled reflection periods remain representable.
    !]]
    local function fBounds(nLow, nHigh)
        assert(_finite(nLow) and _finite(nHigh) and nHigh > nLow and _finite(2 * (nHigh - nLow))
            and nHigh - nLow + 1 > nHigh - nLow, "Invalid knob range.");
    end
    fBounds(nMin, nMax);
    assert(_finite(nRate) and _tModes[sMode], "Invalid knob rate/continuity.");
    assert(tOptions.Value == nil or _finite(tOptions.Value), "Invalid knob value.");
    assert(tOptions.OnChangeComplete == nil or type(tOptions.OnChangeComplete) == "function", "OnChangeComplete must be a function.");
    nRate = math.min(math.abs(nRate), nMax - nMin);
    local nValue, nMotion = nMin, 1;
    local nDragY, tDragStart;
    local oComponent = _Surface.create(oParent, tOptions, "Knob");
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "Knob");
    local tEvents = _Events.attach(oComponent, nil, {"rangeChanged", "rateChanged", "continuityChanged", "motionDirectionChanged", "changeComplete"});
    oComponent.OnChangeComplete = tOptions.OnChangeComplete;
    local oWheelTimer = _wx.wxTimer(oComponent.Control);
    local tInteraction;
    local bUserChange = false;
    local tNeedles = {};
    local tRender, tSystemRender;

    --[[!
    @fqxn wxLuma.UI.Knob.complete
    @desc Ends one changed user gesture before callbacks. Completion carries the
        final value, starting OldValue and Input (pointer, keyboard or wheel).
        A changed gesture can finish at its starting value after moving away/back.
    !]]
    local function fComplete()
        local tFinished = tInteraction;
        if (not tFinished) then return; end
        tInteraction = nil; oWheelTimer:Stop();
        if (tFinished.Input == "pointer") then
            nDragY, tDragStart = nil, nil;
            oComponent.Pressed = false;
            if (oComponent.Control:HasCapture()) then oComponent.Control:ReleaseMouse(); end
        end
        if (tFinished.Changed and oComponent.isEnabled()) then
            local nFinal = nValue;
            tEvents.emit("changeComplete", {Value = nFinal, OldValue = tFinished.Value, Input = tFinished.Input});
            if (not oComponent.Disposed and oComponent.OnChangeComplete) then oComponent.OnChangeComplete(nFinal, oComponent); end
        end
    end

    --[[!
    @fqxn wxLuma.UI.Knob.beginInteraction
    @desc Starts a user gesture. Switching input devices cancels the old gesture;
        repeated keys and wheel events share their existing gesture state.
    !]]
    local function fBegin(sInput)
        if (not oComponent.isEnabled()) then return false; end
        if (tInteraction and tInteraction.Input ~= sInput) then
            if (sInput == "pointer") then
                -- Shared pointer handling has already acquired this new drag.
                -- Clear the old gesture without releasing the new capture.
                oWheelTimer:Stop(); tInteraction = nil; nDragY, tDragStart = nil, nil;
            else oComponent.cancel(); end
        end
        if (not tInteraction) then tInteraction = {Input = sInput, Value = nValue, Keys = {}, Changed = false}; end
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.Knob.userChange
    @desc Marks normalization as user input while preserving the flag across nested
        callbacks and errors. Programmatic changes outside this scope cancel pending completion.
    !]]
    local function fUserChange(fAction)
        local bPrevious = bUserChange; bUserChange = true;
        local bOK, sError = pcall(fAction);
        bUserChange = bPrevious;
        if (not bOK) then error(sError, 0); end
    end

    --[[!
    @fqxn wxLuma.UI.Knob.normalize
    @desc Normalizes any finite absolute position in constant time, retaining
        every alternating boundary crossing, including large/fractional overshoot.
    !]]
    local function fNormalize(nNext, bNotify)
        assert(_finite(nNext), "Knob value must be finite.");
        if (oComponent.Disposed) then return oComponent; end
        if (not bUserChange and tInteraction) then oComponent.cancel(); end
        local nOld, nOldMotion, nSpan = nValue, nMotion, nMax - nMin;
        if (nNext < nMin or nNext > nMax) then
            if (sMode == "revolve") then
                local nPeriod = nSpan + 1;
                nNext = math.min(nMax, nMin + (nNext % nPeriod - nMin % nPeriod) % nPeriod);
            elseif (sMode == "alternate") then
                local nPhase = (nNext % (2 * nSpan) - nMin % (2 * nSpan)) % (2 * nSpan);
                local nCrossings = math.ceil((nNext > nMax and nNext - nMax or nMin - nNext) / nSpan);
                nNext = nMin + (nPhase <= nSpan and nPhase or 2 * nSpan - nPhase);
                if (nCrossings % 2 == 1) then nMotion = -nMotion; end
            else nNext = math.max(nMin, math.min(nMax, nNext)); end
        end
        nValue = nNext;
        if (bUserChange and tInteraction and nOld ~= nValue) then tInteraction.Changed = true; end
        if (nOld ~= nValue or nOldMotion ~= nMotion) then oComponent.refresh(); end
        if (bNotify) then
            if (nOld ~= nValue) then
                tEvents.emit("valueChanged", {Value = nValue, OldValue = nOld});
                if (oComponent.OnChange) then oComponent.OnChange(nValue, oComponent); end
            end
            if (nOldMotion ~= nMotion) then tEvents.emit("motionDirectionChanged", {MotionDirection = nMotion, OldMotionDirection = nOldMotion}); end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Knob.getValue
    @desc Returns current numeric position.
    !]]
    function oComponent.getValue() return nValue; end
    --[[!
    @fqxn wxLuma.UI.Knob.setValue
    @desc Applies finite absolute position with the selected boundary policy; notification defaults false.
    !]]
    function oComponent.setValue(nNext, bNotify) return fNormalize(nNext, bNotify); end
    --[[!
    @fqxn wxLuma.UI.Knob.getRange
    @desc Returns minimum and maximum.
    !]]
    function oComponent.getRange() return nMin, nMax; end
    --[[!
    @fqxn wxLuma.UI.Knob.setRange
    @desc Validates bounds, caps rate, and normalizes current before optional range notification.
    !]]
    function oComponent.setRange(nLow, nHigh, bNotify)
        fBounds(nLow, nHigh);
        if (not oComponent.Disposed and (nLow ~= nMin or nHigh ~= nMax)) then
            oComponent.cancel();
            nMin, nMax = nLow, nHigh; nRate = math.min(nRate, nMax - nMin);
            fNormalize(nValue, bNotify); oComponent.refresh();
            if (bNotify) then tEvents.emit("rangeChanged", {Min = nMin, Max = nMax}); end
        end
        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.Knob.getRate
    @desc Returns nonnegative logical movement magnitude.
    !]]
    function oComponent.getRate() return nRate; end
    --[[!
    @fqxn wxLuma.UI.Knob.setRate
    @desc Uses a finite rate magnitude capped to the range span.
    !]]
    function oComponent.setRate(nNext, bNotify)
        assert(_finite(nNext), "Rate must be finite.");
        nNext = math.min(math.abs(nNext), nMax - nMin);
        if (not oComponent.Disposed and nNext ~= nRate) then
            nRate = nNext;
            if (bNotify) then tEvents.emit("rateChanged", {Rate = nRate}); end
        end
        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.Knob.getContinuity
    @desc Returns none/revolve/alternate.
    !]]
    function oComponent.getContinuity() return sMode; end
    --[[!
    @fqxn wxLuma.UI.Knob.setContinuity
    @desc Selects boundary behavior; leaving alternate resets logical direction.
    !]]
    function oComponent.setContinuity(sNext, bNotify)
        assert(_tModes[sNext], "Invalid Continuity.");
        if (not oComponent.Disposed and sNext ~= sMode) then
            oComponent.cancel();
            sMode = sNext;
            if (sMode ~= "alternate") then oComponent.setMotionDirection(1, bNotify); end
            if (bNotify) then tEvents.emit("continuityChanged", {Continuity = sMode}); end
        end
        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.Knob.getMotionDirection
    @desc Returns +1 ascending or -1 descending for logical movement.
    !]]
    function oComponent.getMotionDirection() return nMotion; end
    --[[!
    @fqxn wxLuma.UI.Knob.setMotionDirection
    @desc Restores alternating direction. Descending is valid only in alternate mode.
    !]]
    function oComponent.setMotionDirection(nNext, bNotify)
        assert(nNext == 1 or nNext == -1 and sMode == "alternate", "Invalid motion direction.");
        if (not oComponent.Disposed and nNext ~= nMotion) then
            local nOld = nMotion; nMotion = nNext;
            if (bNotify) then tEvents.emit("motionDirectionChanged", {MotionDirection = nNext, OldMotionDirection = nOld}); end
        end
        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.Knob.increase
    @desc Moves Rate times multiplier in the current logical direction. Explicit zero does nothing.
    !]]
    function oComponent.increase(nTimes, bNotify)
        nTimes = nTimes == nil and 1 or nTimes;
        assert(_finite(nTimes), "Multiplier must be finite.");
        return fNormalize(nValue + nRate * nTimes * nMotion, bNotify);
    end
    --[[!
    @fqxn wxLuma.UI.Knob.decrease
    @desc Moves against the current logical direction.
    !]]
    function oComponent.decrease(nTimes, bNotify)
        nTimes = nTimes == nil and 1 or nTimes;
        assert(_finite(nTimes), "Multiplier must be finite.");
        return oComponent.increase(-nTimes, bNotify);
    end
    --[[!
    @fqxn wxLuma.UI.Knob.adjust
    @desc Adds an absolute signed amount independent of logical direction; omitted amount uses Rate.
    !]]
    function oComponent.adjust(nAmount, bNotify)
        nAmount = nAmount == nil and nRate or nAmount;
        assert(_finite(nAmount), "Amount must be finite.");
        return fNormalize(nValue + nAmount, bNotify);
    end
    --[[!
    @fqxn wxLuma.UI.Knob.isAtStart
    @desc Tests the absolute minimum endpoint.
    !]]
    function oComponent.isAtStart() return nValue == nMin; end
    --[[!
    @fqxn wxLuma.UI.Knob.isAtEnd
    @desc Tests the absolute maximum endpoint.
    !]]
    function oComponent.isAtEnd() return nValue == nMax; end

    --[[!
    @fqxn wxLuma.UI.Knob.hitTest
    @desc Tests the circular dial using the same geometry as painting. The value
        caption and rectangular corners do not accept pointer interaction.
    !]]
    function oComponent.hitTest(nX, nY)
        if (not oComponent.isEnabled() or not _finite(nX) or not _finite(nY)) then return false; end
        local nWidth, nHeight = oComponent.Control:GetClientSizeWH();
        local nDiameter = math.max(1, math.min(nWidth, nHeight - 26));
        local nCX, nCY = nWidth / 2, 2 + nDiameter / 2;
        return (nX - nCX)^2 + (nY - nCY)^2 <= (nDiameter / 2)^2;
    end
    oComponent.PointerHitTest = oComponent.hitTest;
    oComponent.pointer = function(sEvent, nX, nY)
        if (sEvent == "down" and oComponent.Hover and fBegin("pointer")) then
            nDragY = nY; tDragStart = {Value = nValue, Motion = nMotion};
        elseif (sEvent == "move" and oComponent.Pressed and nDragY) then
            local nPreviousY = nDragY; nDragY = nY;
            fUserChange(function() fNormalize(nValue + (nPreviousY - nY) * (nMax - nMin) / 140 * nMotion, true); end);
        elseif (sEvent == "up" and tInteraction and tInteraction.Input == "pointer") then fComplete();
        end
    end;
    oComponent.onCancel = function()
        nDragY, tDragStart, tInteraction = nil, nil, nil;
        if (not oComponent.Disposed) then oWheelTimer:Stop(); end
    end;
    oComponent.wheel = function(nSteps)
        if (not fBegin("wheel")) then return; end
        fUserChange(function() oComponent.increase(nSteps, true); end);
        if (not oComponent.Disposed and tInteraction and tInteraction.Input == "wheel") then oWheelTimer:Start(200, true); end
    end;
    oComponent.key = function(nKey)
        if (nKey == _wx.WXK_UP or nKey == _wx.WXK_RIGHT) then oComponent.increase(1, true);
        elseif (nKey == _wx.WXK_DOWN or nKey == _wx.WXK_LEFT) then oComponent.decrease(1, true);
        elseif (nKey == _wx.WXK_PAGEUP) then oComponent.increase(10, true);
        elseif (nKey == _wx.WXK_PAGEDOWN) then oComponent.decrease(10, true);
        elseif (nKey == _wx.WXK_HOME) then oComponent.setValue(nMin, true);
        elseif (nKey == _wx.WXK_END) then oComponent.setValue(nMax, true);
        elseif (nKey == _wx.WXK_ESCAPE and tDragStart) then
            local tStart = tDragStart; oComponent.cancel();
            oComponent.setValue(tStart.Value, true); oComponent.setMotionDirection(tStart.Motion, true);
        else return false; end
        return true;
    end;
    local fHandleKey = oComponent.handleKey;
    local tAdjustmentKeys = {[_wx.WXK_UP] = true, [_wx.WXK_RIGHT] = true, [_wx.WXK_DOWN] = true,
        [_wx.WXK_LEFT] = true, [_wx.WXK_PAGEUP] = true, [_wx.WXK_PAGEDOWN] = true,
        [_wx.WXK_HOME] = true, [_wx.WXK_END] = true};

    --[[!
    @fqxn wxLuma.UI.Knob.handleKey
    @desc Groups adjustment-key auto-repeat until all held adjustment keys release.
        Escape retains existing drag rollback and cancels pending wheel/key completion.
    !]]
    function oComponent.handleKey(sEvent, nKey, tModifiers)
        if (not oComponent.isEnabled()) then return false; end
        if (sEvent == "down" and nKey == _wx.WXK_ESCAPE) then
            local bActive = tInteraction ~= nil;
            local bHandled = fHandleKey(sEvent, nKey, tModifiers);
            oComponent.cancel(); return bHandled or bActive;
        end
        if (not tAdjustmentKeys[nKey]) then return fHandleKey(sEvent, nKey, tModifiers); end
        if (sEvent == "up") then
            if (not tInteraction or tInteraction.Input ~= "keyboard" or not tInteraction.Keys[nKey]) then return false; end
            tInteraction.Keys[nKey] = nil;
            if (next(tInteraction.Keys) == nil) then fComplete(); end
            return true;
        elseif (sEvent == "down" and fBegin("keyboard")) then
            tInteraction.Keys[nKey] = true;
            fUserChange(function() fHandleKey(sEvent, nKey, tModifiers); end);
            return true;
        end
        return false;
    end
    oComponent.Control:Connect(_wx.wxEVT_KEY_UP, function(jEvent)
        if (not oComponent.handleKey("up", jEvent:GetKeyCode())) then jEvent:Skip(); end
    end);
    oComponent.Control:Connect(oWheelTimer:GetId(), _wx.wxEVT_TIMER, function()
        if (not oComponent.Disposed and tInteraction and tInteraction.Input == "wheel") then fComplete(); end
    end);
    --[[!
    @fqxn wxLuma.UI.Knob.drawSystemDial
    @desc Paints the dial and needle using system colors, leaving the surrounding DC untouched.
    !]]
    local function fDrawSystemDial(oDC, nX, nY, nDiameter)
        local oFace = _wx.wxSystemSettings.GetColour(_wx.wxSYS_COLOUR_BTNFACE);
        local oParentColour = oComponent.Control:GetParent():GetBackgroundColour();

        -- System panels may themselves use button face. Prefer the system
        -- window color in that case so the dial still reads as a distinct disc.
        local bWindowFace = oFace:Red() == oParentColour:Red() and oFace:Green() == oParentColour:Green()
            and oFace:Blue() == oParentColour:Blue();
        oParentColour:delete();
        local bEnabled = oComponent.isEnabled();
        local nFraction = (nValue - nMin) / (nMax - nMin);

        if (not tSystemRender or tSystemRender.Diameter ~= nDiameter or tSystemRender.Fraction ~= nFraction
            or tSystemRender.Enabled ~= bEnabled or tSystemRender.WindowFace ~= bWindowFace) then
            if (bWindowFace) then
                oFace:delete();
                oFace = _wx.wxSystemSettings.GetColour(_wx.wxSYS_COLOUR_WINDOW);
            end
            local oEdge = _wx.wxSystemSettings.GetColour(_wx.wxSYS_COLOUR_BTNSHADOW);
            local oNeedle = _wx.wxSystemSettings.GetColour(bEnabled and _wx.wxSYS_COLOUR_BTNTEXT
                or _wx.wxSYS_COLOUR_GRAYTEXT);
            local nScale = 3;
            local nSize = nDiameter * nScale;

            -- Pick a mask color absent from the drawing. InitAlpha converts
            -- this mask to alpha before downsampling, including rim coverage.
            local nMaskRed = 0;
            while (nMaskRed == oFace:Red() or nMaskRed == oEdge:Red() or nMaskRed == oNeedle:Red()) do
                nMaskRed = nMaskRed + 1;
            end
            local oMaskColour = _wx.wxColour(nMaskRed, 0, 0);
            local oMaskBrush, oFaceBrush = _wx.wxBrush(oMaskColour), _wx.wxBrush(oFace);
            local oEdgePen = _wx.wxPen(oEdge, nScale, _wx.wxPENSTYLE_SOLID);
            local oNeedlePen = _wx.wxPen(oNeedle, math.max(nScale, math.floor(nSize * 0.025)), _wx.wxPENSTYLE_SOLID);
            local oBitmap, oMemory = _wx.wxBitmap(nSize, nSize), _wx.wxMemoryDC();
            oMemory:SelectObject(oBitmap);
            oMemory:SetBackground(oMaskBrush); oMemory:Clear();
            oMemory:SetBrush(oFaceBrush); oMemory:SetPen(oEdgePen);
            oMemory:DrawEllipse(1, 1, nSize - 2, nSize - 2);

            if (nDiameter >= 4) then
                local nAngle = math.rad(135 + nFraction * 270);
                local nCenter, nLength = nSize / 2, nSize * 0.36;
                oMemory:SetPen(oNeedlePen);
                oMemory:DrawLine(math.floor(nCenter), math.floor(nCenter),
                    math.floor(nCenter + math.cos(nAngle) * nLength), math.floor(nCenter + math.sin(nAngle) * nLength));
            end
            oMemory:SelectObject(_wx.wxNullBitmap); oMemory:delete();
            local oImage = oBitmap:ConvertToImage(); oBitmap:delete();
            oImage:SetMaskColour(nMaskRed, 0, 0); oImage:InitAlpha();
            local oScaled = oImage:Scale(nDiameter, nDiameter, _wx.wxIMAGE_QUALITY_HIGH);
            local oRaster = _wx.wxBitmap(oScaled);
            oScaled:delete(); oImage:delete();
            oNeedlePen:delete(); oEdgePen:delete(); oFaceBrush:delete(); oMaskBrush:delete();
            oNeedle:delete(); oEdge:delete(); oMaskColour:delete();

            if (tSystemRender) then tSystemRender.Bitmap:delete(); end
            tSystemRender = {Diameter = nDiameter, Fraction = nFraction, Enabled = bEnabled,
                WindowFace = bWindowFace, Bitmap = oRaster};
        end
        oFace:delete();
        oDC:DrawBitmap(tSystemRender.Bitmap, math.floor(nX), nY, true);
    end

    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then return; end
        local sState = oComponent.getState();
        local nDiameter = math.max(1, math.min(nWidth, nHeight - 26));
        local nX, nY = (nWidth - nDiameter) / 2, 2;
        if (_Theme.isTheme(oComponent.Skin) and oComponent.Skin.getName() == "System") then
            fDrawSystemDial(oDC, nX, nY, nDiameter);
            return;
        end
        if (not tRender or tRender.Width ~= nWidth or tRender.Height ~= nHeight
            or tRender.State ~= sState or tRender.Fraction ~= (nValue - nMin) / (nMax - nMin)) then
            -- Render the face and needle at triple resolution, then filter down.
            -- The finished bitmap is reused until geometry, angle or state changes.
            -- Text remains at native resolution for crisp typography.
            if (tRender) then tRender.Bitmap:delete(); end
            local nScale = 3;
            local oBitmap = _wx.wxBitmap(nWidth * nScale, nHeight * nScale);
            local oMemory = _wx.wxMemoryDC(); oMemory:SelectObject(oBitmap);
            -- Hover and dragging may affect the dial artwork, never its
            -- rectangular background. Focus adds no surrounding decoration.
            tArt.part(oMemory, oComponent.isEnabled() and "Surface Normal" or "Surface Disabled",
                0, 0, nWidth * nScale, nHeight * nScale);
            tArt.part(oMemory, "Face "..sState, nX * nScale, nY * nScale, nDiameter * nScale, nDiameter * nScale);
            local tNeedle = tNeedles[sState];
            if (not tNeedle) then
                tNeedle = {Image = oComponent.Skin.getBitmap((tOptions.Artwork or "Knob").." Needle "..sState):ConvertToImage()};
                tNeedles[sState] = tNeedle;
            end
            local nNeedleSize = math.max(1, math.floor(nDiameter * nScale));
            if (tNeedle.Size ~= nNeedleSize) then
                if (tNeedle.Scaled) then tNeedle.Scaled:delete(); end
                tNeedle.Scaled = tNeedle.Image:Scale(nNeedleSize, nNeedleSize, _wx.wxIMAGE_QUALITY_HIGH);
                tNeedle.Size = nNeedleSize;
            end
            local nAngle = math.rad(135 + (nValue - nMin) / (nMax - nMin) * 270);
            -- A transparent square defines the complete needle, pointing right
            -- from its center at zero degrees. Rotate about that center so skin
            -- authors control thickness, length, shape, color and highlights.
            local oPivot = _wx.wxPoint(math.floor(nNeedleSize / 2), math.floor(nNeedleSize / 2));
            local oRotated = tNeedle.Scaled:Rotate(-nAngle, oPivot, true); oPivot:delete();
            local oNeedleBitmap = _wx.wxBitmap(oRotated);
            local nCX, nCY = (nX + nDiameter / 2) * nScale, (nY + nDiameter / 2) * nScale;
            oMemory:DrawBitmap(oNeedleBitmap, math.floor(nCX - oRotated:GetWidth() / 2),
                math.floor(nCY - oRotated:GetHeight() / 2), true);
            oNeedleBitmap:delete(); oRotated:delete();
            oMemory:SelectObject(_wx.wxNullBitmap); oMemory:delete();
            local oImage = oBitmap:ConvertToImage(); oBitmap:delete();
            local oScaled = oImage:Scale(nWidth, nHeight, _wx.wxIMAGE_QUALITY_HIGH); oImage:delete();
            tRender = {Width = nWidth, Height = nHeight, State = sState,
                Fraction = (nValue - nMin) / (nMax - nMin), Bitmap = _wx.wxBitmap(oScaled)};
            oScaled:delete();
        end
        oDC:DrawBitmap(tRender.Bitmap, 0, 0, false);
        local sText = string.format("%.4g", nValue);
        oDC:SetFont(oComponent.Skin.Font);
        local nTextWidth = oDC:GetTextExtent(sText);
        tArt.text(oDC, sText, (nWidth - nTextWidth) / 2, math.max(0, nHeight - 22), oComponent.isEnabled());
    end;
    --[[!
    @fqxn wxLuma.UI.Knob.onThemeChanged
    @desc Discards skin-derived needle and dial rasters while retaining value.
    !]]
    oComponent.onThemeChanged = function()
        if (tSystemRender) then tSystemRender.Bitmap:delete(); tSystemRender = nil; end
        if (tRender) then tRender.Bitmap:delete(); tRender = nil; end
        for _, tNeedle in pairs(tNeedles) do
            if (tNeedle.Scaled) then tNeedle.Scaled:delete(); end
            tNeedle.Image:delete();
        end
        tNeedles = {};
    end;
    -- wxWidgets 3.2 on Windows needs an initialized rectangular paint buffer.
    -- Apply the parent's solid backing only for native paint, leaving draw()
    -- free to composite the circle over any caller-supplied DC.
    local oControl = oComponent.Control;
    oControl:Connect(_wx.wxEVT_PAINT, function(oEvent)
        if (oComponent.Disposed or not _Theme.isTheme(oComponent.Skin) or oComponent.Skin.getName() ~= "System") then
            oEvent:Skip();
            return;
        end
        local oDC = _wx.wxAutoBufferedPaintDC(oControl);
        local oColour = oControl:GetParent():GetBackgroundColour();
        local oBrush = _wx.wxBrush(oColour);
        oDC:SetBackground(oBrush); oDC:Clear();
        oComponent.draw(oDC, oControl:GetClientSizeWH());
        oDC:delete(); oBrush:delete(); oColour:delete();
    end);

    oComponent.onDestroy = function()
        oWheelTimer:Stop(); oWheelTimer:delete();
        oComponent.onThemeChanged(); tArt.destroy();
    end;
    fNormalize(tOptions.Value == nil and nMin or tOptions.Value);
    _Theme.finish(oComponent, tOptions);
    return oComponent;
end

return Knob;
