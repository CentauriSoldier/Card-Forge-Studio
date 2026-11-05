local _ControlInput = require("wxLuma.Core.ControlInput");
local PushButton    = {};

--[[!
@fqxn wxLuma.UI.PushButton.create
@desc Creates a skinned action button activated by mouse, Enter or Space.
@param wxWindow oParent Native parent.
@param table tOptions Skin, Text, optional Enabled/OnClick. Enter/Space activate on key release.
@ret table oComponent Three-part skinned pushbutton with fixed caps and stretchable middle.
!]]

function PushButton.create(oParent, tOptions)
    return _ControlInput.create(oParent, tOptions, "Button", function(oComponent, tInput)
        local oSkin = tOptions.Skin;
        tInput.Toggle, tInput.Enter = true, true;

        -- Apply user activation through the widget setter and notification path.
        tInput.activate = function()
            if (tOptions.OnClick) then
                tOptions.OnClick(oComponent);
            end
        end;

        -- Draw artwork for the current value and input state.
        tInput.draw = function(oDC, nWidth, nHeight, sState)

            tInput.drawPart(oDC, "Button Left " .. sState, 0, (nHeight - 36) / 2);
            tInput.drawPart(oDC, "Button Middle " .. sState, 12, (nHeight - 36) / 2, nWidth - 24, 36);
            tInput.drawPart(oDC, "Button Right " .. sState, nWidth - 12, (nHeight - 36) / 2);
            oDC:SetFont(oSkin.Font);
            local nTextW, nTextH = oDC:GetTextExtent(oComponent.Text);
            oSkin.text(oDC, oComponent.Text, (nWidth - nTextW) / 2,
                (nHeight - nTextH) / 2 + (sState == "Pressed" and 1 or 0), tInput.enabled());

        end;
    end);
end
return PushButton;
