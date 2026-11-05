local _wx             = require("wx");
local _ControlInput   = require("wxLuma.Core.ControlInput");
local _ControlNumeric = require("wxLuma.Core.ControlNumeric");
local Spinner         = {};

--[[!
@fqxn wxLuma.UI.Spinner.create
@desc Creates a native integer editor with skinned increment and decrement arrows.
@param wxWindow oParent Native parent.
@param table tOptions Skin, integer Min/Max/Step/Value, optional Enabled/OnChange. Min must be below
    Max, Step positive.
@ret table oComponent Integer editor and single-click stepper. Enter/focus loss validates text; invalid
    text restores previous value. No hold-repeat.
!]]

function Spinner.create(oParent, tOptions)
    return _ControlInput.create(oParent, tOptions, "Spinner", function(oComponent, tInput)
        local oSkin   = tOptions.Skin;
        local fFinite = _ControlNumeric.finite;
        _ControlNumeric.configure(oComponent, tInput, tOptions, true);
        local oText = _wx.wxTextCtrl(oComponent.Control, _wx.wxID_ANY, "", _wx.wxDefaultPosition,
            _wx.wxDefaultSize,
            _wx.wxTE_PROCESS_ENTER + _wx.wxTE_RIGHT + _wx.wxBORDER_NONE);
        oComponent.TextControl, tInput.TextControl = oText, oText;
        oText:SetFont(oSkin.Font);
        oText:SetBackgroundColour(_wx.wxColour(24, 29, 36));
        oText:SetForegroundColour(_wx.wxColour(208, 218, 230));

        --[[!
        @fqxn wxLuma.UI.Spinner.commitText
        @desc Commits an in-range integer through numeric snapping; invalid text restores the previous
            value and returns false.
        @ret boolean bCommitted Whether text was accepted.
        !]]
        function oComponent.commitText()
            if (not tInput.enabled()) then
                return false;
            end
            local nValue = tonumber(oText:GetValue());
            if (not fFinite(nValue) or nValue % 1 ~= 0 or nValue < oComponent.Min
                or nValue > oComponent.Max) then
                oText:ChangeValue(tostring(oComponent.Value));
                return false;
            end
            oComponent.setValue(nValue, true);
            return true;
        end

        -- Hit-test the separately clickable spinner arrow regions.
        tInput.part = function(nX, nY)
            local nWidth = oComponent.Control:GetClientSizeWH();
            if (nX >= nWidth - 26 and nX < nWidth - 2 and nY >= 2 and nY < 38) then
                return nY < 20 and 1 or 2;
            end
            return 0;
        end;

        -- Position the native spinner editor inside its frame.
        tInput.layout = function(nWidth)
            oText:SetSize(10, 8, math.max(20, nWidth - 44), 23);
        end;

        -- Apply user activation through the widget setter and notification path.
        tInput.activate = function(nPart)
            if (nPart and nPart > 0) then
                oComponent.commitText();
                oComponent.setValue(oComponent.Value + (nPart == 1 and oComponent.Step or -oComponent.Step),
                    true);
            end
        end;

        -- Draw artwork for the current value and input state.
        tInput.draw = function(oDC, nWidth, nHeight, sState, oBrush)

            local oPen = _wx.wxPen(_wx.wxColour(68, 78, 89), 1, _wx.wxPENSTYLE_SOLID);
            oDC:SetPen(oPen);
            oDC:SetBrush(oBrush);
            oDC:DrawRectangle(1, 1, nWidth - 2, nHeight - 2);
            oPen:delete();
            for nPart, sDirection in ipairs({
                "Up",
                "Down"
            }) do
                local sPartState = not tInput.enabled() and "Disabled" or oComponent.Pressed
                    and tInput.PressedPart == nPart and tInput.HoverPart == nPart and "Pressed"
                or oComponent.Hover and tInput.HoverPart == nPart and "Hover" or "Normal";
                tInput.drawPart(oDC, "Spinner " .. sDirection .." " .. sPartState, nWidth - 26,
                    nPart == 1 and 2 or 20);
            end

        end;
        oText:Connect(_wx.wxEVT_COMMAND_TEXT_ENTER, function()
            oComponent.commitText();
        end);
        oText:Connect(_wx.wxEVT_KILL_FOCUS, function(jEvent)
            oComponent.commitText();
            jEvent:Skip();
        end);
        oText:Connect(_wx.wxEVT_KEY_DOWN, function(jEvent)
            if (not oComponent.handleKey("down", jEvent:GetKeyCode())) then
                jEvent:Skip();
            end
        end);
        oComponent.setValue(tOptions.Value);
    end);
end
return Spinner;
