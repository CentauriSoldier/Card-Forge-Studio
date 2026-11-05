local _ControlInput   = require("wxLuma.Core.ControlInput");
local _ControlNumeric = require("wxLuma.Core.ControlNumeric");
local Slider          = {};

--[[!
@fqxn wxLuma.UI.Slider.create
@desc Creates a continuous pointer-driven input with stepped numeric values and keyboard navigation.
@param wxWindow oParent Native parent.
@param table tOptions Skin, Min, Max, Step, Value; optional Vertical/Enabled/OnChange. Max must exceed Min.
@ret table oComponent Slider. Values clamp/snap to nearest step from Min; vertical maximum is at the
    top. Arrows/Page/Home/End supported.
!]]

function Slider.create(oParent, tOptions)
    return _ControlInput.create(oParent, tOptions, "Slider", function(oComponent, tInput)
        local oSkin = tOptions.Skin;
        _ControlNumeric.configure(oComponent, tInput, tOptions, false);

        -- Map pointer coordinates to the slider value using numeric snapping.
        tInput.drag = function(nX, nY)
            local nWidth, nHeight = oComponent.Control:GetClientSizeWH();
            local nFraction       = oComponent.Vertical and 1 - (nY - 16) / math.max(1, nHeight - 32)
            or (nX - 16) / math.max(1, nWidth - 32);
            oComponent.setValue(oComponent.Min + nFraction * (oComponent.Max - oComponent.Min), true);
        end;

        -- Draw artwork for the current value and input state.
        tInput.draw = function(oDC, nWidth, nHeight, sState)

            local nFraction = (oComponent.Value - oComponent.Min) / (oComponent.Max - oComponent.Min);
            if (oComponent.Vertical) then
                tInput.drawPart(oDC, "Slider Track " .. sState, (nWidth - 12) / 2, 16, 12, nHeight - 32, true);
                tInput.drawPart(oDC, "Slider Thumb " .. sState, (nWidth - 40) / 2,
                    16 + (1 - nFraction) * (nHeight - 32) - 14, 40, 28, true);
            else
                tInput.drawPart(oDC, "Slider Track " .. sState, 16, (nHeight - 12) / 2, nWidth - 32, 12);
                tInput.drawPart(oDC, "Slider Thumb " .. sState,
                    16 + nFraction * (nWidth - 32) - 14, (nHeight - 40) / 2);
            end

        end;
        oComponent.setValue(tOptions.Value);
    end);
end
return Slider;
