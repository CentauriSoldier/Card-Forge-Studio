local _wx           = require("wx");
local Panel         = {};
local createSurface = require("wxLuma.Core.ControlSurface").create;

--[[!
@fqxn wxLuma.UI.Panel.create
@param table tOptions Skin; optional Text, MinWidth (220), MinHeight (140),
    OnResize(width,height,component), Enabled.
@desc Embedded panel owns Content. Drag bottom-right grip or use focused arrows
      (Shift for ten pixels) within parent bounds. Escape cancels a drag. show toggles visibility.
!]]
function Panel.create(oParent, tOptions)
    local oComponent = createSurface(oParent, tOptions, "Panel");
    oComponent.MinWidth, oComponent.MinHeight = tOptions.MinWidth or 220, tOptions.MinHeight or 140;
    oComponent.Content                        = _wx.wxPanel(oComponent.Control, _wx.wxID_ANY, _wx.wxDefaultPosition,
        _wx.wxDefaultSize, _wx.wxBORDER_NONE + _wx.wxTAB_TRAVERSAL);
    oComponent.Content:SetBackgroundColour(_wx.wxColour(24, 29, 36));
    local tDrag;

    -- Discard the active drag state when input is cancelled.
    oComponent.onCancel = function()
        tDrag = nil;
    end;

    -- Lay out owned native children after a size change.
    oComponent.onLayout = function(nWidth, nHeight)
        oComponent.Content:SetSize(8, 34, math.max(1, nWidth - 16), math.max(1, nHeight - 58));
    end;

    --[[!
    @fqxn wxLuma.UI.Panel.resize
    @desc Clamps the requested panel size to its minimum and parent bounds; optionally reports an actual
        size change.
    @param number nWidth The width in client pixels.
    @param number nHeight The height in client pixels.
    @param boolean|nil bNotify Whether to notify when the stored value changes; omitted means silent.
    @ret table oComponent This public component object.
    !]]
    function oComponent.resize(nWidth, nHeight, bNotify)
        local nX, nY             = oComponent.Control:GetPositionXY();
        local nParentW, nParentH = oParent:GetClientSizeWH();
        nWidth  = math.max(math.min(oComponent.MinWidth, nParentW - nX), math.min(nParentW - nX - 4,
            math.floor(nWidth)));
        nHeight = math.max(math.min(oComponent.MinHeight, nParentH - nY), math.min(nParentH - nY - 4,
            math.floor(nHeight)));
        local nOldWidth, nOldHeight = oComponent.Control:GetSizeWH();
        if (nWidth ~= nOldWidth or nHeight ~= nOldHeight) then
            oComponent.layout(nX, nY, nWidth, nHeight);
            if (bNotify and tOptions.OnResize) then
                tOptions.OnResize(nWidth, nHeight, oComponent);
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Panel.show
    @desc Cancels active panel input and changes native visibility.
    @param boolean bShow Whether to show the component.
    !]]
    function oComponent.show(bShow)
        oComponent.cancel();
        oComponent.Control:Show(bShow);
        return oComponent;
    end

    -- Apply this widget's pointer policy after the shared base updates input state.
    oComponent.pointer = function(sEvent, nX, nY)
        local nWidth, nHeight = oComponent.Control:GetClientSizeWH();
        if (sEvent == "down") then
            tDrag = nil;
            if (nX >= nWidth - 24 and nY >= nHeight - 24) then
                tDrag = {
                    X      = nX,
                    Y      = nY,
                    Width  = nWidth,
                    Height = nHeight
                };
            end
        elseif ((sEvent == "move" or sEvent == "up") and oComponent.Pressed and tDrag) then
            oComponent.resize(tDrag.Width + nX - tDrag.X, tDrag.Height + nY - tDrag.Y, true);
        end
        if (sEvent == "move" and not oComponent.Pressed) then
            oComponent.Control:SetCursor(_wx.wxCursor(nX >= nWidth - 24 and nY >= nHeight - 24
                and _wx.wxCURSOR_SIZENWSE or _wx.wxCURSOR_ARROW));
        end
        if (sEvent == "up" or sEvent == "cancel") then
            tDrag = nil;
        end
    end;

    -- Handle this widget's supported navigation or resize keys.
    oComponent.key = function(nKey)
        if (nKey == _wx.WXK_ESCAPE and tDrag) then
            oComponent.resize(tDrag.Width, tDrag.Height, true);
            tDrag = nil;
            oComponent.cancel();
            return true;
        end
        local nWidth, nHeight = oComponent.Control:GetClientSizeWH();
        local nStep           = _wx.wxGetKeyState(_wx.WXK_SHIFT) and 10 or 1;
        if (nKey == _wx.WXK_LEFT) then
            nWidth = nWidth - nStep;
        elseif (nKey == _wx.WXK_RIGHT) then
            nWidth = nWidth + nStep;
        elseif (nKey == _wx.WXK_UP) then
            nHeight = nHeight - nStep;
        elseif (nKey == _wx.WXK_DOWN) then
            nHeight = nHeight + nStep;
        else
            return false;
        end
        oComponent.resize(nWidth, nHeight, true);
        return true;
    end;

    -- Draw the widget content inside the shared frame; shared code owns the paint DC.
    oComponent.drawContent = function(oDC, nWidth, nHeight)
        oComponent.Skin.text(oDC, tOptions.Text or "Panel", 12, 9, oComponent.isEnabled());
        local oPen = _wx.wxPen(_wx.wxColour(125, 143, 160), 1, _wx.wxPENSTYLE_SOLID);
        oDC:SetPen(oPen);
        for nOffset = 5, 17, 4 do
            oDC:DrawLine(nWidth - nOffset, nHeight - 4, nWidth - 4, nHeight - nOffset);
        end;
        oPen:delete();
    end;
    return oComponent;
end

return Panel;
