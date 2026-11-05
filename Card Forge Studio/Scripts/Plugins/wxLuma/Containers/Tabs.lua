local _wx      = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events  = require("wxLuma.Core.ControlEvents");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local _Layout  = require("wxLuma.Core.TabLayout");
local _finite  = require("wxLuma.Core.ControlNumeric").finite;
local Tabs     = {};

--[[!
@fqxn wxLuma.UI.Tabs.create
@desc Creates measured, skinned headers and owned native pages. String captions
    remain supported; descriptors add stable IDs, images and per-tab enabled state.
    Wrapped headers fall back to scrolling when space for a page would be lost.
@param wxWindow oParent Native owner.
@param table tOptions Skin, Items (strings or {Id,Text,Image,Enabled}); optional
    Value (index), LayoutMode (wrap), Position (top), MinTabWidth (80), MaxTabWidth
    (240), Artwork (Tabs), Enabled and OnChange(index, component).
@ret table oComponent Standard surface/events, numeric value, compatible Items
    caption/Pages arrays, plus stable-ID page, mutation and layout APIs.
!]]
function Tabs.create(oParent, tOptions)
    assert(tOptions and tOptions.Skin, "Tabs requires Skin.");
    local sMode = tOptions.LayoutMode == nil and "wrap" or tOptions.LayoutMode;
    local sPosition = tOptions.Position == nil and "top" or tOptions.Position;
    local nMin = tOptions.MinTabWidth == nil and 80 or tOptions.MinTabWidth;
    local nMax = tOptions.MaxTabWidth == nil and 240 or tOptions.MaxTabWidth;
    assert(sMode == "wrap" or sMode == "scroll", "Invalid LayoutMode.");
    assert(sPosition == "top" or sPosition == "bottom" or sPosition == "left" or sPosition == "right",
        "Invalid tab Position.");
    assert(_finite(nMin) and _finite(nMax) and nMin % 1 == 0 and nMax % 1 == 0 and nMin >= 24
        and nMax >= nMin and nMax <= 100000, "Invalid tab width limits.");
    assert(tOptions.Artwork == nil or (type(tOptions.Artwork) == "string" and tOptions.Artwork:find("%S")),
        "Artwork must be a nonempty prefix.");
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "Tabs");
    local tItems, tPages, tWidths = {}, {}, {};
    local tPlan;
    local tEvents;
    local nNextId = 0;
    local nRevision = 0;
    local vHover, vPressed;
    local nOffset = 0;
    local oComponent;

    --[[!
    @fqxn wxLuma.UI.Tabs.fCopy
    @desc Validates/copies dense descriptor data and prepares images before any
        native page mutation. Missing IDs receive collision-free generated IDs.
    !]]
    local function fCopy(tSource)
        assert(type(tSource) == "table", "Tabs Items must be an array.");
        local tSeen, tCopy = {}, {};
        local nCount = 0;
        for nKey in pairs(tSource) do
            nCount = nCount + 1;
            assert(type(nKey) == "number" and nKey % 1 == 0 and nKey >= 1 and nKey <= #tSource,
                "Tabs Items must be a dense array.");
        end
        assert(nCount == #tSource, "Tabs Items must be a dense array.");
        for _, vItem in ipairs(tSource) do
            if (type(vItem) == "table" and vItem.Id ~= nil) then
                assert(type(vItem.Id) == "string" and vItem.Id ~= "" and not tSeen[vItem.Id], "Invalid/duplicate tab Id.");
                tSeen[vItem.Id] = true;
            end
        end
        for nIndex, vItem in ipairs(tSource) do
            assert(type(vItem) == "string" or type(vItem) == "table", "Invalid tab descriptor.");
            local tItem = type(vItem) == "string" and {Text = vItem} or vItem;
            local sId = tItem.Id;
            if (not sId) then
                repeat
                    nNextId = nNextId + 1;
                    sId = "tab:"..nNextId;
                until (not tSeen[sId] and not tPages[sId]);
                tSeen[sId] = true;
            end
            assert(tItem.Text == nil or type(tItem.Text) == "string", "Invalid tab Text.");
            assert(tItem.Image == nil or type(tItem.Image) == "string", "Invalid tab Image.");
            assert(tItem.Enabled == nil or type(tItem.Enabled) == "boolean", "Invalid tab Enabled.");
            tArt.prepare(tItem.Image);
            tCopy[nIndex] = {Id = sId, Text = tItem.Text or sId, Image = tItem.Image, Enabled = tItem.Enabled ~= false};
        end
        return tCopy;
    end
    local bOK, vInitial = pcall(fCopy, tOptions.Items or {});
    if (not bOK) then
        tArt.destroy();
        error(vInitial);
    end
    if (tOptions.Value ~= nil) then
        local bAnyEnabled = false;
        for _, tItem in ipairs(vInitial) do
            bAnyEnabled = bAnyEnabled or tItem.Enabled;
        end
        if (not (_finite(tOptions.Value) and tOptions.Value % 1 == 0 and
            ((tOptions.Value == 0 and not bAnyEnabled) or (vInitial[tOptions.Value] and vInitial[tOptions.Value].Enabled)))) then
            tArt.destroy();
            error("Initial Value must name an enabled tab.");
        end
    end
    oComponent = _Surface.create(oParent, tOptions, "Tabs");
    oComponent.Items, oComponent.Pages, oComponent.Value = {}, {}, 0;

    --[[!
    @fqxn wxLuma.UI.Tabs.fIndex
    @desc Resolves a tab index or stable ID, returning nil for absent tabs.
    !]]
    local function fIndex(vTab)
        if (_finite(vTab) and vTab % 1 == 0 and tItems[vTab]) then
            return vTab;
        elseif (type(vTab) == "string") then
            for nIndex, tItem in ipairs(tItems) do
                if (tItem.Id == vTab) then
                    return nIndex;
                end
            end
        end
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.fMeasure
    @desc Measures labels with this object's font; image space and width limits
        are applied before the shared geometry engine packs the header strip.
    !]]
    local function fMeasure()
        local oDC = _wx.wxClientDC(oComponent.Control);
        oDC:SetFont(oComponent.Skin.Font);
        tWidths = {};
        for nIndex, tItem in ipairs(tItems) do
            local nWidth = oDC:GetTextExtent(tItem.Text);
            tWidths[nIndex] = math.max(nMin, math.min(nMax, nWidth + 28 + (tItem.Image and 28 or 0)));
        end
        oDC:delete();
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.fLayout
    @desc Recomputes headers, keeps the selected tab visible when requested, and
        updates every page's content bounds without recreating child controls.
    !]]
    local function fLayout(bEnsure)
        local nWidth, nHeight = oComponent.Control:GetClientSizeWH();
        tPlan = _Layout.compute(tWidths, nWidth, nHeight, sMode, sPosition, nOffset,
            bEnsure and oComponent.Value or nil);
        nOffset = tPlan.Offset;
        local tPage = tPlan.Page;
        for nIndex, tItem in ipairs(tItems) do
            local oPage = tPages[tItem.Id];
            oPage:SetSize(tPage.X, tPage.Y, tPage.Width, tPage.Height);
            oPage:Show(nIndex == oComponent.Value);
        end
        oComponent.refresh();
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.fNotify
    @desc Emits selection snapshots after all page visibility and geometry changes.
        Reorders also notify if the selected page's numeric index changes.
    !]]
    local function fNotify(nOld, sOldId, bNotify)
        local nValue = oComponent.Value;
        local sId = tItems[nValue] and tItems[nValue].Id;
        if (bNotify and tEvents and (nOld ~= nValue or sOldId ~= sId)) then
            tEvents.emit("valueChanged", {Value = nValue, OldValue = nOld, Id = sId, OldId = sOldId});
            tEvents.emit("selectionChanged", {Value = nValue, OldValue = nOld, Id = sId, OldId = sOldId});
            if (oComponent.OnChange) then
                oComponent.OnChange(nValue, oComponent);
            end
        end
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.getItems
    @desc Returns independent descriptors including stable generated IDs.
    @ret table tItems Display-order descriptor copies.
    !]]
    function oComponent.getItems()
        local tCopy = {};
        for nIndex, tItem in ipairs(tItems) do
            tCopy[nIndex] = {Id = tItem.Id, Text = tItem.Text, Image = tItem.Image, Enabled = tItem.Enabled};
        end
        return tCopy;
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.getPage
    @desc Retrieves the owned native content parent by index or stable ID.
    @param number|string vTab Tab reference.
    @ret wxPanel oPage Native content parent; invalid references raise an error.
    !]]
    function oComponent.getPage(vTab)
        assert(not oComponent.Disposed, "Tabs is disposed.");
        local nIndex = assert(fIndex(vTab), "Unknown tab.");
        return tPages[tItems[nIndex].Id];
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.setValue
    @desc Selects an enabled tab by index or ID and reveals its header. Zero is
        valid only when no enabled tabs exist. Setters are silent by default.
    @param number|string vTab Tab reference, or zero for an unselectable set.
    @param boolean|nil bNotify Emit selection/value events and OnChange.
    @ret table oComponent This object.
    !]]
    function oComponent.setValue(vTab, bNotify)
        assert(not oComponent.Disposed, "Tabs is disposed.");
        local nIndex = fIndex(vTab);
        if (vTab == 0) then
            for _, tItem in ipairs(tItems) do
                assert(not tItem.Enabled, "Zero selection requires no enabled tabs.");
            end
            nIndex = 0;
        else
            assert(nIndex and tItems[nIndex].Enabled, "Value must name an enabled tab.");
        end
        local nOld = oComponent.Value;
        local sOldId = tItems[nOld] and tItems[nOld].Id;
        if (nOld == nIndex) then
            if (nIndex == 0) then
                return oComponent;
            end
            for _, tEntry in ipairs(tPlan and tPlan.Entries or {}) do
                if (tEntry.Index == nIndex and tEntry.Width == tEntry.DrawWidth and tEntry.Height == tEntry.DrawHeight) then
                    return oComponent;
                end
            end
        end
        oComponent.Value = nIndex;
        fLayout(true);
        fNotify(nOld, sOldId, bNotify);
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.setItems
    @desc Replaces descriptors atomically, preserving native pages and selection
        by ID. Removed pages and their native children are destroyed. If selection
        disappears/disabled, the next enabled neighbor is chosen; otherwise zero.
    @param table tSource Strings or descriptors. Use descriptors to retain IDs.
    @param boolean|nil bNotify Emit itemsChanged and effective selection changes.
    @ret table oComponent This object.
    !]]
    function oComponent.setItems(tSource, bNotify)
        assert(not oComponent.Disposed, "Tabs is disposed.");
        local tNext = fCopy(tSource);
        nRevision = nRevision + 1;
        local nOld = oComponent.Value;
        local sOldId = tItems[nOld] and tItems[nOld].Id;
        local tKeep = {};
        for _, tItem in ipairs(tNext) do
            tKeep[tItem.Id] = true;
        end
        oComponent.cancel();
        vHover, vPressed = nil, nil;
        for sId, oPage in pairs(tPages) do
            if (not tKeep[sId]) then
                oPage:Destroy();
                tPages[sId] = nil;
            end
        end
        tItems = tNext;
        oComponent.Items, oComponent.Pages = {}, {};
        oComponent.Value = 0;
        for nIndex, tItem in ipairs(tItems) do
            if (not tPages[tItem.Id]) then
                local oPage = _wx.wxPanel(oComponent.Control, _wx.wxID_ANY, _wx.wxDefaultPosition,
                    _wx.wxDefaultSize, _wx.wxTAB_TRAVERSAL + _wx.wxCLIP_CHILDREN);
                oPage:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
                oPage:SetBackgroundColour(tArt.color(oComponent.isEnabled() and "Page Normal" or "Page Disabled"));
                oPage:Connect(_wx.wxEVT_PAINT, function()
                    local oDC = _wx.wxAutoBufferedPaintDC(oPage);
                    if (not oComponent.Disposed) then
                        local nWidth, nHeight = oPage:GetClientSizeWH();
                        tArt.part(oDC, oComponent.isEnabled() and "Page Normal" or "Page Disabled", 0, 0, nWidth, nHeight);
                    end
                    oDC:delete();
                end);
                tPages[tItem.Id] = oPage;
            end
            tPages[tItem.Id]:Enable(oComponent.isEnabled());
            oComponent.Items[nIndex] = tItem.Text;
            oComponent.Pages[nIndex] = tPages[tItem.Id];
            if (tItem.Id == sOldId and tItem.Enabled) then
                oComponent.Value = nIndex;
            end
        end
        if (oComponent.Value == 0) then
            for nPass = 1, #tItems do
                local nIndex = (math.max(1, math.min(nOld, #tItems)) - 1 + nPass - 1) % #tItems + 1;
                if (tItems[nIndex].Enabled) then
                    oComponent.Value = nIndex;
                    break;
                end
            end
        end
        tArt.retain(tItems);
        fMeasure();
        fLayout(true);
        fNotify(nOld, sOldId, bNotify);
        if (bNotify and tEvents) then
            tEvents.emit("itemsChanged", {Items = oComponent.getItems()});
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.addItem
    @desc Inserts a new tab at a display index, or appends. Existing pages survive.
    @param string|table vItem Caption or descriptor.
    @param number|nil nIndex Insertion index.
    @param boolean|nil bNotify Notify mutation and effective selection changes.
    @ret table oComponent This object.
    !]]
    function oComponent.addItem(vItem, nIndex, bNotify)
        local tCopy = oComponent.getItems();
        nIndex = nIndex or #tCopy + 1;
        assert(_finite(nIndex) and nIndex % 1 == 0 and nIndex >= 1 and nIndex <= #tCopy + 1, "Invalid tab insertion index.");
        table.insert(tCopy, nIndex, vItem);
        return oComponent.setItems(tCopy, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.removeItem
    @desc Removes a tab by index or ID and destroys only its owned native page.
    @param number|string vTab Tab reference.
    @param boolean|nil bNotify Notify mutation and effective selection changes.
    @ret table oComponent This object.
    !]]
    function oComponent.removeItem(vTab, bNotify)
        local nIndex = assert(fIndex(vTab), "Unknown tab.");
        local tCopy = oComponent.getItems();
        table.remove(tCopy, nIndex);
        return oComponent.setItems(tCopy, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.setItem
    @desc Patches text/image/enabled state while preserving ID and native page.
    @param number|string vTab Tab reference.
    @param table tPatch Fields to replace. Use setItems to clear optional fields.
    @param boolean|nil bNotify Notify mutation and effective selection changes.
    @ret table oComponent This object.
    !]]
    function oComponent.setItem(vTab, tPatch, bNotify)
        local nIndex = assert(fIndex(vTab), "Unknown tab.");
        assert(type(tPatch) == "table" and (tPatch.Id == nil or tPatch.Id == tItems[nIndex].Id), "Tab Id is immutable.");
        local tCopy = oComponent.getItems();
        for sKey, vValue in pairs(tPatch) do
            tCopy[nIndex][sKey] = vValue;
        end
        return oComponent.setItems(tCopy, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.moveItem
    @desc Moves a page without recreating it; selection follows its stable ID.
    @param number|string vTab Tab reference.
    @param number nIndex Destination display index.
    @param boolean|nil bNotify Notify mutation and effective selection changes.
    @ret table oComponent This object.
    !]]
    function oComponent.moveItem(vTab, nIndex, bNotify)
        local nFrom = assert(fIndex(vTab), "Unknown tab.");
        assert(_finite(nIndex) and nIndex % 1 == 0 and nIndex >= 1 and nIndex <= #tItems, "Invalid destination index.");
        local tCopy = oComponent.getItems();
        table.insert(tCopy, nIndex, table.remove(tCopy, nFrom));
        return oComponent.setItems(tCopy, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.getPosition
    @desc Returns the configured header edge.
    @ret string sPosition top, bottom, left or right.
    !]]
    function oComponent.getPosition()
        return sPosition;
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.setPosition
    @desc Moves the header edge without recreating or reparenting pages.
    @param string sEdge top, bottom, left or right.
    @param boolean|nil bNotify Emit positionChanged after an effective change.
    @ret table oComponent This object.
    !]]
    function oComponent.setPosition(sEdge, bNotify)
        assert(not oComponent.Disposed, "Tabs is disposed.");
        assert(sEdge == "top" or sEdge == "bottom" or sEdge == "left" or sEdge == "right", "Invalid Position.");
        if (sEdge ~= sPosition) then
            sPosition, nOffset = sEdge, 0;
            oComponent.cancel();
            vHover = nil;
            fLayout(true);
            if (bNotify) then
                tEvents.emit("positionChanged", {Position = sPosition});
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.getLayoutMode
    @desc Returns configured wrap or scroll; getLayout reports effective fallback.
    @ret string sMode Configured mode.
    !]]
    function oComponent.getLayoutMode()
        return sMode;
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.setLayoutMode
    @desc Changes wrapping/scrolling policy and reveals the current selection.
    @param string sLayout wrap or scroll.
    @param boolean|nil bNotify Emit layoutModeChanged after an effective change.
    @ret table oComponent This object.
    !]]
    function oComponent.setLayoutMode(sLayout, bNotify)
        assert(not oComponent.Disposed, "Tabs is disposed.");
        assert(sLayout == "wrap" or sLayout == "scroll", "Invalid LayoutMode.");
        if (sLayout ~= sMode) then
            sMode, nOffset = sLayout, 0;
            oComponent.cancel();
            vHover = nil;
            fLayout(true);
            if (bNotify) then
                tEvents.emit("layoutModeChanged", {LayoutMode = sMode});
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.scrollBy
    @desc Moves the scrolling viewport by finite pixel distance; selection is
        preserved. Selecting a tab or resizing reveals the selected header again.
    @param number nPixels Signed pixel distance.
    @ret table oComponent This object.
    !]]
    function oComponent.scrollBy(nPixels)
        assert(not oComponent.Disposed, "Tabs is disposed.");
        assert(_finite(nPixels), "Scroll distance must be finite.");
        nOffset = math.max(0, math.min(tPlan and tPlan.Maximum or 0, nOffset + nPixels));
        fLayout(false);
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.getLayout
    @desc Returns an independent layout snapshot with visible entries, content
        Page bounds, Viewport, navigation rectangles, effective Mode and Offset.
    @ret table tLayout Geometry snapshot; entries include Index and stable Id.
    !]]
    function oComponent.getLayout()
        --[[!
        @fqxn wxLuma.UI.Tabs.getLayout.fClone
        @desc Recursively copies plain geometry tables without exposing live layout state.
        !]]
        local function fClone(tSource)
            local tCopy = {};
            for sKey, vValue in pairs(tSource or {}) do
                tCopy[sKey] = type(vValue) == "table" and fClone(vValue) or vValue;
            end
            return tCopy;
        end
        local tCopy = fClone(tPlan);
        for _, tEntry in ipairs(tCopy.Entries or {}) do
            tEntry.Id = tItems[tEntry.Index].Id;
        end
        return tCopy;
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.fHit
    @desc Tests only visible clipped headers/navigation, never page content.
    !]]
    local function fHit(nX, nY)
        for _, tNav in ipairs({{"back", tPlan.Back}, {"forward", tPlan.Forward}}) do
            local tRect = tNav[2];
            if (tRect and nX >= tRect.X and nX < tRect.X + tRect.Width
                and nY >= tRect.Y and nY < tRect.Y + tRect.Height) then
                return tNav[1];
            end
        end
        for _, tEntry in ipairs(tPlan.Entries) do
            if (nX >= tEntry.X and nX < tEntry.X + tEntry.Width and nY >= tEntry.Y and nY < tEntry.Y + tEntry.Height) then
                return tEntry.Index;
            end
        end
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.fStep
    @desc Selects the next/previous enabled tab, wrapping once through the array.
    !]]
    local function fStep(nDelta)
        for nPass = 1, #tItems do
            local nIndex = (oComponent.Value - 1 + nPass * nDelta) % #tItems + 1;
            if (tItems[nIndex].Enabled) then
                oComponent.setValue(nIndex, true);
                return true;
            end
        end
        return false;
    end
    oComponent.onLayout = function()
        fLayout(true);
    end;
    oComponent.onCancel = function()
        vPressed = nil;
    end;
    oComponent.onEnable = function(bEnabled)
        for _, oPage in pairs(tPages) do
            oPage:Enable(bEnabled);
            oPage:SetBackgroundColour(tArt.color(bEnabled and "Page Normal" or "Page Disabled"));
            oPage:Refresh(false);
        end
    end;
    oComponent.pointer = function(sEvent, nX, nY)
        local nBefore = nRevision;
        local vHit = sEvent ~= "leave" and sEvent ~= "cancel" and fHit(nX, nY) or nil;
        if (vHover ~= vHit) then
            if (type(vHover) == "number") then
                tEvents.emit("itemLeft", {Index = vHover, Id = tItems[vHover].Id});
                if (nBefore ~= nRevision or oComponent.Disposed) then
                    return;
                end
            end
            vHover = vHit;
            if (type(vHover) == "number") then
                tEvents.emit("itemHovered", {Index = vHover, Id = tItems[vHover].Id});
                if (nBefore ~= nRevision or oComponent.Disposed) then
                    return;
                end
            end
            oComponent.refresh();
        end
        if (sEvent == "down") then
            vPressed = vHit;
        elseif (sEvent == "up" and vHit and vPressed == vHit) then
            if (type(vHit) == "number") then
                if (tItems[vHit].Enabled) then
                    oComponent.setValue(vHit, true);
                end
            else
                oComponent.scrollBy(vHit == "back" and -120 or 120);
            end
        end
    end;
    oComponent.key = function(nKey, tModifiers)
        if (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_UP) then
            return fStep(-1);
        elseif (nKey == _wx.WXK_RIGHT or nKey == _wx.WXK_DOWN) then
            return fStep(1);
        elseif (nKey == _wx.WXK_HOME or nKey == _wx.WXK_END) then
            for nPass = 1, #tItems do
                local nIndex = nKey == _wx.WXK_HOME and nPass or #tItems - nPass + 1;
                if (tItems[nIndex].Enabled) then
                    oComponent.setValue(nIndex, true);
                    return true;
                end
            end
        elseif (tModifiers and tModifiers.Command and (nKey == _wx.WXK_TAB
            or nKey == _wx.WXK_PAGEUP or nKey == _wx.WXK_PAGEDOWN)) then
            return fStep((nKey == _wx.WXK_PAGEUP or tModifiers.Shift) and -1 or 1);
        end
        return false;
    end;
    oComponent.wheel = function(nSteps)
        oComponent.scrollBy(-nSteps * 80);
    end;
    oComponent.Control:Connect(_wx.wxEVT_CHAR_HOOK, function(jEvent)
        local nKey = jEvent:GetKeyCode();
        if ((jEvent:ControlDown() or jEvent:MetaDown()) and (nKey == _wx.WXK_TAB
            or nKey == _wx.WXK_PAGEUP or nKey == _wx.WXK_PAGEDOWN)
            and oComponent.handleKey("down", nKey, {Command = true, Shift = jEvent:ShiftDown()})) then
            return;
        end
        jEvent:Skip();
    end);
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then
            return;
        end
        local bEnabled = oComponent.isEnabled();
        tArt.part(oDC, bEnabled and "Surface Normal" or "Surface Disabled", 0, 0, nWidth, nHeight);
        for _, tEntry in ipairs(tPlan and tPlan.Entries or {}) do
            local tItem = tItems[tEntry.Index];
            local sState = (not bEnabled or not tItem.Enabled) and "Disabled" or vPressed == tEntry.Index and "Pressed"
                or vHover == tEntry.Index and "Hover" or "Normal";
            local sPart = tEntry.Index == oComponent.Value and "Tab Selected " or "Tab ";
            local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(tEntry.X, tEntry.Y, tEntry.Width, tEntry.Height));
            tArt.part(oDC, sPart..sState, tEntry.DrawX, tEntry.DrawY, tEntry.DrawWidth, tEntry.DrawHeight);
            if (tItem.Image) then
                tArt.image(oDC, tItem.Image, tEntry.DrawX + 10, tEntry.DrawY + 6, 24);
            end
            tArt.text(oDC, tItem.Text, tEntry.DrawX + (tItem.Image and 40 or 14), tEntry.DrawY + 9,
                bEnabled and tItem.Enabled);
            if (oComponent.Control:HasFocus() and tEntry.Index == oComponent.Value) then
                tArt.part(oDC, "Focus", tEntry.DrawX + 4, tEntry.DrawY + 32, math.max(1, tEntry.DrawWidth - 8), 2);
            end
            oClip:delete();
        end
        for _, tNav in ipairs({{"back", tPlan and tPlan.Back}, {"forward", tPlan and tPlan.Forward}}) do
            local sName, tRect = tNav[1], tNav[2];
            if (tRect and tRect.Width > 0 and tRect.Height > 0) then
                local bAvailable = bEnabled and (sName == "back" and tPlan.Offset > 0 or sName == "forward" and tPlan.Offset < tPlan.Maximum);
                local sState = not bAvailable and "Disabled" or vPressed == sName and "Pressed" or vHover == sName and "Hover" or "Normal";
                tArt.part(oDC, "Navigation "..sState, tRect.X, tRect.Y, tRect.Width, tRect.Height);
                local sText = tPlan.Vertical and (sName == "back" and "^" or "v") or (sName == "back" and "<" or ">");
                tArt.text(oDC, sText, tRect.X + (tRect.Width - 10) / 2, tRect.Y + (tRect.Height - 18) / 2, bAvailable);
            end
        end
    end;
    oComponent.onDestroy = tArt.destroy;
    oComponent.setItems(vInitial);
    if (tOptions.Value ~= nil) then
        oComponent.setValue(tOptions.Value);
    end
    tEvents = _Events.attach(oComponent, nil, {"itemsChanged", "selectionChanged", "itemHovered", "itemLeft",
        "positionChanged", "layoutModeChanged"});
    return oComponent;
end

return Tabs;
