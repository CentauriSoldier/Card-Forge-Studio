local _ControlInput = require("wxLuma.Core.ControlInput");
local _Border       = require("wxLuma.Core.ControlBorder");
local _wx           = require("wx");
local _Theme        = require("wxLuma.Core.ControlTheme");
local PushButton    = {};

--[[!
@fqxn wxLuma.UI.PushButton.create
@desc Creates an action button activated by mouse, Enter or Space, using the
    configured theme by default or an explicitly borrowed legacy skin.
@param wxWindow oParent Native parent.
@param table tOptions Optional Theme or legacy Skin, Text, Enabled/OnClick. Enter/Space activate on key release.
@ret table oComponent Three-part skinned pushbutton with fixed caps and stretchable middle.
!]]

function PushButton.create(oParent, tOptions)
    local oTheme;
    tOptions, oTheme = _Theme.options(tOptions, oParent);
    tOptions = _Border.withDefault(tOptions, _wx.wxBORDER_NONE);
    local oButton = _ControlInput.create(oParent, tOptions, "Button", function(oComponent, tInput)
        local oSkin = tOptions.Skin;
        tInput.Toggle, tInput.Enter = true, true;
        tInput.focus = false;

        --[[!
        @fqxn wxLuma.UI.PushButton.hitTest
        @desc Accepts enabled points within the visible button body. Legacy
            artwork occupies a centered 36-pixel strip; System fills the client.
        @param number nX Client x.
        @param number nY Client y.
        @ret boolean bHit Whether the button accepts the point.
        !]]
        function oComponent.hitTest(nX, nY)
            if (not tInput.enabled() or type(nX) ~= "number" or type(nY) ~= "number") then return false; end
            local nWidth, nHeight = oComponent.Control:GetClientSizeWH();
            if (not (nX >= 0 and nY >= 0 and nX < nWidth and nY < nHeight)) then return false; end
            if (oTheme and oTheme.getName() == "System") then return true; end
            local nTop = (nHeight - 36) / 2;
            return nY >= nTop and nY < nTop + 36;
        end

        -- Activation and public pointer events share the same visible bounds.
        tInput.inside = oComponent.hitTest;
        oComponent.PointerHitTest = oComponent.hitTest;

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

        -- The theme owns decoration; the shared input engine still owns gestures.
        if (oTheme) then
            tInput.background = function() end;
            tInput.draw = function(oDC, nWidth, nHeight, sState)
                oTheme.button(oComponent, oDC, nWidth, nHeight, sState);
            end;
        end
    end);
    if (oTheme) then
        oTheme.attach(oButton, function()
            oButton.Control:SetFont(oTheme.Font);
            oButton.Control:SetBackgroundColour(oTheme.color("Background"));
            oButton.refresh();
        end);
    end
    return oButton;
end
return PushButton;
