local _wx            = require("wx");
local ControlDrawing = {};

--[[!
@fqxn wxLuma.UI.ControlDrawing.frame
@desc Draws the common charcoal frame, optional enabled highlight and active border using temporary
    native drawing resources.
@param wxDC oDC The destination drawing context.
@param number nX The horizontal client coordinate.
@param number nY The vertical client coordinate.
@param number nWidth The width in client pixels.
@param number nHeight The height in client pixels.
@param boolean bEnabled Whether the component is enabled.
@param boolean bActive Whether to draw the active border.
!]]
function ControlDrawing.frame(oDC, nX, nY, nWidth, nHeight, bEnabled, bActive)
    local oBrush = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    local oPen   = _wx.wxPen(_wx.wxColour(bActive and 145 or 68, bActive and 170 or 78, bActive and 191
        or 89), 1, _wx.wxPENSTYLE_SOLID);
    oDC:SetBrush(oBrush);
    oDC:SetPen(oPen);
    oDC:DrawRectangle(nX, nY, nWidth, nHeight);
    oPen:delete();
    oBrush:delete();
    if (bEnabled) then
        oDC:GradientFillLinear(_wx.wxRect(nX + 1, nY + 1, math.max(1, nWidth - 2), 3),
            _wx.wxColour(67, 76, 87), _wx.wxColour(29, 35, 43), _wx.wxSOUTH);
    end
end

return ControlDrawing;
