local _Selection = require("wxLuma.Core.ControlSelection");
local _Containment = require("wxLuma.Core.ControlContainment");
local _ControlObject = require("wxLuma.Core.ControlObject");
local _Events = require("wxLuma.Core.ControlEvents");
local _wx            = require("wx");
local drawFrame      = require("wxLuma.Core.ControlDrawing").frame;
local ControlSurface = {};

--[[!
@fqxn wxLuma.UI.ControlSurface.create
@desc Creates an independent public proxy and native component, binds shared events and installs
    widget-specific policy.
@param wxWindow oParent The native parent.
@param table tOptions The factory options, including optional Containment
    (ancestor native window/visual component) and ContainmentOverflow (hide/allow).
    Nil settings inherit ancestor policy, then top-level/default policy.
@param string sKind The component kind.
@ret table oComponent The public component object.
!]]
function ControlSurface.create(oParent, tOptions, sKind)
    assert(tOptions and tOptions.Skin, "Control options require a shared Skin.");
    local oControl = _wx.wxControl(oParent, _wx.wxID_ANY, _wx.wxDefaultPosition, _wx.wxDefaultSize,
        _wx.wxBORDER_NONE + _wx.wxWANTS_CHARS + _wx.wxTAB_TRAVERSAL);
    oControl:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
    oControl:SetBackgroundColour(_wx.wxColour(24, 29, 36));
    oControl:SetName(tOptions.Text or sKind);
    local bLayoutApplied = false;
    local oComponent     = _ControlObject.create({
        Control  = oControl,
        Kind     = sKind,
        Skin     = tOptions.Skin,
        Disposed = false,
        Hover    = false,
        Pressed  = false,
        OnChange = tOptions.OnChange
    }, "wxLuma.UI." .. sKind);

    --[[!
    @fqxn wxLuma.UI.ControlSurface.getValue
    @desc Returns the current value without changing component state or notifying.
    @ret any vValue The current value.
    !]]
    function oComponent.getValue()
        return oComponent.Value;
    end

    --[[!
    @fqxn wxLuma.UI.ControlSurface.refresh
    @desc Schedules an erase-free repaint unless the component is disposed.
    !]]
    function oComponent.refresh()
        if (not oComponent.Disposed) then
            oControl:Refresh(false);
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlSurface.isEnabled
    @desc Reports whether the component is alive and its native control accepts input.
    @ret boolean bEnabled Whether input is available.
    !]]
    function oComponent.isEnabled()
        return not oComponent.Disposed and oControl:IsEnabled();
    end

    --[[!
    @fqxn wxLuma.UI.ControlSurface.getState
    @desc Resolves the current Normal, Hover, Pressed or Disabled artwork state.
    @ret string sState The artwork state.
    !]]
    function oComponent.getState()
        return not oComponent.isEnabled() and "Disabled" or oComponent.Pressed and "Pressed"
            or oComponent.Hover and "Hover" or "Normal";
    end

    --[[!
    @fqxn wxLuma.UI.ControlSurface.cancel
    @desc Clears the press state, releases mouse capture and invokes the optional cancellation hook.
    !]]
    function oComponent.cancel()
        oComponent.Pressed = false;
        if (oControl:HasCapture()) then
            oControl:ReleaseMouse();
        end
        if (oComponent.onCancel) then
            oComponent.onCancel();
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlSurface.setEnabled
    @desc Cancels active input, changes native enabled state and refreshes the component.
    @param boolean bEnabled Whether the component is enabled.
    @ret table oComponent This public component object.
    !]]
    function oComponent.setEnabled(bEnabled)
        assert(type(bEnabled) == "boolean", "Enabled flag must be boolean.");
        local sOldState = oComponent.getState();
        local bChanged  = oControl:IsEnabled() ~= bEnabled;
        oComponent.cancel();
        oComponent.Hover = false;

        if (bChanged) then
            oControl:Enable(bEnabled);
        end
        if (oComponent.onEnable) then
            oComponent.onEnable(bEnabled);
        end;
        if (bChanged or sOldState ~= oComponent.getState()) then
            oComponent.refresh();
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ControlSurface.layout
    @desc Applies changed bounds and child layout once; repeated identical layouts preserve open popups.
    @param number nX The horizontal client coordinate.
    @param number nY The vertical client coordinate.
    @param table|nil tModifiers Optional Shift and Command flags; omitted means neither.
    @param number nWidth The width in pixels.
    @param number nHeight The height in pixels.
    @ret table oComponent This public component object.
    !]]
    function oComponent.layout(nX, nY, nWidth, nHeight)
        local nOldX, nOldY          = oControl:GetPositionXY();
        local nOldWidth, nOldHeight = oControl:GetSizeWH();
        local bChanged = nX ~= nOldX or nY ~= nOldY or nWidth ~= nOldWidth or nHeight ~= nOldHeight;

        -- A stable layout must not repeatedly resize children or dismiss a
        -- dropdown popup. Its first application still initializes child bounds.
        if (not bChanged and bLayoutApplied) then
            return oComponent;
        end

        if (bChanged) then
            oControl:SetSize(nX, nY, nWidth, nHeight);
        end
        if (oComponent.onLayout) then
            oComponent.onLayout(nWidth, nHeight);
        end;

        bLayoutApplied = true;
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ControlSurface.destroy
    @desc Disposes component-owned state and resources once. Native window ownership remains with
        wxWidgets unless this component owns a popup.
    !]]
    function oComponent.destroy()
        if (oComponent.Disposed) then
            return;
        end;
        oComponent.cancel();
        oComponent.Disposed = true;
        if (oComponent.onDestroy) then
            oComponent.onDestroy();
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlSurface.handlePointer
    @desc Processes hover, focus and capture before invoking the widget pointer policy.
    @param string sEvent The adapter event name.
    @param number nX The horizontal client coordinate.
    @param number nY The vertical client coordinate.
    @param table|nil tModifiers Optional Shift and Command flags; omitted means neither.
    !]]
    function oComponent.handlePointer(sEvent, nX, nY, tModifiers)
        if (not oComponent.isEnabled()) then
            return;
        end
        local bOldHover, bOldPressed = oComponent.Hover, oComponent.Pressed;
        local nWidth, nHeight        = oControl:GetClientSizeWH();
        oComponent.Hover = sEvent ~= "leave" and nX >= 0 and nY >= 0 and nX < nWidth and nY < nHeight;
        if (sEvent == "down" and oComponent.Hover) then
            oControl:SetFocus();
            oComponent.Pressed = true;
            if (not oControl:HasCapture()) then
                oControl:CaptureMouse();
            end
        end
        if (oComponent.pointer) then
            oComponent.pointer(sEvent, nX, nY, tModifiers);
        end
        if (sEvent == "up" or sEvent == "cancel") then
            oComponent.cancel();
        end;
        -- Widgets such as List manage their own dirty rows. Other surfaces
        -- repaint for visual transitions, rather than every mouse-motion event.
        if ((not oComponent.PointerRefresh or oComponent.PointerStateRefresh) and
            (bOldHover ~= oComponent.Hover or bOldPressed ~= oComponent.Pressed)) then
            oComponent.refresh();
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlSurface.handleKey
    @desc Routes supported key input to widget policy and reports whether it handled the key.
    @param string sEvent The adapter event name.
    @param number nKey The wx key code.
    @param table|nil tModifiers Optional Shift and Command flags; omitted means neither.
    @ret boolean bHandled Whether the key was handled.
    !]]
    function oComponent.handleKey(sEvent, nKey, tModifiers)
        return oComponent.isEnabled() and sEvent == "down" and oComponent.key and oComponent.key(nKey, tModifiers) or false;
    end
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
            oComponent.handlePointer(sEvent, jEvent:GetX(), jEvent:GetY(), _Selection.modifiers(jEvent));
        end);
    end
    oControl:Connect(_wx.wxEVT_MOUSE_CAPTURE_LOST, function()
        oComponent.cancel();
        oComponent.refresh();
    end);
    oControl:Connect(_wx.wxEVT_KEY_DOWN, function(jEvent)
        if (not oComponent.handleKey("down", jEvent:GetKeyCode(), _Selection.modifiers(jEvent))) then
            jEvent:Skip();
        end
    end);
    oControl:Connect(_wx.wxEVT_MOUSEWHEEL, function(jEvent)
        if (oComponent.isEnabled() and oComponent.wheel) then
            oComponent.wheel(jEvent:GetWheelRotation() / jEvent:GetWheelDelta());
        else
            jEvent:Skip();
        end
    end);
    oControl:Connect(_wx.wxEVT_KILL_FOCUS, function(jEvent)
        oComponent.cancel();
        oComponent.refresh();
        jEvent:Skip();
    end);
    oControl:Connect(_wx.wxEVT_SET_FOCUS, function(jEvent)
        oComponent.refresh();
        jEvent:Skip();
    end);
    oControl:Connect(_wx.wxEVT_SIZE, function(jEvent)
        if (oComponent.onLayout) then
            oComponent.onLayout(oControl:GetClientSizeWH());
        end;
        oComponent.refresh();
        jEvent:Skip();
    end);

    --[[!
    @fqxn wxLuma.UI.ControlSurface.draw
    @desc Draws current component artwork and content into the supplied DC without taking ownership of
        that DC.
    @param wxDC oDC The destination drawing context.
    @param number nWidth The width in pixels.
    @param number nHeight The height in pixels.
    !]]
    function oComponent.draw(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then
            return;
        end;
        drawFrame(oDC, 0, 0, nWidth, nHeight, oComponent.isEnabled(), oControl:HasFocus());
        if (oComponent.drawContent) then
            oComponent.drawContent(oDC, nWidth, nHeight);
        end
    end
    oControl:Connect(_wx.wxEVT_PAINT, function()

        -- Buffered DCs do not limit our Lua row loop to the native dirty area.
        -- Read it before creating the paint DC, which validates that region.
        if (oComponent.TrackPaintBounds and not oComponent.Disposed) then
            local oBox = oControl:GetUpdateRegion():GetBox();
            oComponent.PaintTop, oComponent.PaintBottom = oBox:GetY(), oBox:GetY() + oBox:GetHeight();
        end
        local oDC = _wx.wxAutoBufferedPaintDC(oControl);
        oComponent.draw(oDC, oControl:GetClientSizeWH());
        oComponent.PaintTop, oComponent.PaintBottom = nil, nil;
        oDC:delete();
    end);
    local nID = oControl:GetId();
    oControl:Connect(_wx.wxEVT_DESTROY, function(jEvent)
        if (jEvent:GetId() == nID) then
            oComponent.destroy();
        end;
        jEvent:Skip();
    end);
    oControl:Enable(tOptions.Enabled ~= false);
    _Containment.attach(oComponent, oControl, tOptions);
    _Events.attach(oComponent);
    return oComponent;
end

return ControlSurface;
