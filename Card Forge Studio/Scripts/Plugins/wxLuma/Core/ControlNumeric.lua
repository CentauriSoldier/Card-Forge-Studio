local _wx            = require("wx");
local ControlNumeric = {};

--[[!
@fqxn wxLuma.UI.ControlNumeric.finite
@desc Checks for a numeric value other than NaN or infinity.
@param number nValue The requested value or index.
@ret boolean bFinite Whether the value is finite.
!]]
function ControlNumeric.finite(nValue)
    return type(nValue) == "number" and nValue == nValue and math.abs(nValue) < math.huge;
end

--[[!
@fqxn wxLuma.UI.ControlNumeric.validateRange
@desc Requires finite ordered bounds, a positive step and a representable span and step count.
@param number nMin Inclusive minimum.
@param number nMax Inclusive maximum.
@param number nStep Positive snapping increment.
!]]
function ControlNumeric.validateRange(nMin, nMax, nStep)
    assert(ControlNumeric.finite(nMin) and ControlNumeric.finite(nMax) and nMax > nMin
        and ControlNumeric.finite(nMax - nMin), "Invalid numeric range.");
    assert(ControlNumeric.finite(nStep) and nStep > 0
        and ControlNumeric.finite((nMax - nMin) / nStep), "Invalid numeric step.");
end

--[[!
@fqxn wxLuma.UI.ControlNumeric.validateOptions
@desc Validates numeric factory options before allocating native controls; integer editors require whole values.
@param table tOptions Min, Max, Step and Value factory settings.
@param boolean bWhole Whether every setting must be a whole number.
!]]
function ControlNumeric.validateOptions(tOptions, bWhole)
    ControlNumeric.validateRange(tOptions.Min, tOptions.Max, tOptions.Step);
    assert(ControlNumeric.finite(tOptions.Value), "Numeric controls require Value.");
    if (bWhole) then
        assert(tOptions.Min % 1 == 0 and tOptions.Max % 1 == 0 and tOptions.Step % 1 == 0
            and tOptions.Value % 1 == 0, "Spinner requires whole-number values.");
    end
end

--[[!
@fqxn wxLuma.UI.ControlNumeric.snap
@desc Clamps a finite value and rounds to a step from Min within a previously validated range.
@param number nValue Requested finite value.
@param number nMin Inclusive minimum.
@param number nMax Inclusive maximum.
@param number nStep Positive snapping increment.
@ret number nSnapped Clamped, stepped value.
!]]
function ControlNumeric.snap(nValue, nMin, nMax, nStep)
    local nClamped = math.max(nMin, math.min(nMax, nValue));
    local nCount = math.floor((nClamped - nMin) / nStep + 0.5);

    if (nCount == 0) then return nMin; end
    -- A rounded step beyond the range must clamp before its product can overflow.
    if (nCount >= (nMax - nMin) / nStep) then return nMax; end
    return math.max(nMin, math.min(nMax, nMin + nCount * nStep));
end

--[[!
@fqxn wxLuma.UI.ControlNumeric.advance
@desc Moves by a signed whole number of steps, saturating before multiplication or addition can overflow.
@param number nValue Current value within the validated range.
@param number nMin Inclusive minimum.
@param number nMax Inclusive maximum.
@param number nStep Positive snapping increment.
@param number nTimes Signed whole number of steps.
@ret number nNext Finite value within the range, before snapping.
!]]
function ControlNumeric.advance(nValue, nMin, nMax, nStep, nTimes)
    if (nTimes == 0) then return nValue; end
    local nDistance = nTimes > 0 and nMax - nValue or nValue - nMin;
    local nCount = math.abs(nTimes);

    -- Compare against the remaining distance before forming the requested delta.
    if (nStep >= nDistance / nCount) then return nTimes > 0 and nMax or nMin; end
    return nValue + nStep * nTimes;
end

--[[!
@fqxn wxLuma.UI.ControlNumeric.configure
@desc Installs finite range validation, nearest-step snapping and keyboard stepping for numeric input.
@param table oComponent The public component.
@param table tInput The private input helpers.
@param table tOptions The factory options.
@param boolean bWhole Whether numeric values must be whole numbers.
!]]
function ControlNumeric.configure(oComponent, tInput, tOptions, bWhole)
    local fFinite = ControlNumeric.finite;
    ControlNumeric.validateOptions(tOptions, bWhole);
    oComponent.Min, oComponent.Max, oComponent.Step = tOptions.Min, tOptions.Max, tOptions.Step;

    --[[!
    @fqxn wxLuma.UI.ControlNumeric.setValue
    @desc Clamps and snaps a finite value to the nearest step from Min, updates native editor text and
        optionally notifies. Unchanged values do not repaint the default background.
    @param number nValue The requested value or index.
    @param boolean|nil bNotify Whether to notify after a change; omitted means silent.
    @ret table oComponent This public component object.
    !]]
    function oComponent.setValue(nValue, bNotify)
        if (bWhole) then
            assert(fFinite(nValue) and nValue % 1 == 0, "Spinner value must be a whole number.");
        end
        assert(fFinite(nValue), "Control value must be finite.");
        nValue = ControlNumeric.snap(nValue, oComponent.Min, oComponent.Max, oComponent.Step);
        local bChanged = oComponent.getValue() ~= nValue;
        oComponent.Value = nValue;
        if (tInput.TextControl) then
            local sText = tostring(oComponent.Value);

            -- Still canonicalize edits such as "04" when the numeric value is
            -- unchanged, without resetting a stable native editor every frame.
            if (tInput.TextControl:GetValue() ~= sText) then
                tInput.TextControl:ChangeValue(sText);
            end
        end

        if (bChanged or tInput.DynamicBackground) then
            tInput.refresh();
        end
        if (bChanged and bNotify) then
            tInput.notify();
        end;
        return oComponent;
    end

    -- Handle the widget navigation or resize keys.
    tInput.key = function(nKey)
        local nValue;
        if (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_DOWN) then
            nValue = ControlNumeric.advance(oComponent.Value, oComponent.Min, oComponent.Max, oComponent.Step, -1);
        elseif (nKey == _wx.WXK_RIGHT or nKey == _wx.WXK_UP) then
            nValue = ControlNumeric.advance(oComponent.Value, oComponent.Min, oComponent.Max, oComponent.Step, 1);
        elseif (nKey == _wx.WXK_HOME) then
            nValue = oComponent.Min;
        elseif (nKey == _wx.WXK_END) then
            nValue = oComponent.Max;
        elseif (nKey == _wx.WXK_PAGEUP) then
            nValue = ControlNumeric.advance(oComponent.Value, oComponent.Min, oComponent.Max, oComponent.Step, 10);
        elseif (nKey == _wx.WXK_PAGEDOWN) then
            nValue = ControlNumeric.advance(oComponent.Value, oComponent.Min, oComponent.Max, oComponent.Step, -10);
        end
        if (nValue) then
            oComponent.setValue(nValue, true);
            return true;
        end
        return false;
    end;
end
return ControlNumeric;
