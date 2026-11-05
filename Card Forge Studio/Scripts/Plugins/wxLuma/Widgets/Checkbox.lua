local _ControlInput = require("wxLuma.Core.ControlInput");
local Checkbox      = {};

--[[!
@fqxn wxLuma.UI.Checkbox.create
@desc Creates a skinned boolean input with mouse and Space-key activation.
@param wxWindow oParent Native parent.
@param table tOptions Skin, Text, optional Selected/Enabled/OnChange(value,component).
@ret table oComponent Component with Control, getValue/setValue, setEnabled, layout, draw, getState,
    input adapters and destroy.
!]]

function Checkbox.create(oParent, tOptions)
    return _ControlInput.create(oParent, tOptions, "Checkbox", function(oComponent, tInput)
        local oSkin = tOptions.Skin;
        tInput.Toggle = true;

        --[[!
        @fqxn wxLuma.UI.Checkbox.getValue
        @desc Returns the checkbox selection flag.
        @ret any vValue The current value.
        !]]
        function oComponent.getValue()
            return oComponent.Selected;
        end

        --[[!
        @fqxn wxLuma.UI.Checkbox.setValue
        @desc Validates and updates the component value, refreshes its appearance and optionally
            notifies when the value changes.
        @param boolean bValue The requested selection.
        @param boolean|nil bNotify Whether to notify after a change; omitted means silent.
        @ret table oComponent This public component object.
        !]]
        function oComponent.setValue(bValue, bNotify)
            assert(type(bValue) == "boolean", "Checkbox selection must be boolean.");
            local bChanged = oComponent.getValue() ~= bValue;
            oComponent.Selected = bValue;
            if (bChanged or tInput.DynamicBackground) then
                tInput.refresh();
            end

            if (bChanged and bNotify) then
                tInput.notify();
            end;
            return oComponent;
        end

        -- Apply user activation through the widget setter and notification path.
        tInput.activate = function()
            oComponent.setValue(not oComponent.Selected, true);
        end;

        -- Draw artwork for the current value and input state.
        tInput.draw = function(oDC, nWidth, nHeight, sState)

            tInput.drawPart(oDC, "Checkbox" .. (oComponent.Selected and " On " or " Off ") .. sState, 0,
                math.floor((nHeight - 32) / 2));
            oSkin.text(oDC, oComponent.Text, 40, math.floor((nHeight - 18) / 2), tInput.enabled());

        end;
    end);
end
return Checkbox;
