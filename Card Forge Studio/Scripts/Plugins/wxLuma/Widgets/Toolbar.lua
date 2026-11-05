local _wx          = require("wx");
local _Surface     = require("wxLuma.Core.ControlSurface");
local _Events      = require("wxLuma.Core.ControlEvents");
local _Artwork     = require("wxLuma.Core.ControlArtwork");
local _Containment = require("wxLuma.Core.ControlContainment");
local _ContextMenu = require("wxLuma.Widgets.ContextMenu");
local _finite      = require("wxLuma.Core.ControlNumeric").finite;
local Toolbar      = {};

--[[!
@fqxn wxLuma.UI.Toolbar.create
@desc Creates a horizontal command strip with buttons, persistent toggles,
    separators, images, skinned hover hints and a contained overflow menu. Items
    retain order; a final More button exposes commands that do not fit.
@param wxWindow oParent Native owner.
@param table tOptions Skin, optional Items ({Id,Text,Image,Kind,Selected,Enabled,
    Width,Tooltip}), Artwork (Toolbar), Enabled, OnActivate(id, component).
@param string|nil sKind Internal component kind for a composed command strip.
@ret table oComponent Standard surface/events plus mutable command APIs.
!]]
function Toolbar.create(oParent, tOptions, sKind)
    assert(tOptions and tOptions.Skin, "Toolbar requires Skin.");
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "Toolbar");
    local tItems, tRects, tOverflow = {}, {}, {};
    local tEvents;
    local sHovered, sFocused, sPressed;

    --[[!
    @fqxn wxLuma.UI.Toolbar.fCopy
    @desc Copies/validates unique command IDs and loads image resources before
        replacing live descriptors. Separator IDs remain stable for mutation.
    !]]
    local function fCopy(tSource)
        assert(type(tSource) == "table", "Items must be an array.");
        local tCopy, tSeen = {}, {};
        local nCount = 0;
        for nKey in pairs(tSource) do
            nCount = nCount + 1;
            assert(type(nKey) == "number" and nKey % 1 == 0 and nKey >= 1 and nKey <= #tSource,
                "Items must be a dense array.");
        end
        assert(nCount == #tSource, "Items must be a dense array.");
        for nIndex, tItem in ipairs(tSource) do
            assert(type(tItem) == "table" and type(tItem.Id) == "string" and tItem.Id ~= ""
                and tItem.Id:sub(1, 2) ~= "__" and not tSeen[tItem.Id], "Invalid/duplicate command ID.");
            local sKind = tItem.Kind or "button";
            assert(sKind == "button" or sKind == "toggle" or sKind == "separator", "Invalid command Kind.");
            assert(tItem.Text == nil or type(tItem.Text) == "string", "Invalid Text.");
            assert(tItem.Tooltip == nil or type(tItem.Tooltip) == "string", "Invalid Tooltip.");
            assert(tItem.Selected == nil or type(tItem.Selected) == "boolean", "Invalid Selected.");
            assert(tItem.Enabled == nil or type(tItem.Enabled) == "boolean", "Invalid Enabled.");
            local nWidth = tItem.Width or (sKind == "separator" and 12 or 112);
            assert(_finite(nWidth) and nWidth % 1 == 0 and nWidth >= 8, "Width must be integer pixels, at least eight.");
            assert(tItem.Image == nil or type(tItem.Image) == "string", "Invalid Image.");
            tArt.prepare(tItem.Image);
            tCopy[nIndex] = {Id = tItem.Id, Text = tItem.Text or tItem.Id, Image = tItem.Image,
                Kind = sKind, Selected = tItem.Selected == true, Enabled = tItem.Enabled ~= false,
                Width = nWidth, Tooltip = tItem.Tooltip or ""};
            tSeen[tItem.Id] = true;
        end
        return tCopy;
    end
    local bOK, vItems = pcall(fCopy, tOptions.Items or {});
    if (not bOK) then
        tArt.destroy();
        error(vItems);
    end
    tItems = vItems;
    local oComponent = _Surface.create(oParent, tOptions, sKind or "Toolbar");
    local tPolicy = _Containment.getPolicy(oComponent);
    local oHint = _wx.wxPopupWindow(oComponent.Control, _wx.wxBORDER_NONE);
    local oHintCanvas = _wx.wxPanel(oHint, _wx.wxID_ANY);
    oHintCanvas:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
    local oTimer = _wx.wxTimer(oComponent.Control);
    local sHint = "";
    local oOverflow;

    --[[!
    @fqxn wxLuma.UI.Toolbar.fHideHint
    @desc Cancels pending hints and hides the nonactivating owned popup.
    !]]
    local function fHideHint()
        oTimer:Stop();
        oHint:Hide();
    end

    --[[!
    @fqxn wxLuma.UI.Toolbar.fFind
    @desc Finds a live descriptor by stable command ID.
    !]]
    local function fFind(sId)
        for _, tItem in ipairs(tItems) do
            if (tItem.Id == sId) then
                return tItem;
            end
        end
    end

    --[[!
    @fqxn wxLuma.UI.Toolbar.fLayout
    @desc Fits whole commands into the client width, reserving More space only
        when needed. Never shrinks commands to hide overflow.
    !]]
    local function fLayout()
        local nWidth, nHeight = oComponent.Control:GetClientSizeWH();
        local nTotal = 8;
        for _, tItem in ipairs(tItems) do
            nTotal = nTotal + tItem.Width + 4;
        end
        local bOverflow = nTotal > nWidth;
        local nLimit = math.max(4, nWidth - (bOverflow and 44 or 4));
        local nX, bFull = 4, false;
        tRects, tOverflow = {}, {};
        for _, tItem in ipairs(tItems) do
            if (not bFull and nX + tItem.Width <= nLimit) then
                tRects[#tRects + 1] = {Id = tItem.Id, X = nX, Y = 4, Width = tItem.Width,
                    Height = math.max(1, nHeight - 8)};
                nX = nX + tItem.Width + 4;
            else
                bFull = true;
                if (tItem.Kind ~= "separator") then
                    tOverflow[#tOverflow + 1] = tItem.Id;
                end
            end
        end
        if (#tOverflow > 0) then
            tRects[#tRects + 1] = {Id = "__more", X = math.max(0, nWidth - 40), Y = 4,
                Width = math.min(36, nWidth), Height = math.max(1, nHeight - 8)};
        end
        sFocused = nil;
        sHovered, sPressed = nil, nil;
        fHideHint();
        if (oOverflow) then
            oOverflow.close();
        end
        oComponent.refresh();
    end

    --[[!
    @fqxn wxLuma.UI.Toolbar.getItems
    @desc Returns descriptor copies, preserving display order and toggle state.
    @ret table tItems Independent descriptors.
    !]]
    function oComponent.getItems()
        local tCopy = {};
        for nIndex, tItem in ipairs(tItems) do
            tCopy[nIndex] = {};
            for sKey, vValue in pairs(tItem) do
                tCopy[nIndex][sKey] = vValue;
            end
        end
        return tCopy;
    end

    --[[!
    @fqxn wxLuma.UI.Toolbar.setItems
    @desc Atomically replaces commands and dismisses transient input/overflow.
    @param table tSource Command descriptors.
    @param boolean|nil bNotify Emit itemsChanged.
    @ret table oComponent This object.
    !]]
    function oComponent.setItems(tSource, bNotify)
        assert(not oComponent.Disposed, "Toolbar is disposed.");
        local tNext = fCopy(tSource);
        oComponent.cancel();
        tItems = tNext;
        tArt.retain(tItems);
        fLayout();
        if (bNotify) then
            tEvents.emit("itemsChanged", {Items = oComponent.getItems()});
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Toolbar.addItem
    @desc Inserts a descriptor at an optional display index after validating the
        entire replacement array. Omitted index appends.
    @param table tItem New descriptor with a unique Id.
    @param number|nil nIndex Insertion index.
    @param boolean|nil bNotify Emit itemsChanged.
    @ret table oComponent This object.
    !]]
    function oComponent.addItem(tItem, nIndex, bNotify)
        local tCopy = oComponent.getItems();
        nIndex = nIndex or #tCopy + 1;
        assert(_finite(nIndex) and nIndex % 1 == 0 and nIndex >= 1 and nIndex <= #tCopy + 1,
            "Invalid insertion index.");
        table.insert(tCopy, nIndex, tItem);
        return oComponent.setItems(tCopy, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.Toolbar.removeItem
    @desc Removes an existing descriptor by stable ID. Associated transient state
        is cancelled through the same replacement path as setItems.
    @param string sId Existing item ID.
    @param boolean|nil bNotify Emit itemsChanged.
    @ret table oComponent This object.
    !]]
    function oComponent.removeItem(sId, bNotify)
        local tCopy = oComponent.getItems();
        for nIndex, tItem in ipairs(tCopy) do
            if (tItem.Id == sId) then
                table.remove(tCopy, nIndex);
                return oComponent.setItems(tCopy, bNotify);
            end
        end
        error("Unknown item: "..tostring(sId));
    end

    --[[!
    @fqxn wxLuma.UI.Toolbar.setItem
    @desc Patches one command while preserving its ID. Use setItems to clear fields.
    @param string sId Existing command ID.
    @param table tPatch Descriptor fields.
    @param boolean|nil bNotify Emit itemsChanged.
    @ret table oComponent This object.
    !]]
    function oComponent.setItem(sId, tPatch, bNotify)
        assert(type(tPatch) == "table" and (tPatch.Id == nil or tPatch.Id == sId), "Invalid command patch.");
        local tCopy = oComponent.getItems();
        for _, tItem in ipairs(tCopy) do
            if (tItem.Id == sId) then
                for sKey, vValue in pairs(tPatch) do
                    tItem[sKey] = vValue;
                end
                return oComponent.setItems(tCopy, bNotify);
            end
        end
        error("Unknown command: "..tostring(sId));
    end

    --[[!
    @fqxn wxLuma.UI.Toolbar.getSelected
    @desc Returns selected toggle IDs in display order, always as an independent array.
    @ret table tIds Selected toggles.
    !]]
    function oComponent.getSelected()
        local tIds = {};
        for _, tItem in ipairs(tItems) do
            if (tItem.Kind == "toggle" and tItem.Selected) then
                tIds[#tIds + 1] = tItem.Id;
            end
        end
        return tIds;
    end

    --[[!
    @fqxn wxLuma.UI.Toolbar.setSelected
    @desc Replaces selected toggle IDs atomically. Multiple toggles are independent.
    @param table tIds Array of existing toggle IDs.
    @param boolean|nil bNotify Emit selectionChanged after an effective change.
    @ret table oComponent This object.
    !]]
    function oComponent.setSelected(tIds, bNotify)
        assert(type(tIds) == "table", "Selected IDs must be an array.");
        local tSet = {};
        local nCount = 0;
        for nKey in pairs(tIds) do
            nCount = nCount + 1;
            assert(type(nKey) == "number" and nKey % 1 == 0 and nKey >= 1 and nKey <= #tIds,
                "Selected IDs must be a dense array.");
        end
        assert(nCount == #tIds, "Selected IDs must be a dense array.");
        for _, sId in ipairs(tIds) do
            local tItem = fFind(sId);
            assert(tItem and tItem.Kind == "toggle", "Selected ID must name a toggle.");
            tSet[sId] = true;
        end
        local bChanged = false;
        for _, tItem in ipairs(tItems) do
            if (tItem.Kind == "toggle") then
                local bSelected = tSet[tItem.Id] == true;
                bChanged = bChanged or tItem.Selected ~= bSelected;
                tItem.Selected = bSelected;
            end
        end
        if (bChanged) then
            oComponent.refresh();
            if (oOverflow) then
                oOverflow.close();
            end
            if (bNotify) then
                tEvents.emit("selectionChanged", {Selected = oComponent.getSelected()});
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Toolbar.activateItem
    @desc Activates an enabled command, toggles persistent state when appropriate,
        then emits toolActivated and OnActivate. Separators never activate.
    @param string sId Command ID.
    @ret boolean bActivated Whether activation occurred.
    !]]
    function oComponent.activateItem(sId)
        local tItem = fFind(sId);
        if (not oComponent.isEnabled() or not tItem or not tItem.Enabled or tItem.Kind == "separator") then
            return false;
        end
        fHideHint();
        if (tItem.Kind == "toggle") then
            tItem.Selected = not tItem.Selected;
            tEvents.emit("selectionChanged", {Selected = oComponent.getSelected()});
        end
        local sOld = oComponent.Value;
        oComponent.Value = sId;
        oComponent.refresh();
        if (sOld ~= sId) then
            tEvents.emit("valueChanged", {Value = sId, OldValue = sOld});
        end
        tEvents.emit("toolActivated", {Id = sId, Selected = tItem.Selected});
        if (tOptions.OnActivate) then
            tOptions.OnActivate(sId, oComponent);
        end
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.Toolbar.getLayout
    @desc Returns independent visible rectangles and hidden command IDs.
    @ret table tLayout Entries and Overflow arrays.
    !]]
    function oComponent.getLayout()
        local tCopy = {Entries = {}, Overflow = {}};
        for nIndex, tRect in ipairs(tRects) do
            tCopy.Entries[nIndex] = {};
            for sKey, vValue in pairs(tRect) do
                tCopy.Entries[nIndex][sKey] = vValue;
            end
        end
        for nIndex, sId in ipairs(tOverflow) do
            tCopy.Overflow[nIndex] = sId;
        end
        return tCopy;
    end

    --[[!
    @fqxn wxLuma.UI.Toolbar.openOverflow
    @desc Opens hidden commands in the existing contained ContextMenu engine.
    @ret boolean bOpened Whether the overflow menu fits and opened.
    !]]
    function oComponent.openOverflow()
        if (not oComponent.isEnabled() or #tOverflow == 0) then
            return false;
        end
        local tMenuItems = {};
        for _, sId in ipairs(tOverflow) do
            local tItem = fFind(sId);
            tMenuItems[#tMenuItems + 1] = {Id = sId, Image = tItem.Image, Enabled = tItem.Enabled,
                Text = (tItem.Kind == "toggle" and (tItem.Selected and "[x] " or "[ ] ") or "")..tItem.Text};
        end
        oOverflow.setItems(tMenuItems);
        return oOverflow.showAtObject(oComponent.Control);
    end
    oOverflow = _ContextMenu.create(oComponent.Control, {Skin = tOptions.Skin, Items = {},
        OnSelect = function(tSelection)
            oComponent.activateItem(tSelection.Id);
        end});
    oComponent.OverflowMenu = oOverflow;
    -- Keep the existing menu engine's navigation, containment and dismissal,
    -- while rendering every overflow pixel through this toolbar's own skin.
    local sOverflowHover, sOverflowPressed;
    oOverflow.on("itemHovered", function(oSource, tEvent)
        sOverflowHover = tEvent.Id;
    end);
    oOverflow.on("itemLeft", function()
        sOverflowHover = nil;
    end);
    oOverflow.on("leftDown", function(oSource, tEvent)
        local tLayout = oOverflow.getLayout();
        for _, tEntry in ipairs(tLayout and tLayout.Entries or {}) do
            if (tEvent.X >= tEntry.X and tEvent.X < tEntry.X + tEntry.Width
                and tEvent.Y >= tEntry.Y and tEvent.Y < tEntry.Y + tEntry.Height) then
                sOverflowPressed = tEntry.Id;
            end
        end
    end);
    oOverflow.on("leftUp", function()
        sOverflowPressed = nil;
    end);
    oOverflow.on("closed", function()
        sOverflowHover, sOverflowPressed = nil, nil;
    end);

    --[[!
    @fqxn wxLuma.UI.Toolbar.drawOverflow
    @desc Renders overflow rows using toolbar surface, text, image and state
        materials, including the menu engine's Back/More navigation rows.
    !]]
    oOverflow.draw = function(oDC, nWidth, nHeight)
        if (oOverflow.Disposed or oComponent.Disposed) then
            return;
        end
        local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(0, 0, math.max(1, nWidth), math.max(1, nHeight)));
        tArt.part(oDC, "Hint", 0, 0, nWidth, nHeight);
        local tLayout = oOverflow.getLayout();
        for _, tEntry in ipairs(tLayout and tLayout.Entries or {}) do
            local tItem = fFind(tEntry.Id);
            local sState = not tEntry.Enabled and "Disabled" or sOverflowPressed == tEntry.Id and "Pressed"
                or (sOverflowHover == tEntry.Id or oOverflow.getFocusedItem() == tEntry.Id) and "Hover" or "Normal";
            local sPart = tItem and tItem.Kind == "toggle" and tItem.Selected and "Toggle On " or "Item ";
            local oRowClip = _wx.wxDCClipper(oDC, _wx.wxRect(tEntry.X, tEntry.Y, tEntry.Width, tEntry.Height));
            tArt.part(oDC, sPart..sState, tEntry.X, tEntry.Y, tEntry.Width, tEntry.Height);
            local sText = tItem and tItem.Text or (tEntry.Role == "back" and "Back" or "More");
            if (tItem and tItem.Kind == "toggle") then
                sText = (tItem.Selected and "[x] " or "[ ] ")..sText;
            end
            local nSize = math.max(1, math.min(24, tEntry.Height - 8));
            tArt.image(oDC, tItem and tItem.Image, tEntry.X + 6, tEntry.Y + (tEntry.Height - nSize) / 2, nSize);
            tArt.text(oDC, sText, tEntry.X + (tItem and tItem.Image and nSize + 12 or 8),
                tEntry.Y + (tEntry.Height - 18) / 2, tEntry.Enabled);
            oRowClip:delete();
        end
        oClip:delete();
    end;

    oHintCanvas:Connect(_wx.wxEVT_PAINT, function()
        if (not oComponent.Disposed) then
            local oDC = _wx.wxAutoBufferedPaintDC(oHintCanvas);
            local nWidth, nHeight = oHintCanvas:GetClientSizeWH();
            tArt.part(oDC, "Hint", 0, 0, nWidth, nHeight);
            tArt.text(oDC, sHint, 10, 8, true);
            oDC:delete();
        end
    end);
    oComponent.Control:Connect(oTimer:GetId(), _wx.wxEVT_TIMER, function()
        if (not oComponent.Disposed and oComponent.isEnabled() and sHovered and sHint ~= "") then
            local oDC = _wx.wxClientDC(oComponent.Control);
            oDC:SetFont(oComponent.Skin.Font);
            local _, nWidth, nHeight = oDC:GetMultiLineTextExtent(sHint);
            oDC:delete();
            oHint:SetSize(nWidth + 20, nHeight + 16);
            oHintCanvas:SetSize(0, 0, nWidth + 20, nHeight + 16);
            if (tPolicy.place(oHint)) then
                oHint:Show(true);
                oHintCanvas:Refresh(false);
            end
        end
    end);
    oComponent.onLayout = fLayout;
    oComponent.onCancel = function()
        sPressed = nil;
    end;
    oComponent.onEnable = function(bEnabled)
        fHideHint();
        if (not bEnabled) then
            oOverflow.close();
        end
    end;
    oComponent.pointer = function(sEvent, nX, nY)
        local sHit;
        for _, tRect in ipairs(tRects) do
            local tItem = fFind(tRect.Id);
            if (nX >= tRect.X and nX < tRect.X + tRect.Width and nY >= tRect.Y
                and nY < tRect.Y + tRect.Height and (not tItem or tItem.Kind ~= "separator")) then
                sHit = tRect.Id;
            end
        end
        if (sEvent == "leave") then
            sHit = nil;
        end
        if (sHit ~= sHovered) then
            fHideHint();
            if (sHovered) then
                tEvents.emit("itemLeft", {Id = sHovered});
            end
            sHovered = sHit;
            local tItem = fFind(sHit);
            sHint = tItem and tItem.Tooltip or "";
            if (sHovered) then
                tEvents.emit("itemHovered", {Id = sHovered});
                oTimer:Start(500, true);
            end
            oComponent.refresh();
        end
        if (sEvent == "down") then
            fHideHint();
            sPressed, sFocused = sHit, sHit;
        elseif (sEvent == "up" and sHit and sPressed == sHit) then
            if (sHit == "__more") then
                oComponent.openOverflow();
            else
                oComponent.activateItem(sHit);
            end
        end
    end;
    oComponent.key = function(nKey)
        fHideHint();
        local tIds = {};
        for _, tRect in ipairs(tRects) do
            local tItem = fFind(tRect.Id);
            if (not tItem or (tItem.Kind ~= "separator" and tItem.Enabled)) then
                tIds[#tIds + 1] = tRect.Id;
            end
        end
        if (#tIds == 0) then
            return false;
        end
        local nIndex = 0;
        for nOther, sId in ipairs(tIds) do
            if (sId == sFocused) then
                nIndex = nOther;
            end
        end
        if (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_RIGHT or nKey == _wx.WXK_HOME or nKey == _wx.WXK_END) then
            if (nKey == _wx.WXK_HOME) then
                nIndex = 1;
            elseif (nKey == _wx.WXK_END) then
                nIndex = #tIds;
            else
                nIndex = (nIndex - 1 + (nKey == _wx.WXK_LEFT and -1 or 1)) % #tIds + 1;
            end
            sFocused = tIds[nIndex];
            oComponent.refresh();
            tEvents.emit("itemFocused", {Id = sFocused});
            return true;
        elseif (nKey == _wx.WXK_SPACE or nKey == _wx.WXK_RETURN) then
            sFocused = sFocused or tIds[1];
            return sFocused == "__more" and oComponent.openOverflow() or oComponent.activateItem(sFocused);
        end
        return false;
    end;
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then
            return;
        end
        tArt.part(oDC, "Surface "..(oComponent.isEnabled() and "Normal" or "Disabled"), 0, 0, nWidth, nHeight);
        for _, tRect in ipairs(tRects) do
            local tItem = fFind(tRect.Id);
            local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(tRect.X, tRect.Y, tRect.Width, tRect.Height));
            if (tItem and tItem.Kind == "separator") then
                tArt.part(oDC, "Separator", tRect.X + math.floor(tRect.Width / 2), tRect.Y + 2, 2,
                    math.max(1, tRect.Height - 4));
            else
                local bEnabled = oComponent.isEnabled() and (not tItem or tItem.Enabled);
                local sState = not bEnabled and "Disabled" or sPressed == tRect.Id and "Pressed"
                    or sHovered == tRect.Id and "Hover" or "Normal";
                local sPart = tItem and tItem.Kind == "toggle" and tItem.Selected and "Toggle On " or "Item ";
                tArt.part(oDC, sPart..sState, tRect.X, tRect.Y, tRect.Width, tRect.Height);
                local nSize = math.max(1, math.min(24, tRect.Height - 8));
                if (tItem) then
                    tArt.image(oDC, tItem.Image, tRect.X + 6, tRect.Y + (tRect.Height - nSize) / 2, nSize);
                end
                local sText = tItem and tItem.Text or "...";
                tArt.text(oDC, sText, tRect.X + (tItem and tItem.Image and nSize + 12 or 8),
                    tRect.Y + (tRect.Height - 18) / 2, bEnabled);
                if (sFocused == tRect.Id and oComponent.Control:HasFocus()) then
                    tArt.part(oDC, "Focus", tRect.X, tRect.Y + tRect.Height - 3, tRect.Width, 3);
                end
            end
            oClip:delete();
        end
    end;
    oComponent.onDestroy = function()
        fHideHint();
        oTimer:delete();
        oHint:Destroy();
        oOverflow.destroy();
        tArt.destroy();
    end;
    tPolicy.watch(function()
        fHideHint();
    end);
    tEvents = _Events.attach(oComponent, nil, {"itemsChanged", "toolActivated", "selectionChanged",
        "itemHovered", "itemLeft", "itemFocused"});
    return oComponent;
end

return Toolbar;
