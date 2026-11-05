local _Containment = require("wxLuma.Core.ControlContainment");
local _wx           = require("wx");
local Dropdown      = {};
local createSurface = require("wxLuma.Core.ControlSurface").create;
local finite        = require("wxLuma.Core.ControlNumeric").finite;
local _List         = require("wxLuma.Widgets.List");

--[[!
@fqxn wxLuma.UI.Dropdown.create
@param table tOptions Skin, Items (strings); optional Value (index/0), Rows (8),
    Enabled, OnChange, Containment and ContainmentOverflow (hide/allow).
@desc Enter/Space/Down opens; popup arrows preview, Enter/click commits; Escape
      cancels. Owned borderless hosting dismisses on native deactivation.
@ret table oComponent Standard methods plus open/close/isOpen/setItems/getText, List and Popup.
!]]
function Dropdown.create(oParent, tOptions)
    local oComponent = createSurface(oParent, tOptions, "Dropdown");
    local tContainment = _Containment.getPolicy(oComponent);
    oComponent.Popup = _wx.wxFrame(oComponent.Control, _wx.wxID_ANY, "", _wx.wxDefaultPosition,
        _wx.wxDefaultSize,
        _wx.wxFRAME_NO_TASKBAR + _wx.wxFRAME_FLOAT_ON_PARENT + _wx.wxBORDER_NONE);
    oComponent.Value = 0;
    oComponent.Open  = false;
    local nRows = tOptions.Rows or 8;
    assert(finite(nRows) and nRows >= 1 and nRows % 1 == 0, "Dropdown Rows must be positive integer.");

    --[[!
    @fqxn wxLuma.UI.Dropdown.isOpen
    @desc Reports whether the live dropdown popup is marked open and shown.
    @ret boolean bOpen Whether the popup is open.
    !]]
    function oComponent.isOpen()
        return not oComponent.Disposed and oComponent.Open and oComponent.Popup:IsShown();
    end

    --[[!
    @fqxn wxLuma.UI.Dropdown.close
    @desc Hides the popup, optionally commits its preview and optionally restores dropdown focus.
    @param boolean bCommit Whether to commit the preview selection.
    @param boolean bFocus Whether to restore focus; only false suppresses it.
    !]]
    function oComponent.close(bCommit, bFocus)
        if (not oComponent.Open) then
            return;
        end;
        oComponent.Open = false;
        oComponent.List.setHover(0);
        local nValue = oComponent.List.getValue();
        oComponent.Popup:Show(false);
        if (bCommit) then
            oComponent.setValue(nValue, true);
        end
        if (bFocus ~= false and oComponent.isEnabled()) then
            oComponent.Control:SetFocus();
        end;
        oComponent.refresh();
    end
    oComponent.List = _List.create(oComponent.Popup, {
        Skin       = oComponent.Skin,
        Items      = tOptions.Items,
        Value      = tOptions.Value or 0,
        OnActivate = function()
            oComponent.close(true);
        end,
        OnCancel = function()
            oComponent.close(false);
        end
    });

    --[[!
    @fqxn wxLuma.UI.Dropdown.setValue
    @desc Validates and updates the component value, refreshes its appearance and optionally notifies
        when the value changes.
    @param number nValue The requested value or index.
    @param boolean|nil bNotify Whether to notify after a change; omitted means silent.
    @ret table oComponent This public component object.
    !]]
    function oComponent.setValue(nValue, bNotify)
        oComponent.List.setValue(nValue);
        oComponent.List.CommittedValue = nValue;
        local bChanged = oComponent.Value ~= nValue;
        oComponent.Value = nValue;
        if (bChanged) then
            oComponent.refresh();
            if (bNotify and oComponent.OnChange) then
                oComponent.OnChange(nValue, oComponent);
            end
        end;
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Dropdown.setItems
    @desc Closes without committing, replaces list items and adopts its clamped selection without notifying.
    @param table tItems An array of strings.
    @ret table oComponent This public component object.
    !]]
    function oComponent.setItems(tItems)
        oComponent.close(false, false);
        oComponent.List.setItems(tItems);
        oComponent.Value = oComponent.List.getValue();
        oComponent.refresh();
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Dropdown.getText
    @desc Returns selected item text, or an empty string when unselected.
    @ret string sText The selected text.
    !]]
    function oComponent.getText()
        return oComponent.List.Items[oComponent.Value] or "";
    end

    --[[!
    @fqxn wxLuma.UI.Dropdown.open
    @desc Positions the nonempty enabled dropdown popup within its containment boundary and focuses its
        preview list.
    @ret boolean bOpened Whether the popup opened.
    !]]
    function oComponent.open()
        if (not oComponent.isEnabled() or not oComponent.Control:IsShownOnScreen() or oComponent.isOpen()
            or #oComponent.List.Items == 0) then
            return false;
        end
        oComponent.cancel();
        local nWidth = oComponent.Control:GetClientSizeWH();
        local nDisplay        = _wx.wxDisplay.GetFromWindow(oComponent.Control);
        local oDisplay        = _wx.wxDisplay(nDisplay < 0 and 0 or nDisplay);
        local oArea           = oDisplay:GetClientArea();
        nWidth = math.min(nWidth, oArea:GetWidth());
        local nVisible = math.max(1, math.floor((oArea:GetHeight() - 8) / oComponent.List.RowHeight));
        local nHeight  = math.min(nRows, #oComponent.List.Items, nVisible) * oComponent.List.RowHeight + 8;
        oComponent.Popup:SetSize(nWidth, nHeight);
        oComponent.List.layout(0, 0, nWidth, nHeight);
        oComponent.List.setValue(oComponent.Value > 0 and oComponent.Value or 1);
        oDisplay:delete();

        -- Preserve the popup's normal row-based size. Containment only adjusts
        -- the overflowing position axes, or refuses an oversized popup by policy.
        if (not tContainment.place(oComponent.Popup)) then
            return false;
        end
        oComponent.List.setHover(0);
        oComponent.List.CommittedValue = oComponent.Value;
        oComponent.Open                = true;
        oComponent.Popup:Show(true);
        oComponent.Popup:Raise();
        oComponent.List.Control:SetFocus();
        oComponent.refresh();
        return true;
    end
    oComponent.Popup:Connect(_wx.wxEVT_ACTIVATE, function(jEvent)
        if (not jEvent:GetActive()) then
            oComponent.close(false, false);
        end;
        jEvent:Skip();
    end);
    oComponent.Popup:Connect(_wx.wxEVT_SHOW, function(jEvent)
        if (not jEvent:IsShown()) then
            oComponent.Open = false;
            oComponent.refresh();
        end;
        jEvent:Skip();
    end);
    oComponent.List.Control:Connect(_wx.wxEVT_KEY_DOWN, function(jEvent)
        if (jEvent:GetKeyCode() == _wx.WXK_TAB) then
            oComponent.close(true);
            oComponent.Control:Navigate(not jEvent:ShiftDown());
        else
            jEvent:Skip();
        end
    end);
    oComponent.Control:Connect(_wx.wxEVT_SHOW, function(jEvent)
        if (not jEvent:IsShown()) then
            oComponent.close(false, false);
        end;
        jEvent:Skip();
    end);
    oParent:Connect(_wx.wxEVT_SHOW, function(jEvent)
        if (not jEvent:IsShown()) then
            oComponent.close(false, false);
        end;
        jEvent:Skip();
    end);

    -- Propagate enabled state and clear transient interaction.
    oComponent.onEnable = function(bEnabled)
        if (not bEnabled) then
            oComponent.close(false, false);
        end;
        oComponent.List.setEnabled(bEnabled);
    end;

    -- Lay out owned child controls after native size changes.
    oComponent.onLayout = function()
        oComponent.close(false, false);
    end;

    -- Dispose resources owned by this widget.
    oComponent.onDestroy = function()
        oComponent.close(false, false);
        oComponent.List.destroy();
        oComponent.Popup:Destroy();
    end;

    -- Apply widget policy after shared pointer-state handling.
    oComponent.pointer = function(sEvent)
        if (sEvent == "up" and oComponent.Pressed and oComponent.Hover) then
            if (oComponent.isOpen()) then
                oComponent.close(false);
            else
                oComponent.open();
            end
        end
    end;

    -- Handle the widget navigation or resize keys.
    oComponent.key = function(nKey)
        if (nKey == _wx.WXK_ESCAPE and oComponent.isOpen()) then
            oComponent.close(false);
            return true;
        end
        if (nKey == _wx.WXK_SPACE or nKey == _wx.WXK_RETURN or nKey == _wx.WXK_DOWN or nKey == _wx.WXK_UP
            or nKey == _wx.WXK_F4) then
            oComponent.open();
            return true;
        end
        return false;
    end;

    -- Draw widget content inside the shared frame; shared code owns the paint DC.
    oComponent.drawContent = function(oDC, nWidth, nHeight)
        oDC:SetClippingRegion(8, 4, math.max(1, nWidth - 38), math.max(1, nHeight - 8));
        oComponent.Skin.text(oDC, oComponent.getText(), 10, (nHeight - 18) / 2, oComponent.isEnabled());
        oDC:DestroyClippingRegion();
        oComponent.Skin.drawOpaque(oDC, "Spinner Down " .. oComponent.getState(), nWidth - 27,
            (nHeight - 18) / 2);
    end;
    oComponent.setValue(tOptions.Value or 0);
    oComponent.setEnabled(tOptions.Enabled ~= false);
    tContainment.watch(function()
        if (oComponent.isOpen()) then
            if (not oComponent.Control:IsShownOnScreen() or not tContainment.place(oComponent.Popup)) then
                oComponent.close(false, false);
            end
        end
    end);
    return oComponent;
end

return Dropdown;
