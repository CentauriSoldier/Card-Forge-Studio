local _wx             = require("wx");
local _ControlSurface = require("wxLuma.Core.ControlSurface");
local _ControlEvents  = require("wxLuma.Core.ControlEvents");
local _finite         = require("wxLuma.Core.ControlNumeric").finite;
local SplitContainer  = {};

--[[!
@fqxn wxLuma.UI.SplitContainer.create
@desc Owns two clipped child panes separated by a draggable divider. Vertical
    means left/right panes; horizontal means top/bottom. Value is the first
    pane's fraction of the available span, excluding divider and outer frame.
    Minima are reduced proportionally when both cannot fit in a small container.
@param wxWindow oParent The native parent.
@param table tOptions Skin, Value (0.5), Orientation (vertical), MinFirst (80),
    MinSecond (80), DividerSize (8), Step (0.02), Enabled and OnChange.
@ret table oComponent Public proxy with Panes[1/2], First/Second and standard events.
!]]
function SplitContainer.create(oParent, tOptions)
    local sOrientation = tOptions.Orientation or "vertical";
    local nValue       = tOptions.Value or 0.5;
    local nMinFirst    = tOptions.MinFirst or 80;
    local nMinSecond   = tOptions.MinSecond or 80;
    local nDivider     = tOptions.DividerSize or 8;
    local nStep        = tOptions.Step or 0.02;
    assert(sOrientation == "vertical" or sOrientation == "horizontal", "Invalid split orientation.");
    assert(_finite(nValue), "Split Value must be finite.");
    assert(_finite(nMinFirst) and _finite(nMinSecond) and nMinFirst >= 0 and nMinSecond >= 0
        and nMinFirst % 1 == 0 and nMinSecond % 1 == 0, "Invalid pane minima.");
    assert(_finite(nDivider) and nDivider >= 2 and nDivider % 1 == 0, "Invalid DividerSize.");
    assert(_finite(nStep) and nStep > 0 and nStep <= 1, "Invalid split Step.");
    local oComponent = _ControlSurface.create(oParent, tOptions, "SplitContainer");
    local tCursors = {
        Arrow      = _wx.wxCursor(_wx.wxCURSOR_ARROW),
        Vertical   = _wx.wxCursor(_wx.wxCURSOR_SIZEWE),
        Horizontal = _wx.wxCursor(_wx.wxCURSOR_SIZENS)
    };
    local tPanes = {};

    for nIndex = 1, 2 do
        local oPane = _wx.wxPanel(oComponent.Control, _wx.wxID_ANY,
            _wx.wxDefaultPosition, _wx.wxDefaultSize, _wx.wxBORDER_NONE + _wx.wxTAB_TRAVERSAL);
        oPane:SetBackgroundColour(_wx.wxColour(24, 29, 36));
        -- Give each pane its own ordinary cursor so an active divider cursor
        -- cannot be inherited by pane contents. Child controls can override it.
        oPane:SetCursor(tCursors.Arrow);
        tPanes[nIndex] = oPane;
    end

    oComponent.Panes = tPanes;
    oComponent.First, oComponent.Second = tPanes[1], tPanes[2];
    oComponent.Value = math.max(0, math.min(1, nValue));
    local nSpan, nPosition, nLower, nUpper = 0, 0, 0, 0;
    local nWidth, nHeight = 1, 1;
    local tDrag;
    local tEvents;
    local nPointerX, nPointerY = 0, 0;
    local bPointerInside = false;
    local sCursor;

    -- Hit-test the complete visible divider rectangle, excluding the frame at
    -- both ends. Cursor feedback and drag initiation must use the same bounds.
    local function fOnDivider(nX, nY)
        if (sOrientation == "vertical") then
            return nX >= 4 + nPosition and nX < 4 + nPosition + nDivider
                and nY >= 4 and nY < nHeight - 4;
        end

        return nY >= 4 + nPosition and nY < 4 + nPosition + nDivider
            and nX >= 4 and nX < nWidth - 4;
    end

    -- Keep the resize cursor during capture, including outside the container.
    -- Otherwise only an enabled divider under the pointer requests that cursor.
    local function fUpdateCursor()
        if (oComponent.Disposed) then
            return;
        end

        local bResize = oComponent.isEnabled() and (tDrag ~= nil
            or (bPointerInside and fOnDivider(nPointerX, nPointerY)));
        local sNext = bResize and (sOrientation == "vertical" and "Vertical" or "Horizontal") or "Arrow";

        if (sCursor ~= sNext) then
            oComponent.Control:SetCursor(tCursors[sNext]);
            sCursor = sNext;
        end
    end

    -- Child bounds derive from one divider position so no gaps accumulate when
    -- resizing repeatedly. Keep requested ratios stable through pixel rounding.
    local function fLayout(nNewWidth, nNewHeight)
        nWidth, nHeight = nNewWidth, nNewHeight;
        local nInnerWidth  = math.max(1, nWidth - 8);
        local nInnerHeight = math.max(1, nHeight - 8);
        local nLength = sOrientation == "vertical" and nInnerWidth or nInnerHeight;
        nSpan = math.max(0, nLength - nDivider);
        local nMinimumSum = nMinFirst + nMinSecond;
        local nScale = nMinimumSum > nSpan and nMinimumSum > 0 and nSpan / nMinimumSum or 1;
        nLower = math.floor(nMinFirst * nScale);
        nUpper = math.max(nLower, nSpan - math.floor(nMinSecond * nScale));
        nPosition = math.max(nLower, math.min(nUpper, math.floor(nSpan * oComponent.Value + 0.5)));

        -- Only a minimum constraint changes the ratio; ordinary pixel rounding
        -- must not make a steady ratio drift as the window changes size.
        if (nSpan > 0) then
            oComponent.Value = math.max(nLower / nSpan, math.min(nUpper / nSpan, oComponent.Value));
        end

        if (sOrientation == "vertical") then
            tPanes[1]:SetSize(4, 4, math.max(1, nPosition), nInnerHeight);
            tPanes[2]:SetSize(4 + nPosition + nDivider, 4, math.max(1, nSpan - nPosition), nInnerHeight);
        else
            tPanes[1]:SetSize(4, 4, nInnerWidth, math.max(1, nPosition));
            tPanes[2]:SetSize(4, 4 + nPosition + nDivider, nInnerWidth, math.max(1, nSpan - nPosition));
        end

        fUpdateCursor();
    end

    --[[!
    @fqxn wxLuma.UI.SplitContainer.setValue
    @desc Clamps the first-pane ratio to available space/minima and lays out both
        panes. Changed values optionally notify; repeated values do not repaint.
    @param number nRatio The requested finite ratio, clamped to zero through one.
    @param boolean|nil bNotify Whether changes notify; default silent.
    @ret table oComponent This component.
    !]]
    function oComponent.setValue(nRatio, bNotify)
        assert(_finite(nRatio), "Split ratio must be finite.");

        if (oComponent.Disposed) then
            return oComponent;
        end

        nRatio = math.max(0, math.min(1, nRatio));

        if (nSpan > 0) then
            nRatio = math.max(nLower / nSpan, math.min(nUpper / nSpan, nRatio));
        end

        if (nRatio ~= oComponent.Value) then
            local nOldValue = oComponent.Value;
            oComponent.Value = nRatio;
            fLayout(nWidth, nHeight);
            oComponent.refresh();

            if (bNotify) then
                if (oComponent.OnChange) then
                    oComponent.OnChange(oComponent.Value, oComponent);
                end

                tEvents.emit("valueChanged", {Value = oComponent.Value, OldValue = nOldValue});
                tEvents.emit("splitChanged", {Value = oComponent.Value, OldValue = nOldValue, Position = nPosition});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.SplitContainer.getSplitPosition
    @desc Returns the first pane's pixel span, excluding the outer frame.
    @ret number nPosition The divider offset in the available pane span.
    !]]
    function oComponent.getSplitPosition()
        return nPosition;
    end

    --[[!
    @fqxn wxLuma.UI.SplitContainer.getOrientation
    @desc Returns vertical (left/right) or horizontal (top/bottom).
    @ret string sOrientation The divider orientation.
    !]]
    function oComponent.getOrientation()
        return sOrientation;
    end

    --[[!
    @fqxn wxLuma.UI.SplitContainer.setOrientation
    @desc Changes orientation while retaining the ratio where minima allow it.
        Cancels any active drag before changing the divider axis.
    @param string sValue vertical or horizontal.
    @ret table oComponent This component.
    !]]
    function oComponent.setOrientation(sValue)
        assert(sValue == "vertical" or sValue == "horizontal", "Invalid split orientation.");

        if (not oComponent.Disposed and sValue ~= sOrientation) then
            oComponent.cancel();
            sOrientation = sValue;
            fLayout(nWidth, nHeight);
            oComponent.refresh();
        end

        return oComponent;
    end

    -- Base surface input owns capture/focus. Only the exposed divider can start
    -- dragging; child panes remain independent native parents for arbitrary UI.
    oComponent.pointer = function(sEvent, nX, nY)
        nPointerX, nPointerY = nX, nY;
        bPointerInside = sEvent ~= "leave" and nX >= 0 and nY >= 0 and nX < nWidth and nY < nHeight;
        local nAt = (sOrientation == "vertical" and nX or nY) - 4;

        if (sEvent == "down" and fOnDivider(nX, nY)) then
            tDrag = {Offset = nAt - nPosition, Value = oComponent.Value};
            tEvents.emit("dragStarted", {Value = oComponent.Value});
        elseif (tDrag and (sEvent == "move" or sEvent == "up") and nSpan > 0) then
            oComponent.setValue((nAt - tDrag.Offset) / nSpan, true);

            if (sEvent == "up") then
                tEvents.emit("dragEnded", {Value = oComponent.Value, Cancelled = false});
                tDrag = nil;
            end
        elseif (sEvent == "down") then
            -- The outer frame is not a drag target; undo shared capture there.
            oComponent.cancel();
        end

        fUpdateCursor();
    end;
    oComponent.onCancel = function()
        if (tDrag) then
            tDrag = nil;
            tEvents.emit("dragEnded", {Value = oComponent.Value, Cancelled = true});
        end

        fUpdateCursor();
    end;
    oComponent.key = function(nKey)
        if (nKey == _wx.WXK_ESCAPE and tDrag) then
            local nOriginal = tDrag.Value;
            oComponent.setValue(nOriginal, true);
            oComponent.cancel();
        elseif (nKey == _wx.WXK_HOME) then
            oComponent.setValue(0, true);
        elseif (nKey == _wx.WXK_END) then
            oComponent.setValue(1, true);
        elseif ((sOrientation == "vertical" and nKey == _wx.WXK_LEFT)
            or (sOrientation == "horizontal" and nKey == _wx.WXK_UP)) then
            oComponent.setValue(oComponent.Value - nStep, true);
        elseif ((sOrientation == "vertical" and nKey == _wx.WXK_RIGHT)
            or (sOrientation == "horizontal" and nKey == _wx.WXK_DOWN)) then
            oComponent.setValue(oComponent.Value + nStep, true);
        else
            return false;
        end

        return true;
    end;
    oComponent.onLayout = fLayout;
    oComponent.onEnable = function(bEnabled)
        for _, oPane in ipairs(tPanes) do
            oPane:Enable(bEnabled);
        end

        fUpdateCursor();
    end;
    oComponent.onDestroy = function()
        -- Native windows retain their own cursor copies until parent disposal.
        oComponent.Control:SetCursor(tCursors.Arrow);

        for _, oCursor in pairs(tCursors) do
            oCursor:delete();
        end
    end;

    oComponent.drawContent = function(oDC)
        -- The exposed strip remains visible between the two child panes. A
        -- small grip gives the draggable surface an obvious visual target.
        local sGrip = sOrientation == "vertical" and ":" or "=";
        local nX = sOrientation == "vertical" and 4 + nPosition or math.floor(nWidth / 2);
        local nY = sOrientation == "vertical" and math.floor(nHeight / 2) or 4 + nPosition - 5;
        oComponent.Skin.text(oDC, sGrip, nX, nY, oComponent.isEnabled());
    end;
    tEvents = _ControlEvents.attach(oComponent, nil, {"splitChanged", "dragStarted", "dragEnded"});
    oComponent.onEnable(tOptions.Enabled ~= false);
    return oComponent;
end

return SplitContainer;