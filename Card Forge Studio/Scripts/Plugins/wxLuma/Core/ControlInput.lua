local _Containment = require("wxLuma.Core.ControlContainment");
local _ControlObject = require("wxLuma.Core.ControlObject");
local _Events = require("wxLuma.Core.ControlEvents");

-- Shared native input/lifecycle for the indicator, button and numeric widgets.
-- Widget policy and artwork live in their individual modules.
local _wx          = require("wx");
local ControlInput = {};

--[[!
@fqxn wxLuma.UI.ControlInput.create
@desc Creates an independent public proxy and native component, binds shared events and installs
    widget-specific policy.
@param wxWindow oParent The native parent.
@param table tOptions The factory options, including optional Containment
    (ancestor native window/visual component) and ContainmentOverflow (hide/allow).
    Nil settings inherit ancestor policy, then top-level/default policy.
@param string sKind The component kind.
@param function fConfigure The nested configurator for the public object and private input helpers.
@ret table oComponent The public component object.
!]]
function ControlInput.create(oParent, tOptions, sKind, fConfigure)
    assert(tOptions and tOptions.Skin, "Control options require a shared Skin.");
    local oSkin    = tOptions.Skin;
    local oControl = _wx.wxControl(oParent, _wx.wxID_ANY, _wx.wxDefaultPosition,
        _wx.wxDefaultSize, _wx.wxBORDER_NONE + _wx.wxWANTS_CHARS);
    oControl:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
    oControl:SetBackgroundColour(_wx.wxColour(24, 29, 36));
    oControl:SetName(tOptions.Text or sKind);
    local oComponent = _ControlObject.create({
        Control  = oControl,
        Kind     = sKind,
        Text     = tOptions.Text or "",
        Hover    = false,
        Pressed  = false,
        Selected = tOptions.Selected == true,
        Value    = tOptions.Value,
        OnChange = tOptions.OnChange,
        Disposed = false,
        Vertical = tOptions.Vertical == true
    }, "wxLuma.UI." .. sKind);
    local bLayoutApplied = false;
    local tInput         = {
        drawPart          = tOptions.Background and oSkin.draw or oSkin.drawOpaque,
        DynamicBackground = tOptions.Background ~= nil
    };

    --[[!
    @fqxn wxLuma.UI.ControlInput.enabled
    @desc Reports whether the input component is alive and enabled.
    @ret boolean bEnabled Whether input is available.
    !]]
    function tInput.enabled()
        return not oComponent.Disposed and oControl:IsEnabled();
    end

    --[[!
    @fqxn wxLuma.UI.ControlInput.refresh
    @desc Schedules an erase-free repaint unless the component is disposed.
    !]]
    function tInput.refresh()
        if (not oComponent.Disposed) then
            oControl:Refresh(false);
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlInput.isEnabled
    @desc Reports whether this live input accepts interaction. Shared event
        observers use the same availability policy as the input handlers.
    @ret boolean bEnabled Whether input is available.
    !]]
    oComponent.isEnabled = tInput.enabled;

    --[[!
    @fqxn wxLuma.UI.ControlInput.refresh
    @desc Requests an erase-free repaint through the input's existing helper.
    !]]
    oComponent.refresh = tInput.refresh;

    --[[!
    @fqxn wxLuma.UI.ControlInput.release
    @desc Clears keyboard and mouse press tracking and releases held native capture.
    !]]
    function tInput.release()
        oComponent.Pressed, tInput.Keyboard, tInput.PressedPart = false, false, nil;
        if (oControl:HasCapture()) then
            oControl:ReleaseMouse();
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlInput.inside
    @desc Tests client coordinates against the native control bounds.
    @param number nX The horizontal client coordinate.
    @param number nY The vertical client coordinate.
    @ret boolean bInside Whether the point is inside.
    !]]
    function tInput.inside(nX, nY)
        local nWidth, nHeight = oControl:GetClientSizeWH();
        return nX >= 0 and nY >= 0 and nX < nWidth and nY < nHeight;
    end

    --[[!
    @fqxn wxLuma.UI.ControlInput.part
    @desc Returns the default hit-test part, overridden by widgets with separate interactive areas.
    @ret number nPart The hit-test part.
    !]]
    function tInput.part()
        return 0;
    end

    --[[!
    @fqxn wxLuma.UI.ControlInput.notify
    @desc Invokes OnChange with the current value and the public component identity.
    !]]
    function tInput.notify()
        if (oComponent.OnChange) then
            oComponent.OnChange(oComponent.getValue(), oComponent);
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlInput.getValue
    @desc Returns the current value without changing component state or notifying.
    @ret any vValue The current value.
    !]]
    function oComponent.getValue()
        return oComponent.Value;
    end

    --[[!
    @fqxn wxLuma.UI.ControlInput.setValue
    @desc Validates and updates the component value, refreshes its appearance and optionally notifies
        when the value changes.
    @param any vValue The requested value.
    @param boolean|nil bNotify Whether to notify after a change; omitted means silent.
    @ret table oComponent This public component object.
    !]]
    function oComponent.setValue(vValue, bNotify)
        local bChanged = oComponent.getValue() ~= vValue;
        oComponent.Value = vValue;
        -- Stable bindings do not invalidate unchanged artwork. Custom backgrounds
        -- retain their explicit redraw behavior because their content is external.
        if (bChanged or tInput.DynamicBackground) then
            tInput.refresh();
        end

        if (bChanged and bNotify) then
            tInput.notify();
        end;
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ControlInput.setEnabled
    @desc Cancels active input, changes native enabled state and refreshes the component.
    @param boolean bFlag Whether input is enabled.
    @ret table oComponent This public component object.
    !]]
    function oComponent.setEnabled(bFlag)
        assert(type(bFlag) == "boolean", "Enabled flag must be boolean.");
        local sOldState = oComponent.getState();
        local bChanged  = oControl:IsEnabled() ~= bFlag;
        tInput.release();
        oComponent.Hover, tInput.HoverPart = false, nil;

        if (bChanged) then
            oControl:Enable(bFlag);
        end

        if (bChanged or sOldState ~= oComponent.getState() or tInput.DynamicBackground) then
            tInput.refresh();
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ControlInput.getState
    @desc Resolves the current Normal, Hover, Pressed or Disabled artwork state.
    @ret string sState The artwork state.
    !]]
    function oComponent.getState()
        if (not tInput.enabled()) then
            return "Disabled";
        end
        return oComponent.Pressed and (oComponent.Hover or tInput.Keyboard or tInput.drag) and "Pressed"
            or oComponent.Hover and "Hover" or "Normal";
    end

    --[[!
    @fqxn wxLuma.UI.ControlInput.layout
    @desc Applies changed bounds and the child-layout hook. Repeated identical layouts do no work.
    @param number nX The horizontal client coordinate.
    @param number nY The vertical client coordinate.
    @param number nWidth The width in pixels.
    @param number nHeight The height in pixels.
    @ret table oComponent This public component object.
    !]]
    function oComponent.layout(nX, nY, nWidth, nHeight)
        local nOldX, nOldY          = oControl:GetPositionXY();
        local nOldWidth, nOldHeight = oControl:GetSizeWH();
        local bChanged = nX ~= nOldX or nY ~= nOldY or nWidth ~= nOldWidth or nHeight ~= nOldHeight;

        -- Apply child geometry once even when the initial native bounds match.
        if (not bChanged and bLayoutApplied) then
            return oComponent;
        end

        if (bChanged) then
            oControl:SetSize(nX, nY, nWidth, nHeight);
        end

        if (tInput.layout) then
            tInput.layout(nWidth, nHeight);
        end

        bLayoutApplied = true;
        tInput.refresh();
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ControlInput.commitText
    @desc Returns false for noneditable controls; numeric editors override this method to validate and
        commit text.
    @ret boolean bCommitted Whether text was accepted.
    !]]
    function oComponent.commitText()
        return false;
    end

    -- Native bindings use these same adapters; there is no separate test path.

    --[[!
    @fqxn wxLuma.UI.ControlInput.handlePointer
    @desc Processes hover, focus and capture before invoking the widget pointer policy.
    @param string sEvent The adapter event name.
    @param number nX The horizontal client coordinate.
    @param number nY The vertical client coordinate.
    !]]
    function oComponent.handlePointer(sEvent, nX, nY)
        if (not tInput.enabled()) then
            oComponent.Hover, oComponent.Pressed = false, false;
            return;
        end
        local sOldState       = oComponent.getState();
        local nOldHoverPart   = tInput.HoverPart;
        local nOldPressedPart = tInput.PressedPart;
        local bInside         = tInput.inside(nX, nY);
        if (sEvent == "down" and bInside) then
            oControl:SetFocus();
            oComponent.Hover, oComponent.Pressed = true, true;
            tInput.PressedPart, tInput.HoverPart = tInput.part(nX, nY), tInput.part(nX, nY);
            if (not oControl:HasCapture()) then
                oControl:CaptureMouse();
            end
            if (tInput.drag) then
                tInput.drag(nX, nY);
            end
        elseif (sEvent == "move") then
            oComponent.Hover, tInput.HoverPart = bInside, tInput.part(nX, nY);
            if (oComponent.Pressed and tInput.drag and not tInput.Keyboard) then
                tInput.drag(nX, nY);
            end
        elseif (sEvent == "leave") then
            oComponent.Hover, tInput.HoverPart = false, nil;
        elseif (sEvent == "up") then
            local bActivate = oComponent.Pressed and not tInput.Keyboard and bInside
                and tInput.PressedPart == tInput.part(nX, nY);
            local nPart     = tInput.PressedPart;
            if (oComponent.Pressed and not tInput.Keyboard and tInput.drag) then
                tInput.drag(nX, nY);
            end
            tInput.release();
            oComponent.Hover, tInput.HoverPart = bInside, tInput.part(nX, nY);
            if (bActivate and not tInput.drag) then
                tInput.activate(nPart);
            end
        elseif (sEvent == "cancel") then
            tInput.release();
            oComponent.Hover, tInput.HoverPart = false, nil;
        end
        -- Drag setters invalidate value changes themselves. Pointer movement
        -- needs an additional repaint only when the drawn state or part changes.
        if (sOldState ~= oComponent.getState() or nOldHoverPart ~= tInput.HoverPart or
            nOldPressedPart ~= tInput.PressedPart or tInput.DynamicBackground) then
            tInput.refresh();
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlInput.handleKey
    @desc Routes supported key input to widget policy and reports whether it handled the key.
    @param string sEvent The adapter event name.
    @param number nKey The wx key code.
    @ret boolean bHandled Whether the key was handled.
    !]]
    function oComponent.handleKey(sEvent, nKey)
        if (not tInput.enabled()) then
            return false;
        end
        local bToggle = nKey == _wx.WXK_SPACE or (tInput.Enter and nKey == _wx.WXK_RETURN);
        if (bToggle and tInput.Toggle) then
            local sOldState = oComponent.getState();

            if (sEvent == "down" and not tInput.Keyboard) then
                tInput.Keyboard, oComponent.Pressed = true, true;
            elseif (sEvent == "up" and tInput.Keyboard) then
                tInput.release();
                tInput.activate(0);
            end
            -- Ignore visual no-ops from keyboard auto-repeat; activation still
            -- follows the existing press/release and notification path.
            if (sOldState ~= oComponent.getState() or tInput.DynamicBackground) then
                tInput.refresh();
            end

            return true;
        end
        if (sEvent ~= "down") then
            return false;
        end
        return tInput.key and tInput.key(nKey) or false;
    end

    --[[!
    @fqxn wxLuma.UI.ControlInput.draw
    @desc Draws current component artwork and content into the supplied DC without taking ownership of
        that DC.
    @param wxDC oDC The destination drawing context.
    @param number nWidth The width in pixels.
    @param number nHeight The height in pixels.
    !]]
    function oComponent.draw(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then
            return;
        end
        local sState = oComponent.getState();
        local oBrush = _wx.wxBrush(_wx.wxColour(24, 29, 36));
        if (tOptions.Background) then
            tOptions.Background(oDC, oComponent);
        elseif (tInput.background) then
            tInput.background(oDC, nWidth, nHeight, sState);
        else
            oDC:SetBackground(oBrush);
            oDC:Clear();
        end
        tInput.draw(oDC, nWidth, nHeight, sState, oBrush);
        if (tInput.enabled() and oControl:HasFocus()) then
            if (tInput.focus) then
                tInput.focus(oDC, nWidth, nHeight);
            else
                local oPen = _wx.wxPen(_wx.wxColour(105, 125, 145), 1, _wx.wxPENSTYLE_DOT);
                oDC:SetPen(oPen);
                oDC:SetBrush(_wx.wxTRANSPARENT_BRUSH);
                oDC:DrawRectangle(0, 0, nWidth, nHeight);
                oPen:delete();
            end
        end
        oBrush:delete();
    end

    --[[!
    @fqxn wxLuma.UI.ControlInput.destroy
    @desc Disposes component-owned state and resources once. Native window ownership remains with
        wxWidgets unless this component owns a popup.
    !]]
    function oComponent.destroy()
        if (oComponent.Disposed) then
            return;
        end
        tInput.release();
        oComponent.Disposed = true;
        if (tInput.destroy) then
            tInput.destroy();
        end
    end
    fConfigure(oComponent, tInput, tOptions);
    oControl:Connect(_wx.wxEVT_PAINT, function()
        if (oComponent.Disposed) then
            return;
        end
        local nWidth, nHeight = oControl:GetClientSizeWH();
        local oDC             = _wx.wxAutoBufferedPaintDC(oControl);
        oComponent.draw(oDC, nWidth, nHeight);
        oDC:delete();
    end);
    for _, tBinding in ipairs({
        {
            _wx.wxEVT_LEFT_DOWN,
            "down"
        },
        {
            _wx.wxEVT_LEFT_DCLICK,
            "down"
        },
        {
            _wx.wxEVT_LEFT_UP,
            "up"
        },
        {
            _wx.wxEVT_MOTION,
            "move"
        },
        {
            _wx.wxEVT_ENTER_WINDOW,
            "move"
        },
        {
            _wx.wxEVT_LEAVE_WINDOW,
            "leave"
        }
    }) do
        local sEvent = tBinding[2];
        oControl:Connect(tBinding[1], function(jEvent)
            oComponent.handlePointer(sEvent, jEvent:GetX(), jEvent:GetY());
        end);
    end
    oControl:Connect(_wx.wxEVT_MOUSE_CAPTURE_LOST, function()
        oComponent.Pressed, oComponent.Hover, tInput.Keyboard = false, false, false;
        tInput.refresh();
    end);
    oControl:Connect(_wx.wxEVT_KILL_FOCUS, function(jEvent)
        tInput.release();
        oComponent.Hover = false;
        tInput.refresh();
        jEvent:Skip();
    end);
    oControl:Connect(_wx.wxEVT_SET_FOCUS, function(jEvent)
        tInput.refresh();
        jEvent:Skip();
    end);
    oControl:Connect(_wx.wxEVT_KEY_DOWN, function(jEvent)
        if (not oComponent.handleKey("down", jEvent:GetKeyCode())) then
            jEvent:Skip();
        end
    end);
    oControl:Connect(_wx.wxEVT_KEY_UP, function(jEvent)
        if (not oComponent.handleKey("up", jEvent:GetKeyCode())) then
            jEvent:Skip();
        end
    end);
    oControl:Connect(_wx.wxEVT_SIZE, function(jEvent)
        tInput.refresh();
        jEvent:Skip();
    end);
    local nID = oControl:GetId();
    oControl:Connect(_wx.wxEVT_DESTROY, function(jEvent)
        if (jEvent:GetId() == nID) then
            oComponent.destroy();
        end;
        jEvent:Skip();
    end);
    oComponent.setEnabled(tOptions.Enabled ~= false);
    _Containment.attach(oComponent, oControl, tOptions);
    _Events.attach(oComponent, oComponent.TextControl and {oComponent.TextControl} or nil);
    return oComponent;
end
return ControlInput;
