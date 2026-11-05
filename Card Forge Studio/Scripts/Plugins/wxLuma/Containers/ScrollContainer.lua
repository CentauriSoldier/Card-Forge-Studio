local _wx             = require("wx");
local _ControlSurface = require("wxLuma.Core.ControlSurface");
local _ControlEvents  = require("wxLuma.Core.ControlEvents");
local _Scrollbar      = require("wxLuma.Widgets.Scrollbar");
local _finite         = require("wxLuma.Core.ControlNumeric").finite;
local ScrollContainer = {};

--[[!
@fqxn wxLuma.UI.ScrollContainer.create
@desc Creates a clipped native viewport with automatic horizontal/vertical bars.
    Parent arbitrary child widgets to Content. This container moves real children;
    it does not virtualize them. Child widgets retain their own input handling.
@param wxWindow oParent The native parent.
@param table tOptions Skin, ContentWidth/ContentHeight (0), Step (32), Enabled,
    OnChange. Offsets and content sizes are expressed in integer client pixels.
@ret table oComponent A public proxy with Content, Viewport and standard events.
!]]
function ScrollContainer.create(oParent, tOptions)
    local nContentWidth  = tOptions.ContentWidth or 0;
    local nContentHeight = tOptions.ContentHeight or 0;
    local nStep          = tOptions.Step or 32;
    assert(_finite(nContentWidth) and nContentWidth >= 0 and nContentWidth % 1 == 0,
        "Invalid ContentWidth.");
    assert(_finite(nContentHeight) and nContentHeight >= 0 and nContentHeight % 1 == 0,
        "Invalid ContentHeight.");
    assert(_finite(nStep) and nStep > 0 and nStep % 1 == 0, "Step must be a positive integer.");

    local oComponent = _ControlSurface.create(oParent, tOptions, "ScrollContainer");
    local oViewport  = _wx.wxPanel(oComponent.Control, _wx.wxID_ANY,
        _wx.wxDefaultPosition, _wx.wxDefaultSize, _wx.wxBORDER_NONE);
    local oContent   = _wx.wxPanel(oViewport, _wx.wxID_ANY,
        _wx.wxDefaultPosition, _wx.wxDefaultSize, _wx.wxBORDER_NONE);
    oComponent.Viewport, oComponent.Content = oViewport, oContent;
    oViewport:SetBackgroundColour(_wx.wxColour(24, 29, 36));
    oContent:SetBackgroundColour(_wx.wxColour(24, 29, 36));
    local nX, nY = 0, 0;
    local nViewWidth, nViewHeight = 1, 1;
    local nMaxX, nMaxY = 0, 0;
    local tEvents;
    local oHorizontal, oVertical;

    --[[!
    @fqxn wxLuma.UI.ScrollContainer.getValue
    @desc Returns an independent offset snapshot; mutating it cannot scroll content.
    @ret table tPosition X and Y offsets.
    !]]
    function oComponent.getValue()
        return {X = nX, Y = nY};
    end

    --[[!
    @fqxn wxLuma.UI.ScrollContainer.getScrollPosition
    @desc Returns the horizontal and vertical offsets in client pixels.
    @ret number nX Horizontal offset, followed by vertical offset.
    !]]
    function oComponent.getScrollPosition()
        return nX, nY;
    end

    --[[!
    @fqxn wxLuma.UI.ScrollContainer.getContentSize
    @desc Returns the requested content extent, independent of viewport size.
    @ret number nWidth Content width, followed by height.
    !]]
    function oComponent.getContentSize()
        return nContentWidth, nContentHeight;
    end

    --[[!
    @fqxn wxLuma.UI.ScrollContainer.getViewportSize
    @desc Returns the visible extent after accounting for both scrollbars.
    @ret number nWidth Viewport width, followed by height.
    !]]
    function oComponent.getViewportSize()
        return nViewWidth, nViewHeight;
    end

    --[[!
    @fqxn wxLuma.UI.ScrollContainer.scrollTo
    @desc Rounds and clamps offsets, moves content and synchronizes the bars.
    @param number nHorizontal Requested horizontal offset.
    @param number nVertical Requested vertical offset.
    @param boolean|nil bNotify Whether changed offsets notify; default silent.
    @ret table oComponent This component.
    !]]
    function oComponent.scrollTo(nHorizontal, nVertical, bNotify)
        assert(_finite(nHorizontal) and _finite(nVertical), "Scroll offsets must be finite.");

        if (oComponent.Disposed) then
            return oComponent;
        end

        local nNewX = math.max(0, math.min(nMaxX, math.floor(nHorizontal + 0.5)));
        local nNewY = math.max(0, math.min(nMaxY, math.floor(nVertical + 0.5)));

        if (nNewX ~= nX or nNewY ~= nY) then
            local tOldValue = oComponent.getValue();
            nX, nY = nNewX, nNewY;
            oContent:Move(-nX, -nY);
            oHorizontal.setValue(nX);
            oVertical.setValue(nY);

            if (bNotify) then
                if (oComponent.OnChange) then
                    oComponent.OnChange(oComponent.getValue(), oComponent);
                end

                tEvents.emit("valueChanged", {Value = oComponent.getValue(), OldValue = tOldValue});
                tEvents.emit("scrolled", {Value = oComponent.getValue(), OldValue = tOldValue});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ScrollContainer.setValue
    @desc Sets offsets through the same clamping/notification policy as scrollTo.
    @param table tValue A table containing finite X and Y numbers.
    @param boolean|nil bNotify Whether changed offsets notify.
    @ret table oComponent This component.
    !]]
    function oComponent.setValue(tValue, bNotify)
        assert(type(tValue) == "table", "Scroll value must contain X and Y.");
        return oComponent.scrollTo(tValue.X, tValue.Y, bNotify);
    end

    oHorizontal = _Scrollbar.create(oComponent.Control, {
        Skin = tOptions.Skin, Min = 0, Max = 0, Page = 1, Value = 0,
        Step = nStep, Vertical = false,
        OnChange = function(nValue)
            oComponent.scrollTo(nValue, nY, true);
        end
    });
    oVertical = _Scrollbar.create(oComponent.Control, {
        Skin = tOptions.Skin, Min = 0, Max = 0, Page = 1, Value = 0,
        Step = nStep,
        OnChange = function(nValue)
            oComponent.scrollTo(nX, nValue, true);
        end
    });
    oComponent.HorizontalScrollbar = oHorizontal;
    oComponent.VerticalScrollbar   = oVertical;

    -- Resolve both bar requirements together: adding either bar can make the
    -- other necessary. Starting without bars avoids retaining obsolete bars.
    local function fLayout(nWidth, nHeight)
        local nInnerWidth  = math.max(1, nWidth - 8);
        local nInnerHeight = math.max(1, nHeight - 8);
        local bHorizontal, bVertical = false, false;

        for nPass = 1, 3 do
            nViewWidth  = math.max(1, nInnerWidth - (bVertical and 22 or 0));
            nViewHeight = math.max(1, nInnerHeight - (bHorizontal and 22 or 0));
            bHorizontal = nContentWidth > nViewWidth;
            bVertical   = nContentHeight > nViewHeight;
        end

        nViewWidth  = math.max(1, nInnerWidth - (bVertical and 22 or 0));
        nViewHeight = math.max(1, nInnerHeight - (bHorizontal and 22 or 0));
        nMaxX = math.max(0, nContentWidth - nViewWidth);
        nMaxY = math.max(0, nContentHeight - nViewHeight);
        oViewport:SetSize(4, 4, nViewWidth, nViewHeight);
        oHorizontal.Control:Show(bHorizontal);
        oVertical.Control:Show(bVertical);
        oHorizontal.layout(4, 6 + nViewHeight, nViewWidth, 20);
        oVertical.layout(6 + nViewWidth, 4, 20, nViewHeight);
        oHorizontal.setRange(0, nMaxX, nViewWidth);
        oVertical.setRange(0, nMaxY, nViewHeight);
        oComponent.scrollTo(nX, nY);
        oContent:SetSize(-nX, -nY, math.max(nContentWidth, nViewWidth),
            math.max(nContentHeight, nViewHeight));
    end

    --[[!
    @fqxn wxLuma.UI.ScrollContainer.setContentSize
    @desc Changes the content extent, recomputes bars and clamps existing offsets.
        Optional notification describes both the extent and any offset clamp.
    @param number nWidth Nonnegative integer content width.
    @param number nHeight Nonnegative integer content height.
    @param boolean|nil bNotify Whether to notify changed extent/offsets.
    @ret table oComponent This component.
    !]]
    function oComponent.setContentSize(nWidth, nHeight, bNotify)
        assert(_finite(nWidth) and _finite(nHeight) and nWidth >= 0 and nHeight >= 0
            and nWidth % 1 == 0 and nHeight % 1 == 0, "Invalid content size.");

        if (not oComponent.Disposed and (nWidth ~= nContentWidth or nHeight ~= nContentHeight)) then
            local tOldValue = oComponent.getValue();
            local nOldWidth, nOldHeight = nContentWidth, nContentHeight;
            nContentWidth, nContentHeight = nWidth, nHeight;
            fLayout(oComponent.Control:GetClientSizeWH());

            if (bNotify) then
                tEvents.emit("contentSizeChanged", {
                    Width = nWidth, Height = nHeight, OldWidth = nOldWidth, OldHeight = nOldHeight
                });

                if (tOldValue.X ~= nX or tOldValue.Y ~= nY) then
                    if (oComponent.OnChange) then
                        oComponent.OnChange(oComponent.getValue(), oComponent);
                    end

                    tEvents.emit("valueChanged", {Value = oComponent.getValue(), OldValue = tOldValue});
                    tEvents.emit("scrolled", {Value = oComponent.getValue(), OldValue = tOldValue});
                end
            end
        end

        return oComponent;
    end

    -- Wheel events on owned empty surfaces scroll vertically, or horizontally
    -- with Shift. Interactive descendants can consume wheel events themselves.
    oComponent.wheel = function(nSteps)
        oComponent.scrollTo(nX, nY - nSteps * nStep * 3, true);
    end;
    oComponent.key = function(nKey)
        if (nKey == _wx.WXK_LEFT) then
            oComponent.scrollTo(nX - nStep, nY, true);
        elseif (nKey == _wx.WXK_RIGHT) then
            oComponent.scrollTo(nX + nStep, nY, true);
        elseif (nKey == _wx.WXK_UP) then
            oComponent.scrollTo(nX, nY - nStep, true);
        elseif (nKey == _wx.WXK_DOWN) then
            oComponent.scrollTo(nX, nY + nStep, true);
        elseif (nKey == _wx.WXK_PAGEUP) then
            oComponent.scrollTo(nX, nY - nViewHeight, true);
        elseif (nKey == _wx.WXK_PAGEDOWN) then
            oComponent.scrollTo(nX, nY + nViewHeight, true);
        elseif (nKey == _wx.WXK_HOME) then
            oComponent.scrollTo(0, 0, true);
        elseif (nKey == _wx.WXK_END) then
            oComponent.scrollTo(nMaxX, nMaxY, true);
        else
            return false;
        end

        return true;
    end;

    for _, oTarget in ipairs({oViewport, oContent}) do
        oTarget:Connect(_wx.wxEVT_MOUSEWHEEL, function(jEvent)
            local nDelta = jEvent:GetWheelDelta();

            if (not oComponent.isEnabled() or nDelta == 0) then
                jEvent:Skip();
                return;
            end

            local nMovement = jEvent:GetWheelRotation() / nDelta * nStep * 3;

            if (jEvent:ShiftDown()) then
                oComponent.scrollTo(nX - nMovement, nY, true);
            else
                oComponent.scrollTo(nX, nY - nMovement, true);
            end
        end);
        oTarget:Connect(_wx.wxEVT_LEFT_DOWN, function()
            -- Keep navigation on the scroll surface. Skipping this event lets
            -- wxPanel's default behavior redirect focus into a child widget.
            if (oComponent.isEnabled()) then
                oComponent.Control:SetFocus();
            end
        end);
        oTarget:Connect(_wx.wxEVT_KEY_DOWN, function(jEvent)
            -- Owned panels can receive focus from native traversal. Route their
            -- keys too; interactive descendants keep their own key handlers.
            if (not oComponent.handleKey("down", jEvent:GetKeyCode())) then
                jEvent:Skip();
            end
        end);
    end

    oComponent.onLayout = fLayout;
    oComponent.onEnable = function(bEnabled)
        oViewport:Enable(bEnabled);
        oHorizontal.setEnabled(bEnabled);
        oVertical.setEnabled(bEnabled);
    end;
    oComponent.onDestroy = function()
        oHorizontal.destroy();
        oVertical.destroy();
    end;
    tEvents = _ControlEvents.attach(oComponent, {oViewport, oContent});
    oComponent.onEnable(tOptions.Enabled ~= false);
    fLayout(oComponent.Control:GetClientSizeWH());
    return oComponent;
end

return ScrollContainer;