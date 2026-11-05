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
@fqxn wxLuma.UI.ControlNumeric.configure
@desc Installs finite range validation, nearest-step snapping and keyboard stepping for numeric input.
@param table oComponent The public component.
@param table tInput The private input helpers.
@param table tOptions The factory options.
@param boolean bWhole Whether numeric values must be whole numbers.
!]]
function ControlNumeric.configure(oComponent, tInput, tOptions, bWhole)
    local fFinite = ControlNumeric.finite;
    assert(fFinite(tOptions.Min) and fFinite(tOptions.Max) and fFinite(tOptions.Step),
        "Numeric controls require finite Min, Max, Step.");
    assert(tOptions.Max > tOptions.Min and tOptions.Step > 0, "Invalid control range/step.");
    oComponent.Min, oComponent.Max, oComponent.Step = tOptions.Min, tOptions.Max, tOptions.Step;
    assert(fFinite(tOptions.Value), "Numeric controls require Value.");
    if (bWhole) then
        assert(oComponent.Min % 1 == 0 and oComponent.Max % 1 == 0 and oComponent.Step % 1 == 0
            and tOptions.Value % 1 == 0, "Spinner requires whole-number values.");
    end

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
        local nClamped = math.max(oComponent.Min, math.min(oComponent.Max, nValue));
        local nStep    = math.floor((nClamped - oComponent.Min) / oComponent.Step + 0.5);
        nValue = math.max(oComponent.Min, math.min(oComponent.Max, oComponent.Min + nStep * oComponent.Step));
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
            nValue = oComponent.Value - oComponent.Step;
        elseif (nKey == _wx.WXK_RIGHT or nKey == _wx.WXK_UP) then
            nValue = oComponent.Value + oComponent.Step;
        elseif (nKey == _wx.WXK_HOME) then
            nValue = oComponent.Min;
        elseif (nKey == _wx.WXK_END) then
            nValue = oComponent.Max;
        elseif (nKey == _wx.WXK_PAGEUP) then
            nValue = oComponent.Value + oComponent.Step * 10;
        elseif (nKey == _wx.WXK_PAGEDOWN) then
            nValue = oComponent.Value - oComponent.Step * 10;
        end
        if (nValue) then
            oComponent.setValue(nValue, true);
            return true;
        end
        return false;
    end;
end
return ControlNumeric;
