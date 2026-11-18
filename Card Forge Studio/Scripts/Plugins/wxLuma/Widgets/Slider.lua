local _SliderArtwork = require("wxLuma.Core.ControlSliderArtwork");
local _Border = require("wxLuma.Core.ControlBorder");
local _wx = require("wx");
local _Theme = require("wxLuma.Core.ControlTheme");
local _ControlInput   = require("wxLuma.Core.ControlInput");
local _ControlNumeric = require("wxLuma.Core.ControlNumeric");
local Slider          = {};

--[[!
@fqxn wxLuma.UI.Slider.create
@desc Creates a continuous pointer-driven input with stepped numeric values and keyboard navigation.
@param wxWindow oParent Native parent.
@param table tOptions Skin, Min, Max, Step, Value; optional Vertical/Enabled/OnChange. Max must exceed Min.
    FocusBorder is accepted for compatibility; focus adds no decorative outline.
@ret table oComponent Slider. Values clamp/snap to nearest step from Min; vertical maximum is at the
    top. Arrows/Page/Home/End supported.
!]]

function Slider.create(oParent, tOptions)
    tOptions = _Theme.options(tOptions, oParent);
    tOptions = _Border.withDefault(tOptions, _wx.wxBORDER_NONE);
    assert(tOptions.FocusBorder == nil or type(tOptions.FocusBorder) == "boolean", "FocusBorder must be boolean.");
    _ControlNumeric.validateOptions(tOptions, false);
    return _ControlInput.create(oParent, tOptions, "Slider", function(oComponent, tInput)
        local oSkin = tOptions.Skin;
        -- Focus retains keyboard ownership without adding an outer rectangle.
        if (tOptions.FocusBorder ~= true) then tInput.focus = false; end
        _ControlNumeric.configure(oComponent, tInput, tOptions, false);

        -- Map pointer coordinates to the slider value using numeric snapping.
        tInput.drag = function(nX, nY)
            local nWidth, nHeight = oComponent.Control:GetClientSizeWH();
            local nMargin = _Theme.isTheme(oSkin) and oSkin.getName() == "System" and oComponent.Control:FromDIP(16) or 16;
            local nFraction       = oComponent.Vertical and 1 - (nY - nMargin) / math.max(1, nHeight - nMargin * 2)
            or (nX - nMargin) / math.max(1, nWidth - nMargin * 2);
            nFraction = math.max(0, math.min(1, nFraction));
            oComponent.setValue(oComponent.Min + nFraction * (oComponent.Max - oComponent.Min), true);
        end;

        -- Draw artwork for the current value and input state.
        tInput.draw = function(oDC, nWidth, nHeight, sState)
            _SliderArtwork.draw(oComponent.Control, oSkin, tInput.drawPart, oDC, nWidth, nHeight,
                sState, oComponent.Vertical, {(oComponent.Value - oComponent.Min) / (oComponent.Max - oComponent.Min)});
        end;
        oComponent.setValue(tOptions.Value);
    end);
end
return Slider;
