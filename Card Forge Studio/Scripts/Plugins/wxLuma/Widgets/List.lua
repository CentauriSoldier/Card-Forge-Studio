local _wx          = require("wx");
local _Surface     = require("wxLuma.Core.ControlSurface");
local _Numeric     = require("wxLuma.Core.ControlNumeric");
local _Scrollbar   = require("wxLuma.Widgets.Scrollbar");
local _RowRenderer = require("wxLuma.Core.ListRowRenderer");
local _Selection   = require("wxLuma.Core.ControlSelection");
local _Events      = require("wxLuma.Core.ControlEvents");
local _Checks      = require("wxLuma.Core.ControlChecks");
local _Artwork     = require("wxLuma.Core.ControlArtwork");
local List         = {};

--[[!
@fqxn wxLuma.UI.List.create
@desc Creates a list with optional runtime multi-selection backed by actual storage and a public
    decoy object. Only visible, invalidated rows draw; the shared surface owns
    input and native lifetime handling.
@param wxWindow oParent The native parent.
@param table tOptions Skin, Items, optional Value, RowHeight, Enabled,
    OnChange, OnActivate, OnCancel and MultiSelect (false). Columns optionally defines typed row
    fields using Key, Type (image/text/number/boolean), Width or flexible Weight,
    Align and Format. Column definitions are fixed; row/cell data is mutable.
@param string|nil sKind Internal shared-engine identity used by ListEx.
@ret table oList The list object. Value is a one-based index, or zero for none.
!]]
function List.create(oParent, tOptions, sKind)
    -- ListEx shares this engine and receives its own single proxy identity.
    assert(sKind == nil or sKind == "ListEx", "Invalid shared list identity.");
    assert(tOptions.Checkboxes == nil or type(tOptions.Checkboxes) == "boolean", "Checkboxes must be boolean.");
    if (tOptions.Checked ~= nil) then
        _Selection.validate(tOptions.Checked, function(nIndex)
            return _Numeric.finite(nIndex) and nIndex % 1 == 0 and nIndex >= 1
                and nIndex <= #(tOptions.Items or {});
        end, true);
    end
    local tArt = tOptions.Artwork and _Artwork.create(tOptions.Skin, tOptions.Artwork);
    local oRowSkin = tOptions.Skin;
    if (tArt) then
        oRowSkin = setmetatable({text = tArt.text}, {__index = tOptions.Skin});
    end
    local tRenderer = tOptions.Columns and _RowRenderer.create(tOptions.Columns, oRowSkin);
    local oList = _Surface.create(oParent, tOptions, sKind or "List");
    assert(tOptions.MultiSelect == nil or type(tOptions.MultiSelect) == "boolean", "MultiSelect must be boolean.");
    local nDown, tDownModifiers;
    local tEvents;
    local tChecks;
    local nCheckDown;
    local bCheckSpaceDown = false;
    local sCheckArtwork = tOptions.CheckboxArtwork or (tOptions.Artwork or "ListEx").." Check";
    local tSelected = {};
    local nFocus, nAnchor = 0, 0;
    local bMulti = tOptions.MultiSelect == true;

    -- Plain lists retain their string representation. Typed lists own shallow
    -- row copies and validate cells before changing any live component state.
    local function fCopyItem(vItem)
        if (tRenderer) then
            return tRenderer.copyItem(vItem);
        end

        assert(type(vItem) == "string", "Plain list items must be strings.");
        return vItem;
    end

    -- The shared surface creates the single public proxy for this instance.
    oList.RowHeight        = tOptions.RowHeight or 28;
    oList.First            = 1;
    oList.Value            = 0;
    oList.HoverRow         = 0;
    oList.PointerRefresh   = true;
    oList.TrackPaintBounds = true;

    assert(_Numeric.finite(oList.RowHeight) and oList.RowHeight >= 20 and
        oList.RowHeight % 1 == 0, "Invalid list RowHeight.");

    --[[!
    @fqxn wxLuma.UI.List.getVisibleCount
    @desc Returns the number of complete rows available inside the frame.
    @ret number nCount At least one row, matching the original list policy.
    !]]
    function oList.getVisibleCount()
        local _, nHeight = oList.Control:GetClientSizeWH();
        return math.max(1, math.floor((nHeight - 8) / oList.RowHeight));
    end

    -- Invalidate only the affected visible row, preserving partial-paint behavior.

    --[[!
    @fqxn wxLuma.UI.List.fRefreshRow
    @desc Invalidates one visible row instead of requesting a full-list redraw.
    @param number nIndex The row index.
    !]]
    local function fRefreshRow(nIndex)
        if (oList.Disposed or nIndex < oList.First or
            nIndex >= oList.First + oList.getVisibleCount()) then
            return;
        end

        local nWidth = oList.Control:GetClientSizeWH();
        oList.Control:RefreshRect(_wx.wxRect(
            4,
            4 + (nIndex - oList.First) * oList.RowHeight,
            math.max(1, nWidth - 30),
            oList.RowHeight
        ), false);
    end

    --[[!
    @fqxn wxLuma.UI.List.setHover
    @desc Updates row hover and invalidates the old and new row rectangles.
    @param number nIndex The item index; zero clears hover.
    !]]
    function oList.setHover(nIndex)
        if (not oList.isEnabled() or nIndex < oList.First or
            nIndex >= oList.First + oList.getVisibleCount() or
            nIndex > #oList.Items) then
            nIndex = 0;
        end

        if (nIndex ~= oList.HoverRow) then
            local nOld = oList.HoverRow;
            oList.HoverRow = nIndex;
            fRefreshRow(nOld);
            fRefreshRow(nIndex);

            -- Report row transitions once, rather than every pointer movement,
            -- so application audio can follow the same visible hover state.
            if (tEvents) then
                if (nOld > 0) then
                    tEvents.emit("itemLeft", {Index = nOld});
                end
                if (nIndex > 0 and not oList.Disposed and oList.HoverRow == nIndex) then
                    tEvents.emit("itemHovered", {Index = nIndex});
                end
            end
        end
    end

    --[[!
    @fqxn wxLuma.UI.List.scrollTo
    @desc Clamps the first visible row and synchronizes the child scrollbar.
        Small visible scrolls reuse existing pixels; other scrolls repaint.
    @param number nFirst The requested first visible item.
    @ret table oList This list object.
    !]]
    function oList.scrollTo(nFirst)
        nFirst = math.max(1, math.min(
            math.max(1, #oList.Items - oList.getVisibleCount() + 1),
            math.floor(nFirst)
        ));

        if (nFirst == oList.First) then
            return oList;
        end

        oList.setHover(0);
        local nDelta = oList.First - nFirst;
        oList.First = nFirst;

        if (oList.Scrollbar) then
            oList.Scrollbar.setValue(oList.First - 1);
        end

        local nWidth = oList.Control:GetClientSizeWH();

        if (math.abs(nDelta) < oList.getVisibleCount() and
            oList.Control:IsShownOnScreen()) then
            oList.Control:ScrollWindow(0, nDelta * oList.RowHeight, _wx.wxRect(
                4, 4, math.max(1, nWidth - 30),
                oList.getVisibleCount() * oList.RowHeight
            ));
        else
            oList.refresh();
        end

        return oList;
    end

    --[[!
    @fqxn wxLuma.UI.List.getSelected
    @desc Always returns an independent array in row order, including zero or one
        entry in single-selection mode. ListEx uses the same one-based indices.
    @ret table tIndices Selected row indices; empty means no selection.
    !]]
    function oList.getSelected()
        local tIndices = {};

        for nIndex in pairs(tSelected) do
            tIndices[#tIndices + 1] = nIndex;
        end

        table.sort(tIndices);
        return tIndices;
    end

    -- Commit membership, primary row, keyboard focus and range anchor together.
    -- Invalidate changed rows only, retaining the existing large-list paint path.
    local function fSelection(tNew, nPrimary, bNotify, nNewFocus, nNewAnchor)
        local tOld = tSelected;
        local nOldValue = oList.Value;
        local nOldFocus = nFocus;
        local bChanged = nOldValue ~= nPrimary;

        for nIndex in pairs(tOld) do
            bChanged = bChanged or not tNew[nIndex];
        end

        for nIndex in pairs(tNew) do
            bChanged = bChanged or not tOld[nIndex];
        end

        local tOldSelected = bNotify and oList.getSelected() or nil;
        tSelected = tNew;
        oList.Value = nPrimary;
        nFocus = nNewFocus or nPrimary;
        nAnchor = nNewAnchor or nFocus;

        if (nFocus > 0) then
            if (nFocus < oList.First) then
                oList.scrollTo(nFocus);
            elseif (nFocus >= oList.First + oList.getVisibleCount()) then
                oList.scrollTo(nFocus - oList.getVisibleCount() + 1);
            end
        end

        if (bChanged) then
            for nIndex in pairs(tOld) do
                if (not tNew[nIndex]) then
                    fRefreshRow(nIndex);
                end
            end

            for nIndex in pairs(tNew) do
                if (not tOld[nIndex]) then
                    fRefreshRow(nIndex);
                end
            end
        end

        if (bMulti and nOldFocus ~= nFocus) then
            fRefreshRow(nOldFocus);
            fRefreshRow(nFocus);
        end

        if (bChanged and bNotify) then
            if (oList.OnChange) then
                oList.OnChange(nPrimary, oList, oList.getSelected());
            end

            if (nOldValue ~= nPrimary) then
                tEvents.emit("valueChanged", {Value = nPrimary, OldValue = nOldValue});
            end

            tEvents.emit("selectionChanged", {
                Value = nPrimary, OldValue = nOldValue,
                Selected = oList.getSelected(), OldSelected = tOldSelected
            });
        end

        return oList;
    end

    --[[!
    @fqxn wxLuma.UI.List.setSelected
    @desc Atomically replaces selection. The last requested row becomes primary,
        focused and anchored. Multiple distinct rows require MultiSelect enabled.
    @param table tIndices One-based row indices; an empty table clears selection.
    @param boolean|nil bNotify Emit changed-only selection notifications.
    @ret table oList This component.
    !]]
    function oList.setSelected(tIndices, bNotify)
        local tCopy = _Selection.validate(tIndices, function(nIndex)
            return _Numeric.finite(nIndex) and nIndex % 1 == 0
                and nIndex > 0 and nIndex <= #oList.Items;
        end, bMulti);

        if (oList.Disposed) then
            return oList;
        end

        local tNew = {};

        for _, nIndex in ipairs(tCopy) do
            tNew[nIndex] = true;
        end

        return fSelection(tNew, tCopy[#tCopy] or 0, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.List.setValue
    @desc Replaces selection with one row, even in multi-selection mode. Zero clears.
        getValue remains the scalar primary row for compatibility.
    @param number nValue One-based row index, or zero.
    @param boolean|nil bNotify Emit changed-only selection notifications.
    @ret table oList This component.
    !]]
    function oList.setValue(nValue, bNotify)
        assert(_Numeric.finite(nValue) and nValue % 1 == 0
            and nValue >= 0 and nValue <= #oList.Items, "Invalid list selection.");
        return oList.setSelected(nValue == 0 and {} or {nValue}, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.List.isMultiSelectEnabled
    @desc Reports whether modifier gestures can select multiple rows.
    @ret boolean bEnabled Current selection mode.
    !]]
    function oList.isMultiSelectEnabled()
        return bMulti;
    end

    --[[!
    @fqxn wxLuma.UI.List.setMultiSelectEnabled
    @desc Changes mode at runtime. Disabling retains the primary selected row,
        or no row when empty. Enabling preserves the current selection.
    @param boolean bEnabled Requested mode; creation defaults to false.
    @param boolean|nil bNotify Emit selectionChanged and multiSelectChanged as needed.
    @ret table oList This component.
    !]]
    function oList.setMultiSelectEnabled(bEnabled, bNotify)
        assert(type(bEnabled) == "boolean", "MultiSelect must be boolean.");

        if (not oList.Disposed and bMulti ~= bEnabled) then
            bMulti = bEnabled;

            if (not bMulti) then
                oList.setValue(oList.Value, bNotify);
            end

            oList.refresh();

            if (bNotify) then
                tEvents.emit("multiSelectChanged", {Enabled = bMulti});
            end
        end

        return oList;
    end

    -- Focus is independent of membership: Ctrl/Cmd+arrows move focus without
    -- clearing selected rows. Ctrl/Cmd+Space then toggles that focused row.
    local function fGesture(nIndex, tModifiers, bKeyboard)
        tModifiers = tModifiers or {};

        if (not bMulti or nIndex == 0) then
            return oList.setValue(nIndex, true);
        end

        local tNew = {};

        if (tModifiers.Command) then
            for nSelected in pairs(tSelected) do
                tNew[nSelected] = true;
            end
        end

        if (tModifiers.Shift) then
            local nStart = nAnchor > 0 and nAnchor or (nFocus > 0 and nFocus or nIndex);

            for nSelected = math.min(nStart, nIndex), math.max(nStart, nIndex) do
                tNew[nSelected] = true;
            end

            return fSelection(tNew, nIndex, true, nIndex, nStart);
        elseif (tModifiers.Command and bKeyboard) then
            return fSelection(tNew, oList.Value, false, nIndex, nAnchor);
        elseif (tModifiers.Command) then
            tNew[nIndex] = not tNew[nIndex] or nil;
            local nPrimary = tNew[nIndex] and nIndex or (tNew[oList.Value] and oList.Value or 0);

            if (nPrimary == 0) then
                for nSelected in pairs(tNew) do
                    if (nPrimary == 0 or nSelected < nPrimary) then
                        nPrimary = nSelected;
                    end
                end
            end

            return fSelection(tNew, nPrimary, true, nIndex, nIndex);
        end

        return oList.setValue(nIndex, true);
    end

    --[[!
    @fqxn wxLuma.UI.List.getText
    @desc Retrieves item text; typed rows use their first text column.
    @param number|nil nIndex The item index; omitted means the current selection.
    @ret string sText The selected text, or an empty string when unselected.
    !]]
    function oList.getText(nIndex)
        nIndex = nIndex or oList.Value;

        if (tRenderer) then
            return tRenderer.getText(oList.Items[nIndex], nIndex);
        end

        return oList.Items[nIndex] or "";
    end

    --[[!
    @fqxn wxLuma.UI.List.setItems
    @desc Validates/copies all items atomically, clamps selection and resets
        scrolling. Plain lists accept strings; configured lists accept records.
    @param table tItems The replacement item array.
    @param boolean|nil bNotify Whether item/selection changes notify; default silent.
    @ret table oList This list object.
    !]]
    function oList.setItems(tItems, bNotify)
        assert(type(tItems) == "table", "List Items must be an array.");
        local tCopy = {};

        for nIndex, vItem in ipairs(tItems) do
            tCopy[nIndex] = fCopyItem(vItem);
        end

        local tNew = {};

        for nIndex in pairs(tSelected) do
            if (nIndex <= #tCopy) then
                tNew[nIndex] = true;
            end
        end

        local nPrimary = math.min(oList.Value, #tCopy);

        if (not bMulti and nPrimary > 0) then
            tNew[nPrimary] = true;
        elseif (not tNew[nPrimary]) then
            nPrimary = 0;

            for nIndex = 1, #tCopy do
                if (tNew[nIndex]) then
                    nPrimary = nIndex;
                    break;
                end
            end
        end

        oList.setHover(0);
        oList.Items = tCopy;
        oList.First = 1;
        if (tChecks) then
            tChecks.prune();
        end
        nCheckDown = nil;
        oList.cancel();

        if (tRenderer) then
            tRenderer.clear();
        end

        if (oList.onLayout) then
            oList.onLayout(oList.Control:GetClientSizeWH());
        end

        fSelection(tNew, nPrimary, bNotify, math.min(nFocus, #tCopy), math.min(nAnchor, #tCopy));
        oList.refresh();

        if (bNotify) then
            tEvents.emit("itemsChanged", {Count = #tCopy});
        end

        return oList;
    end

    --[[!
    @fqxn wxLuma.UI.List.getColumns
    @desc Returns column-definition snapshots, or nil for a plain string list.
        Definitions are fixed for this instance; mutate row/cell data instead.
    @ret table|nil tColumns Independent column definitions.
    !]]
    function oList.getColumns()
        return tRenderer and tRenderer.getColumns() or nil;
    end

    --[[!
    @fqxn wxLuma.UI.List.getItem
    @desc Returns one item snapshot, or nil when absent. Configured rows are
        shallow copies; application-owned nested metadata retains its identity.
    @param number nIndex The one-based item index.
    @ret string|table|nil vItem The string or row snapshot.
    !]]
    function oList.getItem(nIndex)
        local vItem = oList.Items[nIndex];
        return vItem ~= nil and fCopyItem(vItem) or nil;
    end

    --[[!
    @fqxn wxLuma.UI.List.setItem
    @desc Atomically replaces one item without changing selection or scroll.
        Equal values are no-ops; changed visible rows alone are invalidated.
    @param number nIndex The existing one-based row index.
    @param string|table vItem The replacement item.
    @param boolean|nil bNotify Whether to emit itemChanged; default silent.
    @ret table oList This list object.
    !]]
    function oList.setItem(nIndex, vItem, bNotify)
        assert(not oList.Disposed and _Numeric.finite(nIndex) and nIndex % 1 == 0
            and oList.Items[nIndex] ~= nil, "Invalid list item index.");
        local vCopy = fCopyItem(vItem);
        local vOld = oList.Items[nIndex];
        local bEqual = vOld == vCopy;

        if (type(vOld) == "table" and type(vCopy) == "table") then
            bEqual = true;

            for vKey, vValue in pairs(vOld) do
                if (vCopy[vKey] ~= vValue) then
                    bEqual = false;
                    break;
                end
            end

            if (bEqual) then
                for vKey, vValue in pairs(vCopy) do
                    if (vOld[vKey] ~= vValue) then
                        bEqual = false;
                        break;
                    end
                end
            end
        end

        if (not bEqual) then
            oList.Items[nIndex] = vCopy;
            fRefreshRow(nIndex);

            if (bNotify) then
                tEvents.emit("itemChanged", {Index = nIndex, Item = oList.getItem(nIndex)});
            end
        end

        return oList;
    end

    --[[!
    @fqxn wxLuma.UI.List.getCell
    @desc Reads typed cell data by one-based row/column index. A plain string
        list has one text column. Nil is a blank configured cell.
    @param number nIndex The existing row index.
    @param number nColumn The column index.
    @ret any vValue The cell's typed value.
    !]]
    function oList.getCell(nIndex, nColumn)
        assert(_Numeric.finite(nIndex) and nIndex % 1 == 0 and oList.Items[nIndex] ~= nil,
            "Invalid list item index.");

        if (tRenderer) then
            return oList.Items[nIndex][tRenderer.getColumnKey(nColumn)];
        end

        assert(nColumn == 1, "Plain lists have one column.");
        return oList.Items[nIndex];
    end

    --[[!
    @fqxn wxLuma.UI.List.setCell
    @desc Changes one cell independently while preserving the remaining row,
        selection and scroll. Validates the declared type before any mutation.
    @param number nIndex The existing one-based row index.
    @param number nColumn The one-based column index.
    @param any vValue The typed value, or nil for a blank configured cell.
    @param boolean|nil bNotify Whether to emit cellChanged/itemChanged.
    @ret table oList This list object.
    !]]
    function oList.setCell(nIndex, nColumn, vValue, bNotify)
        assert(not oList.Disposed, "Cannot change a disposed list.");
        local vOld = oList.getCell(nIndex, nColumn);

        if (vOld ~= vValue) then
            local vItem = oList.getItem(nIndex);

            if (tRenderer) then
                vItem[tRenderer.getColumnKey(nColumn)] = vValue;
            else
                vItem = vValue;
            end

            oList.setItem(nIndex, vItem, false);

            if (bNotify) then
                tEvents.emit("cellChanged", {
                    Index = nIndex, Column = nColumn, Value = vValue, OldValue = vOld
                });
                tEvents.emit("itemChanged", {Index = nIndex, Item = oList.getItem(nIndex)});
            end
        end

        return oList;
    end

    --[[!
    @fqxn wxLuma.UI.List.addItem
    @desc Appends a validated item, preserving the selected index and scroll.
    @param string|table vItem The appended item.
    @param boolean|nil bNotify Whether to emit itemAdded.
    @ret table oList This list object.
    !]]
    function oList.addItem(vItem, bNotify)
        assert(not oList.Disposed, "Cannot append to a disposed list.");
        local vCopy = fCopyItem(vItem);
        oList.Items[#oList.Items + 1] = vCopy;
        oList.onLayout(oList.Control:GetClientSizeWH());
        fRefreshRow(#oList.Items);

        if (bNotify) then
            tEvents.emit("itemAdded", {Index = #oList.Items});
        end

        return oList;
    end

    --[[!
    @fqxn wxLuma.UI.List.removeItem
    @desc Removes one row. All surviving selections shift with their logical
        items. Removing the primary chooses the first remaining selection, or zero.
    @param number nIndex The existing one-based index.
    @param boolean|nil bNotify Whether removal/selection changes notify.
    @ret table oList This list object.
    !]]
    function oList.removeItem(nIndex, bNotify)
        assert(not oList.Disposed and _Numeric.finite(nIndex) and nIndex % 1 == 0
            and oList.Items[nIndex] ~= nil, "Invalid list item index.");
        local tNew = {};

        for nSelected in pairs(tSelected) do
            if (nSelected ~= nIndex) then
                tNew[nSelected > nIndex and nSelected - 1 or nSelected] = true;
            end
        end

        local function fShift(nRow)
            return nRow == nIndex and 0 or (nRow > nIndex and nRow - 1 or nRow);
        end

        local nPrimary = fShift(oList.Value);

        if (nPrimary == 0) then
            for nSelected in pairs(tNew) do
                if (nPrimary == 0 or nSelected < nPrimary) then
                    nPrimary = nSelected;
                end
            end
        end

        if (tChecks) then
            tChecks.remap(function(nRow)
                if (nRow ~= nIndex) then
                    return nRow > nIndex and nRow - 1 or nRow;
                end
            end);
        end
        nCheckDown = nil;
        oList.cancel();
        table.remove(oList.Items, nIndex);
        oList.onLayout(oList.Control:GetClientSizeWH());
        local nNewFocus = nFocus == nIndex and math.min(nIndex, #oList.Items) or fShift(nFocus);
        local nNewAnchor = nAnchor == nIndex and nNewFocus or fShift(nAnchor);
        fSelection(tNew, nPrimary, bNotify, nNewFocus, nNewAnchor);
        oList.refresh();

        if (bNotify) then
            tEvents.emit("itemRemoved", {Index = nIndex});
        end

        return oList;
    end
    oList.Items     = {};
    oList.Scrollbar = _Scrollbar.create(oList.Control, {
        Skin     = oList.Skin,
        Min      = 0,
        Max      = 0,
        Page     = 1,
        Value    = 0,
        OnChange = function(nValue)
            oList.scrollTo(nValue + 1);
        end,
    });

    -- Keep the scrollbar range tied to the number of complete visible rows.
    oList.onLayout = function(nWidth, nHeight)
        oList.setHover(0);
        oList.Scrollbar.layout(math.max(1, nWidth - 23), 4, 20, math.max(40, nHeight - 8));
        oList.Scrollbar.setRange(
            0, math.max(0, #oList.Items - oList.getVisibleCount()),
            oList.getVisibleCount()
        );
        oList.scrollTo(oList.First);
        oList.Scrollbar.Control:Show(#oList.Items > oList.getVisibleCount());
    end;

    -- Propagate enabled state and clear transient interaction.
    oList.onEnable = function(bEnabled)
        oList.setHover(0);
        oList.Scrollbar.setEnabled(bEnabled);
    end;

    -- Dispose resources owned by this widget.
    oList.onDestroy = function()
        oList.Scrollbar.destroy();

        if (tRenderer) then
            tRenderer.clear();
        end
        if (tArt) then
            tArt.destroy();
        end
    end;
    oList.onCancel = function()
        local nOld = nCheckDown;
        nCheckDown, bCheckSpaceDown = nil, false;
        if (nOld) then
            fRefreshRow(nOld);
        end
    end;

    -- Preserve the original single-click activation policy for dropdown users.
    oList.pointer = function(sEvent, nX, nY, tModifiers)
        local nWidth   = oList.Control:GetClientSizeWH();
        local nIndex   = oList.First + math.floor((nY - 4) / oList.RowHeight);
        local bOverRow = sEvent ~= "leave" and sEvent ~= "cancel" and
        oList.Hover and nX >= 4 and nX < nWidth - 26 and nY >= 4;

        oList.setHover(bOverRow and nIndex or 0);

        if (oList.isCheckboxesEnabled()) then
            local nRowY = 4 + (nIndex - oList.First) * oList.RowHeight;
            local nCheckY = nRowY + math.floor((oList.RowHeight - 20) / 2);
            local bCheckHit = bOverRow and nIndex >= 1 and nIndex <= #oList.Items
                and nX >= 8 and nX < 28 and nY >= nCheckY and nY < nCheckY + 20;
            if (sEvent == "down" and bCheckHit) then
                nCheckDown = nIndex;
                local nOldFocus = nFocus;
                nFocus = nIndex;
                fRefreshRow(nOldFocus);
                fRefreshRow(nIndex);
                return;
            elseif (sEvent == "up" and nCheckDown) then
                local nPressed = nCheckDown;
                nCheckDown = nil;
                fRefreshRow(nPressed);
                if (bCheckHit and nPressed == nIndex and oList.Pressed) then
                    oList.setChecked(nIndex, not oList.isChecked(nIndex), true);
                end
                return;
            end
        end
        if (sEvent == "down") then
            nDown = nIndex;
            tDownModifiers = tModifiers;
        elseif (sEvent == "up" and bMulti and oList.Pressed and oList.Hover
            and bOverRow and nIndex > #oList.Items and nIndex == nDown
            and not (tDownModifiers and (tDownModifiers.Shift or tDownModifiers.Command))) then
            oList.setSelected({}, true);
        elseif (sEvent == "up" and oList.Pressed and oList.Hover and
            nY >= 4 and nX < nWidth - 24 and nIndex == nDown and
            nIndex >= 1 and nIndex <= #oList.Items) then
            fGesture(nIndex, tDownModifiers, false);
            oList.cancel();

            if (tOptions.OnActivate) then
                tOptions.OnActivate(nIndex, oList);
            end

            tEvents.emit("itemActivated", {Index = nIndex});
        end
    end;

    -- Keyboard selection uses the same setter and notification path as clicks.
    oList.key = function(nKey, tModifiers)
        oList.setHover(0);
        tModifiers = tModifiers or {};
        local nValue = (bMulti or oList.isCheckboxesEnabled() or tOptions.FocusNavigation) and nFocus > 0 and nFocus or oList.Value;
        if (oList.isCheckboxesEnabled() and nKey == _wx.WXK_SPACE
            and not tModifiers.Command and not tModifiers.Shift) then
            if (not bCheckSpaceDown and nValue > 0 and oList.Items[nValue]) then
                bCheckSpaceDown = true;
                oList.setChecked(nValue, not oList.isChecked(nValue), true);
            end
            return true;
        end

        if (bMulti and tModifiers.Command and (nKey == 65 or nKey == 97)) then
            local tAll = {};

            for nIndex = 1, #oList.Items do
                tAll[nIndex] = true;
            end

            local nPrimary = nValue > 0 and nValue or (#oList.Items > 0 and 1 or 0);
            fSelection(tAll, nPrimary, true, nPrimary, nAnchor);
            return true;
        elseif (bMulti and nKey == _wx.WXK_SPACE) then
            fGesture(nValue, tModifiers, false);
            return true;
        elseif (nKey == _wx.WXK_UP) then
            nValue = math.max(1, nValue - 1);
        elseif (nKey == _wx.WXK_DOWN) then
            nValue = math.min(#oList.Items, nValue + 1);
        elseif (nKey == _wx.WXK_HOME) then
            nValue = 1;
        elseif (nKey == _wx.WXK_END) then
            nValue = #oList.Items;
        elseif (nKey == _wx.WXK_PAGEUP) then
            nValue = math.max(1, nValue - oList.getVisibleCount());
        elseif (nKey == _wx.WXK_PAGEDOWN) then
            nValue = math.min(#oList.Items, nValue + oList.getVisibleCount());
        elseif (nKey == _wx.WXK_RETURN or nKey == _wx.WXK_NUMPAD_ENTER) then
            if (nValue > 0) then
                if (tOptions.OnActivate) then
                    tOptions.OnActivate(nValue, oList);
                end

                tEvents.emit("itemActivated", {Index = nValue});
            end

            return true;
        elseif (nKey == _wx.WXK_ESCAPE and tOptions.OnCancel) then
            tOptions.OnCancel(oList);
            return true;
        else
            return false;
        end

        fGesture(#oList.Items == 0 and 0 or nValue, tModifiers, true);
        return true;
    end;

    -- Apply wheel movement to the value or scroll offset.
    oList.wheel = function(nSteps)
        oList.scrollTo(oList.First - nSteps * 3);
    end;

    -- Character search wraps after the selected item and matches its first byte.
    oList.Control:Connect(_wx.wxEVT_CHAR, function(jEvent)
        local nKey = jEvent:GetKeyCode();

        local tModifiers = _Selection.modifiers(jEvent);

        if (oList.isCheckboxesEnabled() and nKey == _wx.WXK_SPACE
            and not tModifiers.Command and not tModifiers.Shift) then
            return;
        end
        if (oList.isEnabled() and not tModifiers.Command and nKey >= 32
            and nKey <= 126 and #oList.Items > 0) then
            local sChar = string.char(nKey):lower();

            for nOffset = 1, #oList.Items do
                local nIndex = (oList.Value + nOffset - 1) % #oList.Items + 1;

                if (oList.getText(nIndex):sub(1, 1):lower() == sChar) then
                    oList.setValue(nIndex, true);
                    break;
                end
            end
        else
            jEvent:Skip();
        end
    end);

    -- Native paint bounds limit the Lua row loop as well as the DC clipping.
    oList.drawContent = function(oDC, nWidth, nHeight)
        oDC:SetClippingRegion(4, 4, math.max(1, nWidth - 30), math.max(1, nHeight - 8));

        local nFirst = oList.PaintTop and math.max(
            oList.First, oList.First + math.floor((oList.PaintTop - 4) / oList.RowHeight)
        ) or oList.First;
        local nLast = math.min(#oList.Items, oList.First + oList.getVisibleCount() - 1);

        if (oList.PaintBottom) then
            nLast = math.min(nLast, oList.First + math.floor((oList.PaintBottom - 5) / oList.RowHeight));
        end

        for nIndex = nFirst, nLast do
            local nY = 4 + (nIndex - oList.First) * oList.RowHeight;

            if (tArt) then
                local sRow = tSelected[nIndex] and (oList.isEnabled() and "Row Selected" or "Row Selected Disabled")
                    or not oList.isEnabled() and "Row Disabled" or nIndex == oList.HoverRow and "Row Hover" or "Row Normal";
                tArt.part(oDC, sRow, 4, nY, math.max(1, nWidth - 30), oList.RowHeight);
            end
            if (not tArt and tSelected[nIndex]) then
                oDC:GradientFillLinear(_wx.wxRect(4, nY, nWidth - 30, oList.RowHeight),
                    oList.isEnabled() and _wx.wxColour(65, 82, 99) or _wx.wxColour(41, 46, 53),
                    _wx.wxColour(28, 36, 45), _wx.wxSOUTH);
            end

            if (not tArt and nIndex == oList.HoverRow) then
                if (not tSelected[nIndex]) then
                    oDC:GradientFillLinear(_wx.wxRect(4, nY, nWidth - 30, oList.RowHeight),
                        _wx.wxColour(43, 55, 67), _wx.wxColour(29, 38, 48), _wx.wxSOUTH);
                end

                local oPen = _wx.wxPen(_wx.wxColour(117, 145, 166), 1, _wx.wxPENSTYLE_SOLID);
                oDC:SetPen(oPen);
                oDC:SetBrush(_wx.wxTRANSPARENT_BRUSH);
                oDC:DrawRectangle(4, nY, nWidth - 30, oList.RowHeight);
                oPen:delete();
            end

            if ((bMulti or oList.isCheckboxesEnabled()) and nIndex == nFocus and oList.Control:HasFocus()) then
                if (tArt) then
                    tArt.part(oDC, "Focus", 5, nY + oList.RowHeight - 3, math.max(1, nWidth - 32), 2);
                else
                    local oPen = _wx.wxPen(_wx.wxColour(160, 180, 200), 1, _wx.wxPENSTYLE_DOT);
                    oDC:SetPen(oPen);
                    oDC:SetBrush(_wx.wxTRANSPARENT_BRUSH);
                    oDC:DrawRectangle(5, nY + 1, math.max(1, nWidth - 32), oList.RowHeight - 2);
                    oPen:delete();
                end
            end

            if (nIndex == oList.CommittedValue) then
                local oPen = _wx.wxPen(_wx.wxColour(145, 175, 198), 2, _wx.wxPENSTYLE_SOLID);
                oDC:SetPen(oPen);
                oDC:DrawLine(6, nY + 5, 6, nY + oList.RowHeight - 5);
                oPen:delete();
            end

            local nInset = oList.isCheckboxesEnabled() and 28 or 0;
            if (nInset > 0) then
                local sState = not oList.isEnabled() and "Disabled" or nCheckDown == nIndex and "Pressed"
                    or nIndex == oList.HoverRow and "Hover" or "Normal";
                oList.Skin.draw(oDC, sCheckArtwork..(oList.isChecked(nIndex) and " On " or " Off ")..sState,
                    8, nY + math.floor((oList.RowHeight - 20) / 2), 20, 20);
            end
            if (oList.drawRowPrefix) then
                oList.drawRowPrefix(oDC, nIndex, 4, nY, math.max(1, nWidth - 30), oList.RowHeight);
            end
            if (tRenderer) then
                tRenderer.draw(oDC, oList.Items[nIndex], nIndex, 4 + nInset, nY,
                    math.max(1, nWidth - 30 - nInset), oList.RowHeight, oList.isEnabled(),
                    oList.getRowInsets and oList.getRowInsets(nIndex) or nil);
            else
                oRowSkin.text(oDC, oList.Items[nIndex], 10 + nInset,
                    nY + (oList.RowHeight - 18) / 2, oList.isEnabled());
            end
        end

        oDC:DestroyClippingRegion();
    end;

    --[[!
    @fqxn wxLuma.UI.List.getColumnLayout
    @desc Returns typed column geometry relative to content origin, for aligned headers.
    @param number nWidth Content width.
    @ret table tLayout Column rectangles, or an empty array for plain lists.
    !]]
    function oList.getColumnLayout(nWidth)
        return tRenderer and tRenderer.getLayout(nWidth) or {};
    end
    --[[!
    @fqxn wxLuma.UI.List.focusItem
    @desc Moves keyboard focus without changing row selection or range anchor.
    @param number nIndex Existing row index.
    @ret table oList This object.
    !]]
    function oList.focusItem(nIndex)
        assert(_Numeric.finite(nIndex) and nIndex % 1 == 0 and oList.Items[nIndex], "Invalid focus row.");
        local nOld = nFocus;
        nFocus = nIndex;
        oList.Control:SetFocus();
        fRefreshRow(nOld);
        fRefreshRow(nFocus);
        return oList;
    end
    --[[!
    @fqxn wxLuma.UI.List.getFocusedIndex
    @desc Returns the keyboard-focused row independently of selected membership.
    @ret number nIndex Focused row or zero.
    !]]
    function oList.getFocusedIndex()
        return nFocus;
    end
    if (tArt) then
        oList.draw = function(oDC, nWidth, nHeight)
            if (not oList.Disposed) then
                tArt.part(oDC, oList.isEnabled() and "Surface Normal" or "Surface Disabled", 0, 0, nWidth, nHeight);
                oList.drawContent(oDC, nWidth, nHeight);
            end
        end;
        oList.Scrollbar.draw = function(oDC, nWidth, nHeight)
            if (not oList.Disposed) then
                local sState = not oList.isEnabled() and "Disabled" or oList.Scrollbar.Pressed and "Pressed"
                    or oList.Scrollbar.Hover and "Hover" or "Normal";
                local nAt, nThumb = oList.Scrollbar.getThumb();
                tArt.part(oDC, "Scroll Track", 0, 0, nWidth, nHeight);
                tArt.part(oDC, "Scroll Thumb "..sState, 2, nAt, math.max(1, nWidth - 4), nThumb);
                tArt.text(oDC, "^", 5, 0, oList.isEnabled());
                tArt.text(oDC, "v", 5, nHeight - 18, oList.isEnabled());
            end
        end;
    end
    local fHandleKey = oList.handleKey;
    oList.handleKey = function(sEvent, nKey, tModifiers)
        if (sEvent == "up" and nKey == _wx.WXK_SPACE) then
            local bHandled = bCheckSpaceDown;
            bCheckSpaceDown = false;
            return bHandled;
        end
        return fHandleKey(sEvent, nKey, tModifiers);
    end;
    oList.Control:Connect(_wx.wxEVT_KEY_UP, function(jEvent)
        oList.handleKey("up", jEvent:GetKeyCode());
        jEvent:Skip();
    end);
    tEvents = _Events.attach(oList, nil, {
        "selectionChanged", "itemsChanged", "itemAdded", "itemRemoved",
        "itemChanged", "cellChanged", "itemActivated", "multiSelectChanged", "checkChanged", "checkboxesChanged",
        "itemHovered", "itemLeft"
    });
    tChecks = _Checks.attach(oList, tEvents, tOptions, {
        keys = function()
            local tKeys = {};
            for nIndex = 1, #oList.Items do
                tKeys[nIndex] = nIndex;
            end
            return tKeys;
        end,
        valid = function(nIndex)
            return _Numeric.finite(nIndex) and nIndex % 1 == 0 and oList.Items[nIndex] ~= nil;
        end,
        refresh = fRefreshRow,
        payload = function(nIndex)
            local vItem = oList.Items[nIndex];
            return {Index = nIndex, Id = type(vItem) == "table" and vItem.Id or nil,
                Item = oList.getItem(nIndex)};
        end,
    });
    oList.setItems(tOptions.Items);
    oList.setValue(tOptions.Value or 0);
    oList.setCheckedItems(tOptions.Checked or {});
    oList.setEnabled(tOptions.Enabled ~= false);
    return oList;
end

return List;
