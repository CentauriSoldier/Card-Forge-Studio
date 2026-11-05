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
    No LuaEx dependency or timer is used.
    Needle state images are transparent squares pointing right from their center;
    artwork defines their complete appearance and rotates with the dial value.
@param wxWindow oParent Native owner.
@param table tOptions Skin, optional Min (0), Max (100), Value (Min), Rate (1),
    Continuity (none/revolve/alternate), Artwork (Knob), Enabled, OnChange.
@ret table oComponent Numeric value/range/rate/continuity/direction APIs and shared events.
!]]
function Knob.create(oParent, tOptions)
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
    nRate = math.min(math.abs(nRate), nMax - nMin);
    local nValue, nMotion = nMin, 1;
    local nDragY, tDragStart;
    local oComponent = _Surface.create(oParent, tOptions, "Knob");
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "Knob");
    local tEvents = _Events.attach(oComponent, nil, {"rangeChanged", "rateChanged", "continuityChanged", "motionDirectionChanged"});
    local tNeedles = {};
    local tRender;

    --[[!
    @fqxn wxLuma.UI.Knob.normalize
    @desc Normalizes any finite absolute position in constant time, retaining
        every alternating boundary crossing, including large/fractional overshoot.
    !]]
    local function fNormalize(nNext, bNotify)
        assert(_finite(nNext), "Knob value must be finite.");
        if (oComponent.Disposed) then return oComponent; end
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

    oComponent.pointer = function(sEvent, nX, nY)
        if (sEvent == "down") then nDragY = nY; tDragStart = {Value = nValue, Motion = nMotion};
        elseif (sEvent == "move" and oComponent.Pressed and nDragY) then
            fNormalize(nValue + (nDragY - nY) * (nMax - nMin) / 140 * nMotion, true); nDragY = nY;
        end
    end;
    oComponent.onCancel = function() nDragY, tDragStart = nil, nil; end;
    oComponent.wheel = function(nSteps) oComponent.increase(nSteps, true); end;
    oComponent.key = function(nKey)
        if (nKey == _wx.WXK_UP or nKey == _wx.WXK_RIGHT) then oComponent.increase(1, true);
        elseif (nKey == _wx.WXK_DOWN or nKey == _wx.WXK_LEFT) then oComponent.decrease(1, true);
        elseif (nKey == _wx.WXK_PAGEUP) then oComponent.increase(10, true);
        elseif (nKey == _wx.WXK_PAGEDOWN) then oComponent.decrease(10, true);
        elseif (nKey == _wx.WXK_HOME) then oComponent.setValue(nMin, true);
        elseif (nKey == _wx.WXK_END) then oComponent.setValue(nMax, true);
        elseif (nKey == _wx.WXK_ESCAPE and tDragStart) then
            oComponent.setValue(tDragStart.Value, true); oComponent.setMotionDirection(tDragStart.Motion, true); oComponent.cancel();
        else return false; end
        return true;
    end;
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then return; end
        local sState = oComponent.getState();
        local nDiameter = math.max(1, math.min(nWidth, nHeight - 26));
        local nX, nY = (nWidth - nDiameter) / 2, 2;
        if (not tRender or tRender.Width ~= nWidth or tRender.Height ~= nHeight
            or tRender.State ~= sState or tRender.Fraction ~= (nValue - nMin) / (nMax - nMin)) then
            -- Render the face and needle at triple resolution, then filter down.
            -- The finished bitmap is reused until geometry, angle or state changes.
            -- Text and focus remain at native resolution for crisp typography.
            if (tRender) then tRender.Bitmap:delete(); end
            local nScale = 3;
            local oBitmap = _wx.wxBitmap(nWidth * nScale, nHeight * nScale);
            local oMemory = _wx.wxMemoryDC(); oMemory:SelectObject(oBitmap);
            tArt.part(oMemory, "Surface "..sState, 0, 0, nWidth * nScale, nHeight * nScale);
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
        if (oComponent.Control:HasFocus()) then tArt.part(oDC, "Focus", 0, 0, nWidth, nHeight); end
    end;
    oComponent.onDestroy = function()
        if (tRender) then tRender.Bitmap:delete(); tRender = nil; end
        for _, tNeedle in pairs(tNeedles) do
            if (tNeedle.Scaled) then tNeedle.Scaled:delete(); end
            tNeedle.Image:delete();
        end
        tNeedles = {};
        tArt.destroy();
    end;
    fNormalize(tOptions.Value == nil and nMin or tOptions.Value);
    return oComponent;
end

return Knob;
