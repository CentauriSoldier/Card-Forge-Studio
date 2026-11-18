local _SliderArtwork = require("wxLuma.Core.ControlSliderArtwork");
local _Border = require("wxLuma.Core.ControlBorder");
local _Theme = require("wxLuma.Core.ControlTheme");
local _wx = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events = require("wxLuma.Core.ControlEvents");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local _Numeric = require("wxLuma.Core.ControlNumeric");
local _finite = _Numeric.finite;
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
    tOptions = _Theme.options(tOptions, oParent);
    tOptions = _Border.withDefault(tOptions, _wx.wxBORDER_NONE);
    assert(tOptions.FocusBorder == nil or type(tOptions.FocusBorder) == "boolean", "FocusBorder must be boolean.");
    local nMin, nMax, nStep = tOptions.Min or 0, tOptions.Max or 100, tOptions.Step or 1;
    _Numeric.validateRange(nMin, nMax, nStep);
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
        return _Numeric.snap(nValue, nMin, nMax, nStep);
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
    @desc Requires a finite span and step count before changing bounds, then silently fits the interval before optional rangeChanged.
    !]]
    function oComponent.setRange(nLowBound, nHighBound, bNotify)
        _Numeric.validateRange(nLowBound, nHighBound, nStep);
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
    @fqxn wxLuma.UI.RangeSlider.getRangeAndStep
    @desc Returns bounds and step together so persistence can restore coupled numeric settings atomically.
    @ret number nMin Minimum, followed by maximum and step.
    !]]
    function oComponent.getRangeAndStep() return nMin, nMax, nStep; end

    --[[!
    @fqxn wxLuma.UI.RangeSlider.setRangeAndStep
    @desc Validates and silently applies bounds and step together, then fits the current interval.
    @param number nLowBound New minimum.
    @param number nHighBound New maximum.
    @param number nNextStep New positive step.
    @ret table oComponent This object.
    !]]
    function oComponent.setRangeAndStep(nLowBound, nHighBound, nNextStep)
        _Numeric.validateRange(nLowBound, nHighBound, nNextStep);
        if (not oComponent.Disposed) then
            nMin, nMax, nStep = nLowBound, nHighBound, nNextStep;
            oComponent.setValue(oComponent.getValue()); oComponent.refresh();
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.RangeSlider.setStep
    @desc Requires a positive finite step with a finite step count before fitting the interval; optional notification is changed-only.
    !]]
    function oComponent.setStep(nNext, bNotify)
        _Numeric.validateRange(nMin, nMax, nNext);
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
        local nMargin = _SliderArtwork.margin(oComponent.Control, oComponent.Skin);
        local nFraction = math.max(0, math.min(1, (nX - nMargin) / math.max(1, nWidth - nMargin * 2)));
        local nValue = nMin + nFraction * (nMax - nMin);
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
        elseif (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_DOWN) then fMove(_Numeric.advance(nCurrent, nMin, nMax, nStep, -1));
        elseif (nKey == _wx.WXK_RIGHT or nKey == _wx.WXK_UP) then fMove(_Numeric.advance(nCurrent, nMin, nMax, nStep, 1));
        elseif (nKey == _wx.WXK_PAGEUP) then fMove(_Numeric.advance(nCurrent, nMin, nMax, nStep, 10));
        elseif (nKey == _wx.WXK_PAGEDOWN) then fMove(_Numeric.advance(nCurrent, nMin, nMax, nStep, -10));
        elseif (nKey == _wx.WXK_HOME) then fMove(nMin);
        elseif (nKey == _wx.WXK_END) then fMove(nMax);
        elseif (nKey == _wx.WXK_ESCAPE and tDragStart) then oComponent.setValue(tDragStart, true); oComponent.cancel();
        else return false; end
        return true;
    end;
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then return; end
        local sState = oComponent.getState();
        -- Match the single slider's backdrop as well as its track and thumbs.
        if (tOptions.Background) then
            tOptions.Background(oDC, oComponent);
        else
            local oColor = _Theme.colour(oComponent.Skin, "Background", 24, 29, 36);
            local oBrush = _wx.wxBrush(oColor);
            oDC:SetBackground(oBrush); oDC:Clear(); oBrush:delete(); oColor:delete();
        end
        _SliderArtwork.draw(oComponent.Control, oComponent.Skin, oComponent.Skin.drawOpaque,
            oDC, nWidth, nHeight, sState, false,
            {(nLow - nMin) / (nMax - nMin), (nHigh - nMin) / (nMax - nMin)});
    end;
    oComponent.onDestroy = tArt.destroy;
    oComponent.setValue(tValue);
    _Theme.finish(oComponent, tOptions);
    return oComponent;
end

return RangeSlider;
