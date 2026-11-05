local _wx           = require("wx");
local _Events       = require("wxLuma.Core.ControlEvents");
local TextField     = {};
local createSurface = require("wxLuma.Core.ControlSurface").create;

--[[!
@fqxn wxLuma.UI.TextField.create
@param table tOptions Skin; optional Value (string), Hint, MaxLength, ReadOnly, Enabled, OnChange, OnEnter.
@desc Native single-line editing, selection and clipboard inside a skinned frame.
      setValue does not notify by default; TextControl exposes native editing API.
!]]
function TextField.create(oParent, tOptions)
    local oComponent = createSurface(oParent, tOptions, "Textfield");
    oComponent.TextControl = _wx.wxTextCtrl(oComponent.Control, _wx.wxID_ANY, tOptions.Value or "",
        _wx.wxDefaultPosition, _wx.wxDefaultSize,
        _wx.wxBORDER_NONE + _wx.wxTE_PROCESS_ENTER);
    local oText = oComponent.TextControl;
    oText:SetFont(oComponent.Skin.Font);
    oText:SetBackgroundColour(_wx.wxColour(24, 29, 36));
    oText:SetForegroundColour(_wx.wxColour(208, 218, 230));
    if (tOptions.Hint) then
        oText:SetHint(tOptions.Hint);
    end
    if (tOptions.MaxLength) then
        oText:SetMaxLength(tOptions.MaxLength);
    end;
    oText:SetEditable(tOptions.ReadOnly ~= true);

    --[[!
    @fqxn wxLuma.UI.TextField.getValue
    @desc Returns native editor text, keeping wx text editing as the source of truth.
    @ret any vValue The current value.
    !]]
    function oComponent.getValue()
        return oText:GetValue();
    end

    --[[!
    @fqxn wxLuma.UI.TextField.setValue
    @desc Changes native text without generating its text-updated event, then optionally notifies when
        text differs. Identical values preserve caret and selection without repainting.
    @param string sValue The editor text.
    @param boolean|nil bNotify Whether to notify after a change; omitted means silent.
    @ret table oComponent This public component object.
    !]]
    function oComponent.setValue(sValue, bNotify)
        assert(type(sValue) == "string", "Textfield value must be a string.");
        local bChanged = oComponent.getValue() ~= sValue;
        if (bChanged) then
            -- Keep caret and selection intact when bindings repeat the same text.
            oText:ChangeValue(sValue);

            -- Disabled fields paint their text on the outer surface because
            -- their native editor is hidden; that surface must be invalidated.
            if (not oComponent.isEnabled()) then
                oComponent.refresh();
            end
        end
        if (bChanged and bNotify and oComponent.OnChange) then
            oComponent.OnChange(sValue, oComponent);
        end;
        return oComponent;
    end

    -- Lay out owned child controls after native size changes.
    oComponent.onLayout = function(nWidth, nHeight)
        oText:SetSize(9, math.max(5, math.floor((nHeight - 23) / 2)), math.max(1, nWidth - 18), 23);
    end;

    -- Propagate enabled state and clear transient interaction.
    oComponent.onEnable = function(bEnabled)
        oText:Enable(bEnabled);
        oText:Show(bEnabled);
    end;

    -- Draw widget content inside the shared frame; shared code owns the paint DC.
    oComponent.drawContent = function(oDC, nWidth, nHeight)
        if (not oComponent.isEnabled()) then
            oDC:SetClippingRegion(9, 5, math.max(1, nWidth - 18), math.max(1, nHeight - 10));
            oComponent.Skin.text(oDC, oComponent.getValue(), 9, (nHeight - 18) / 2, false);
            oDC:DestroyClippingRegion();
        end
    end;
    oText:Connect(_wx.wxEVT_COMMAND_TEXT_UPDATED, function()
        if (oComponent.isEnabled() and oComponent.OnChange) then
            oComponent.OnChange(oComponent.getValue(), oComponent);
        end
    end);
    oText:Connect(_wx.wxEVT_COMMAND_TEXT_ENTER, function()
        if (oComponent.isEnabled() and tOptions.OnEnter) then
            tOptions.OnEnter(oComponent.getValue(), oComponent);
        end
    end);

    -- Apply widget policy after shared pointer-state handling.
    oComponent.pointer = function(sEvent)
        if (sEvent == "down") then
            oComponent.cancel();
            oText:SetFocus();
        end
    end;
    oComponent.setEnabled(tOptions.Enabled ~= false);
    -- Native editor interaction belongs to this field's public subscriptions.
    _Events.attach(oComponent, {oText});
    return oComponent;
end

return TextField;
