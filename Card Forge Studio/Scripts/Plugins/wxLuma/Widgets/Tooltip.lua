local _Containment   = require("wxLuma.Core.ControlContainment");
local _ControlObject = require("wxLuma.Core.ControlObject");
local _Events        = require("wxLuma.Core.ControlEvents");
local _wx            = require("wx");
local Tooltip        = {};
local drawFrame      = require("wxLuma.Core.ControlDrawing").frame;

--[[!
@fqxn wxLuma.UI.Tooltip.create
@param wxWindow oTarget Hover/focus target; tooltip lifetime follows target.
@param table tOptions Skin, Text; optional Delay (500 milliseconds), Enabled,
    Automatic (true; false leaves show/hide under application control),
    Containment (ancestor window/component), ContainmentOverflow (hide/allow).
@desc Skinned non-activating popup after hover delay or focus; hides on leave,
      press, key, focus loss, disable, target hiding or destruction.
@ret table oComponent Control, show/hide/setText/setEnabled/destroy/isShown.
!]]
function Tooltip.create(oTarget, tOptions)
    assert(tOptions and tOptions.Skin and type(tOptions.Text) == "string", "Tooltip requires Skin and Text.");
    oTarget = _Containment.native(oTarget);
    local oPopup     = _wx.wxPopupWindow(oTarget, _wx.wxBORDER_NONE);
    local oComponent = _ControlObject.create({
        Control  = oPopup,
        Text     = tOptions.Text,
        Disposed = false,
        Enabled  = tOptions.Enabled ~= false
    }, "wxLuma.UI.Tooltip");
    local oTimer   = _wx.wxTimer(oTarget);
    local nTimerID = oTimer:GetId();
    local tContainment;

    --[[!
    @fqxn wxLuma.UI.Tooltip.hide
    @desc Stops the tooltip delay and hides its popup when it is still alive.
    !]]
    function oComponent.hide()
        if (oComponent.Disposed) then
            return;
        end;
        oTimer:Stop();
        oPopup:Show(false);
    end

    --[[!
    @fqxn wxLuma.UI.Tooltip.isShown
    @desc Reports whether the tooltip is alive and its popup is shown.
    @ret boolean bShown Whether the tooltip is shown.
    !]]
    function oComponent.isShown()
        return not oComponent.Disposed and oPopup:IsShown();
    end

    --[[!
    @fqxn wxLuma.UI.Tooltip.show
    @desc Measures the tooltip text and displays its popup only while its target is enabled and visible.
    !]]
    function oComponent.show()
        if (oComponent.Disposed) then
            return false;
        end

        if (not oComponent.Enabled or not oTarget:IsEnabled() or not oTarget:IsShownOnScreen()) then
            oComponent.hide();
            return false;
        end
        oTimer:Stop();
        local oDC = _wx.wxClientDC(oTarget);
        oDC:SetFont(tOptions.Skin.Font);
        local _, nWidth, nHeight = oDC:GetMultiLineTextExtent(oComponent.Text);
        oDC:delete();
        -- Text determines natural size. Containment changes only position and
        -- never wraps, truncates or scales the text to make the popup fit.
        oPopup:SetSize(nWidth + 24, nHeight + 20);

        if (not tContainment.place(oPopup)) then
            oComponent.hide();
            return false;
        end
        oPopup:Show(true);
        oPopup:Refresh(false);
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.Tooltip.setText
    @desc Updates tooltip text and hides the popup so its next showing recalculates size.
    @param string sText The displayed text.
    @ret table oComponent This public component object.
    !]]
    function oComponent.setText(sText)
        assert(type(sText) == "string", "Tooltip text must be a string.");
        oComponent.Text = sText;
        oComponent.hide();
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Tooltip.setEnabled
    @desc Updates tooltip availability and hides the popup when disabled.
    @param boolean bEnabled Whether the component is enabled.
    @ret table oComponent This public component object.
    !]]
    function oComponent.setEnabled(bEnabled)
        oComponent.Enabled = bEnabled;
        if (not bEnabled) then
            oComponent.hide();
        end;
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Tooltip.destroy
    @desc Disposes component-owned state and resources once. Native window ownership remains with
        wxWidgets unless this component owns a popup.
    !]]
    function oComponent.destroy()
        if (oComponent.Disposed) then
            return;
        end;
        oComponent.hide();
        oComponent.Disposed = true;
        oTimer:Stop();
        oTimer:delete();
        oPopup:Destroy();
    end
    oPopup:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
    oPopup:Connect(_wx.wxEVT_PAINT, function()
        local oDC = _wx.wxAutoBufferedPaintDC(oPopup);
        if (oComponent.Disposed) then
            oDC:delete();
            return;
        end
        local nWidth, nHeight = oPopup:GetClientSizeWH();
        drawFrame(oDC, 0, 0, nWidth, nHeight, true, true);
        tOptions.Skin.text(oDC, oComponent.Text, 12, 10, true);
        oDC:delete();
    end);
    oTarget:Connect(nTimerID, _wx.wxEVT_TIMER, function()
        if (not oComponent.Disposed) then
            oComponent.show();
        end
    end);
    oTarget:Connect(_wx.wxEVT_ENTER_WINDOW, function(jEvent)
        if (not oComponent.Disposed and tOptions.Automatic ~= false) then
            oTimer:Start(tOptions.Delay or 500, true);
        end;
        jEvent:Skip();
    end);
    oTarget:Connect(_wx.wxEVT_SET_FOCUS, function(jEvent)
        if (tOptions.Automatic ~= false) then oComponent.show(); end
        jEvent:Skip();
    end);
    for _, nEvent in ipairs({
        _wx.wxEVT_LEAVE_WINDOW,
        _wx.wxEVT_LEFT_DOWN,
        _wx.wxEVT_KILL_FOCUS,
        _wx.wxEVT_KEY_DOWN,
        _wx.wxEVT_SHOW
    }) do
        oTarget:Connect(nEvent, function(jEvent)
            if (not oComponent.Disposed) then
                oComponent.hide();
            end;
            jEvent:Skip();
        end);
    end
    local nTargetID = oTarget:GetId();
    oTarget:Connect(_wx.wxEVT_DESTROY, function(jEvent)
        if (jEvent:GetId() == nTargetID) then
            oComponent.destroy();
        end;
        jEvent:Skip();
    end);
    --[[!
    @fqxn wxLuma.UI.Tooltip.isEnabled
    @desc Reports whether the live tooltip and its target allow interaction.
    @ret boolean bEnabled Whether the tooltip is available.
    !]]
    function oComponent.isEnabled()
        return not oComponent.Disposed and oComponent.Enabled and oTarget:IsEnabled();
    end

    tContainment = _Containment.attach(oComponent, oTarget, tOptions);
    _Events.attach(oComponent, {oTarget});
    tContainment.watch(function()
        if (oComponent.isShown()) then
            if (not oTarget:IsShownOnScreen() or not tContainment.place(oPopup)) then
                oComponent.hide();
            end
        end
    end);
    return oComponent;
end

return Tooltip;
