local _wx      = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events  = require("wxLuma.Core.ControlEvents");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local ControlEditor = {};

--[[!
@fqxn wxLuma.UI.ControlEditor.create
@desc Composes a native single-line editor with a completely skinned surface,
    optional leading icon and trailing action. Text editing remains native;
    colors, glyphs and focus come from the named artwork family. The caller
    owns the shared Skin. Internal hooks are installed by the composing widget.
@param wxWindow oParent Native owner.
@param table tOptions Skin, optional Value, Hint, ReadOnly, MaxLength, Enabled,
    Artwork, OnChange. Value is a string and updates are silent by default.
@param string sKind Public component kind and default artwork family.
@ret table oComponent Component, followed by private artwork and event helpers.
!]]
function ControlEditor.create(oParent, tOptions, sKind)
    assert(tOptions and tOptions.Skin, "Editor requires Skin.");
    assert(tOptions.Value == nil or type(tOptions.Value) == "string", "Editor Value must be a string.");
    local oComponent = _Surface.create(oParent, tOptions, sKind);
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or sKind);
    local oText = _wx.wxTextCtrl(oComponent.Control, _wx.wxID_ANY, tOptions.Value or "",
        _wx.wxDefaultPosition, _wx.wxDefaultSize, _wx.wxBORDER_NONE + _wx.wxTE_PROCESS_ENTER);
    oComponent.TextControl = oText;
    oComponent.LeadingIcon, oComponent.ActionIcon = nil, nil;
    oText:SetFont(tOptions.Skin.Font);
    oText:SetBackgroundColour(tArt.color("Editor Normal"));
    oText:SetForegroundColour(tArt.color("Text Normal"));
    oText:SetEditable(tOptions.ReadOnly ~= true);
    if (tOptions.Hint) then oText:SetHint(tOptions.Hint); end
    if (tOptions.MaxLength) then oText:SetMaxLength(tOptions.MaxLength); end
    local sValue = oText:GetValue();
    local tEvents = _Events.attach(oComponent, {oText}, {"submitted", "action"});

    --[[!
    @fqxn wxLuma.UI.ControlEditor.fChanged
    @desc Records effective text changes before callbacks, emitting one value
        notification and preserving the old value for application bindings.
    !]]
    local function fChanged(bNotify)
        local sNext = oText:GetValue();
        if (sValue == sNext) then return; end
        local sOld = sValue;
        sValue = sNext;
        oComponent.refresh();
        if (bNotify) then
            tEvents.emit("valueChanged", {Value = sNext, OldValue = sOld});
            if (oComponent.onTextChanged) then oComponent.onTextChanged(sNext); end
            if (oComponent.OnChange) then oComponent.OnChange(sNext, oComponent); end
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlEditor.getValue
    @desc Returns the editor's current text, including unfinished typing.
    @ret string sValue Current text.
    !]]
    function oComponent.getValue()
        return oText:GetValue();
    end

    --[[!
    @fqxn wxLuma.UI.ControlEditor.setValue
    @desc Replaces text without native text events; identical values preserve
        caret/selection. Optional notification uses the same path as user edits.
    @param string sNext New text.
    @param boolean|nil bNotify Notify an effective change.
    @ret table oComponent This object.
    !]]
    function oComponent.setValue(sNext, bNotify)
        assert(not oComponent.Disposed and type(sNext) == "string", "Invalid editor value.");
        if (oText:GetValue() ~= sNext) then oText:ChangeValue(sNext); end
        fChanged(bNotify);
        return oComponent;
    end

    -- Owned editor bounds leave room for artwork instead of covering its glyphs.
    oComponent.onLayout = function(nWidth, nHeight)
        local nLeft = oComponent.LeadingIcon and 32 or 9;
        local nRight = oComponent.ActionIcon and 34 or 9;
        oText:SetSize(nLeft, math.max(4, math.floor((nHeight - 23) / 2)),
            math.max(1, nWidth - nLeft - nRight), math.min(23, math.max(1, nHeight - 8)));
        if (oComponent.onEditorLayout) then oComponent.onEditorLayout(nWidth, nHeight); end
    end;
    oComponent.onEnable = function(bEnabled)
        oText:Enable(bEnabled);
        oText:Show(bEnabled);
        if (oComponent.onEditorEnable) then oComponent.onEditorEnable(bEnabled); end
    end;
    oComponent.onDestroy = function()
        if (oComponent.onEditorDestroy) then oComponent.onEditorDestroy(); end
        tArt.destroy();
    end;
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then return; end
        tArt.part(oDC, "Surface "..oComponent.getState(), 0, 0, nWidth, nHeight);
        if (oComponent.LeadingIcon) then
            tArt.part(oDC, oComponent.LeadingIcon.." "..oComponent.getState(), 8, (nHeight - 20) / 2, 20, 20);
        end
        if (oComponent.ActionIcon) then
            tArt.part(oDC, oComponent.ActionIcon.." "..oComponent.getState(), nWidth - 28, (nHeight - 20) / 2, 20, 20);
        end
        if (not oComponent.isEnabled()) then
            local nLeft = oComponent.LeadingIcon and 32 or 9;
            oDC:SetClippingRegion(nLeft, 4, math.max(1, nWidth - nLeft - 34), math.max(1, nHeight - 8));
            tArt.text(oDC, oText:GetValue(), nLeft, (nHeight - 18) / 2, false);
            oDC:DestroyClippingRegion();
        elseif (oText:HasFocus() or oComponent.Control:HasFocus()) then
            tArt.part(oDC, "Focus", 0, 0, nWidth, nHeight);
        end
    end;
    oComponent.pointer = function(sEvent, nX)
        local nWidth = oComponent.Control:GetClientSizeWH();
        if (sEvent == "up" and oComponent.Pressed and oComponent.Hover
            and oComponent.ActionIcon and nX >= nWidth - 34) then
            tEvents.emit("action");
            if (oComponent.onAction) then oComponent.onAction(); end
        elseif (sEvent == "down" and (not oComponent.ActionIcon or nX < nWidth - 34)) then
            oComponent.cancel();
            oText:SetFocus();
        end
    end;
    oText:Connect(_wx.wxEVT_COMMAND_TEXT_UPDATED, function()
        if (oComponent.isEnabled()) then
            fChanged(true);
            -- Native edits are distinct from notified application setters.
            -- Suggestion widgets can react without reopening after a commit.
            if (oComponent.isEnabled() and oComponent.onTextEdited) then oComponent.onTextEdited(); end
        end
    end);
    oText:Connect(_wx.wxEVT_COMMAND_TEXT_ENTER, function()
        if (oComponent.isEnabled()) then
            tEvents.emit("submitted", {Value = oText:GetValue()});
            if (oComponent.onTextEnter) then oComponent.onTextEnter(); end
        end
    end);
    oText:Connect(_wx.wxEVT_KEY_DOWN, function(jEvent)
        if (not oComponent.onEditorKey or not oComponent.onEditorKey(jEvent:GetKeyCode())) then jEvent:Skip(); end
    end);
    for _, nEvent in ipairs({_wx.wxEVT_SET_FOCUS, _wx.wxEVT_KILL_FOCUS}) do
        oText:Connect(nEvent, function(jEvent) oComponent.refresh(); jEvent:Skip(); end);
    end
    oComponent.setEnabled(tOptions.Enabled ~= false);
    return oComponent, tArt, tEvents;
end

return ControlEditor;
