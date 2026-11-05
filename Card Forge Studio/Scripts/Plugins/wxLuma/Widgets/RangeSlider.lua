local _wx = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events = require("wxLuma.Core.ControlEvents");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local _finite = require("wxLuma.Core.ControlNumeric").finite;
local RangeSlider = {};

--[[!
@fqxn wxLuma.UI.RangeSlider.create
@desc Creates a two-handle numeric interval. Handles never cross. Pointer input
    chooses the closest handle; Space switches the keyboard handle. Arrows/Page/
    Home/End move that handle, Escape restores its pointer-down interval.
@param wxWindow oParent Native owner.
@param table tOptions Skin, Min, Max, Step (1), Value={Low,High}, Artwork, Enabled,
    OnChange(interval, component). Values are detached snapshots.
@ret table oComponent Standard surface, get/setValue, get/setRange and get/setStep.
!]]
function RangeSlider.create(oParent, tOptions)
    local nMin, nMax, nStep = tOptions.Min or 0, tOptions.Max or 100, tOptions.Step or 1;
    assert(_finite(nMin) and _finite(nMax) and nMax > nMin and _finite(nMax - nMin), "Invalid range.");
    assert(_finite(nStep) and nStep > 0, "Invalid Step.");
    local tValue = tOptions.Value or {Low = nMin, High = nMax};
    assert(type(tValue) == "table" and _finite(tValue.Low) and _finite(tValue.High) and tValue.Low <= tValue.High, "Invalid interval.");
    local oComponent = _Surface.create(oParent, tOptions, "RangeSlider");
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "Range Slider");
    local tEvents = _Events.attach(oComponent, nil, {"rangeChanged", "stepChanged"});
    local nLow, nHigh, sActive = nMin, nMax, "Low";
    local tDragStart;

    --[[!
    @fqxn wxLuma.UI.RangeSlider.snap
    @desc Clamps and snaps a position to the nearest step from Min.
    !]]
    local function fSnap(nValue)
        local nClamped = math.max(nMin, math.min(nMax, nValue));
        return math.max(nMin, math.min(nMax, nMin + math.floor((nClamped - nMin) / nStep + 0.5) * nStep));
    end

    --[[!
    @fqxn wxLuma.UI.RangeSlider.getValue
    @desc Returns an independent {Low,High} interval.
    !]]
    function oComponent.getValue() return {Low = nLow, High = nHigh}; end

    --[[!
    @fqxn wxLuma.UI.RangeSlider.setValue
    @desc Validates before mutation, clamps/snaps both endpoints and optionally notifies effective changes.
    !]]
    function oComponent.setValue(tNext, bNotify)
        assert(type(tNext) == "table" and _finite(tNext.Low) and _finite(tNext.High) and tNext.Low <= tNext.High, "Invalid interval.");
        if (oComponent.Disposed) then return oComponent; end
        local nNextLow, nNextHigh = fSnap(tNext.Low), fSnap(tNext.High);
        if (nNextLow ~= nLow or nNextHigh ~= nHigh) then
            local tOld = oComponent.getValue();
            nLow, nHigh = nNextLow, nNextHigh;
            oComponent.refresh();
            if (bNotify) then
                tEvents.emit("valueChanged", {Value = oComponent.getValue(), OldValue = tOld});
                if (oComponent.OnChange) then oComponent.OnChange(oComponent.getValue(), oComponent); end
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.RangeSlider.getRange
    @desc Returns the configured minimum and maximum.
    !]]
    function oComponent.getRange() return nMin, nMax; end

    --[[!
    @fqxn wxLuma.UI.RangeSlider.setRange
    @desc Validates new bounds, then silently fits the interval before optional rangeChanged.
    !]]
    function oComponent.setRange(nLowBound, nHighBound, bNotify)
        assert(_finite(nLowBound) and _finite(nHighBound) and nHighBound > nLowBound
            and _finite(nHighBound - nLowBound), "Invalid range.");
        if (not oComponent.Disposed and (nMin ~= nLowBound or nMax ~= nHighBound)) then
            nMin, nMax = nLowBound, nHighBound;
            oComponent.setValue(oComponent.getValue()); oComponent.refresh();
            if (bNotify) then tEvents.emit("rangeChanged", {Min = nMin, Max = nMax}); end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.RangeSlider.getStep
    @desc Returns the numeric step.
    !]]
    function oComponent.getStep() return nStep; end

    --[[!
    @fqxn wxLuma.UI.RangeSlider.setStep
    @desc Changes positive finite snapping step and fits the interval; optional notification is changed-only.
    !]]
    function oComponent.setStep(nNext, bNotify)
        assert(_finite(nNext) and nNext > 0, "Invalid Step.");
        if (not oComponent.Disposed and nNext ~= nStep) then
            nStep = nNext; oComponent.setValue(oComponent.getValue());
            if (bNotify) then tEvents.emit("stepChanged", {Step = nStep}); end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.RangeSlider.move
    @desc Moves only the active handle, preserving interval order.
    !]]
    local function fMove(nNext)
        if (sActive == "Low") then oComponent.setValue({Low = math.min(nHigh, nNext), High = nHigh}, true);
        else oComponent.setValue({Low = nLow, High = math.max(nLow, nNext)}, true); end
    end

    oComponent.pointer = function(sEvent, nX)
        local nWidth = oComponent.Control:GetClientSizeWH();
        local nValue = nMin + (nX - 16) / math.max(1, nWidth - 32) * (nMax - nMin);
        if (sEvent == "down") then
            tDragStart = oComponent.getValue();
            -- Compare both distances directly. A point just left of the upper
            -- handle still belongs to it; it must not move the lower handle.
            -- Equal distances retain the selected handle, including overlap.
            local nLowDistance, nHighDistance = math.abs(nValue - nLow), math.abs(nValue - nHigh);
            if (nLowDistance < nHighDistance) then sActive = "Low";
            elseif (nHighDistance < nLowDistance) then sActive = "High"; end
        end
        if ((sEvent == "down" or sEvent == "move") and oComponent.Pressed) then fMove(nValue); end
    end;
    oComponent.onCancel = function() tDragStart = nil; end;
    oComponent.key = function(nKey)
        local nCurrent = sActive == "Low" and nLow or nHigh;
        if (nKey == _wx.WXK_SPACE) then sActive = sActive == "Low" and "High" or "Low"; oComponent.refresh();
        elseif (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_DOWN) then fMove(nCurrent - nStep);
        elseif (nKey == _wx.WXK_RIGHT or nKey == _wx.WXK_UP) then fMove(nCurrent + nStep);
        elseif (nKey == _wx.WXK_PAGEUP) then fMove(nCurrent + 10 * nStep);
        elseif (nKey == _wx.WXK_PAGEDOWN) then fMove(nCurrent - 10 * nStep);
        elseif (nKey == _wx.WXK_HOME) then fMove(nMin);
        elseif (nKey == _wx.WXK_END) then fMove(nMax);
        elseif (nKey == _wx.WXK_ESCAPE and tDragStart) then oComponent.setValue(tDragStart, true); oComponent.cancel();
        else return false; end
        return true;
    end;
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then return; end
        local sState = oComponent.getState();
        tArt.part(oDC, "Surface "..sState, 0, 0, nWidth, nHeight);
        tArt.part(oDC, "Track "..sState, 16, (nHeight - 8) / 2, math.max(1, nWidth - 32), 8);
        local nXLow = 16 + (nWidth - 32) * (nLow - nMin) / (nMax - nMin);
        local nXHigh = 16 + (nWidth - 32) * (nHigh - nMin) / (nMax - nMin);
        tArt.part(oDC, "Fill "..sState, nXLow, (nHeight - 8) / 2, nXHigh - nXLow, 8);
        for _, tHandle in ipairs({{"Low", nXLow}, {"High", nXHigh}}) do
            tArt.part(oDC, "Thumb "..(oComponent.isEnabled() and sActive == tHandle[1] and "Hover" or sState),
                tHandle[2] - 12, (nHeight - 28) / 2, 24, 28);
        end
        if (oComponent.Control:HasFocus()) then tArt.part(oDC, "Focus", 0, 0, nWidth, nHeight); end
    end;
    oComponent.onDestroy = tArt.destroy;
    oComponent.setValue(tValue);
    return oComponent;
end

return RangeSlider;
