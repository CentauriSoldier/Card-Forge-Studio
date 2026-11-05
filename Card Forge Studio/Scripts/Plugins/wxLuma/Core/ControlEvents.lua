local _wx = require("wx");
local _tAttached = setmetatable({}, {__mode = "k"});
local ControlEvents = {};

--[[!
@fqxn wxLuma.UI.ControlEvents.attach
@desc Adds on/off notification subscriptions to a component. Native observers
    always continue native processing; notifications do not veto widget behavior.
    Event tables are callback-local snapshots. NativeEvent is valid only during
    that callback. Child widgets retain their own event ownership.
@param table oComponent The public component object.
@param table|nil tTargets Extra native surfaces belonging to this component.
@param table|nil tExtraEvents Additional semantic event names owned by the widget.
@ret table tEvents Private emit/bind helpers for widget implementation.
!]]
function ControlEvents.attach(oComponent, tTargets, tExtraEvents)
    -- Bases install native observers once. Widgets can subsequently add their
    -- semantic names and owned surfaces without replacing existing listeners.
    local tExisting = _tAttached[oComponent];

    if (tExisting) then
        tExisting.extend(tTargets, tExtraEvents);
        return tExisting;
    end

    local tListeners  = {};
    local tBound      = {};
    local tPressResets = {};
    local tEvents     = {};
    local tSupported  = {};

    for _, sName in ipairs({
        "pointerEnter", "pointerLeave", "pointerMove", "mouseWheel", "contextMenu",
        "leftDown", "leftUp", "leftClick", "leftDoubleClick",
        "rightDown", "rightUp", "rightClick", "rightDoubleClick",
        "middleDown", "middleUp", "middleClick", "middleDoubleClick",
        "keyDown", "keyUp", "character", "focusGained", "focusLost", "captureLost",
        "resized", "shown", "hidden", "enabledChanged", "destroyed",
        "valueChanged", "imageLoaded", "scrolled", "contentSizeChanged"
    }) do
        tSupported[sName] = true;
    end

    for _, sName in ipairs(tExtraEvents or {}) do
        assert(type(sName) == "string" and sName ~= "", "Invalid semantic event name.");
        tSupported[sName] = true;
    end

    --[[!
    @fqxn wxLuma.UI.ControlEvents.on
    @desc Registers one listener per function identity. Listeners receive
        (public component, event table); registration order is preserved.
    @param string sEvent A supported camelCase event name.
    @param function fCallback The listener.
    @ret table oComponent This public component.
    !]]
    function oComponent.on(sEvent, fCallback)
        assert(not oComponent.Disposed, "Cannot subscribe to a disposed component.");
        assert(tSupported[sEvent], "Unsupported event: "..tostring(sEvent));
        assert(type(fCallback) == "function", "Event listener must be a function.");
        local tCallbacks = tListeners[sEvent] or {};

        for _, fOther in ipairs(tCallbacks) do
            if (fOther == fCallback) then
                return oComponent;
            end
        end

        tCallbacks[#tCallbacks + 1] = fCallback;
        tListeners[sEvent] = tCallbacks;
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ControlEvents.off
    @desc Removes one listener, or every listener for an event when omitted.
        Removing an absent listener is harmless. Current dispatch uses a snapshot.
    @param string sEvent A supported event name.
    @param function|nil fCallback The listener to remove, or nil for all.
    @ret table oComponent This public component.
    !]]
    function oComponent.off(sEvent, fCallback)
        assert(tSupported[sEvent], "Unsupported event: "..tostring(sEvent));
        assert(fCallback == nil or type(fCallback) == "function", "Invalid listener.");
        local tCallbacks = tListeners[sEvent];

        if (fCallback == nil) then
            tListeners[sEvent] = nil;
        elseif (tCallbacks) then
            for nIndex = #tCallbacks, 1, -1 do
                if (tCallbacks[nIndex] == fCallback) then
                    table.remove(tCallbacks, nIndex);
                end
            end
        end

        return oComponent;
    end

    -- Copy both the listener list and payload so subscription changes during a
    -- callback affect the next emission, not the current listener traversal.
    function tEvents.emit(sEvent, tData)
        local tCallbacks = tListeners[sEvent];

        if (not tCallbacks) then
            return;
        end

        local tCopy = {};
        local tEvent = {Name = sEvent, Source = oComponent};

        for sKey, vValue in pairs(tData or {}) do
            tEvent[sKey] = vValue;
        end

        for nIndex, fCallback in ipairs(tCallbacks) do
            tCopy[nIndex] = fCallback;
        end

        for _, fCallback in ipairs(tCopy) do
            fCallback(oComponent, tEvent);
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlEvents.bind
    @desc Observes one native surface. Origin checks prevent duplicate reports
        when a native event propagates through another bound surface.
    @param wxWindow oTarget The component-owned native surface.
    !]]
    function tEvents.bind(oTarget)
        if (tBound[oTarget]) then
            return;
        end

        tBound[oTarget] = true;
        local tPressed = {};
        tPressResets[#tPressResets + 1] = function()
            tPressed = {};
        end;
        -- wxLua can wrap the same native pointer as different userdata classes.
        -- Native control IDs remain stable across those wrapper identities.

        local function fObserve(nType, sName, fPayload, fAfter)
            if (not nType) then
                return;
            end

            oTarget:Connect(nType, function(jEvent)
                if (not oComponent.Disposed and jEvent:GetId() == oTarget:GetId()) then
                    local tData = fPayload and fPayload(jEvent) or {};
                    tData.NativeEvent = jEvent;
                    tData.Target = oTarget;
                    tEvents.emit(sName, tData);

                    if (fAfter) then
                        fAfter(tData);
                    end
                end

                -- Existing native handlers, focus/capture logic and editing keep
                -- their normal behavior after these observation callbacks.
                jEvent:Skip();
            end);
        end

        local function fMouse(jEvent)
            local oPoint = oComponent.Control:ScreenToClient(
                oTarget:ClientToScreen(_wx.wxPoint(jEvent:GetX(), jEvent:GetY()))
            );
            return {
                X = oPoint:GetX(), Y = oPoint:GetY(),
                Shift = jEvent:ShiftDown(), Control = jEvent:ControlDown(),
                Alt = jEvent:AltDown(), Meta = jEvent:MetaDown(),
            };
        end

        local function fKey(jEvent)
            return {
                KeyCode = jEvent:GetKeyCode(),
                Shift = jEvent:ShiftDown(), Control = jEvent:ControlDown(),
                Alt = jEvent:AltDown(), Meta = jEvent:MetaDown(),
            };
        end

        fObserve(_wx.wxEVT_ENTER_WINDOW, "pointerEnter", fMouse);
        fObserve(_wx.wxEVT_LEAVE_WINDOW, "pointerLeave", fMouse);
        fObserve(_wx.wxEVT_MOTION, "pointerMove", fMouse);
        fObserve(_wx.wxEVT_MOUSEWHEEL, "mouseWheel", function(jEvent)
            local tData = fMouse(jEvent);
            tData.Rotation = jEvent:GetWheelRotation();
            tData.Delta = jEvent:GetWheelDelta();
            return tData;
        end);

        for _, tButton in ipairs({
            {"left", _wx.wxEVT_LEFT_DOWN, _wx.wxEVT_LEFT_UP, _wx.wxEVT_LEFT_DCLICK},
            {"right", _wx.wxEVT_RIGHT_DOWN, _wx.wxEVT_RIGHT_UP, _wx.wxEVT_RIGHT_DCLICK},
            {"middle", _wx.wxEVT_MIDDLE_DOWN, _wx.wxEVT_MIDDLE_UP, _wx.wxEVT_MIDDLE_DCLICK},
        }) do
            local sButton = tButton[1];

            fObserve(tButton[2], sButton.."Down", fMouse, function()
                tPressed[sButton] = true;
            end);
            fObserve(tButton[3], sButton.."Up", fMouse, function(tData)
                -- Owned editors and tooltip targets have their own bounds.
                -- Payload coordinates still remain relative to the component.
                local nWidth, nHeight = oTarget:GetClientSizeWH();
                local nX, nY = tData.NativeEvent:GetX(), tData.NativeEvent:GetY();
                local bClick = tPressed[sButton] and nX >= 0 and nY >= 0 and
                    nX < nWidth and nY < nHeight;
                tPressed[sButton] = nil;

                if (bClick) then
                    tEvents.emit(sButton.."Click", tData);
                end
            end);
            fObserve(tButton[4], sButton.."DoubleClick", fMouse, function()
                tPressed[sButton] = true;
            end);
        end

        fObserve(_wx.wxEVT_KEY_DOWN, "keyDown", fKey);
        fObserve(_wx.wxEVT_KEY_UP, "keyUp", fKey);
        fObserve(_wx.wxEVT_CHAR, "character", fKey);
        fObserve(_wx.wxEVT_SET_FOCUS, "focusGained");
        fObserve(_wx.wxEVT_KILL_FOCUS, "focusLost", nil, function()
            tPressed = {};
        end);
        fObserve(_wx.wxEVT_MOUSE_CAPTURE_LOST, "captureLost", nil, function()
            tPressed = {};
        end);
        fObserve(_wx.wxEVT_CONTEXT_MENU, "contextMenu", function(jEvent)
            local oPoint = jEvent:GetPosition();
            local bKeyboard = oPoint:GetX() == -1 and oPoint:GetY() == -1;
            local tData = {FromKeyboard = bKeyboard};

            if (not bKeyboard) then
                oPoint = oComponent.Control:ScreenToClient(oPoint);
                tData.X, tData.Y = oPoint:GetX(), oPoint:GetY();
            end

            return tData;
        end);
    end

    --[[!
    @fqxn wxLuma.UI.ControlEvents.extend
    @desc Adds widget-owned native surfaces and semantic names to the existing
        subscription set. Repeated attachment never duplicates native observers.
    @param table|nil tAdditionalTargets Additional native surfaces.
    @param table|nil tAdditionalEvents Additional semantic event names.
    !]]
    function tEvents.extend(tAdditionalTargets, tAdditionalEvents)
        for _, sName in ipairs(tAdditionalEvents or {}) do
            assert(type(sName) == "string" and sName ~= "", "Invalid semantic event name.");
            tSupported[sName] = true;
        end

        for _, oTarget in ipairs(tAdditionalTargets or {}) do
            tEvents.bind(oTarget);
        end
    end

    tEvents.bind(oComponent.Control);

    for _, oTarget in ipairs(tTargets or {}) do
        tEvents.bind(oTarget);
    end

    oComponent.Control:Connect(_wx.wxEVT_SIZE, function(jEvent)
        if (not oComponent.Disposed and jEvent:GetId() == oComponent.Control:GetId()) then
            local nWidth, nHeight = oComponent.Control:GetClientSizeWH();
            tEvents.emit("resized", {Width = nWidth, Height = nHeight});
        end

        jEvent:Skip();
    end);
    oComponent.Control:Connect(_wx.wxEVT_SHOW, function(jEvent)
        if (not oComponent.Disposed and jEvent:GetId() == oComponent.Control:GetId()) then
            tEvents.emit(jEvent:IsShown() and "shown" or "hidden");
        end

        jEvent:Skip();
    end);

    local fSetEnabled = oComponent.setEnabled;
    local fDestroy    = oComponent.destroy;

    oComponent.setEnabled = function(bEnabled)
        local bBefore = oComponent.isEnabled();
        fSetEnabled(bEnabled);

        -- Disabling cancels an incomplete click even if the surface is later
        -- enabled before a delayed button-up event reaches it.
        if (not bEnabled) then
            for _, fReset in ipairs(tPressResets) do
                fReset();
            end
        end

        local bAfter = oComponent.isEnabled();

        if (bBefore ~= bAfter) then
            tEvents.emit("enabledChanged", {Enabled = bAfter});
        end

        return oComponent;
    end;
    oComponent.destroy = function()
        if (oComponent.Disposed) then
            return;
        end

        fDestroy();
        tEvents.emit("destroyed");
        tListeners = {};
    end;

    _tAttached[oComponent] = tEvents;
    return tEvents;
end

return ControlEvents;
