local _wx        = require("wx");
local _Surface   = require("wxLuma.Core.ControlSurface");
local _Events    = require("wxLuma.Core.ControlEvents");
local _ListEx    = require("wxLuma.Widgets.ListEx");
local _Renderer  = require("wxLuma.Core.ListRowRenderer");
local _Artwork   = require("wxLuma.Core.ControlArtwork");
local _Checks    = require("wxLuma.Core.ControlChecks");
local _Selection = require("wxLuma.Core.ControlSelection");
local _finite    = require("wxLuma.Core.ControlNumeric").finite;
local TreeEx     = {};

--[[!
@fqxn wxLuma.UI.TreeEx.create
@desc Creates a skinned typed-column hierarchy with stable node IDs. Only expanded
    visible rows are painted. Independent checkboxes default off, as does multi-
    selection. Checks survive collapsed branches and propagate downward by default;
    set CheckPropagation=false for independent node checks.
@param wxWindow oParent Native owner.
@param table tOptions Skin, Columns (ListEx definitions), nested Items with Id,
    optional Text/Image/Value/Expanded/Children and typed data fields. Image is a
    node icon directly before its hierarchy label, independent of image columns.
    Optional Value
    (selected ID), Checkboxes, Checked (IDs), CheckPropagation (true), MultiSelect,
    RowHeight (32), Indent
    (18), HierarchyColumn (1), Artwork (TreeEx), OnChange, OnActivate, OnCheckChange.
@ret table oTree Standard surface/events, typed data, hierarchy and checkbox APIs.
!]]
function TreeEx.create(oParent, tOptions)
    assert(tOptions and tOptions.Skin, "TreeEx requires Skin.");
    assert(tOptions.Checkboxes == nil or type(tOptions.Checkboxes) == "boolean", "Invalid Checkboxes.");
    assert(tOptions.MultiSelect == nil or type(tOptions.MultiSelect) == "boolean", "Invalid MultiSelect.");
    assert(tOptions.CheckPropagation == nil or type(tOptions.CheckPropagation) == "boolean", "Invalid CheckPropagation.");
    local bPropagation = tOptions.CheckPropagation ~= false;
    local tColumns = tOptions.Columns or {{Key = "Text", Type = "text", Title = "Name"}};
    local oValidator = _Renderer.create(tColumns, tOptions.Skin);
    local nHierarchy = tOptions.HierarchyColumn == nil and 1 or tOptions.HierarchyColumn;
    local nIndent = tOptions.Indent == nil and 18 or tOptions.Indent;
    assert(_finite(nHierarchy) and nHierarchy % 1 == 0 and tColumns[nHierarchy], "Invalid HierarchyColumn.");
    assert(_finite(nIndent) and nIndent % 1 == 0 and nIndent >= 8 and nIndent <= 64, "Invalid Indent.");
    local nRowHeight = tOptions.RowHeight == nil and 32 or tOptions.RowHeight;
    assert(_finite(nRowHeight) and nRowHeight % 1 == 0 and nRowHeight >= 20, "Invalid RowHeight.");
    assert(tOptions.Artwork == nil or (type(tOptions.Artwork) == "string" and tOptions.Artwork:find("%S")),
        "Invalid Artwork prefix.");
    local tNodes, tRoots, tOrder = {}, {}, {};
    local tVisible, tIndex = {}, {};
    local tEvents, tChecks;
    local oRows;
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "TreeEx");
    local tLastSelected, sLastValue = {}, nil;
    local sPrefixId, sPrefixRole;
    local bRebuilding = false;
    local bCheckSpaceDown = false;

    --[[!
    @fqxn wxLuma.UI.TreeEx.fNormalize
    @desc Validates/copies a complete hierarchy before mutation, rejecting cycles,
        shared child arrays, duplicate IDs and typed-cell mismatches.
    !]]
    local function fNormalize(tSource)
        local tNew, tNewRoots, tNewOrder, tSeen = {}, {}, {}, {};
        --[[!
        @fqxn wxLuma.UI.TreeEx.fNormalize.fVisit
        @desc Copies one child array while recording unique IDs and parent/depth metadata.
        !]]
        local function fVisit(tItems, sParent, nDepth)
            assert(type(tItems) == "table" and not tSeen[tItems], "Invalid/cyclic Children array.");
            tSeen[tItems] = true;
            local nCount = 0;
            for nKey in pairs(tItems) do
                nCount = nCount + 1;
                assert(type(nKey) == "number" and nKey % 1 == 0 and nKey >= 1 and nKey <= #tItems,
                    "Tree items must be a dense array.");
            end
            assert(nCount == #tItems, "Tree items must be a dense array.");
            local tChildren = {};
            for _, tItem in ipairs(tItems) do
                assert(type(tItem) == "table" and type(tItem.Id) == "string" and tItem.Id ~= ""
                    and not tNew[tItem.Id], "Invalid/duplicate tree Id.");
                assert(tItem.Text == nil or type(tItem.Text) == "string", "Invalid node Text.");
                assert(tItem.Expanded == nil or type(tItem.Expanded) == "boolean", "Invalid Expanded.");
                assert(tItem.Image == nil or type(tItem.Image) == "string", "Node Image must be a path or nil.");
                tArt.prepare(tItem.Image);
                local tData = {};
                for sKey, vValue in pairs(tItem) do
                    if (sKey ~= "Children" and sKey ~= "Expanded") then
                        tData[sKey] = vValue;
                    end
                end
                tData.Text = tData.Text or tItem.Id;
                tData = oValidator.copyItem(tData);
                local bExpanded = tItem.Expanded;
                if (bExpanded == nil) then
                    bExpanded = tNodes[tItem.Id] and tNodes[tItem.Id].Expanded or false;
                end
                local tNode = {Id = tItem.Id, Data = tData, Parent = sParent, Depth = nDepth,
                    Expanded = bExpanded, Children = {}};
                tNew[tItem.Id] = tNode;
                tNewOrder[#tNewOrder + 1] = tItem.Id;
                tChildren[#tChildren + 1] = tItem.Id;
                if (tItem.Children ~= nil) then
                    tNode.Children = fVisit(tItem.Children, tItem.Id, nDepth + 1);
                end
                if (#tNode.Children == 0) then
                    tNode.Expanded = false;
                end
            end
            return tChildren;
        end
        tNewRoots = fVisit(tSource, nil, 0);
        return tNew, tNewRoots, tNewOrder;
    end
    tNodes, tRoots, tOrder = fNormalize(tOptions.Items or {});
    assert(tOptions.Value == nil or tNodes[tOptions.Value], "Unknown initial TreeEx selection.");
    _Selection.validate(tOptions.Checked or {}, function(sId)
        return tNodes[sId] ~= nil;
    end, true);
    local oTree = _Surface.create(oParent, tOptions, "TreeEx");

    --[[!
    @fqxn wxLuma.UI.TreeEx.getValue
    @desc Returns the selected primary stable ID, or nil.
    @ret string|nil sId Primary selected node.
    !]]
    function oTree.getValue()
        local tNode = oRows and tVisible[oRows.getValue()];
        return tNode and tNode.Id or nil;
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.getSelected
    @desc Returns selected IDs in visible tree order, always as an independent array.
    @ret table tIds Selected stable IDs.
    !]]
    function oTree.getSelected()
        local tIds = {};
        for _, nIndex in ipairs(oRows and oRows.getSelected() or {}) do
            if (tVisible[nIndex]) then
                tIds[#tIds + 1] = tVisible[nIndex].Id;
            end
        end
        return tIds;
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.fPublish
    @desc Converts the row engine's numeric selection into stable-ID snapshots.
    !]]
    local function fPublish(bNotify)
        local sValue = oTree.getValue();
        local tSelected = oTree.getSelected();
        local sOld, tOld = sLastValue, tLastSelected;
        local bChanged = sOld ~= sValue or not _Selection.same(tOld, tSelected);
        sLastValue, tLastSelected, oTree.Value = sValue, tSelected, sValue;
        if (bNotify and bChanged and tEvents) then
            if (sOld ~= sValue) then
                tEvents.emit("valueChanged", {Value = sValue, OldValue = sOld});
            end
            tEvents.emit("selectionChanged", {Value = sValue, OldValue = sOld,
                Selected = _Selection.copy(tSelected), OldSelected = _Selection.copy(tOld)});
            if (oTree.OnChange) then
                oTree.OnChange(sValue, oTree, _Selection.copy(tSelected));
            end
        end
    end
    oRows = _ListEx.create(oTree.Control, {Skin = tOptions.Skin, Artwork = tOptions.Artwork or "TreeEx",
        Columns = tColumns, Items = {}, RowHeight = nRowHeight,
        MultiSelect = tOptions.MultiSelect, FocusNavigation = true,
        OnChange = function()
            if (not bRebuilding) then
                fPublish(true);
            end
        end});
    oTree.Rows = oRows;

    --[[!
    @fqxn wxLuma.UI.TreeEx.fRebuild
    @desc Rebuilds only the expanded row projection. Checks remain keyed by all
        node IDs; surviving visible selections are mapped back into row indices.
    !]]
    local function fRebuild(bNotify, sFallback)
        local tOld = _Selection.copy(tLastSelected);
        local sPrimary = sLastValue;
        tVisible, tIndex = {}, {};
        local tRows = {};
        --[[!
        @fqxn wxLuma.UI.TreeEx.fRebuild.fVisit
        @desc Projects only expanded branches into visible rows in tree order.
        !]]
        local function fVisit(tIds)
            for _, sId in ipairs(tIds) do
                local tNode = tNodes[sId];
                tVisible[#tVisible + 1] = tNode;
                tIndex[sId] = #tVisible;
                tRows[#tRows + 1] = tNode.Data;
                if (tNode.Expanded) then
                    fVisit(tNode.Children);
                end
            end
        end
        fVisit(tRoots);
        local tKeep = {};
        for _, sId in ipairs(tOld) do
            if (tIndex[sId] and sId ~= sPrimary) then
                tKeep[#tKeep + 1] = tIndex[sId];
            end
        end
        if (sPrimary and tIndex[sPrimary]) then
            tKeep[#tKeep + 1] = tIndex[sPrimary];
        elseif (sFallback and tIndex[sFallback] and #tKeep == 0 and #tOld > 0) then
            tKeep[1] = tIndex[sFallback];
        end
        bRebuilding = true;
        oRows.setItems(tRows);
        oRows.setSelected(tKeep);
        bRebuilding = false;
        if (tChecks) then
            tChecks.prune();
        end
        fPublish(bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.getItems
    @desc Returns independent nested descriptors. Application Value/nested data
        fields remain shallow references, matching ListEx cell semantics.
    @ret table tItems Ordered nested nodes with current expansion state.
    !]]
    function oTree.getItems()
        --[[!
        @fqxn wxLuma.UI.TreeEx.getItems.fCopy
        @desc Reconstructs independent ordered descriptor/Children arrays from stable nodes.
        !]]
        local function fCopy(tIds)
            local tCopy = {};
            for nIndex, sId in ipairs(tIds) do
                local tNode = tNodes[sId];
                local tItem = {};
                for sKey, vValue in pairs(tNode.Data) do
                    tItem[sKey] = vValue;
                end
                tItem.Expanded, tItem.Children = tNode.Expanded, fCopy(tNode.Children);
                tCopy[nIndex] = tItem;
            end
            return tCopy;
        end
        return fCopy(tRoots);
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.getNode
    @desc Returns a node's data and independent child-ID snapshot, even if collapsed.
    @param string sId Stable node ID.
    @ret table|nil tNode Data plus Parent, Depth, Expanded and Children IDs.
    !]]
    function oTree.getNode(sId)
        local tNode = tNodes[sId];
        if (tNode) then
            local tCopy = {};
            for sKey, vValue in pairs(tNode.Data) do
                tCopy[sKey] = vValue;
            end
            tCopy.Parent, tCopy.Depth, tCopy.Expanded = tNode.Parent, tNode.Depth, tNode.Expanded;
            tCopy.Children = _Selection.copy(tNode.Children);
            return tCopy;
        end
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.getChildren
    @desc Returns ordered child IDs; nil addresses root nodes.
    @param string|nil sParent Parent ID or nil.
    @ret table tIds Independent child IDs.
    !]]
    function oTree.getChildren(sParent)
        assert(sParent == nil or tNodes[sParent], "Unknown parent.");
        return _Selection.copy(sParent and tNodes[sParent].Children or tRoots);
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.setItems
    @desc Atomically replaces hierarchy, preserving check/selection identities for
        surviving IDs. Removed checks are pruned; hidden selections are removed.
    @param table tItems Nested descriptors.
    @param boolean|nil bNotify Notify item/selection changes.
    @ret table oTree This object.
    !]]
    function oTree.setItems(tItems, bNotify)
        assert(not oTree.Disposed, "TreeEx is disposed.");
        local tNew, tNewRoots, tNewOrder = fNormalize(tItems);
        oRows.cancel();
        sPrefixId, sPrefixRole = nil, nil;
        tNodes, tRoots, tOrder = tNew, tNewRoots, tNewOrder;
        local tImageItems = {};
        for nIndex, sId in ipairs(tOrder) do
            tImageItems[nIndex] = tNodes[sId].Data;
        end
        tArt.retain(tImageItems);
        fRebuild(bNotify);
        if (bNotify) then
            tEvents.emit("itemsChanged", {Count = #tOrder});
        end
        return oTree;
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.setSelected
    @desc Selects stable IDs atomically, expanding ancestors to reveal requested
        nodes. Multiple distinct IDs require MultiSelect to be enabled.
    @param table tIds Requested stable IDs.
    @param boolean|nil bNotify Notify effective selection changes.
    @ret table oTree This object.
    !]]
    function oTree.setSelected(tIds, bNotify)
        local tCopy = _Selection.validate(tIds, function(sId)
            return tNodes[sId] ~= nil;
        end, oRows.isMultiSelectEnabled());
        local bReveal = false;
        for _, sId in ipairs(tCopy) do
            local sParent = tNodes[sId].Parent;
            while (sParent) do
                if (not tNodes[sParent].Expanded) then
                    tNodes[sParent].Expanded = true;
                    bReveal = true;
                end
                sParent = tNodes[sParent].Parent;
            end
        end
        if (bReveal) then
            fRebuild(false);
        end
        local tIndices = {};
        for nIndex, sId in ipairs(tCopy) do
            tIndices[nIndex] = tIndex[sId];
        end
        oRows.setSelected(tIndices);
        fPublish(bNotify);
        return oTree;
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.setValue
    @desc Replaces selection with one stable ID; nil clears selection.
    @param string|nil sId Node ID or nil.
    @param boolean|nil bNotify Notify effective selection changes.
    @ret table oTree This object.
    !]]
    function oTree.setValue(sId, bNotify)
        return oTree.setSelected(sId == nil and {} or {sId}, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.isMultiSelectEnabled
    @desc Reports current selection mode, which defaults to false.
    @ret boolean bEnabled Whether modifier selection is enabled.
    !]]
    function oTree.isMultiSelectEnabled()
        return oRows.isMultiSelectEnabled();
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.setMultiSelectEnabled
    @desc Changes multi-selection policy; disabling retains the primary ID.
    @param boolean bFlag Requested mode.
    @param boolean|nil bNotify Notify selection and mode changes.
    @ret table oTree This object.
    !]]
    function oTree.setMultiSelectEnabled(bFlag, bNotify)
        local bOld = oRows.isMultiSelectEnabled();
        oRows.setMultiSelectEnabled(bFlag);
        fPublish(bNotify);
        if (bNotify and bOld ~= bFlag) then
            tEvents.emit("multiSelectChanged", {Enabled = bFlag});
        end
        return oTree;
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.setExpanded
    @desc Expands/collapses one branch. Collapsing removes hidden selections;
        if none remain, its parent becomes selected. Checks never change.
    @param string sId Existing node ID.
    @param boolean bExpanded Expanded policy; leaves remain collapsed.
    @param boolean|nil bNotify Notify expansion and resulting selection changes.
    @ret table oTree This object.
    !]]
    function oTree.setExpanded(sId, bExpanded, bNotify)
        assert(tNodes[sId] and type(bExpanded) == "boolean", "Invalid tree expansion.");
        local tNode = tNodes[sId];
        bExpanded = bExpanded and #tNode.Children > 0;
        if (tNode.Expanded ~= bExpanded) then
            tNode.Expanded = bExpanded;
            oRows.cancel();
            fRebuild(bNotify, sId);
            if (bNotify) then
                tEvents.emit(bExpanded and "itemExpanded" or "itemCollapsed", {Id = sId});
            end
        end
        return oTree;
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.fEdit
    @desc Finds one descriptor in a temporary nested snapshot for atomic edits.
    !]]
    local function fEdit(tItems, sId)
        for _, tItem in ipairs(tItems) do
            if (tItem.Id == sId) then
                return tItem;
            end
            local tFound = fEdit(tItem.Children, sId);
            if (tFound) then
                return tFound;
            end
        end
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.addNode
    @desc Appends a validated node/subtree beneath a parent or at root level.
    @param string|nil sParent Parent ID or nil.
    @param table tNode New descriptor/subtree with unique IDs.
    @param boolean|nil bNotify Notify items and itemAdded.
    @ret table oTree This object.
    !]]
    function oTree.addNode(sParent, tNode, bNotify)
        assert(sParent == nil or tNodes[sParent], "Unknown parent.");
        local tCopy = oTree.getItems();
        local tTarget = sParent and fEdit(tCopy, sParent).Children or tCopy;
        tTarget[#tTarget + 1] = tNode;
        oTree.setItems(tCopy, bNotify);
        if (bNotify) then
            tEvents.emit("itemAdded", {Id = tNode.Id, Parent = sParent});
        end
        return oTree;
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.removeNode
    @desc Removes an entire subtree and prunes its selected/checked identities.
    @param string sId Existing node ID.
    @param boolean|nil bNotify Notify items, selection and itemRemoved.
    @ret table oTree This object.
    !]]
    function oTree.removeNode(sId, bNotify)
        assert(tNodes[sId], "Unknown node.");
        local sParent = tNodes[sId].Parent;
        local tCopy = oTree.getItems();
        local tTarget = sParent and fEdit(tCopy, sParent).Children or tCopy;
        for nIndex, tItem in ipairs(tTarget) do
            if (tItem.Id == sId) then
                table.remove(tTarget, nIndex);
                break;
            end
        end
        oTree.setItems(tCopy, bNotify);
        if (bNotify) then
            tEvents.emit("itemRemoved", {Id = sId, Parent = sParent});
        end
        return oTree;
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.setItem
    @desc Patches node data without changing identity/children. Expansion has its
        own setter; use add/removeNode for structural changes.
    @param string sId Existing node ID.
    @param table tPatch Typed data fields.
    @param boolean|nil bNotify Notify items and itemChanged.
    @ret table oTree This object.
    !]]
    function oTree.setItem(sId, tPatch, bNotify)
        assert(tNodes[sId] and type(tPatch) == "table" and tPatch.Id == nil and tPatch.Children == nil
            and tPatch.Expanded == nil, "Invalid node patch.");
        local bChanged = false;
        for sKey, vValue in pairs(tPatch) do
            bChanged = bChanged or tNodes[sId].Data[sKey] ~= vValue;
        end
        if (not bChanged) then
            return oTree;
        end
        local tCopy = oTree.getItems();
        local tItem = fEdit(tCopy, sId);
        for sKey, vValue in pairs(tPatch) do
            tItem[sKey] = vValue;
        end
        oTree.setItems(tCopy, bNotify);
        if (bNotify) then
            tEvents.emit("itemChanged", {Id = sId, Item = oTree.getNode(sId)});
        end
        return oTree;
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.setNodeImage
    @desc Changes or clears the icon directly beside a node's hierarchy label.
        Image validation completes before live data changes. Other columns,
        selection, checks and expansion retain their existing state.
    @param string sId Existing node ID.
    @param string|nil pImage Image path, or nil to remove the node icon.
    @param boolean|nil bNotify Emit itemChanged and imageLoaded when applicable.
    @ret table oTree This object.
    !]]
    function oTree.setNodeImage(sId, pImage, bNotify)
        assert(not oTree.Disposed and tNodes[sId] and (pImage == nil or type(pImage) == "string"),
            "Invalid node image update.");
        if (tNodes[sId].Data.Image ~= pImage) then
            local tCopy = oTree.getItems();
            fEdit(tCopy, sId).Image = pImage;
            oTree.setItems(tCopy, bNotify);
            if (bNotify) then
                tEvents.emit("itemChanged", {Id = sId, Item = oTree.getNode(sId)});
                if (pImage) then
                    tEvents.emit("imageLoaded", {Id = sId, Path = pImage});
                end
            end
        end
        return oTree;
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.getCell
    @desc Returns one configured typed cell by stable node ID and column index.
    !]]
    function oTree.getCell(sId, nColumn)
        assert(tNodes[sId], "Unknown node.");
        return tNodes[sId].Data[oValidator.getColumnKey(nColumn)];
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.setCell
    @desc Replaces one typed cell atomically, preserving hierarchy, selection and
        checks. Structural fields cannot be edited as cells.
    !]]
    function oTree.setCell(sId, nColumn, vValue, bNotify)
        local vKey = oValidator.getColumnKey(nColumn);
        assert(vKey ~= "Id" and vKey ~= "Children" and vKey ~= "Expanded", "Structural field is not editable as a cell.");
        assert(tNodes[sId], "Unknown node.");
        if (tNodes[sId].Data[vKey] == vValue) then
            return oTree;
        end
        local tCopy = oTree.getItems();
        fEdit(tCopy, sId)[vKey] = vValue;
        oTree.setItems(tCopy, bNotify);
        if (bNotify) then
            tEvents.emit("cellChanged", {Id = sId, Column = nColumn, Value = vValue});
        end
        return oTree;
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.getColumns
    @desc Returns independent fixed column definitions, matching ListEx.
    !]]
    oTree.getColumns = oRows.getColumns;
    oTree.getItem = oTree.getNode;
    oTree.removeItem = oTree.removeNode;

    --[[!
    @fqxn wxLuma.UI.TreeEx.addItem
    @desc Standard item-first insertion alias for addNode(parent, node, notify).
    !]]
    function oTree.addItem(tNode, sParent, bNotify)
        return oTree.addNode(sParent, tNode, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.getVisible
    @desc Returns an independent display-order array of expanded visible node IDs.
    !]]
    function oTree.getVisible()
        local tIds = {};
        for nIndex, tNode in ipairs(tVisible) do
            tIds[nIndex] = tNode.Id;
        end
        return tIds;
    end
    oTree.onLayout = function(nWidth, nHeight)
        oRows.layout(4, 32, math.max(1, nWidth - 8), math.max(28, nHeight - 36));
    end;
    oTree.onEnable = function(bFlag)
        oRows.setEnabled(bFlag);
    end;
    oTree.onCancel = function()
        sPrefixId, sPrefixRole = nil, nil;
        oRows.cancel();
    end;
    oTree.onDestroy = function()
        oRows.destroy();
        oValidator.clear();
        tArt.destroy();
    end;
    oTree.draw = function(oDC, nWidth, nHeight)
        if (not oTree.Disposed) then
            tArt.part(oDC, oTree.isEnabled() and "Surface Normal" or "Surface Disabled", 0, 0, nWidth, nHeight);
            local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(4, 4, math.max(1, nWidth - 8), 28));
            for _, tColumn in ipairs(oRows.getColumnLayout(math.max(1, nWidth - 38))) do
                if (tColumn.Width > 0) then
                    local oCellClip = _wx.wxDCClipper(oDC, _wx.wxRect(8 + tColumn.X, 4, tColumn.Width, 28));
                    tArt.part(oDC, "Header", 8 + tColumn.X, 4, tColumn.Width, 28);
                    tArt.text(oDC, tColumn.Title, 14 + tColumn.X, 9, oTree.isEnabled());
                    oCellClip:delete();
                end
            end
            oClip:delete();
        end
    end;
    local fRowsPointer, fRowsKey = oRows.pointer, oRows.key;
    local fRowsCancel = oRows.onCancel;
    oRows.onCancel = function()
        sPrefixId, sPrefixRole = nil, nil;
        bCheckSpaceDown = false;
        if (fRowsCancel) then
            fRowsCancel();
        end
    end;
    oRows.getRowInsets = function(nIndex)
        local tNode = tVisible[nIndex];
        -- Node icons belong to the hierarchy prefix, not a separate data column.
        -- Reserve space only for this node's icon; other column origins stay fixed.
        return {[nHierarchy] = tNode.Depth * nIndent + 20 + (oTree.isCheckboxesEnabled() and 28 or 0)
            + (tNode.Data.Image and 24 or 0)};
    end;
    oRows.drawRowPrefix = function(oDC, nIndex, nX, nY, nWidth, nHeight)
        local tNode = tVisible[nIndex];
        local tColumn = oRows.getColumnLayout(nWidth)[nHierarchy];
        local nStart = nX + tColumn.X + tNode.Depth * nIndent;
        local nTop = nY + math.floor((nHeight - 20) / 2);
        if (tColumn.Width <= 0) then
            return;
        end
        local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(nX + tColumn.X, nY, tColumn.Width, nHeight));
        local sState = not oTree.isEnabled() and "Disabled" or sPrefixId == tNode.Id and "Pressed"
            or nIndex == oRows.HoverRow and "Hover" or "Normal";
        if (#tNode.Children > 0) then
            tArt.part(oDC, (tNode.Expanded and "Branch Open " or "Branch Closed ")..sState,
                nStart, nTop, 20, 20);
        end
        if (oTree.isCheckboxesEnabled()) then
            tArt.part(oDC, (oTree.isChecked(tNode.Id) and "Check On " or "Check Off ")..sState,
                nStart + 20, nTop, 20, 20);
        end
        if (tNode.Data.Image) then
            local nImageX = nStart + 26 + (oTree.isCheckboxesEnabled() and 28 or 0);
            local nImageSize = math.min(20, nHeight - 4);
            tArt.image(oDC, tNode.Data.Image, nImageX, nY + (nHeight - nImageSize) / 2, nImageSize);
        end
        oClip:delete();
    end;
    oRows.pointer = function(sEvent, nX, nY, tModifiers)
        local nWidth = oRows.Control:GetClientSizeWH();
        local nIndex = oRows.First + math.floor((nY - 4) / oRows.RowHeight);
        local tNode = tVisible[nIndex];
        local sRole;
        if (tNode and oRows.Hover and nY >= 4 and nIndex < oRows.First + oRows.getVisibleCount()) then
            local tColumn = oRows.getColumnLayout(math.max(1, nWidth - 30))[nHierarchy];
            local nStart = 4 + tColumn.X + tNode.Depth * nIndent;
            local nTop = 4 + (nIndex - oRows.First) * oRows.RowHeight + math.floor((oRows.RowHeight - 20) / 2);
            if (nX >= 4 + tColumn.X and nX < math.min(4 + tColumn.X + tColumn.Width, nWidth - 26)
                and nY >= nTop and nY < nTop + 20) then
                if (nX >= nStart and nX < nStart + 20 and #tNode.Children > 0) then
                    sRole = "branch";
                elseif (oTree.isCheckboxesEnabled() and nX >= nStart + 20 and nX < nStart + 40) then
                    sRole = "check";
                end
            end
        end
        if (sEvent == "down" and sRole) then
            sPrefixId, sPrefixRole = tNode.Id, sRole;
            oRows.focusItem(nIndex);
            oRows.refresh();
            return;
        elseif (sEvent == "up" and sPrefixId) then
            local sId, sAction = sPrefixId, sPrefixRole;
            sPrefixId, sPrefixRole = nil, nil;
            if (tNode and sId == tNode.Id and sAction == sRole and oRows.Pressed) then
                if (sAction == "check") then
                    oTree.setChecked(sId, not oTree.isChecked(sId), true);
                else
                    oTree.setExpanded(sId, not tNodes[sId].Expanded, true);
                end
            end
            oRows.refresh();
            return;
        end
        fRowsPointer(sEvent, nX, nY, tModifiers);
    end;
    oRows.key = function(nKey, tModifiers)
        local nFocus = oRows.getFocusedIndex();
        local tNode = tVisible[nFocus > 0 and nFocus or oRows.getValue()];
        if (nKey == _wx.WXK_SPACE and oTree.isCheckboxesEnabled()
            and not (tModifiers and (tModifiers.Command or tModifiers.Shift))) then
            if (not bCheckSpaceDown and tNode) then
                bCheckSpaceDown = true;
                oTree.setChecked(tNode.Id, not oTree.isChecked(tNode.Id), true);
            end
            return true;
        elseif (tNode and (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_RIGHT)) then
            if (nKey == _wx.WXK_LEFT) then
                if (tNode.Expanded) then
                    oTree.setExpanded(tNode.Id, false, true);
                elseif (tNode.Parent) then
                    oTree.setValue(tNode.Parent, true);
                end
            elseif (#tNode.Children > 0) then
                if (not tNode.Expanded) then
                    oTree.setExpanded(tNode.Id, true, true);
                else
                    oTree.setValue(tNode.Children[1], true);
                end
            end
            return true;
        elseif (tNode and (nKey == _wx.WXK_RETURN or nKey == _wx.WXK_NUMPAD_ENTER)) then
            tEvents.emit("itemActivated", {Id = tNode.Id});
            if (tOptions.OnActivate) then
                tOptions.OnActivate(tNode.Id, oTree);
            end
            return true;
        end
        return fRowsKey(nKey, tModifiers);
    end;
    oTree.key = oRows.key;
    local fRowHandleKey = oRows.handleKey;
    oRows.handleKey = function(sEvent, nKey, tModifiers)
        if (sEvent == "up" and nKey == _wx.WXK_SPACE) then
            local bHandled = bCheckSpaceDown;
            bCheckSpaceDown = false;
            return bHandled;
        end
        return fRowHandleKey(sEvent, nKey, tModifiers);
    end;
    oTree.handleKey = oRows.handleKey;
    for _, oTarget in ipairs({oTree.Control, oRows.Control}) do
        oTarget:Connect(_wx.wxEVT_KEY_UP, function(jEvent)
            if (jEvent:GetKeyCode() == _wx.WXK_SPACE) then
                bCheckSpaceDown = false;
            end
            jEvent:Skip();
        end);
    end

    oRows.Control:Connect(_wx.wxEVT_CHAR, function(jEvent)
        if (oTree.isCheckboxesEnabled() and jEvent:GetKeyCode() == _wx.WXK_SPACE
            and not jEvent:ControlDown() and not jEvent:MetaDown() and not jEvent:ShiftDown()) then
            return;
        end
        jEvent:Skip();
    end);
    tEvents = _Events.attach(oTree, {oRows.Control}, {"itemsChanged", "itemAdded", "itemRemoved", "itemChanged",
        "cellChanged", "selectionChanged", "multiSelectChanged", "itemExpanded", "itemCollapsed", "itemActivated",
        "checkChanged", "checkboxesChanged", "checkPropagationChanged", "itemHovered", "itemLeft"});

    -- Row indices are transient; publish the stable node identity for audio
    -- subscriptions on the tree rather than requiring callers to inspect Rows.
    for _, sEvent in ipairs({"itemHovered", "itemLeft"}) do
        oRows.on(sEvent, function(oSource, tEvent)
            local tNode = tVisible[tEvent.Index];
            if (tNode) then
                tEvents.emit(sEvent, {Id = tNode.Id, Index = tEvent.Index});
            end
        end);
    end
    tChecks = _Checks.attach(oTree, tEvents, tOptions, {
        keys = function()
            return _Selection.copy(tOrder);
        end,
        valid = function(sId)
            return tNodes[sId] ~= nil;
        end,
        refresh = function()
            oRows.refresh();
        end,
        refreshMany = function()
            oRows.refresh();
        end,
        payload = function(sId)
            return {Id = sId, Index = tIndex[sId]};
        end,
    });
    local fSetCheckedItems = oTree.setCheckedItems;
    local fSetChecked = oTree.setChecked;

    --[[!
    @fqxn wxLuma.UI.TreeEx.isCheckPropagationEnabled
    @desc Reports downward checkbox propagation, enabled by default. It includes
        collapsed descendants and does not automatically change ancestor state.
    @ret boolean bEnabled Whether node changes propagate to descendants.
    !]]
    function oTree.isCheckPropagationEnabled()
        return bPropagation;
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.setCheckPropagationEnabled
    @desc Changes future checkbox propagation without altering current checks.
    @param boolean bFlag Downward propagation policy.
    @param boolean|nil bNotify Emit checkPropagationChanged after a change.
    @ret table oTree This object.
    !]]
    function oTree.setCheckPropagationEnabled(bFlag, bNotify)
        assert(not oTree.Disposed and type(bFlag) == "boolean", "Invalid CheckPropagation flag.");
        if (bPropagation ~= bFlag) then
            bPropagation = bFlag;
            if (bNotify) then
                tEvents.emit("checkPropagationChanged", {Enabled = bFlag});
            end
        end
        return oTree;
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.fDescendants
    @desc Adds a node and every descendant to a temporary set, including collapsed nodes.
    !]]
    local function fDescendants(sId, tSet)
        tSet[sId] = true;
        for _, sChild in ipairs(tNodes[sId].Children) do
            fDescendants(sChild, tSet);
        end
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.setCheckedItems
    @desc Replaces checked membership atomically. With propagation enabled,
        requested branches include all descendants. Every effective node change
        emits its own event after the complete new check set has been installed.
    @param table tIds Stable IDs to check; all other nodes become unchecked.
    @param boolean|nil bNotify Notify per-node check changes.
    @ret table oTree This object.
    !]]
    function oTree.setCheckedItems(tIds, bNotify)
        if (not bPropagation) then
            return fSetCheckedItems(tIds, bNotify);
        end
        local tCopy = _Selection.validate(tIds, function(sId)
            return tNodes[sId] ~= nil;
        end, true);
        local tSet, tOrdered = {}, {};
        for _, sId in ipairs(tCopy) do
            fDescendants(sId, tSet);
        end
        for _, sId in ipairs(tOrder) do
            if (tSet[sId]) then
                tOrdered[#tOrdered + 1] = sId;
            end
        end
        return fSetCheckedItems(tOrdered, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.TreeEx.setChecked
    @desc Checks/unchecks one node and, by default, every descendant atomically.
        Turning propagation off restricts the update to the addressed node.
        Selection and expansion remain unchanged.
    @param string sId Existing node ID.
    @param boolean bFlag Requested state.
    @param boolean|nil bNotify Emit checkChanged for each effective node change.
    @ret table oTree This object.
    !]]
    function oTree.setChecked(sId, bFlag, bNotify)
        assert(not oTree.Disposed and tNodes[sId] and type(bFlag) == "boolean", "Invalid checkbox update.");
        if (not bPropagation) then
            return fSetChecked(sId, bFlag, bNotify);
        end
        local tAffected, tSet, tOrdered = {}, {}, {};
        fDescendants(sId, tAffected);
        for _, sChecked in ipairs(oTree.getChecked()) do
            tSet[sChecked] = true;
        end
        for sAffected in pairs(tAffected) do
            tSet[sAffected] = bFlag or nil;
        end
        for _, sNode in ipairs(tOrder) do
            if (tSet[sNode]) then
                tOrdered[#tOrdered + 1] = sNode;
            end
        end
        return fSetCheckedItems(tOrdered, bNotify);
    end
    local fCheckboxes = oTree.setCheckboxesEnabled;
    oTree.setCheckboxesEnabled = function(bFlag, bNotify)
        local bOld = oTree.isCheckboxesEnabled();
        fCheckboxes(bFlag, bNotify);
        if (bOld ~= bFlag) then
            oRows.refresh();
        end
        return oTree;
    end;
    fRebuild(false);
    oTree.setCheckedItems(tOptions.Checked or {});
    if (tOptions.Value) then
        oTree.setValue(tOptions.Value);
    end
    oTree.setEnabled(tOptions.Enabled ~= false);
    return oTree;
end

return TreeEx;
