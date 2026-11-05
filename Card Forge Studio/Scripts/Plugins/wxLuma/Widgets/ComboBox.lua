local _wx          = require("wx");
local _Editor      = require("wxLuma.Core.ControlEditor");
local _List        = require("wxLuma.Widgets.List");
local _Containment = require("wxLuma.Core.ControlContainment");
local _finite      = require("wxLuma.Core.ControlNumeric").finite;
local ComboBox     = {};

--[[!
@fqxn wxLuma.UI.ComboBox.create
@desc Composes free text editing with a skinned suggestion list. Typing opens
    and highlights the first case-insensitive prefix match by default, keeping
    the caret in the editor. Enter/click commits; Escape cancels its preview.
    Selection is an index; the value is always text.
@param wxWindow oParent Native owner.
@param table tOptions Skin, Items (strings); optional Value (string), Hint,
    Rows (8), AutoComplete (true), Artwork (Combo Box), Enabled, OnChange.
@ret table oComponent Editor with List, Popup, open/close/isOpen, get/setItems,
    getSelection/setSelection, get/setAutoComplete and standard events.
!]]
function ComboBox.create(oParent, tOptions)
    local nRows = tOptions.Rows or 8;
    assert(_finite(nRows) and nRows >= 1 and nRows % 1 == 0, "Invalid combo Rows.");
    assert(tOptions.AutoComplete == nil or type(tOptions.AutoComplete) == "boolean", "Invalid AutoComplete.");
    local tCopy = {};
    for sKey, vValue in pairs(tOptions) do tCopy[sKey] = vValue; end
    tCopy.Artwork = tCopy.Artwork or "Combo Box";
    local oComponent, tArt, tEvents = _Editor.create(oParent, tCopy, "ComboBox");
    tEvents.extend(nil, {"selectionChanged", "itemsChanged", "opened", "closed", "itemHovered", "itemLeft"});
    oComponent.ActionIcon = "Arrow";
    local tPolicy = _Containment.getPolicy(oComponent);
    local bOpen = false;
    local bTypingOpen = false;
    local bAutoComplete = tOptions.AutoComplete ~= false;
    local oPopup = _wx.wxFrame(oComponent.Control, _wx.wxID_ANY, "", _wx.wxDefaultPosition,
        _wx.wxDefaultSize, _wx.wxFRAME_NO_TASKBAR + _wx.wxFRAME_FLOAT_ON_PARENT + _wx.wxBORDER_NONE);
    local oList = _List.create(oPopup, {Skin = tOptions.Skin, Items = tOptions.Items or {},
        OnActivate = function() oComponent.close(true); end,
        OnCancel = function() oComponent.close(false); end});
    oComponent.List, oComponent.Popup = oList, oPopup;

    --[[!
    @fqxn wxLuma.UI.ComboBox.getItems
    @desc Returns an independent copy of available suggestion strings.
    @ret table tItems Ordered suggestions.
    !]]
    function oComponent.getItems()
        local tItems = {};
        for nIndex, sText in ipairs(oList.Items) do tItems[nIndex] = sText; end
        return tItems;
    end

    --[[!
    @fqxn wxLuma.UI.ComboBox.setItems
    @desc Replaces suggestions without changing free text or notifying a value.
    @param table tItems Dense array of strings.
    @param boolean|nil bNotify Emit itemsChanged.
    @ret table oComponent This object.
    !]]
    function oComponent.setItems(tItems, bNotify)
        -- List validates before mutation. A failed replacement keeps the popup.
        oList.setItems(tItems);
        oComponent.close(false, false);
        if (bNotify) then tEvents.emit("itemsChanged", {Items = oComponent.getItems()}); end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ComboBox.getSelection
    @desc Returns the first exact suggestion match, or zero for free text.
    @ret number nIndex Matching index or zero.
    !]]
    function oComponent.getSelection()
        for nIndex, sText in ipairs(oList.Items) do
            if (sText == oComponent.getValue()) then return nIndex; end
        end
        return 0;
    end

    --[[!
    @fqxn wxLuma.UI.ComboBox.setSelection
    @desc Selects a validated suggestion as text; zero clears the editor.
    @param number nIndex Suggestion index or zero.
    @param boolean|nil bNotify Notify an effective text change and selection.
    @ret table oComponent This object.
    !]]
    function oComponent.setSelection(nIndex, bNotify)
        assert(_finite(nIndex) and nIndex % 1 == 0 and nIndex >= 0 and nIndex <= #oList.Items,
            "Invalid combo selection.");
        local sOld = oComponent.getValue();
        oComponent.setValue(nIndex == 0 and "" or oList.Items[nIndex], bNotify);
        if (bNotify and sOld ~= oComponent.getValue()) then
            tEvents.emit("selectionChanged", {Index = nIndex, Value = oComponent.getValue(), OldValue = sOld});
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ComboBox.isOpen
    @desc Reports visibility of the owned suggestion popup.
    @ret boolean bOpen Popup visibility.
    !]]
    function oComponent.isOpen() return not oComponent.Disposed and bOpen and oPopup:IsShown(); end

    --[[!
    @fqxn wxLuma.UI.ComboBox.close
    @desc Closes the suggestion preview, optionally committing and restoring edit focus.
    @param boolean|nil bCommit Commit the preview.
    @param boolean|nil bFocus Restore editor focus unless false.
    @ret table oComponent This object.
    !]]
    function oComponent.close(bCommit, bFocus)
        if (not bOpen) then return oComponent; end
        bOpen, bTypingOpen = false, false;
        local nIndex = oList.getValue();
        oList.setHover(0);
        oPopup:Show(false);
        if (bCommit and nIndex > 0) then oComponent.setSelection(nIndex, true); end
        if (bFocus ~= false and oComponent.isEnabled()) then oComponent.TextControl:SetFocus(); end
        tEvents.emit("closed", {Committed = bCommit == true});
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ComboBox.fOpen
    @desc Positions the suggestion popup, optionally keeping native typing
        focus. Automatic opening previews a prefix without modifying editor text.
    @param boolean bTyping Keep the caret in the editor instead of focusing the list.
    @param number nPreview Initial highlighted suggestion index.
    @ret boolean bOpened Whether suggestions opened.
    !]]
    local function fOpen(bTyping, nPreview)
        if (not oComponent.isEnabled() or not oComponent.Control:IsShownOnScreen() or bOpen or #oList.Items == 0) then return false; end
        local nWidth = oComponent.Control:GetClientSizeWH();
        local nDisplay = _wx.wxDisplay.GetFromWindow(oComponent.Control);
        local oDisplay = _wx.wxDisplay(nDisplay < 0 and 0 or nDisplay);
        local oArea = oDisplay:GetClientArea();
        local nVisible = math.max(1, math.floor((oArea:GetHeight() - 8) / oList.RowHeight));
        local nHeight = math.min(nRows, #oList.Items, nVisible) * oList.RowHeight + 8;
        nWidth = math.min(nWidth, oArea:GetWidth());
        oPopup:SetClientSize(nWidth, nHeight);
        oList.layout(0, 0, nWidth, nHeight);
        oList.setValue(nPreview);
        oList.setHover(0);
        oDisplay:delete();
        if (not tPolicy.place(oPopup)) then return false; end
        bOpen, bTypingOpen = true, bTyping;
        if (bTyping) then
            oPopup:ShowWithoutActivating();
        else
            oPopup:Show(true); oPopup:Raise(); oList.Control:SetFocus();
        end
        tEvents.emit("opened", {Automatic = bTyping});
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.ComboBox.open
    @desc Opens suggestions for explicit keyboard/mouse navigation. An automatic
        preview already open is promoted to list focus without losing its row.
    @ret boolean bOpened Whether suggestions opened or received navigation focus.
    !]]
    function oComponent.open()
        if (bOpen and oComponent.isEnabled()) then
            bTypingOpen = false;
            oList.Control:SetFocus();
            return true;
        end
        local nIndex = oComponent.getSelection();
        return fOpen(false, nIndex > 0 and nIndex or 1);
    end

    --[[!
    @fqxn wxLuma.UI.ComboBox.getAutoComplete
    @desc Reports whether native typing automatically opens matching suggestions.
    @ret boolean bAutoComplete Current typing policy.
    !]]
    function oComponent.getAutoComplete() return bAutoComplete; end

    --[[!
    @fqxn wxLuma.UI.ComboBox.setAutoComplete
    @desc Changes typing policy. Disabling dismisses an automatic preview while
        preserving text and explicitly opened suggestion navigation.
    @param boolean bEnabled Whether typing should open/select a prefix match.
    @ret table oComponent This object.
    !]]
    function oComponent.setAutoComplete(bEnabled)
        assert(not oComponent.Disposed and type(bEnabled) == "boolean", "Invalid AutoComplete.");
        bAutoComplete = bEnabled;
        if (not bEnabled and bTypingOpen) then oComponent.close(false, false); end
        return oComponent;
    end

    -- Select only the preview row. Replacing typed text here would interrupt
    -- deletion, caret edits, clipboard operations and input-method composition.
    oComponent.onTextEdited = function()
        if (not bAutoComplete or not oComponent.TextControl:HasFocus()) then return; end
        local sPrefix = oComponent.getValue():lower();
        local nMatch = 0;
        if (sPrefix ~= "") then
            for nIndex, sItem in ipairs(oList.Items) do
                if (sItem:lower():sub(1, #sPrefix) == sPrefix) then nMatch = nIndex; break; end
            end
        end
        if (nMatch == 0) then
            if (bTypingOpen) then oComponent.close(false, false); end
        elseif (bOpen) then
            oList.setValue(nMatch);
        else
            fOpen(true, nMatch);
        end
    end;
    oComponent.onTextEnter = function()
        if (bOpen) then oComponent.close(true); end
    end;
    oComponent.onAction = function()
        if (bOpen) then oComponent.close(false); else oComponent.open(); end
    end;
    oComponent.onEditorKey = function(nKey)
        if (bOpen and (nKey == _wx.WXK_DOWN or nKey == _wx.WXK_UP)) then
            oList.handleKey("down", nKey);
            return true;
        end
        if (bOpen and nKey == _wx.WXK_ESCAPE) then oComponent.close(false); return true; end
        if (bOpen and nKey == _wx.WXK_TAB) then oComponent.close(true, false); return false; end
        if (nKey == _wx.WXK_DOWN or nKey == _wx.WXK_F4) then oComponent.open(); return true; end
        return false;
    end;
    oComponent.onEditorLayout = function() oComponent.close(false, false); end;
    oComponent.onEditorEnable = function(bEnabled)
        if (not bEnabled) then oComponent.close(false, false); end
        oList.setEnabled(bEnabled);
    end;
    oComponent.onEditorDestroy = function()
        oComponent.close(false, false); oList.destroy(); oPopup:Destroy();
    end;
    oList.Control:Connect(_wx.wxEVT_KEY_DOWN, function(jEvent)
        if (jEvent:GetKeyCode() == _wx.WXK_TAB) then
            oComponent.close(true); oComponent.TextControl:Navigate(not jEvent:ShiftDown());
        else jEvent:Skip(); end
    end);
    oPopup:Connect(_wx.wxEVT_ACTIVATE, function(jEvent)
        if (jEvent:GetActive()) then
            -- Clicking a nonactivating typing preview promotes it to ordinary
            -- popup navigation, including dismissal on subsequent deactivation.
            bTypingOpen = false;
        elseif (not bTypingOpen) then oComponent.close(false, false); end
        jEvent:Skip();
    end);
    oComponent.TextControl:Connect(_wx.wxEVT_KILL_FOCUS, function(jEvent)
        -- Automatic previews do not activate their top-level host. Focus loss
        -- dismisses them unless focus is moving into the suggestion popup itself.
        local oFocus = jEvent:GetWindow();
        if (bTypingOpen and (not oFocus or (oFocus ~= oPopup and oFocus ~= oList.Control and not oPopup:IsDescendant(oFocus)))) then
            oComponent.close(false, false);
        end
        jEvent:Skip();
    end);
    oPopup:Connect(_wx.wxEVT_SHOW, function(jEvent)
        if (not jEvent:IsShown() and bOpen) then oComponent.close(false, false); end
        jEvent:Skip();
    end);
    oComponent.Control:Connect(_wx.wxEVT_SHOW, function(jEvent)
        if (not jEvent:IsShown()) then oComponent.close(false, false); end
        jEvent:Skip();
    end);
    tPolicy.watch(function()
        if (bOpen and (not oComponent.Control:IsShownOnScreen() or not tPolicy.place(oPopup))) then oComponent.close(false, false); end
    end);
    for _, sEvent in ipairs({"itemHovered", "itemLeft", "leftDown", "rightDown", "leftClick", "rightClick"}) do
        oList.on(sEvent, function(oSource, tEvent)
            tEvents.emit(sEvent, {Index = tEvent.Index, Child = oSource, NativeEvent = tEvent.NativeEvent});
        end);
    end
    oComponent.setEnabled(tOptions.Enabled ~= false);
    return oComponent;
end

return ComboBox;
