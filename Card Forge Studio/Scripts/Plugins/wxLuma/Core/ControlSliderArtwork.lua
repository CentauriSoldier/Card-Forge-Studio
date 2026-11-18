local _Theme = require("wxLuma.Core.ControlTheme");
local ControlSliderArtwork = {};

--[[!
@fqxn wxLuma.UI.ControlSliderArtwork.margin
@desc Returns the shared track endpoint inset used by painting and pointer input.
!]]
function ControlSliderArtwork.margin(oWindow, oSkin)
    return _Theme.isTheme(oSkin) and oSkin.getName() == "System" and oWindow:FromDIP(16) or 16;
end

--[[!
@fqxn wxLuma.UI.ControlSliderArtwork.draw
@desc Paints one slider track and one thumb per normalized value. Single and
    range sliders share identical geometry, materials and state treatment.
@param wxWindow oWindow Native control for DIP conversion.
@param table oSkin Appearance provider.
@param function fPart Draws a named material into the borrowed DC.
@param wxDC oDC Borrowed destination.
@param number nWidth Client width.
@param number nHeight Client height.
@param string sState Current input state.
@param boolean bVertical Vertical orientation.
@param table tFractions Ordered thumb values between zero and one.
!]]
function ControlSliderArtwork.draw(oWindow, oSkin, fPart, oDC, nWidth, nHeight, sState, bVertical, tFractions)
    local bSystem = _Theme.isTheme(oSkin) and oSkin.getName() == "System";
    local nMargin = ControlSliderArtwork.margin(oWindow, oSkin);
    local nTrack = bSystem and oWindow:FromDIP(4) or 12;
    local nThumbW = bSystem and oWindow:FromDIP(10) or 28;
    local nThumbH = bSystem and oWindow:FromDIP(20) or 40;
    if (bVertical) then
        fPart(oDC, "Slider Track "..sState, (nWidth - nTrack) / 2, nMargin,
            nTrack, math.max(1, nHeight - nMargin * 2), not bSystem);
    else
        fPart(oDC, "Slider Track "..sState, nMargin, (nHeight - nTrack) / 2,
            math.max(1, nWidth - nMargin * 2), nTrack);
    end

    -- Draw the track once so it cannot paint over an earlier range thumb.
    local nPrevious;
    for _, nFraction in ipairs(tFractions) do
        -- Coincident handles share one footprint. Drawing translucent skin
        -- artwork twice would darken it compared with the normal slider.
        if (nFraction ~= nPrevious) then
            if (bVertical) then
                fPart(oDC, "Slider Thumb "..sState, (nWidth - nThumbH) / 2,
                    nMargin + (1 - nFraction) * (nHeight - nMargin * 2) - nThumbW / 2,
                    nThumbH, nThumbW, not bSystem);
            else
                fPart(oDC, "Slider Thumb "..sState,
                    nMargin + nFraction * (nWidth - nMargin * 2) - nThumbW / 2,
                    (nHeight - nThumbH) / 2, nThumbW, nThumbH);
            end
            end
        nPrevious = nFraction;
    end
end

return ControlSliderArtwork;
