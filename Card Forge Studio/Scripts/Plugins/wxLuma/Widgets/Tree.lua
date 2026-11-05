local _wx             = require("wx");
local _ControlSurface = require("wxLuma.Core.ControlSurface");
local _ControlEvents  = require("wxLuma.Core.ControlEvents");
local Tree            = {};

--[[!
@fqxn wxLuma.UI.Tree.create
@desc Creates a single-selection hierarchy using native tree input/accessibility
    inside the shared frame. Stable string IDs identify nodes independently of
    captions. The native tree owns item data; the parent owns native windows.
@param wxWindow oParent The native parent.
@param table tOptions Skin, Items (nested Id/Text/Value/Children/Expanded records),
    Value (selected ID or nil), Enabled and OnChange.
@ret table oComponent Public proxy with TreeControl and standard surface/events API.
!]]
function Tree.create(oParent, tOptions)
    local tInitial, tIds, tVisited = {}, {}, {};

    -- Validate the entire initial hierarchy before allocating native resources.
    local function fValidate(tItems, sParent)
        assert(type(tItems) == "table", "Tree Items/Children must be tables.");
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

    fValidate(tOptions.Items or {}, nil);
    assert(tOptions.Value == nil or tIds[tOptions.Value], "Unknown initial tree selection.");
    local oComponent = _ControlSurface.create(oParent, tOptions, "Tree");
    local oTree = _wx.wxTreeCtrl(oComponent.Control, _wx.wxID_ANY,
        _wx.wxDefaultPosition, _wx.wxDefaultSize,
        _wx.wxBORDER_NONE + _wx.wxTR_HAS_BUTTONS + _wx.wxTR_HIDE_ROOT + _wx.wxTR_LINES_AT_ROOT);
    oComponent.TreeControl = oTree;
    oTree:SetFont(oComponent.Skin.Font);
    oTree:SetBackgroundColour(_wx.wxColour(24, 29, 36));
    oTree:SetForegroundColour(_wx.wxColour(208, 218, 230));
    local oRoot = oTree:AddRoot("wxLuma root");
    local tNodes, tRoots = {}, {};
    local bInternal = false;
    local tEvents;

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
    @ret table tChildren Child IDs in insertion order.
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

    oComponent.onLayout = function(nWidth, nHeight)
        oTree:SetSize(4, 4, math.max(1, nWidth - 8), math.max(1, nHeight - 8));
    end;
    oComponent.onEnable = function(bEnabled)
        oTree:Enable(bEnabled);
    end;
    oComponent.pointer = function(sEvent)
        if (sEvent == "down") then
            oComponent.cancel();
            oTree:SetFocus();
        end
    end;
    oComponent.onDestroy = function()
        tNodes, tRoots = {}, {};
    end;
    tEvents = _ControlEvents.attach(oComponent, {oTree}, {
        "selectionChanged", "itemAdded", "itemRemoved", "itemChanged",
        "itemExpanded", "itemCollapsed", "itemActivated", "itemRightClick"
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
    return oComponent;
end

return Tree;