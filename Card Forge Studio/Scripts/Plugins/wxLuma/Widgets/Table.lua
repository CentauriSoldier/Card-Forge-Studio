local _wx             = require("wx");
local _ControlSurface = require("wxLuma.Core.ControlSurface");
local _ControlEvents  = require("wxLuma.Core.ControlEvents");
local _Selection      = require("wxLuma.Core.ControlSelection");
local Table           = {};

--[[!
@fqxn wxLuma.UI.Table.create
@desc Creates a report table with optional runtime multi-selection with native column headers and
    keyboard/accessibility behavior inside the shared frame. Stable string IDs
    survive sorting and replacement. Cells are strings; sorting is lexical.
@param wxWindow oParent The native parent.
@param table tOptions Skin, Columns (Text/Width records), Items (Id/Cells/Value
    records), Value (primary selected ID or nil), MultiSelect (false), Enabled
    and OnChange. getSelected always returns an array of stable selected row IDs.
@ret table oComponent Public proxy with TableControl and standard surface/events API.
!]]
function Table.create(oParent, tOptions)
    assert(type(tOptions.Columns) == "table" and #tOptions.Columns > 0, "Table requires Columns.");
    local tColumns = {};

    for nIndex, tColumn in ipairs(tOptions.Columns) do
        assert(type(tColumn) == "table" and type(tColumn.Text) == "string", "Invalid table column.");
        local nWidth = tColumn.Width or 160;
        assert(type(nWidth) == "number" and nWidth > 0 and nWidth < math.huge and nWidth % 1 == 0,
            "Column Width must be a positive integer.");
        tColumns[nIndex] = {Text = tColumn.Text, Width = nWidth};
    end

    -- Own structural copies so caller edits cannot desynchronize native rows.
    local function fRows(tItems)
        assert(type(tItems) == "table", "Table Items must be an array.");
        local tRows, tIds = {}, {};

        for nIndex, tRow in ipairs(tItems) do
            assert(type(tRow) == "table" and type(tRow.Id) == "string" and tRow.Id ~= ""
                and not tIds[tRow.Id] and type(tRow.Cells) == "table", "Invalid/duplicate table row.");
            assert(#tRow.Cells == #tColumns, "Row cell count must match Columns.");
            local tCells = {};

            for nColumn = 1, #tColumns do
                assert(type(tRow.Cells[nColumn]) == "string", "Table cells must be strings.");
                tCells[nColumn] = tRow.Cells[nColumn];
            end

            tRows[nIndex] = {Id = tRow.Id, Cells = tCells, Value = tRow.Value};
            tIds[tRow.Id] = nIndex;
        end

        return tRows, tIds;
    end

    local tRows, tIndices = fRows(tOptions.Items or {});
    assert(tOptions.Value == nil or tIndices[tOptions.Value], "Unknown initial table selection.");
    assert(tOptions.MultiSelect == nil or type(tOptions.MultiSelect) == "boolean", "MultiSelect must be boolean.");
    local bMulti = tOptions.MultiSelect == true;
    local tSelected = {};
    local sFocus;
    local oComponent = _ControlSurface.create(oParent, tOptions, "Table");
    local oTable = _wx.wxListCtrl(oComponent.Control, _wx.wxID_ANY,
        _wx.wxDefaultPosition, _wx.wxDefaultSize,
        _wx.wxBORDER_NONE + _wx.wxLC_REPORT + (bMulti and 0 or _wx.wxLC_SINGLE_SEL));
    oComponent.TableControl = oTable;
    oTable:SetFont(oComponent.Skin.Font);
    oTable:SetBackgroundColour(_wx.wxColour(24, 29, 36));
    oTable:SetTextColour(_wx.wxColour(208, 218, 230));
    local bInternal = false;
    local bPendingDeselection = false;
    local nSortColumn, sSortDirection;
    local tEvents;

    for nIndex, tColumn in ipairs(tColumns) do
        oTable:InsertColumn(nIndex - 1, tColumn.Text, _wx.wxLIST_FORMAT_LEFT, tColumn.Width);
    end

    -- Read all native rows immediately, including selection changes awaiting idle.
    -- This keeps getters correct inside native callbacks without forcing events.
    local function fReadSelected()
        local tIds = {};
        local nIndex = oTable:GetNextItem(-1, _wx.wxLIST_NEXT_ALL, _wx.wxLIST_STATE_SELECTED);

        while (nIndex >= 0) do
            if (tRows[nIndex + 1]) then
                tIds[#tIds + 1] = tRows[nIndex + 1].Id;
            end

            nIndex = oTable:GetNextItem(nIndex, _wx.wxLIST_NEXT_ALL, _wx.wxLIST_STATE_SELECTED);
        end

        return tIds;
    end

    -- Focus is separate from selection for native Ctrl/Cmd navigation. Prefer a
    -- selected focused row, then the previous primary, then the first survivor.
    local function fPrimary(tIds)
        local nIndex = oTable:GetNextItem(-1, _wx.wxLIST_NEXT_ALL, _wx.wxLIST_STATE_FOCUSED);
        sFocus = tRows[nIndex + 1] and tRows[nIndex + 1].Id or nil;
        local bPrevious = false;

        for _, sId in ipairs(tIds) do
            if (sId == sFocus) then
                return sId;
            end

            bPrevious = bPrevious or sId == oComponent.Value;
        end

        return bPrevious and oComponent.Value or tIds[1];
    end

    -- Coalesce complete native selections rather than notifying for each row in
    -- a range. Programmatic setters use the same snapshot/event contract.
    local function fSelection(tIds, sPrimary, bNotify)
        local tOld = tSelected;
        local sOldValue = oComponent.Value;
        local bChanged = sOldValue ~= sPrimary or not _Selection.same(tOld, tIds);
        tSelected = _Selection.copy(tIds);
        oComponent.Value = sPrimary;

        if (bChanged and bNotify) then
            if (oComponent.OnChange) then
                oComponent.OnChange(sPrimary, oComponent, _Selection.copy(tSelected));
            end

            if (sOldValue ~= sPrimary) then
                tEvents.emit("valueChanged", {Value = sPrimary, OldValue = sOldValue});
            end

            tEvents.emit("selectionChanged", {
                Value = sPrimary, OldValue = sOldValue,
                Selected = _Selection.copy(tSelected), OldSelected = _Selection.copy(tOld)
            });
        end
    end

    -- Flush a pending native gesture before a row mutation or explicit setter.
    local function fFlush()
        if (bPendingDeselection) then
            bPendingDeselection = false;
            local tIds = fReadSelected();
            fSelection(tIds, fPrimary(tIds), true);
        end
    end

    -- Rebuild native rows under event suppression. Preserve the selected stable
    -- ID and keep native focus/selection states synchronized after reordering.
    local function fRender()
        bPendingDeselection = false;
        bInternal = true;
        oTable:Freeze();
        oTable:DeleteAllItems();
        tIndices = {};

        for nIndex, tRow in ipairs(tRows) do
            tIndices[tRow.Id] = nIndex;
            oTable:InsertItem(nIndex - 1, tRow.Cells[1]);

            for nColumn = 2, #tColumns do
                oTable:SetItem(nIndex - 1, nColumn - 1, tRow.Cells[nColumn]);
            end
        end

        for _, sId in ipairs(tSelected) do
            local nSelected = tIndices[sId];

            if (nSelected) then
                oTable:SetItemState(nSelected - 1, _wx.wxLIST_STATE_SELECTED, _wx.wxLIST_STATE_SELECTED);
            end
        end

        local nFocus = tIndices[sFocus] or tIndices[oComponent.Value];

        if (nFocus) then
            oTable:SetItemState(nFocus - 1, _wx.wxLIST_STATE_FOCUSED, _wx.wxLIST_STATE_FOCUSED);
        end

        oTable:Thaw();
        bInternal = false;
    end

    --[[!
    @fqxn wxLuma.UI.Table.getRow
    @desc Returns a row snapshot with copied Cells. Application Value is not cloned.
    @param string sId The stable row ID.
    @ret table|nil tRow Id, Cells and Value, or nil for an absent row.
    !]]
    function oComponent.getRow(sId)
        local nIndex = tIndices[sId];

        if (nIndex) then
            local tRow = tRows[nIndex];
            local tCells = {};

            for nColumn, sText in ipairs(tRow.Cells) do
                tCells[nColumn] = sText;
            end

            return {Id = sId, Cells = tCells, Value = tRow.Value};
        end
    end

    --[[!
    @fqxn wxLuma.UI.Table.getItems
    @desc Returns ordered row snapshots; editing the result does not change rows.
    @ret table tItems Independent structural snapshots in display order.
    !]]
    function oComponent.getItems()
        local tItems = {};

        for nIndex, tRow in ipairs(tRows) do
            tItems[nIndex] = oComponent.getRow(tRow.Id);
        end

        return tItems;
    end

    --[[!
    @fqxn wxLuma.UI.Table.getSelected
    @desc Always returns an independent array of stable IDs in current display
        order, even when single-selection mode is enabled. Empty means none.
    @ret table tIds Selected row IDs, immediately reflecting native selection.
    !]]
    function oComponent.getSelected()
        return oComponent.Disposed and _Selection.copy(tSelected) or fReadSelected();
    end

    --[[!
    @fqxn wxLuma.UI.Table.setSelected
    @desc Atomically replaces selected IDs; the last requested ID becomes primary
        and focused. More than one distinct ID requires MultiSelect enabled.
    @param table tIds Stable row IDs; an empty table clears selection.
    @param boolean|nil bNotify Emit changed-only selection notifications.
    @ret table oComponent This component.
    !]]
    function oComponent.setSelected(tIds, bNotify)
        local tCopy = _Selection.validate(tIds, function(sId)
            return type(sId) == "string" and tIndices[sId] ~= nil;
        end, bMulti);

        if (oComponent.Disposed) then
            return oComponent;
        end

        fFlush();
        local sPrimary = tCopy[#tCopy];
        local tNative = fReadSelected();

        if (_Selection.same(tNative, tCopy) and oComponent.Value == sPrimary) then
            return oComponent;
        end

        bInternal = true;
        oTable:SetItemState(-1, 0, _wx.wxLIST_STATE_SELECTED + _wx.wxLIST_STATE_FOCUSED);

        for _, sId in ipairs(tCopy) do
            oTable:SetItemState(tIndices[sId] - 1, _wx.wxLIST_STATE_SELECTED, _wx.wxLIST_STATE_SELECTED);
        end

        sFocus = sPrimary;

        if (sPrimary) then
            oTable:SetItemState(tIndices[sPrimary] - 1, _wx.wxLIST_STATE_FOCUSED, _wx.wxLIST_STATE_FOCUSED);
            oTable:EnsureVisible(tIndices[sPrimary] - 1);
        end

        bInternal = false;
        fSelection(fReadSelected(), sPrimary, bNotify);
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Table.setValue
    @desc Replaces selection with one stable ID, even in multi-selection mode.
        Nil clears. getValue remains the scalar primary ID for compatibility.
    @param string|nil sId Row ID or nil.
    @param boolean|nil bNotify Emit changed-only selection notifications.
    @ret table oComponent This component.
    !]]
    function oComponent.setValue(sId, bNotify)
        assert(sId == nil or tIndices[sId], "Unknown table selection.");
        return oComponent.setSelected(sId == nil and {} or {sId}, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.Table.isMultiSelectEnabled
    @desc Reports whether native modifier gestures can select multiple rows.
    @ret boolean bEnabled Current selection mode.
    !]]
    function oComponent.isMultiSelectEnabled()
        return bMulti;
    end

    --[[!
    @fqxn wxLuma.UI.Table.setMultiSelectEnabled
    @desc Changes mode at runtime. Disabling retains the primary selected row;
        enabling preserves selection. The existing native control is retained.
    @param boolean bEnabled Requested mode; creation defaults to false.
    @param boolean|nil bNotify Emit selectionChanged and multiSelectChanged as needed.
    @ret table oComponent This component.
    !]]
    function oComponent.setMultiSelectEnabled(bEnabled, bNotify)
        assert(type(bEnabled) == "boolean", "MultiSelect must be boolean.");

        if (not oComponent.Disposed and bMulti ~= bEnabled) then
            fFlush();
            local tIds = fReadSelected();
            local sPrimary = fPrimary(tIds);
            bMulti = bEnabled;

            if (not bMulti) then
                oComponent.setValue(sPrimary, bNotify);
            end

            bInternal = true;
            oTable:SetSingleStyle(_wx.wxLC_SINGLE_SEL, not bMulti);
            bInternal = false;

            if (bNotify) then
                tEvents.emit("multiSelectChanged", {Enabled = bMulti});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Table.setItems
    @desc Atomically validates/replaces rows. Keeps selection if its ID survives,
        clears it otherwise, and resets sort metadata to the supplied row order.
    @param table tItems The replacement Id/Cells/Value records.
    @param boolean|nil bNotify Whether rows/selection changes notify.
    @ret table oComponent This component.
    !]]
    function oComponent.setItems(tItems, bNotify)
        assert(not oComponent.Disposed, "Cannot replace rows on a disposed table.");
        local tReplacement, tReplacementIndices = fRows(tItems);
        fFlush();
        tRows, tIndices = tReplacement, tReplacementIndices;
        nSortColumn, sSortDirection = nil, nil;
        fRender();

        local tIds = fReadSelected();
        fSelection(tIds, fPrimary(tIds), bNotify);

        if (bNotify) then
            tEvents.emit("itemsChanged", {Count = #tRows});
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Table.addRow
    @desc Appends one validated row while retaining selection. Resets sort metadata.
    @param table tRow A unique Id, Cells and optional Value.
    @param boolean|nil bNotify Whether to emit itemAdded.
    @ret table oComponent This component.
    !]]
    function oComponent.addRow(tRow, bNotify)
        assert(not oComponent.Disposed, "Cannot add rows to a disposed table.");
        local tNew = fRows({tRow});
        assert(not tIndices[tNew[1].Id], "Duplicate table row ID.");
        local tAdded = tNew[1];
        tRows[#tRows + 1] = tAdded;
        tIndices[tAdded.Id] = #tRows;
        nSortColumn, sSortDirection = nil, nil;

        -- Append only the new native row; adding repeatedly must not rebuild
        -- every existing row or disturb the user's scroll/focus position.
        local nIndex = oTable:InsertItem(#tRows - 1, tAdded.Cells[1]);

        for nColumn = 2, #tColumns do
            oTable:SetItem(nIndex, nColumn - 1, tAdded.Cells[nColumn]);
        end

        if (bNotify) then
            tEvents.emit("itemAdded", {Id = tNew[1].Id});
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Table.removeRow
    @desc Removes one row, clearing selection only if that row was selected.
    @param string sId The stable row ID.
    @param boolean|nil bNotify Whether removal/selection changes notify.
    @ret table oComponent This component.
    !]]
    function oComponent.removeRow(sId, bNotify)
        assert(not oComponent.Disposed and tIndices[sId], "Unknown/disposed table row.");
        fFlush();
        local nIndex = tIndices[sId];
        bPendingDeselection = false;
        bInternal = true;
        oTable:DeleteItem(nIndex - 1);
        bInternal = false;
        table.remove(tRows, nIndex);
        tIndices[sId] = nil;

        for nRow = nIndex, #tRows do
            tIndices[tRows[nRow].Id] = nRow;
        end

        local tIds = fReadSelected();
        fSelection(tIds, fPrimary(tIds), bNotify);

        if (bNotify) then
            tEvents.emit("itemRemoved", {Id = sId});
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Table.sortBy
    @desc Sorts cell text lexically, retaining selection by stable ID. Equal cells
        retain their previous display order. Header clicks toggle ascending/descending.
    @param number nColumn The one-based column index.
    @param string sDirection ascending or descending.
    @param boolean|nil bNotify Whether to emit sorted.
    @ret table oComponent This component.
    !]]
    function oComponent.sortBy(nColumn, sDirection, bNotify)
        assert(type(nColumn) == "number" and nColumn % 1 == 0 and tColumns[nColumn], "Invalid sort column.");
        assert(sDirection == "ascending" or sDirection == "descending", "Invalid sort direction.");

        if (oComponent.Disposed or (nSortColumn == nColumn and sSortDirection == sDirection)) then
            return oComponent;
        end

        fFlush();
        local tOrder = {};

        for nIndex, tRow in ipairs(tRows) do
            tOrder[tRow.Id] = nIndex;
        end

        table.sort(tRows, function(tLeft, tRight)
            local sLeft, sRight = tLeft.Cells[nColumn], tRight.Cells[nColumn];

            if (sLeft == sRight) then
                return tOrder[tLeft.Id] < tOrder[tRight.Id];
            end

            if (sDirection == "ascending") then
                return sLeft < sRight;
            end

            return sLeft > sRight;
        end);
        nSortColumn, sSortDirection = nColumn, sDirection;
        fRender();

        if (bNotify) then
            tEvents.emit("sorted", {Column = nColumn, Direction = sDirection});
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Table.setCell
    @desc Changes one cell without rebuilding rows or changing selection. Clears
        sort metadata because edited cells may no longer match the prior order.
    @param string sId The stable row ID.
    @param number nColumn The one-based column index.
    @param string sText The replacement cell text.
    @param boolean|nil bNotify Whether to emit cellChanged.
    @ret table oComponent This component.
    !]]
    function oComponent.setCell(sId, nColumn, sText, bNotify)
        assert(not oComponent.Disposed and tIndices[sId], "Unknown/disposed table row.");
        assert(type(nColumn) == "number" and nColumn % 1 == 0 and tColumns[nColumn]
            and type(sText) == "string", "Invalid table cell.");
        local tRow = tRows[tIndices[sId]];

        if (tRow.Cells[nColumn] ~= sText) then
            local sOldValue = tRow.Cells[nColumn];
            tRow.Cells[nColumn] = sText;
            nSortColumn, sSortDirection = nil, nil;
            oTable:SetItem(tIndices[sId] - 1, nColumn - 1, sText);

            if (bNotify) then
                tEvents.emit("cellChanged", {Id = sId, Column = nColumn, Value = sText, OldValue = sOldValue});
            end
        end

        return oComponent;
    end
    oTable:Connect(_wx.wxEVT_COMMAND_LIST_ITEM_SELECTED, function(jEvent)
        if (not bInternal and not oComponent.Disposed) then
            if (bMulti) then
                bPendingDeselection = true;
            else
                bPendingDeselection = false;
                local tIds = fReadSelected();
                fSelection(tIds, fPrimary(tIds), true);
            end
        end

        jEvent:Skip();
    end);
    oTable:Connect(_wx.wxEVT_COMMAND_LIST_ITEM_DESELECTED, function(jEvent)
        if (not bInternal and not oComponent.Disposed) then
            -- A row-to-row transition deselects first, then selects. Wait until
            -- idle before reporting a clear; the selected event cancels it.
            -- This uses core idle events rather than optional scheduling APIs.
            bPendingDeselection = true;
        end

        jEvent:Skip();
    end);
    oTable:Connect(_wx.wxEVT_COMMAND_LIST_ITEM_ACTIVATED, function(jEvent)
        if (not oComponent.Disposed) then
            local tRow = tRows[jEvent:GetIndex() + 1];
            tEvents.emit("itemActivated", {Id = tRow and tRow.Id or nil});
        end

        jEvent:Skip();
    end);
    oTable:Connect(_wx.wxEVT_COMMAND_LIST_COL_CLICK, function(jEvent)
        if (oComponent.isEnabled()) then
            local nColumn = jEvent:GetColumn() + 1;
            local sDirection = nSortColumn == nColumn and sSortDirection == "ascending"
                and "descending" or "ascending";
            oComponent.sortBy(nColumn, sDirection, true);
            tEvents.emit("columnClicked", {Column = nColumn});
        end

        jEvent:Skip();
    end);
    -- Item and header context gestures carry stable row IDs/column indices so
    -- applications do not need to infer an item from pointer coordinates.
    if (_wx.wxEVT_COMMAND_LIST_ITEM_RIGHT_CLICK) then
        oTable:Connect(_wx.wxEVT_COMMAND_LIST_ITEM_RIGHT_CLICK, function(jEvent)
            if (not oComponent.Disposed) then
                local tRow = tRows[jEvent:GetIndex() + 1];
                tEvents.emit("itemRightClick", {Id = tRow and tRow.Id or nil});
            end

            jEvent:Skip();
        end);
    end

    if (_wx.wxEVT_COMMAND_LIST_COL_RIGHT_CLICK) then
        oTable:Connect(_wx.wxEVT_COMMAND_LIST_COL_RIGHT_CLICK, function(jEvent)
            if (not oComponent.Disposed) then
                tEvents.emit("columnRightClick", {Column = jEvent:GetColumn() + 1});
            end

            jEvent:Skip();
        end);
    end

    if (_wx.wxEVT_COMMAND_LIST_COL_END_DRAG) then
        oTable:Connect(_wx.wxEVT_COMMAND_LIST_COL_END_DRAG, function(jEvent)
            local nColumn = jEvent:GetColumn() + 1;

            if (not oComponent.Disposed and tColumns[nColumn]) then
                local nWidth = oTable:GetColumnWidth(nColumn - 1);
                tColumns[nColumn].Width = nWidth;
                tEvents.emit("columnResized", {Column = nColumn, Width = nWidth});
            end

            jEvent:Skip();
        end);
    end
    oTable:Connect(_wx.wxEVT_IDLE, function(jEvent)
        if (bPendingDeselection and not bInternal and not oComponent.Disposed) then
            fFlush();
        end

        jEvent:Skip();
    end);

    --[[!
    @fqxn wxLuma.UI.Table.getValue
    @desc Reads native selection immediately, including a clear awaiting its
        coalesced idle notification. A disposed table retains its last value.
    @ret string|nil sId The selected stable row ID or nil.
    !]]
    function oComponent.getValue()
        if (oComponent.Disposed) then
            return oComponent.Value;
        end

        local tIds = fReadSelected();
        return fPrimary(tIds);
    end
    -- Native report controls own Shift ranges and Ctrl/Cmd toggling. Handle
    -- select-all explicitly so the same command is available across builds.
    oTable:Connect(_wx.wxEVT_KEY_DOWN, function(jEvent)
        local tModifiers = _Selection.modifiers(jEvent);
        local nKey = jEvent:GetKeyCode();

        if (oComponent.isEnabled() and bMulti and tModifiers.Command and (nKey == 65 or nKey == 97)) then
            fFlush();
            bInternal = true;

            -- Select-all must preserve native focus and scroll position, rather
            -- than reveal the final row as an explicit setSelected request does.
            for nIndex = 1, #tRows do
                oTable:SetItemState(nIndex - 1, _wx.wxLIST_STATE_SELECTED, _wx.wxLIST_STATE_SELECTED);
            end

            local nFocused = oTable:GetNextItem(-1, _wx.wxLIST_NEXT_ALL, _wx.wxLIST_STATE_FOCUSED);

            if (nFocused < 0 and #tRows > 0) then
                oTable:SetItemState(0, _wx.wxLIST_STATE_FOCUSED, _wx.wxLIST_STATE_FOCUSED);
            end

            bInternal = false;
            local tIds = fReadSelected();
            fSelection(tIds, fPrimary(tIds), true);
        else
            jEvent:Skip();
        end
    end);
    oComponent.onLayout = function(nWidth, nHeight)
        oTable:SetSize(4, 4, math.max(1, nWidth - 8), math.max(1, nHeight - 8));
    end;
    oComponent.onEnable = function(bEnabled)
        oTable:Enable(bEnabled);
    end;
    oComponent.pointer = function(sEvent)
        if (sEvent == "down") then
            oComponent.cancel();
            oTable:SetFocus();
        end
    end;
    oComponent.onDestroy = function()
        bPendingDeselection = false;
        tRows, tIndices = {}, {};
    end;
    tEvents = _ControlEvents.attach(oComponent, {oTable}, {
        "selectionChanged", "itemsChanged", "itemAdded", "itemRemoved", "cellChanged", "sorted", "columnClicked", "itemActivated",
        "itemRightClick", "columnRightClick", "columnResized", "multiSelectChanged"
    });
    fRender();
    oComponent.setValue(tOptions.Value);
    oComponent.onEnable(tOptions.Enabled ~= false);
    return oComponent;
end

return Table;