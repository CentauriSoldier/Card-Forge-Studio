local _Border = require("wxLuma.Core.ControlBorder");
local _Theme = require("wxLuma.Core.ControlTheme");
local _wx             = require("wx");
local _ControlSurface = require("wxLuma.Core.ControlSurface");
local _ControlEvents  = require("wxLuma.Core.ControlEvents");
local _Options        = require("wxLuma.Core.ControlOptions");
local Tree            = {};

--[[!
@fqxn wxLuma.UI.Tree.planMove
@desc Validates a same-tree move and resolves sibling positions before mutation.
    The destination index is measured after removing the source.
!]]
function Tree.planMove(tNodes, tRoots, sId, sParent, nIndex)
    local tNode = assert(tNodes[sId], "Unknown tree node.");
    assert(sParent == nil or tNodes[sParent], "Unknown tree parent.");
    local sAncestor = sParent;
    while (sAncestor) do
        assert(sAncestor ~= sId, "Cannot move a node into its own subtree.");
        sAncestor = tNodes[sAncestor].Parent;
    end
    local sOldParent = tNode.Parent;
    local tOld = sOldParent and tNodes[sOldParent].Children or tRoots;
    local tNew = sParent and tNodes[sParent].Children or tRoots;
    local nOldIndex;
    for nPosition, sChild in ipairs(tOld) do
        if (sChild == sId) then nOldIndex = nPosition; break; end
    end
    local nLast = #tNew + (tOld == tNew and 0 or 1);
    if (nIndex == nil) then nIndex = nLast; end
    assert(type(nIndex) == "number" and nIndex % 1 == 0 and nIndex >= 1 and nIndex <= nLast,
        "Invalid tree destination index.");
    return tOld, tNew, nOldIndex, nIndex, sOldParent;
end

--[[!
@fqxn wxLuma.UI.Tree.dropDestination
@desc Resolves a valid row drop to its parent and post-removal sibling index.
    Row quarters select before/after; the middle selects a child drop.
!]]
function Tree.dropDestination(tNodes, tRoots, sSource, sTarget, nFraction)
    if (not sSource or not sTarget or sSource == sTarget or not tNodes[sSource] or not tNodes[sTarget]) then return; end
    local sAncestor = sTarget;
    while (sAncestor) do
        if (sAncestor == sSource) then return; end
        sAncestor = tNodes[sAncestor].Parent;
    end
    if (nFraction >= 0.25 and nFraction < 0.75) then
        return {Parent = sTarget, Role = "inside"};
    end
    local sParent = tNodes[sTarget].Parent;
    local tSiblings = sParent and tNodes[sParent].Children or tRoots;
    local nIndex = 0;
    for _, sChild in ipairs(tSiblings) do
        if (sChild ~= sSource) then nIndex = nIndex + 1; end
        if (sChild == sTarget) then break; end
    end
    local bAfter = nFraction >= 0.75;
    return {Parent = sParent, Index = nIndex + (bAfter and 1 or 0), Role = bAfter and "after" or "before"};
end

