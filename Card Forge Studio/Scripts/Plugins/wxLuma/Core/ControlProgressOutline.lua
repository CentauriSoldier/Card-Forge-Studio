local _wx     = require("wx");
local _Theme  = require("wxLuma.Core.ControlTheme");
local _finite = require("wxLuma.Core.ControlNumeric").finite;
local ControlProgressOutline = {};

--[[!
@fqxn wxLuma.UI.ControlProgressOutline.create
@desc Validates and copies progress shape-outline options before native controls
    are allocated. Outlines describe the meter, independently of native borders
    and keyboard focus. Colors are resolved while painting so OS changes apply.
@param table tOptions Outline (true), OutlineWidth (2 pixels, 1..8), optional
    OutlineColour ({R,G,B}, each 0..255). Outline=false disables the shape edge.
@ret table tOutline Private circle and rectangle painters, owning no resources.
!]]
function ControlProgressOutline.create(tOptions)
    assert(tOptions.Outline == nil or type(tOptions.Outline) == "boolean", "Outline must be boolean.");
    local nWidth = tOptions.OutlineWidth or 2;
    assert(_finite(nWidth) and nWidth >= 1 and nWidth <= 8, "OutlineWidth must be between 1 and 8.");
    local tRGB;
    if (tOptions.OutlineColour ~= nil) then
        assert(type(tOptions.OutlineColour) == "table", "OutlineColour must contain R, G and B.");
        tRGB = {};
        for _, sChannel in ipairs({"R", "G", "B"}) do
            local nValue = tOptions.OutlineColour[sChannel];
            assert(_finite(nValue) and nValue >= 0 and nValue <= 255, "Invalid OutlineColour channel.");
            tRGB[sChannel] = nValue;
        end
    end
    local tOutline = {};

    --[[!
    @fqxn wxLuma.UI.ControlProgressOutline.paint
    @desc Paints an inward shape edge in native or supersampled coordinates,
        releasing temporary native resources before returning.
    !]]
    local function fPaint(oDC, oSkin, bEnabled, nScale, bCircle, nX, nY, nW, nH)
        if (tOptions.Outline == false or nW <= 0 or nH <= 0) then return; end
        local oColor = tRGB and _wx.wxColour(tRGB.R, tRGB.G, tRGB.B)
            or _Theme.colour(oSkin, bEnabled and "Border" or "DisabledText", 100, 110, 120);
        local nStroke = math.max(1, math.floor(nWidth * nScale + 0.5));
        nStroke = math.min(nStroke, math.max(1, math.floor(math.min(nW, nH) / 2)));
        if (bCircle) then
            local oPen = _wx.wxPen(oColor, nStroke, _wx.wxPENSTYLE_SOLID);
            oDC:SetPen(oPen); oDC:SetBrush(_wx.wxTRANSPARENT_BRUSH);
            oDC:DrawCircle(nX + nW / 2, nY + nH / 2, math.max(0, nW / 2 - nStroke / 2));
            oPen:delete();
        else
            -- Filled strips use the same pixel bounds as the track. A stroked
            -- rectangle uses native endpoint rules that can leave an exposed row.
            local oBrush = _wx.wxBrush(oColor);
            oDC:SetPen(_wx.wxTRANSPARENT_PEN); oDC:SetBrush(oBrush);
            oDC:DrawRectangle(nX, nY, nW, nStroke);
            oDC:DrawRectangle(nX, nY + nH - nStroke, nW, nStroke);
            local nSideHeight = nH - 2 * nStroke;
            if (nSideHeight > 0) then
                oDC:DrawRectangle(nX, nY + nStroke, nStroke, nSideHeight);
                oDC:DrawRectangle(nX + nW - nStroke, nY + nStroke, nStroke, nSideHeight);
            end
            oDC:SetBrush(_wx.wxTRANSPARENT_BRUSH);
            oBrush:delete();
        end
        oColor:delete();
    end

    --[[!
    @fqxn wxLuma.UI.ControlProgressOutline.circle
    @desc Paints the outer circular silhouette within its existing radius.
    !]]
    function tOutline.circle(oDC, oSkin, bEnabled, nCenter, nRadius, nScale)
        fPaint(oDC, oSkin, bEnabled, nScale, true,
            nCenter - nRadius, nCenter - nRadius, nRadius * 2, nRadius * 2);
    end

    --[[!
    @fqxn wxLuma.UI.ControlProgressOutline.rectangle
    @desc Paints the linear track edge without outlining its surrounding window.
    !]]
    function tOutline.rectangle(oDC, oSkin, bEnabled, nX, nY, nW, nH)
        fPaint(oDC, oSkin, bEnabled, 1, false, nX, nY, nW, nH);
    end
    return tOutline;
end

return ControlProgressOutline;
