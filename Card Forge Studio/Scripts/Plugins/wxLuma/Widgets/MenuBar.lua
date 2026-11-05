local _wx      = require("wx");
local _Toolbar = require("wxLuma.Widgets.Toolbar");
local _Menu    = require("wxLuma.Widgets.ContextMenu");
local _Events  = require("wxLuma.Core.ControlEvents");
local MenuBar  = {};

--[[!
@fqxn wxLuma.UI.MenuBar.create
@desc Creates a skinned horizontal menu strip backed by the existing nested
    popup engine. Arrow keys navigate headings; Enter/Down opens. F10 focuses
    the strip through the native parent's character hook. Narrow strips retain
    headings in Toolbar's overflow menu. Commands emit a stable menu/item ID.
@param wxWindow oParent Native owner and F10 hook target.
@param table tOptions Skin, Menus ({Id,Text,Width,Image,Enabled,Items}); optional
    Artwork (Menu Bar), MenuArtwork (Menu), Enabled, OnSelect(selection, component).
@ret table oComponent Toolbar/event API plus setMenus/getMenus/getMenu,
    open/close/isOpen and command/menuOpened/menuClosed subscriptions.
!]]
function MenuBar.create(oParent, tOptions)
    local tCopy = {};
    for sKey, vValue in pairs(tOptions) do tCopy[sKey] = vValue; end
    tCopy.Artwork, tCopy.Items = tCopy.Artwork or "Menu Bar", {};
    local oComponent;
    tCopy.OnActivate = function(sId) oComponent.open(sId); end;
    oComponent = _Toolbar.create(oParent, tCopy, "MenuBar");
    local tEvents = _Events.attach(oComponent, nil, {"command", "menuOpened", "menuClosed"});
    local tMenus, tSpecs = {}, {};
    local sOpen;
    local fSetHeadings = oComponent.setItems;

    --[[!
    @fqxn wxLuma.UI.MenuBar.close
    @desc Dismisses all owned command popups without activating a command.
    @ret table oComponent This object.
    !]]
    function oComponent.close()
        for _, oMenu in pairs(tMenus) do oMenu.close(); end
        sOpen = nil;
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.MenuBar.isOpen
    @desc Reports whether a heading's command popup is currently visible.
    @ret boolean bOpen Popup visibility.
    !]]
    function oComponent.isOpen()
        return sOpen ~= nil and tMenus[sOpen] ~= nil and tMenus[sOpen].isOpen();
    end

    --[[!
    @fqxn wxLuma.UI.MenuBar.getMenu
    @desc Returns an owned ContextMenu for normal item mutation/activation APIs.
    @param string sId Top-level menu ID.
    @ret table oMenu Popup component.
    !]]
    function oComponent.getMenu(sId) return assert(tMenus[sId], "Unknown menu: "..tostring(sId)); end

    --[[!
    @fqxn wxLuma.UI.MenuBar.open
    @desc Opens an enabled heading below its displayed rectangle, dismissing the
        previous menu. Overflow headings anchor below the visible More button.
    @param string sId Top-level menu ID.
    @ret boolean bOpened Whether the popup opened.
    !]]
    function oComponent.open(sId)
        local oMenu = oComponent.getMenu(sId);
        if (not oComponent.isEnabled()) then return false; end
        local tSpec;
        for _, tOther in ipairs(tSpecs) do if (tOther.Id == sId) then tSpec = tOther; end end
        if (not tSpec or tSpec.Enabled == false) then return false; end
        oComponent.close();
        local nWidth, nHeight = oComponent.Control:GetClientSizeWH();
        local nX = math.max(0, nWidth - 40);
        for _, tRect in ipairs(oComponent.getLayout().Entries) do
            if (tRect.Id == sId) then nX = tRect.X; break; end
        end
        local oPoint = oComponent.Control:ClientToScreen(_wx.wxPoint(nX, nHeight));
        local bOpened = oMenu.showAt(oPoint:GetX(), oPoint:GetY());
        if (bOpened) then sOpen = sId; tEvents.emit("menuOpened", {Id = sId}); end
        return bOpened;
    end

    --[[!
    @fqxn wxLuma.UI.MenuBar.getMenus
    @desc Returns current headings and independently copied nested descriptors.
    @ret table tMenus Menu descriptors in display order.
    !]]
    function oComponent.getMenus()
        local tCopy = {};
        for nIndex, tSpec in ipairs(tSpecs) do
            local tEntry = {};
            for sKey, vValue in pairs(tSpec) do tEntry[sKey] = vValue; end
            tEntry.Items = tMenus[tSpec.Id].getItems();
            tCopy[nIndex] = tEntry;
        end
        return tCopy;
    end

    --[[!
    @fqxn wxLuma.UI.MenuBar.setMenus
    @desc Validates replacement popups before changing headings; failed data
        leaves existing menus available. Previous owned popups are disposed.
    @param table tSource Dense heading descriptors with unique IDs and Items.
    @param boolean|nil bNotify Emit itemsChanged after replacement.
    @ret table oComponent This object.
    !]]
    function oComponent.setMenus(tSource, bNotify)
        assert(not oComponent.Disposed and type(tSource) == "table", "Invalid Menus.");
        local tNext, tHeads, tNextSpecs = {}, {}, {};
        local bOK, sError = pcall(function()
            local nCount = 0;
            for nKey in pairs(tSource) do
                nCount = nCount + 1;
                assert(type(nKey) == "number" and nKey % 1 == 0 and nKey >= 1 and nKey <= #tSource,
                    "Menus must be a dense array.");
            end
            assert(nCount == #tSource, "Menus must be a dense array.");
            for nIndex, tSpec in ipairs(tSource) do
                assert(type(tSpec) == "table" and type(tSpec.Id) == "string" and not tNext[tSpec.Id],
                    "Invalid/duplicate menu Id.");
                local sId = tSpec.Id;
                local oMenu = _Menu.create(oComponent.Control, {Skin = tOptions.Skin, Items = tSpec.Items or {},
                    Artwork = tOptions.MenuArtwork, Containment = tOptions.Containment,
                    ContainmentOverflow = tOptions.ContainmentOverflow,
                    OnSelect = function(tSelection)
                        tSelection.MenuId = sId;
                        tEvents.emit("command", tSelection);
                        if (tOptions.OnSelect) then tOptions.OnSelect(tSelection, oComponent); end
                    end});
                tNext[sId] = oMenu;
                oMenu.setEnabled(oComponent.isEnabled() and tSpec.Enabled ~= false);
                tHeads[nIndex] = {Id = sId, Text = tSpec.Text or sId, Width = tSpec.Width or 88,
                    Image = tSpec.Image, Enabled = tSpec.Enabled};
                tNextSpecs[nIndex] = tHeads[nIndex];
                oMenu.on("closed", function(oSource, tEvent)
                    if (sOpen == sId) then sOpen = nil; end
                    if (tEvent.Reason == "cancelled" and oComponent.isEnabled()) then oComponent.Control:SetFocus(); end
                    tEvents.emit("menuClosed", {Id = sId, Reason = tEvent.Reason});
                end);
                local fMenuKey = oMenu.handleKey;
                oMenu.handleKey = function(sEvent, nKey, tModifiers)
                    local tLayout = oMenu.getLayout();
                    if (sEvent == "down" and oMenu.isOpen() and tLayout and tLayout.Depth == 0
                        and (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_RIGHT)) then
                        local bSubmenu = false;
                        for _, tItem in ipairs(oMenu.getItems()) do
                            if (tItem.Id == oMenu.getFocusedItem() and tItem.Items) then bSubmenu = true; end
                        end
                        if (nKey == _wx.WXK_LEFT or not bSubmenu) then
                            local nCurrent = 1;
                            for nOther, tOther in ipairs(tSpecs) do if (tOther.Id == sId) then nCurrent = nOther; end end
                            local nStep = nKey == _wx.WXK_LEFT and -1 or 1;
                            for nOffset = 1, #tSpecs do
                                local nNext = (nCurrent - 1 + nStep * nOffset) % #tSpecs + 1;
                                if (tSpecs[nNext].Enabled ~= false) then return oComponent.open(tSpecs[nNext].Id); end
                            end
                        end
                    end
                    return fMenuKey(sEvent, nKey, tModifiers);
                end;
                for _, sEvent in ipairs({"itemHovered", "itemLeft"}) do
                    oMenu.on(sEvent, function(oSource, tEvent)
                        tEvents.emit(sEvent, {Id = tEvent.Id, MenuId = sId});
                    end);
                end
            end
            fSetHeadings(tHeads, false);
        end);
        if (not bOK) then
            for _, oMenu in pairs(tNext) do oMenu.destroy(); end
            error(sError);
        end
        oComponent.close();
        for _, oMenu in pairs(tMenus) do oMenu.destroy(); end
        tMenus, tSpecs = tNext, tNextSpecs;
        if (bNotify) then tEvents.emit("itemsChanged", {Menus = oComponent.getMenus()}); end
        return oComponent;
    end
    -- Keep inherited array mutations on the same descriptor path as setMenus.
    oComponent.getItems, oComponent.setItems = oComponent.getMenus, oComponent.setMenus;
    local fEnable, fDestroy, fLayout, fKey = oComponent.onEnable, oComponent.onDestroy, oComponent.onLayout, oComponent.key;
    oComponent.onEnable = function(bEnabled)
        if (not bEnabled) then oComponent.close(); end
        if (fEnable) then fEnable(bEnabled); end
        for _, tSpec in ipairs(tSpecs) do tMenus[tSpec.Id].setEnabled(bEnabled and tSpec.Enabled ~= false); end
    end;
    oComponent.onLayout = function(...)
        oComponent.close();
        if (fLayout) then fLayout(...); end
    end;
    oComponent.onDestroy = function()
        for _, oMenu in pairs(tMenus) do oMenu.destroy(); end
        fDestroy();
    end;
    oComponent.key = function(nKey, tModifiers)
        if (nKey == _wx.WXK_DOWN) then return fKey(_wx.WXK_RETURN, tModifiers); end
        if (nKey == _wx.WXK_ESCAPE and oComponent.isOpen()) then oComponent.close(); return true; end
        return fKey(nKey, tModifiers);
    end;
    oParent:Connect(_wx.wxEVT_CHAR_HOOK, function(jEvent)
        if (not oComponent.Disposed and oComponent.isEnabled() and oComponent.Control:IsShownOnScreen()
            and jEvent:GetKeyCode() == _wx.WXK_F10) then
            oComponent.Control:SetFocus();
        else jEvent:Skip(); end
    end);
    oComponent.on("itemHovered", function(oSource, tEvent)
        if (not tEvent.MenuId and tMenus[tEvent.Id] and sOpen and sOpen ~= tEvent.Id) then oComponent.open(tEvent.Id); end
    end);
    oComponent.setMenus(tOptions.Menus or {});
    oComponent.setEnabled(tOptions.Enabled ~= false);
    return oComponent;
end

return MenuBar;
