local _wx = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events = require("wxLuma.Core.ControlEvents");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local _finite = require("wxLuma.Core.ControlNumeric").finite;
local Notification = {};
local _tSeverity = {info = true, success = true, warning = true, error = true};

--[[!
@fqxn wxLuma.UI.Notification.create
@desc Creates a dismissible inline notification. show(message,severity,duration)
    reuses the same native control and restarts one owned timer. Duration zero
    persists until dismissal. Closing/disposal always cancels the timer.
@param wxWindow oParent Native owner.
@param table tOptions Skin, optional Value, Severity (info), Duration (3000 ms),
    Artwork, Enabled. The caller chooses placement with normal layout().
@ret table oComponent show/dismiss/isShown plus value/severity/duration state APIs.
!]]
function Notification.create(oParent, tOptions)
    local sValue, sSeverity, nDuration = tOptions.Value or "", tOptions.Severity or "info", tOptions.Duration or 3000;
    assert(type(sValue) == "string" and _tSeverity[sSeverity], "Invalid notification text/severity.");
    assert(_finite(nDuration) and nDuration >= 0 and nDuration % 1 == 0 and nDuration <= 2147483647, "Invalid Duration.");
    local oComponent = _Surface.create(oParent, tOptions, "Notification");
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "Notification");
    local tEvents = _Events.attach(oComponent, nil, {"dismissed", "severityChanged", "durationChanged"});
    local oTimer = _wx.wxTimer(oComponent.Control);

    --[[!
    @fqxn wxLuma.UI.Notification.getValue
    @desc Returns notification text.
    !]]
    function oComponent.getValue() return sValue; end
    --[[!
    @fqxn wxLuma.UI.Notification.setValue
    @desc Changes text; optional value notification is changed-only.
    !]]
    function oComponent.setValue(sNext, bNotify)
        assert(type(sNext) == "string", "Notification value must be text.");
        if (not oComponent.Disposed and sNext ~= sValue) then
            local sOld = sValue; sValue = sNext; oComponent.refresh();
            if (bNotify) then
                tEvents.emit("valueChanged", {Value = sNext, OldValue = sOld});
                if (oComponent.OnChange) then oComponent.OnChange(sNext, oComponent); end
            end
        end
        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.Notification.getSeverity
    @desc Returns info/success/warning/error.
    !]]
    function oComponent.getSeverity() return sSeverity; end
    --[[!
    @fqxn wxLuma.UI.Notification.setSeverity
    @desc Changes the skin severity without changing text or restarting a timer.
    !]]
    function oComponent.setSeverity(sNext, bNotify)
        assert(_tSeverity[sNext], "Invalid notification severity.");
        if (not oComponent.Disposed and sNext ~= sSeverity) then
            sSeverity = sNext; oComponent.refresh();
            if (bNotify) then tEvents.emit("severityChanged", {Severity = sNext}); end
        end
        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.Notification.getDuration
    @desc Returns the default visible lifetime in milliseconds.
    !]]
    function oComponent.getDuration() return nDuration; end
    --[[!
    @fqxn wxLuma.UI.Notification.setDuration
    @desc Sets a nonnegative duration; it affects the next show call.
    !]]
    function oComponent.setDuration(nNext, bNotify)
        assert(_finite(nNext) and nNext >= 0 and nNext % 1 == 0 and nNext <= 2147483647, "Invalid Duration.");
        if (not oComponent.Disposed and nNext ~= nDuration) then
            nDuration = nNext;
            if (bNotify) then tEvents.emit("durationChanged", {Duration = nNext}); end
        end
        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.Notification.show
    @desc Shows current/replacement text with validated optional severity and timeout; never creates objects.
    !]]
    function oComponent.show(sNext, sNextSeverity, nDelay)
        if (oComponent.Disposed) then return oComponent; end
        assert(sNext == nil or type(sNext) == "string", "Invalid notification text.");
        assert(sNextSeverity == nil or _tSeverity[sNextSeverity], "Invalid notification severity.");
        nDelay = nDelay == nil and nDuration or nDelay;
        assert(_finite(nDelay) and nDelay >= 0 and nDelay % 1 == 0 and nDelay <= 2147483647, "Invalid timeout.");
        if (sNext) then oComponent.setValue(sNext); end
        if (sNextSeverity) then oComponent.setSeverity(sNextSeverity); end
        oTimer:Stop(); oComponent.Control:Show(true); oComponent.refresh();
        if (nDelay > 0) then oTimer:Start(nDelay, true); end
        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.Notification.isShown
    @desc Reports native notification visibility.
    !]]
    function oComponent.isShown() return not oComponent.Disposed and oComponent.Control:IsShown(); end
    --[[!
    @fqxn wxLuma.UI.Notification.dismiss
    @desc Hides a visible notification and emits one dismissed event with its reason.
    !]]
    function oComponent.dismiss(sReason)
        if (oComponent.Disposed) then return oComponent; end
        oTimer:Stop();
        if (oComponent.isShown()) then
            oComponent.cancel(); oComponent.Control:Hide();
            tEvents.emit("dismissed", {Reason = sReason or "application"});
        end
        return oComponent;
    end
    oComponent.pointer = function(sEvent, nX)
        local nWidth = oComponent.Control:GetClientSizeWH();
        if (sEvent == "up" and oComponent.Pressed and oComponent.Hover and nX >= nWidth - 36) then oComponent.dismiss("close"); end
    end;
    oComponent.key = function(nKey)
        if (nKey == _wx.WXK_ESCAPE or nKey == _wx.WXK_RETURN) then oComponent.dismiss("keyboard"); return true; end
        return false;
    end;
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then return; end
        local sState = oComponent.getState();
        tArt.part(oDC, "Surface "..sSeverity.." "..sState, 0, 0, nWidth, nHeight);
        tArt.part(oDC, "Icon "..sSeverity.." "..sState, 10, (nHeight - 24) / 2, 24, 24);
        tArt.part(oDC, "Close "..sState, nWidth - 28, (nHeight - 20) / 2, 20, 20);
        oDC:SetClippingRegion(42, 4, math.max(1, nWidth - 82), math.max(1, nHeight - 8));
        tArt.text(oDC, sValue, 44, math.max(4, (nHeight - 18) / 2), oComponent.isEnabled());
        oDC:DestroyClippingRegion();
    end;
    oComponent.Control:Connect(oTimer:GetId(), _wx.wxEVT_TIMER, function() oComponent.dismiss("timeout"); end);
    oComponent.onDestroy = function() oTimer:Stop(); oTimer:delete(); tArt.destroy(); end;
    return oComponent;
end

return Notification;
