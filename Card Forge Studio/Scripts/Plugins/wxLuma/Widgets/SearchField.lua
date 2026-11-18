local _Theme = require("wxLuma.Core.ControlTheme");
local _wx     = require("wx");
local _Editor = require("wxLuma.Core.ControlEditor");
local _finite = require("wxLuma.Core.ControlNumeric").finite;
local SearchField = {};

--[[!
@fqxn wxLuma.UI.SearchField.create
@desc Creates a skinned search editor with replaceable magnifier and clear
    images. Search is immediate by default; Debounce delays typing searches.
    Enter searches immediately, Escape clears, and disposal cancels the timer.
@param wxWindow oParent Native owner.
@param table tOptions Skin; optional Value, Hint, Debounce (integer milliseconds,
    0..2147483647, default 0),
    Artwork (Search Field), Enabled, OnChange, OnSearch(text, component).
@ret table oComponent Editor with search/clear and standard value/events APIs.
!]]
function SearchField.create(oParent, tOptions)
    tOptions = _Theme.options(tOptions, oParent);
    local nDelay = tOptions.Debounce;
    if (nDelay == nil) then nDelay = 0; end
    assert(_finite(nDelay) and nDelay >= 0 and nDelay <= 2147483647 and nDelay % 1 == 0, "Invalid search Debounce.");
    local tCopy = {};
    for sKey, vValue in pairs(tOptions) do tCopy[sKey] = vValue; end
    tCopy.Artwork = tCopy.Artwork or "Search Field";
    tCopy.Hint = tCopy.Hint or "Search";
    local oComponent, tArt, tEvents = _Editor.create(oParent, tCopy, "SearchField");
    tEvents.extend(nil, {"searched", "cleared"});
    oComponent.LeadingIcon, oComponent.ActionIcon = "Magnifier", "Clear";
    local oTimer = _wx.wxTimer(oComponent.Control);
    local fSetValue = oComponent.setValue;

    --[[!
    @fqxn wxLuma.UI.SearchField.setValue
    @desc Replaces search text, cancelling a previous debounce request. Silent
        binding changes do not later inherit a search queued for older text.
    @param string sValue New search text.
    @param boolean|nil bNotify Notify and schedule a search for changed text.
    @ret table oComponent This object.
    !]]
    function oComponent.setValue(sValue, bNotify)
        -- Reject invalid calls before stopping a valid pending search or
        -- touching a timer which disposal has already released.
        assert(not oComponent.Disposed and type(sValue) == "string", "Invalid search value or disposed control.");
        oTimer:Stop();
        return fSetValue(sValue, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.SearchField.search
    @desc Cancels pending debounce and searches current text once immediately.
    @ret boolean bSearched Whether enabled input allowed the search.
    !]]
    function oComponent.search()
        if (not oComponent.isEnabled()) then return false; end
        oTimer:Stop();
        local sValue = oComponent.getValue();
        tEvents.emit("searched", {Value = sValue});
        if (tOptions.OnSearch) then tOptions.OnSearch(sValue, oComponent); end
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.SearchField.clear
    @desc Clears nonempty text and notifies immediately, including an empty
        search. Repeated clears are silent; disabled controls do not clear.
    @ret table oComponent This object.
    !]]
    function oComponent.clear()
        if (oComponent.isEnabled() and oComponent.getValue() ~= "") then
            oComponent.setValue("", true);
            if (nDelay > 0) then oComponent.search(); end
            tEvents.emit("cleared");
        end
        return oComponent;
    end
    oComponent.onTextChanged = function()
        -- A value listener can disable input before the internal search hook.
        if (not oComponent.isEnabled()) then return; end
        oTimer:Stop();
        if (nDelay == 0) then oComponent.search(); else oTimer:Start(nDelay, true); end
    end;
    oComponent.onTextEnter = oComponent.search;
    oComponent.onAction = function()
        oComponent.clear();
        if (oComponent.isEnabled()) then oComponent.TextControl:SetFocus(); end
    end;
    oComponent.onEditorKey = function(nKey)
        if (nKey == _wx.WXK_ESCAPE and oComponent.getValue() ~= "") then oComponent.clear(); return true; end
        return false;
    end;
    oComponent.onEditorEnable = function(bEnabled) if (not bEnabled) then oTimer:Stop(); end end;
    oComponent.onEditorDestroy = function() oTimer:Stop(); oTimer:delete(); end;
    oComponent.Control:Connect(oTimer:GetId(), _wx.wxEVT_TIMER, function() oComponent.search(); end);
    _Theme.finish(oComponent, tOptions);
    return oComponent;
end

return SearchField;