--[[!
@fqxn wxLuma.UI.Tree.create
@desc Creates a single-selection hierarchy using native tree input/accessibility
    inside the shared frame. Stable string IDs identify nodes independently of
    captions. The native tree owns item data; the parent owns native windows.
@param wxWindow oParent The native parent.
@param table tOptions Skin, Items (nested Id/Text/Value/Children/Expanded records),
    Value (selected ID or nil), DragDrop (default true), Enabled and OnChange.
@ret table oComponent Public proxy with TreeControl and standard surface/events API.
!]]
function Tree.create(oParent, tOptions)
    tOptions = _Theme.options(tOptions, oParent);
    assert(tOptions.DragDrop == nil or type(tOptions.DragDrop) == "boolean", "Invalid tree DragDrop.");
    local tInitial, tIds, tVisited = {}, {}, {};

    -- Validate the entire initial hierarchy before allocating native resources.
    local function fValidate(tItems, sParent)
        -- Every level must be dense before its nodes are copied. A hole in a
        -- nested Children array must not discard the remaining branch silently.
        _Options.array(tItems);
        assert(not tVisited[tItems], "Tree hierarchy must not contain cycles/shared child arrays.");
        tVisited[tItems] = true;

        for _, tNode in ipairs(tItems) do
            assert(type(tNode) == "table" and type(tNode.Id) == "string" and tNode.Id ~= "",
                "Tree nodes require nonempty string IDs.");
            assert(type(tNode.Text) == "string" and not tIds[tNode.Id], "Invalid/duplicate tree node.");
            tIds[tNode.Id] = true;
            tInitial[#tInitial + 1] = {
                Id = tNode.Id, Text = tNode.Text, Value = tNode.Value,
                Parent = sParent, Expanded = tNode.Expanded == true
            };

            if (tNode.Children ~= nil) then
                fValidate(tNode.Children, tNode.Id);
            end
        end
    end

    local tSource = tOptions.Items;
    if (tSource == nil) then tSource = {}; end
    fValidate(tSource, nil);
    assert(tOptions.Value == nil or tIds[tOptions.Value], "Unknown initial tree selection.");
    local oComponent = _ControlSurface.create(oParent, _Border.hostOptions(tOptions), "Tree");
    local oTree = _wx.wxTreeCtrl(oComponent.Control, _wx.wxID_ANY,
        _wx.wxDefaultPosition, _wx.wxDefaultSize,
        _Border.style(tOptions, _wx.wxTR_HAS_BUTTONS + _wx.wxTR_HIDE_ROOT + _wx.wxTR_LINES_AT_ROOT));
    oComponent.TreeControl, oComponent.BorderControl = oTree, oTree;
    oTree:SetFont(oComponent.Skin.Font);
    oTree:SetBackgroundColour(_wx.wxColour(24, 29, 36));
    oTree:SetForegroundColour(_wx.wxColour(208, 218, 230));
    local oRoot = oTree:AddRoot("wxLuma root");
    local tNodes, tRoots = {}, {};
    local bInternal = false;
    local tEvents;
    local tDrag, oInsertLine;

    -- Resolve IDs through native-owned item data; wxLua userdata identity is not
    -- stable when the same native pointer is returned through different classes.
    local function fId(oItem)
        if (oItem and oItem:IsOk()) then
            local oData = oTree:GetItemData(oItem);

            if (oData) then
                return oData:GetData();
            end
        end
    end

    --[[!
    @fqxn wxLuma.UI.Tree.clearDrag
    @desc Removes visual feedback and releases capture owned by this gesture.
    !]]
    local function fClearDrag()
        local tOld = tDrag;
        tDrag = nil;
        if (not tOld) then return; end
        if (tOld.Role == "inside" and tNodes[tOld.Target]) then
            oTree:SetItemDropHighlight(tNodes[tOld.Target].Item, false);
        end
        if (oInsertLine) then oInsertLine:Show(false); end
        if (tOld.Captured and oTree:HasCapture()) then oTree:ReleaseMouse(); end
    end

    -- Keep semantic notifications tied to stable IDs and actual value changes.
    local function fSelection(sId, bNotify)
        if (oComponent.Value ~= sId) then
            local sOldValue = oComponent.Value;
            oComponent.Value = sId;

            if (bNotify and tEvents) then
                if (oComponent.OnChange) then
                    oComponent.OnChange(sId, oComponent);
                end

                tEvents.emit("valueChanged", {Value = sId, OldValue = sOldValue});
                tEvents.emit("selectionChanged", {Value = sId, OldValue = sOldValue});
            end
        end
    end

    --[[!
    @fqxn wxLuma.UI.Tree.getNode
    @desc Returns a node snapshot. Value is application-owned data and is not cloned.
    @param string sId The node ID.
    @ret table|nil tNode Id, Text, Value, Parent and current Expanded state.
    !]]
    function oComponent.getNode(sId)
        local tNode = tNodes[sId];

        if (tNode and not oComponent.Disposed) then
            return {
                Id = sId, Text = tNode.Text, Value = tNode.Value,
                Parent = tNode.Parent, Expanded = oTree:IsExpanded(tNode.Item)
            };
        end
    end

    --[[!
    @fqxn wxLuma.UI.Tree.getChildren
    @desc Returns an independent ordered array of child IDs; nil selects roots.
    @param string|nil sParent The parent ID or nil.
    @ret table tChildren Child IDs in current sibling order.
    !]]
    function oComponent.getChildren(sParent)
        assert(sParent == nil or tNodes[sParent], "Unknown tree parent.");
        local tSource = sParent and tNodes[sParent].Children or tRoots;
        local tCopy = {};

        for nIndex, sId in ipairs(tSource) do
            tCopy[nIndex] = sId;
        end

        return tCopy;
    end

    --[[!
    @fqxn wxLuma.UI.Tree.addNode
    @desc Appends one leaf node beneath a parent or at the root. Add descendants
        with subsequent calls; use Items for an initial nested hierarchy.
    @param string|nil sParent The parent ID or nil.
    @param table tNode A unique Id, Text and optional application Value.
    @param boolean|nil bNotify Whether to emit itemAdded; default silent.
    @ret table oComponent This component.
    !]]
    function oComponent.addNode(sParent, tNode, bNotify)
        assert(not oComponent.Disposed, "Cannot add nodes to a disposed tree.");
        assert(sParent == nil or tNodes[sParent], "Unknown tree parent.");
        assert(type(tNode) == "table" and type(tNode.Id) == "string" and tNode.Id ~= ""
            and type(tNode.Text) == "string" and not tNodes[tNode.Id], "Invalid/duplicate tree node.");
        assert(tNode.Children == nil, "addNode accepts one node; add children separately.");
        local oItem = oTree:AppendItem(sParent and tNodes[sParent].Item or oRoot, tNode.Text);
        oTree:SetItemData(oItem, _wx.wxLuaTreeItemData(tNode.Id));
        tNodes[tNode.Id] = {
            Text = tNode.Text, Value = tNode.Value, Parent = sParent, Item = oItem, Children = {}
        };
        local tChildren = sParent and tNodes[sParent].Children or tRoots;
        tChildren[#tChildren + 1] = tNode.Id;

        if (bNotify) then
            tEvents.emit("itemAdded", {Id = tNode.Id, Parent = sParent});
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Tree.setValue
    @desc Selects a known node and reveals its ancestors, or clears selection with
        nil. Native selection events are suppressed during programmatic changes.
    @param string|nil sId The node ID or nil.
    @param boolean|nil bNotify Whether changed selection notifies; default silent.
    @ret table oComponent This component.
    !]]
    function oComponent.setValue(sId, bNotify)
        assert(sId == nil or tNodes[sId], "Unknown tree selection.");

        if (oComponent.Disposed or sId == oComponent.Value) then
            return oComponent;
        end

        bInternal = true;

        if (sId) then
            oTree:SelectItem(tNodes[sId].Item);
            oTree:EnsureVisible(tNodes[sId].Item);
        else
            oTree:UnselectAll();
        end

        bInternal = false;
        fSelection(sId, bNotify);
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Tree.setExpanded
    @desc Expands/collapses a node. Leaf nodes remain collapsed. Optional semantic
        notification is emitted only when the native expanded state changes.
    @param string sId The node ID.
    @param boolean bExpanded Whether to expand.
    @param boolean|nil bNotify Whether to notify; default silent.
    @ret table oComponent This component.
    !]]
    function oComponent.setExpanded(sId, bExpanded, bNotify)
        assert(tNodes[sId] and type(bExpanded) == "boolean", "Invalid tree expansion.");

        if (oComponent.Disposed) then
            return oComponent;
        end

        local oItem = tNodes[sId].Item;
        local bBefore = oTree:IsExpanded(oItem);
        bInternal = true;

        if (bExpanded) then
            oTree:Expand(oItem);
        else
            oTree:Collapse(oItem);
        end

        bInternal = false;
        local bAfter = oTree:IsExpanded(oItem);

        -- Native trees may select the parent when collapsing its selected
        -- descendant. Synchronize that side effect under the same notify flag.
        fSelection(fId(oTree:GetSelection()), bNotify);

        if (bNotify and bBefore ~= bAfter) then
            tEvents.emit(bAfter and "itemExpanded" or "itemCollapsed", {Id = sId});
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Tree.moveNode
    @desc Moves a subtree within this tree, preserving IDs, value, and selection.
    @param string sId Source node.
    @param string|nil sParent Destination parent or nil for the root.
    @param number|nil nIndex One-based destination after removal, or nil to append.
    @param boolean|nil bNotify Emit itemMoved on a real change.
    @ret table oComponent This tree.
    !]]
    function oComponent.moveNode(sId, sParent, nIndex, bNotify)
        assert(not oComponent.Disposed, "Cannot move nodes in a disposed tree.");
        local tOld, tNew, nOldIndex, nNextIndex, sOldParent = Tree.planMove(tNodes, tRoots, sId, sParent, nIndex);
        if (tOld == tNew and nOldIndex == nNextIndex) then return oComponent; end
        fClearDrag();
        local oOldItem = tNodes[sId].Item;
        local oDestination = sParent and tNodes[sParent].Item or oRoot;
        local oNewItem;
        -- The insertion anchor excludes the old source, which is still native until
        -- the replacement subtree has been populated.
        if (nNextIndex > 1) then
            local nAnchor = nNextIndex - 1;
            if (tOld == tNew and nAnchor >= nOldIndex) then nAnchor = nAnchor + 1; end
            oNewItem = oTree:InsertItem(oDestination, tNodes[tNew[nAnchor]].Item, tNodes[sId].Text);
        else
            oNewItem = oTree:PrependItem(oDestination, tNodes[sId].Text);
        end
        bInternal = true;
        local tPending = {{Id = sId, Item = oNewItem}};
        local tExpanded = {};
        for _, tEntry in ipairs(tPending) do
            local tNode = tNodes[tEntry.Id];
            if (oTree:IsExpanded(tNode.Item)) then tExpanded[#tExpanded + 1] = tEntry.Item; end
            tNode.Item = tEntry.Item;
            oTree:SetItemData(tEntry.Item, _wx.wxLuaTreeItemData(tEntry.Id));
            for _, sChild in ipairs(tNode.Children) do
                local oChild = oTree:AppendItem(tEntry.Item, tNodes[sChild].Text);
                tPending[#tPending + 1] = {Id = sChild, Item = oChild};
            end
        end
        oTree:Delete(oOldItem);
        table.remove(tOld, nOldIndex);
        table.insert(tNew, nNextIndex, sId);
        tNodes[sId].Parent = sParent;
        for _, oItem in ipairs(tExpanded) do oTree:Expand(oItem); end
        if (oComponent.Value) then
            local oSelected = tNodes[oComponent.Value].Item;
            oTree:EnsureVisible(oSelected);
            oTree:SelectItem(oSelected);
        else
            oTree:UnselectAll();
        end
        bInternal = false;
        if (bNotify) then
            tEvents.emit("itemMoved", {Id = sId, Parent = sParent, OldParent = sOldParent,
                Index = nNextIndex, OldIndex = nOldIndex});
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Tree.removeNode
    @desc Removes a node and its descendants. Removing the selected subtree
        clears selection once; unrelated selections retain their stable IDs.
    @param string sId The node ID.
    @param boolean|nil bNotify Whether removal/selection changes notify.
    @ret table oComponent This component.
    !]]
    function oComponent.removeNode(sId, bNotify)
        assert(tNodes[sId], "Unknown tree node.");

        if (oComponent.Disposed) then
            return oComponent;
        end

        fClearDrag();
        local tRemoved = {};
        local function fCollect(sCurrent)
            tRemoved[#tRemoved + 1] = sCurrent;

            for _, sChild in ipairs(tNodes[sCurrent].Children) do
                fCollect(sChild);
            end
        end

        fCollect(sId);
        local bClearSelection = false;

        for _, sRemoved in ipairs(tRemoved) do
            bClearSelection = bClearSelection or oComponent.Value == sRemoved;
        end

        local tNode = tNodes[sId];
        local tSiblings = tNode.Parent and tNodes[tNode.Parent].Children or tRoots;
        bInternal = true;

        if (bClearSelection) then
            oTree:UnselectAll();
        end

        oTree:Delete(tNode.Item);
        bInternal = false;

        for nIndex = #tSiblings, 1, -1 do
            if (tSiblings[nIndex] == sId) then
                table.remove(tSiblings, nIndex);
            end
        end

        for _, sRemoved in ipairs(tRemoved) do
            tNodes[sRemoved] = nil;
        end

        if (bClearSelection) then
            fSelection(nil, bNotify);
        end

        if (bNotify) then
            tEvents.emit("itemRemoved", {Id = sId, Removed = tRemoved});
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Tree.setNodeText
    @desc Renames a node without changing its identity, children or selection.
    @param string sId The stable node ID.
    @param string sText The replacement caption.
    @param boolean|nil bNotify Whether to emit itemChanged.
    @ret table oComponent This component.
    !]]
    function oComponent.setNodeText(sId, sText, bNotify)
        assert(not oComponent.Disposed and tNodes[sId] and type(sText) == "string", "Invalid tree caption.");
        local tNode = tNodes[sId];

        if (tNode.Text ~= sText) then
            local sOldText = tNode.Text;
            tNode.Text = sText;
            oTree:SetItemText(tNode.Item, sText);

            if (bNotify) then
                tEvents.emit("itemChanged", {Id = sId, Text = sText, OldText = sOldText});
            end
        end

        return oComponent;
    end
    oTree:Connect(_wx.wxEVT_COMMAND_TREE_SEL_CHANGED, function(jEvent)
        if (not bInternal and not oComponent.Disposed) then
            fSelection(fId(jEvent:GetItem()), true);
        end

        jEvent:Skip();
    end);

    for _, tBinding in ipairs({
        {_wx.wxEVT_COMMAND_TREE_ITEM_EXPANDED, "itemExpanded"},
        {_wx.wxEVT_COMMAND_TREE_ITEM_COLLAPSED, "itemCollapsed"},
        {_wx.wxEVT_COMMAND_TREE_ITEM_ACTIVATED, "itemActivated"},
        {_wx.wxEVT_COMMAND_TREE_ITEM_RIGHT_CLICK, "itemRightClick"}
    }) do
        local sEvent = tBinding[2];
        oTree:Connect(tBinding[1], function(jEvent)
            if (not bInternal and not oComponent.Disposed) then
                tEvents.emit(sEvent, {Id = fId(jEvent:GetItem())});
            end

            jEvent:Skip();
        end);
    end

    if (tOptions.DragDrop ~= false) then
        --[[!
        @fqxn wxLuma.UI.Tree.updateDrop
        @desc Resolves the release action and updates the corresponding native cue.
        !]]
        local function fUpdateDrop(nX, nY)
            local sTarget, nTop, nRowHeight, tDrop;
            local nWidth, nHeight = oTree:GetClientSizeWH();
            if (oComponent.isEnabled() and nX >= 0 and nX < nWidth and nY >= 0 and nY < nHeight) then
                local oPoint = _wx.wxPoint(nX, nY);
                local oItem = oTree:HitTest(oPoint);
                oPoint:delete();
                sTarget = fId(oItem);
                if (sTarget) then
                    local oRect = _wx.wxRect();
                    if (oTree:GetBoundingRect(oItem, oRect, false)) then
                        nTop, nRowHeight = oRect:GetY(), oRect:GetHeight();
                        local nFraction = (nY - nTop) / math.max(1, nRowHeight);
                        if (nFraction >= 0 and nFraction < 1) then
                            tDrop = Tree.dropDestination(tNodes, tRoots, tDrag.Id, sTarget, nFraction);
                        end
                    end
                    oRect:delete();
                end
            end

            local sRole = tDrop and tDrop.Role;
            if (tDrag.Role == "inside" and (sRole ~= "inside" or tDrag.Target ~= sTarget)) then
                oTree:SetItemDropHighlight(tNodes[tDrag.Target].Item, false);
            end
            if (not sRole or sRole == "inside") then
                if (oInsertLine and oInsertLine:IsShown()) then oInsertLine:Show(false); end
                if (sRole == "inside" and (tDrag.Role ~= sRole or tDrag.Target ~= sTarget)) then
                    oTree:SetItemDropHighlight(tNodes[sTarget].Item, true);
                end
            else
                -- A thin child window survives native repaint without painting
                -- over every row or relying on a transient client DC.
                if (not oInsertLine) then
                    oInsertLine = _wx.wxPanel(oTree, _wx.wxID_ANY, _wx.wxDefaultPosition, _wx.wxDefaultSize, _wx.wxBORDER_NONE);
                    oInsertLine:SetName("Tree drop insertion line");
                end
                if (not oInsertLine:IsShown() or tDrag.Role ~= sRole or tDrag.Target ~= sTarget) then
                    local oColour = _Theme.colour(oComponent.Skin, "Selection", 55, 130, 220);
                    oInsertLine:SetBackgroundColour(oColour); oColour:delete();
                end
                local nLineY = sRole == "before" and nTop or nTop + nRowHeight - 2;
                oInsertLine:SetSize(1, nLineY, math.max(1, nWidth - 2), 2);
                oInsertLine:Show(true);
            end
            tDrag.Target, tDrag.Role = sTarget, sRole;
            return tDrop, sTarget;
        end

        oTree:Connect(_wx.wxEVT_COMMAND_TREE_BEGIN_DRAG, function(jEvent)
            -- Keep native drag detection. Supply our own feedback so the native
            -- drag image handler cannot highlight every drop as a child drop.
            jEvent:Veto();
            fClearDrag();
            local sSource = oComponent.isEnabled() and fId(jEvent:GetItem());
            if (not sSource) then return; end
            tDrag = {Id = sSource, Captured = not oTree:HasCapture()};
            if (tDrag.Captured) then oTree:CaptureMouse(); end
            local oPoint = jEvent:GetPoint();
            fUpdateDrop(oPoint:GetX(), oPoint:GetY());
        end);
        oTree:Connect(_wx.wxEVT_MOTION, function(jEvent)
            if (not tDrag) then jEvent:Skip(); return; end
            fUpdateDrop(jEvent:GetX(), jEvent:GetY());
        end);
        oTree:Connect(_wx.wxEVT_LEFT_UP, function(jEvent)
            if (not tDrag) then jEvent:Skip(); return; end
            local sSource = tDrag.Id;
            local tDrop, sTarget = fUpdateDrop(jEvent:GetX(), jEvent:GetY());
            fClearDrag();
            if (tDrop) then
                oComponent.moveNode(sSource, tDrop.Parent, tDrop.Index, true);
                if (tDrop.Role == "inside" and not oComponent.Disposed
                    and tNodes[sSource] and tNodes[sSource].Parent == sTarget) then
                    oComponent.setExpanded(sTarget, true);
                end
            end
        end);
        oTree:Connect(_wx.wxEVT_MOUSE_CAPTURE_LOST, function(jEvent)
            fClearDrag();
            jEvent:Skip();
        end);
        oTree:Connect(_wx.wxEVT_KEY_DOWN, function(jEvent)
            if (tDrag and jEvent:GetKeyCode() == _wx.WXK_ESCAPE) then
                fClearDrag();
                return;
            end
            jEvent:Skip();
        end);
    end

    oComponent.onLayout = function(nWidth, nHeight)
        oTree:SetSize(4, 4, math.max(1, nWidth - 8), math.max(1, nHeight - 8));
    end;
    oComponent.onEnable = function(bEnabled)
        if (not bEnabled) then fClearDrag(); end
        oTree:Enable(bEnabled);
    end;
    oComponent.pointer = function(sEvent)
        if (sEvent == "down") then
            oComponent.cancel();
            oTree:SetFocus();
        end
    end;
    oComponent.onDestroy = function()
        fClearDrag();
        tNodes, tRoots = {}, {};
    end;
    tEvents = _ControlEvents.attach(oComponent, {oTree}, {
        "selectionChanged", "itemAdded", "itemRemoved", "itemChanged",
        "itemExpanded", "itemCollapsed", "itemActivated", "itemRightClick", "itemMoved"
    });

    for _, tNode in ipairs(tInitial) do
        oComponent.addNode(tNode.Parent, {Id = tNode.Id, Text = tNode.Text, Value = tNode.Value});
    end

    for _, tNode in ipairs(tInitial) do
        if (tNode.Expanded) then
            oComponent.setExpanded(tNode.Id, true);
        end
    end

    oComponent.setValue(tOptions.Value);
    oComponent.onEnable(tOptions.Enabled ~= false);
    _Theme.finish(oComponent, tOptions);
    return oComponent;
end

return Tree;
