local _finite = require("wxLuma.Core.ControlNumeric").finite;
local ControlColor = {};

--[[!
@fqxn wxLuma.UI.ControlColor.rgba
@desc Validates and copies integer RGBA channels. Omitted alpha means opaque.
@param table tColor R/G/B and optional A in the inclusive range 0-255.
@ret table tCopy Independent normalized color.
!]]
function ControlColor.rgba(tColor)
    assert(type(tColor) == "table", "Color must be a table.");
    local tCopy = {};
    for _, sKey in ipairs({"R", "G", "B", "A"}) do
        local nValue = tColor[sKey];
        if (sKey == "A" and nValue == nil) then
            nValue = 255;
        end
        assert(_finite(nValue) and nValue % 1 == 0 and nValue >= 0 and nValue <= 255,
            "RGBA channels must be integers from 0 through 255.");
        tCopy[sKey] = nValue;
    end
    return tCopy;
end

--[[!
@fqxn wxLuma.UI.ControlColor.hsv
@desc Converts validated RGBA into H degrees [0,360), S/V percentages [0,100], A byte.
@param table tColor Normalized RGBA.
@ret table tHSV Independent HSV plus alpha.
!]]
function ControlColor.hsv(tColor)
    local nR, nG, nB = tColor.R / 255, tColor.G / 255, tColor.B / 255;
    local nMax, nMin = math.max(nR, nG, nB), math.min(nR, nG, nB);
    local nDelta = nMax - nMin;
    local nHue = 0;
    if (nDelta > 0) then
        if (nMax == nR) then
            nHue = ((nG - nB) / nDelta) % 6;
        elseif (nMax == nG) then
            nHue = (nB - nR) / nDelta + 2;
        else
            nHue = (nR - nG) / nDelta + 4;
        end
        nHue = nHue * 60;
    end
    return {H = nHue, S = nMax == 0 and 0 or nDelta / nMax * 100, V = nMax * 100, A = tColor.A};
end

--[[!
@fqxn wxLuma.UI.ControlColor.fromHSV
@desc Validates HSV and converts to rounded byte RGBA. Hue wraps at 360 degrees.
@param table tHSV Finite H, S/V in 0-100, optional integer A in 0-255.
@ret table tColor Independent RGBA.
!]]
function ControlColor.fromHSV(tHSV)
    assert(type(tHSV) == "table" and _finite(tHSV.H) and _finite(tHSV.S) and _finite(tHSV.V)
        and tHSV.S >= 0 and tHSV.S <= 100 and tHSV.V >= 0 and tHSV.V <= 100, "Invalid HSV color.");
    local nH = (tHSV.H % 360) / 60;
    local nS, nV = tHSV.S / 100, tHSV.V / 100;
    local nC = nV * nS;
    local nX = nC * (1 - math.abs(nH % 2 - 1));
    local nM = nV - nC;
    local nR, nG, nB;
    if (nH < 1) then
        nR, nG, nB = nC, nX, 0;
    elseif (nH < 2) then
        nR, nG, nB = nX, nC, 0;
    elseif (nH < 3) then
        nR, nG, nB = 0, nC, nX;
    elseif (nH < 4) then
        nR, nG, nB = 0, nX, nC;
    elseif (nH < 5) then
        nR, nG, nB = nX, 0, nC;
    else
        nR, nG, nB = nC, 0, nX;
    end
    return ControlColor.rgba({R = math.floor((nR + nM) * 255 + 0.5),
        G = math.floor((nG + nM) * 255 + 0.5), B = math.floor((nB + nM) * 255 + 0.5), A = tHSV.A});
end

return ControlColor;
