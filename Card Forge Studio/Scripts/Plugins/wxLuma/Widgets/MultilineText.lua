local _wx = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events = require("wxLuma.Core.ControlEvents");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local MultilineText = {};

--[[!
@fqxn wxLuma.UI.MultilineText.create
@desc Creates a skinned multiline native editor. Enter inserts a newline; native
    selection, clipboard, undo and scrolling remain available. Bindings are silent
    unless requested. Disabling retains readable text instead of hiding it.
@param wxWindow oParent Native owner.
@param table tOptions Skin, optional Value, ReadOnly, Wrap (true), Hint, Artwork,
    Enabled and OnChange(text, component). Wrap is a creation-time layout policy.
@ret table oComponent Value/read-only APIs, TextControl and shared input events.
!]]
function MultilineText.create(oParent, tOptions)
    assert(tOptions and tOptions.Skin, "MultilineText requires Skin.");
    assert(tOptions.Value == nil or type(tOptions.Value) == "string", "Value must be text.");
    assert(tOptions.ReadOnly == nil or type(tOptions.ReadOnly) == "boolean", "Invalid ReadOnly.");
    assert(tOptions.Wrap == nil or type(tOptions.Wrap) == "boolean", "Invalid Wrap.");
    local oComponent = _Surface.create(oParent, tOptions, "MultilineText");
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "Multiline Text");
    local nStyle = _wx.wxBORDER_NONE + _wx.wxTE_MULTILINE;
    if (tOptions.Wrap == false) then nStyle = nStyle + _wx.wxHSCROLL; end
    local oText = _wx.wxTextCtrl(oComponent.Control, _wx.wxID_ANY, tOptions.Value or "",
        _wx.wxDefaultPosition, _wx.wxDefaultSize, nStyle);
    local bReadOnly = tOptions.ReadOnly == true;
    local sValue = oText:GetValue();
    oComponent.TextControl = oText;
    local tEvents = _Events.attach(oComponent, {oText}, {"readOnlyChanged"});
    oText:SetFont(tOptions.Skin.Font);
    oText:SetBackgroundColour(tArt.color("Editor Normal"));
    oText:SetForegroundColour(tArt.color("Text Normal"));
    oText:SetEditable(not bReadOnly);
    if (tOptions.Hint) then oText:SetHint(tOptions.Hint); end

    --[[!
    @fqxn wxLuma.UI.MultilineText.changed
    @desc Commits effective text before sending changed-only notifications.
    !]]
    local function fChanged(bNotify)
        local sNext = oText:GetValue();
        if (sNext == sValue) then return; end
        local sOld = sValue;
        sValue = sNext;
        if (bNotify) then
            tEvents.emit("valueChanged", {Value = sNext, OldValue = sOld});
            if (oComponent.OnChange) then oComponent.OnChange(sNext, oComponent); end
        end
    end

    --[[!
    @fqxn wxLuma.UI.MultilineText.getValue
    @desc Returns all text, including newlines.
    !]]
    function oComponent.getValue() return oText:GetValue(); end

    --[[!
    @fqxn wxLuma.UI.MultilineText.setValue
    @desc Replaces text; identical text preserves selection. Optional notify defaults false.
    !]]
    function oComponent.setValue(sNext, bNotify)
        assert(not oComponent.Disposed and type(sNext) == "string", "Invalid text value.");
        if (oText:GetValue() ~= sNext) then oText:ChangeValue(sNext); end
        fChanged(bNotify);
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.MultilineText.isReadOnly
    @desc Returns the editing policy.
    !]]
    function oComponent.isReadOnly() return bReadOnly; end

    --[[!
    @fqxn wxLuma.UI.MultilineText.setReadOnly
    @desc Changes editing policy without changing text; optional notify emits readOnlyChanged.
    !]]
    function oComponent.setReadOnly(bNext, bNotify)
        assert(type(bNext) == "boolean", "ReadOnly must be boolean.");
        if (not oComponent.Disposed and bNext ~= bReadOnly) then
            bReadOnly = bNext;
            oText:SetEditable(not bNext);
            if (bNotify) then tEvents.emit("readOnlyChanged", {ReadOnly = bNext}); end
        end
        return oComponent;
    end

    oComponent.onLayout = function(nWidth, nHeight)
        oText:SetSize(9, 8, math.max(1, nWidth - 18), math.max(1, nHeight - 16));
    end;
    oComponent.onEnable = function(bEnabled) oText:Enable(bEnabled); end;
    oComponent.onDestroy = tArt.destroy;
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then return; end
        tArt.part(oDC, "Surface "..oComponent.getState(), 0, 0, nWidth, nHeight);
        if (oText:HasFocus()) then tArt.part(oDC, "Focus", 0, 0, nWidth, nHeight); end
    end;
    oComponent.pointer = function(sEvent)
        if (sEvent == "down") then oComponent.cancel(); oText:SetFocus(); end
    end;
    oText:Connect(_wx.wxEVT_COMMAND_TEXT_UPDATED, function() if (oComponent.isEnabled()) then fChanged(true); end end);
    oText:Connect(_wx.wxEVT_SET_FOCUS, function(jEvent) oComponent.refresh(); jEvent:Skip(); end);
    oText:Connect(_wx.wxEVT_KILL_FOCUS, function(jEvent) oComponent.refresh(); jEvent:Skip(); end);
    oComponent.setEnabled(tOptions.Enabled ~= false);
    return oComponent;
end

return MultilineText;
