local _wx      = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events  = require("wxLuma.Core.ControlEvents");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local _finite  = require("wxLuma.Core.ControlNumeric").finite;
local StatusBar = {};

--[[!
@fqxn wxLuma.UI.StatusBar.create
@desc Creates fixed-width and weighted status sections. Text/images are clipped
    independently; getSection(id) lazily creates a native parent for custom controls.
@param wxWindow oParent Native owner.
@param table tOptions Skin, optional Items ({Id,Text,Image,Width,Weight}), Artwork
    (Status Bar), Enabled, OnActivate(id, component). Width is fixed; omitted Width
    shares remaining space by positive Weight (default 1).
@ret table oComponent Standard surface/events plus item and section APIs.
!]]
function StatusBar.create(oParent, tOptions)
    assert(tOptions and tOptions.Skin, "StatusBar requires Skin.");
    local sArtwork = tOptions.Artwork or "Status Bar";
    local tArt = _Artwork.create(tOptions.Skin, sArtwork);
    local tItems, tHosts, tRects = {}, {}, {};
    local tEvents;
    local nFocused = 1;
    local nPressed;

    --[[!
    @fqxn wxLuma.UI.StatusBar.fCopy
    @desc Validates and copies a dense descriptor array before mutation. Image
        resources load before installation so failed edits preserve live sections.
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
                and not tSeen[tItem.Id], "Section IDs must be unique nonempty strings.");
            assert(tItem.Text == nil or type(tItem.Text) == "string", "Invalid section Text.");
            assert(tItem.Width == nil or (_finite(tItem.Width) and tItem.Width >= 1 and tItem.Width % 1 == 0),
                "Section Width must be positive integer pixels.");
            assert(tItem.Weight == nil or (_finite(tItem.Weight) and tItem.Weight > 0), "Invalid Weight.");
            assert(tItem.Image == nil or type(tItem.Image) == "string", "Invalid Image.");
            tArt.prepare(tItem.Image);
            tSeen[tItem.Id] = true;
            tCopy[nIndex] = {Id = tItem.Id, Text = tItem.Text or "", Image = tItem.Image,
                Width = tItem.Width, Weight = tItem.Weight or 1};
        end
        return tCopy;
    end
    local bOK, vItems = pcall(fCopy, tOptions.Items or {});
    if (not bOK) then
        tArt.destroy();
        error(vItems);
    end
    tItems = vItems;
    local oComponent = _Surface.create(oParent, tOptions, "StatusBar");

    --[[!
    @fqxn wxLuma.UI.StatusBar.fLayout
    @desc Allocates fixed sections first, distributes flexible pixels by cumulative
        weight, and clips excess fixed widths without negative geometry.
    !]]
    local function fLayout()
        local nWidth, nHeight = oComponent.Control:GetClientSizeWH();
        local nFixed, nWeight, nMaxWeight = 0, 0, 1;
        for _, tItem in ipairs(tItems) do
            if (not tItem.Width) then
                nMaxWeight = math.max(nMaxWeight, tItem.Weight);
            end
        end
        for _, tItem in ipairs(tItems) do
            nFixed = nFixed + (tItem.Width or 0);
            nWeight = nWeight + (tItem.Width and 0 or tItem.Weight / nMaxWeight);
        end
        local nFree = math.max(0, nWidth - nFixed);
        local nX, nUsedWeight, nDistributed = 0, 0, 0;
        tRects = {};
        for nIndex, tItem in ipairs(tItems) do
            local nPartWidth = tItem.Width;
            if (not nPartWidth) then
                nUsedWeight = nUsedWeight + tItem.Weight / nMaxWeight;
                local nBoundary = math.floor(nFree * nUsedWeight / nWeight);
                nPartWidth = nBoundary - nDistributed;
                nDistributed = nBoundary;
            end
            nPartWidth = math.max(0, math.min(nPartWidth, nWidth - nX));
            tRects[nIndex] = {Id = tItem.Id, X = nX, Y = 0, Width = nPartWidth, Height = nHeight};
            local oHost = tHosts[tItem.Id];
            if (oHost) then
                oHost:SetSize(nX + 3, 3, math.max(1, nPartWidth - 6), math.max(1, nHeight - 6));
                oHost:Show(nPartWidth > 6 and nHeight > 6);
            end
            nX = nX + nPartWidth;
        end
        oComponent.refresh();
    end

    --[[!
    @fqxn wxLuma.UI.StatusBar.getItems
    @desc Returns independent section descriptor copies.
    @ret table tItems Display-order descriptors.
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
    @fqxn wxLuma.UI.StatusBar.setItems
    @desc Atomically replaces sections, retaining hosts with matching IDs. Removed
        hosts and their application-owned children are destroyed with that section.
    @param table tSource Replacement descriptors.
    @param boolean|nil bNotify Emit itemsChanged.
    @ret table oComponent This object.
    !]]
    function oComponent.setItems(tSource, bNotify)
        assert(not oComponent.Disposed, "StatusBar is disposed.");
        local tNext = fCopy(tSource);
        local tKeep = {};
        for _, tItem in ipairs(tNext) do
            tKeep[tItem.Id] = true;
        end
        for sId, oHost in pairs(tHosts) do
            if (not tKeep[sId]) then
                oHost:Destroy();
                tHosts[sId] = nil;
            end
        end
        tItems, nFocused, nPressed = tNext, 1, nil;
        tArt.retain(tItems);
        oComponent.cancel();
        fLayout();
        if (bNotify) then
            tEvents.emit("itemsChanged", {Items = oComponent.getItems()});
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.StatusBar.addItem
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
    @fqxn wxLuma.UI.StatusBar.removeItem
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
    @fqxn wxLuma.UI.StatusBar.setItem
    @desc Applies a descriptor patch to one existing ID; Id itself remains stable.
    @param string sId Section ID.
    @param table tPatch Fields to replace. Use setItems to clear optional fields.
    @param boolean|nil bNotify Emit itemsChanged.
    @ret table oComponent This object.
    !]]
    function oComponent.setItem(sId, tPatch, bNotify)
        assert(type(tPatch) == "table" and (tPatch.Id == nil or tPatch.Id == sId), "Invalid section patch.");
        local tCopy = oComponent.getItems();
        for _, tItem in ipairs(tCopy) do
            if (tItem.Id == sId) then
                for sKey, vValue in pairs(tPatch) do
                    tItem[sKey] = vValue;
                end
                return oComponent.setItems(tCopy, bNotify);
            end
        end
        error("Unknown section: "..tostring(sId));
    end

    --[[!
    @fqxn wxLuma.UI.StatusBar.getSection
    @desc Returns a stable native host for custom controls. Hosted content replaces
        this section's default text/image rendering and follows section geometry.
    @param string sId Section ID.
    @ret wxPanel oHost Native child parent, owned by this status section.
    !]]
    function oComponent.getSection(sId)
        assert(not oComponent.Disposed, "StatusBar is disposed.");
        for _, tItem in ipairs(tItems) do
            if (tItem.Id == sId) then
                if (not tHosts[sId]) then
                    local oHost = _wx.wxPanel(oComponent.Control, _wx.wxID_ANY,
                        _wx.wxDefaultPosition, _wx.wxDefaultSize, _wx.wxTAB_TRAVERSAL);
                    oHost:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
                    oHost:SetBackgroundColour(tArt.color(oComponent.isEnabled() and "Section Normal" or "Section Disabled"));
                    oHost:Enable(oComponent.isEnabled());
                    oHost:Connect(_wx.wxEVT_PAINT, function()
                        -- Always validate the native paint region, even after
                        -- resource disposal while the parent still owns this host.
                        local oDC = _wx.wxAutoBufferedPaintDC(oHost);
                        if (not oComponent.Disposed) then
                            local nWidth, nHeight = oHost:GetClientSizeWH();
                            tArt.part(oDC, oComponent.isEnabled() and "Section Normal" or "Section Disabled",
                                0, 0, nWidth, nHeight);
                        end
                        oDC:delete();
                    end);
                    tHosts[sId] = oHost;
                    tEvents.bind(oHost);
                    fLayout();
                end
                return tHosts[sId];
            end
        end
        error("Unknown section: "..tostring(sId));
    end

    --[[!
    @fqxn wxLuma.UI.StatusBar.getLayout
    @desc Returns independent, clipped display-order section rectangles.
    @ret table tRects Rectangles with Id, X, Y, Width, Height.
    !]]
    function oComponent.getLayout()
        local tCopy = {};
        for nIndex, tRect in ipairs(tRects) do
            tCopy[nIndex] = {};
            for sKey, vValue in pairs(tRect) do
                tCopy[nIndex][sKey] = vValue;
            end
        end
        return tCopy;
    end

    --[[!
    @fqxn wxLuma.UI.StatusBar.activateItem
    @desc Emits sectionActivated and invokes OnActivate for an existing section.
    @param string sId Section ID.
    @ret boolean bActivated False when disabled or not found.
    !]]
    function oComponent.activateItem(sId)
        if (oComponent.isEnabled()) then
            for _, tItem in ipairs(tItems) do
                if (tItem.Id == sId) then
                    tEvents.emit("sectionActivated", {Id = sId});
                    if (tOptions.OnActivate) then
                        tOptions.OnActivate(sId, oComponent);
                    end
                    return true;
                end
            end
        end
        return false;
    end
    oComponent.onLayout = fLayout;
    oComponent.onEnable = function(bEnabled)
        for _, oHost in pairs(tHosts) do
            oHost:Enable(bEnabled);
            oHost:SetBackgroundColour(tArt.color(bEnabled and "Section Normal" or "Section Disabled"));
            oHost:Refresh(false);
        end
    end;
    oComponent.onCancel = function()
        nPressed = nil;
    end;
    oComponent.pointer = function(sEvent, nX, nY)
        local nHit;
        for nIndex, tRect in ipairs(tRects) do
            if (nX >= tRect.X and nX < tRect.X + tRect.Width and nY >= 0 and nY < tRect.Height) then
                nHit = nIndex;
            end
        end
        if (sEvent == "down") then
            nPressed, nFocused = nHit, nHit or nFocused;
        elseif (sEvent == "up" and nHit and nPressed == nHit) then
            oComponent.activateItem(tItems[nHit].Id);
        end
    end;
    oComponent.key = function(nKey)
        if (#tItems == 0) then
            return false;
        end
        if (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_RIGHT) then
            nFocused = (nFocused - 1 + (nKey == _wx.WXK_LEFT and -1 or 1)) % #tItems + 1;
            oComponent.refresh();
            return true;
        elseif (nKey == _wx.WXK_RETURN or nKey == _wx.WXK_SPACE) then
            return oComponent.activateItem(tItems[nFocused].Id);
        end
        return false;
    end;
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then
            return;
        end
        local sState = oComponent.isEnabled() and "Normal" or "Disabled";
        tArt.part(oDC, "Surface "..sState, 0, 0, nWidth, nHeight);
        for nIndex, tRect in ipairs(tRects) do
            if (tRect.Width > 0) then
                local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(tRect.X, 0, tRect.Width, nHeight));
                tArt.part(oDC, "Section "..sState, tRect.X, 0, tRect.Width, nHeight);
                if (not tHosts[tRect.Id]) then
                    local tItem = tItems[nIndex];
                    local nSize = math.max(1, math.min(24, nHeight - 8));
                    tArt.image(oDC, tItem.Image, tRect.X + 8, (nHeight - nSize) / 2, nSize);
                    tArt.text(oDC, tItem.Text, tRect.X + (tItem.Image and nSize + 16 or 8),
                        (nHeight - 18) / 2, oComponent.isEnabled());
                end
                if (nIndex == nFocused and oComponent.Control:HasFocus()) then
                    tArt.part(oDC, "Focus", tRect.X, nHeight - 3, tRect.Width, 3);
                end
                tArt.part(oDC, "Separator", tRect.X + tRect.Width - 1, 0, 1, nHeight);
                oClip:delete();
            end
        end
    end;
    oComponent.onDestroy = tArt.destroy;
    tEvents = _Events.attach(oComponent, nil, {"itemsChanged", "sectionActivated"});
    return oComponent;
end

return StatusBar;
