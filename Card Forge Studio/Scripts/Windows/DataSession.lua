--[[!
@fqxn CFS.Windows.DataSession
@desc Shared grid data, source-row identity, selection, filtering, sorting, and save state.
!]]

-- Shared data and view state for Base Data and Final Data.
-- Visible row positions always map back to the original source row.
local DataSession = {};

--[[!
@fqxn CFS.Windows.DataSession.create
@pulsarlua function DataSession.create
@desc Creates shared base/final data, filtering, sorting, selection, scrolling, and dirty-state callbacks for both grids.
@param any tOptions Options table.
!]]
function DataSession.create(tOptions)
    tOptions = tOptions or {};

    local tSession = {
        headers         = {},
        base            = {},
        final           = {},
        visible         = {},
        codeColumns     = {},
        search          = "",
        source          = "Base",
        filterColumn    = "",
        filterText      = "",
        sortColumn      = "",
        descending      = false,
        selected        = nil,
        column          = 1,
        editing         = false,
        dirty           = false,
        options         = tOptions,
    };
    local tListeners       = {};
    local tScrollListeners = {};
    local nScrollX         = 0;
    local nScrollY         = 0;

    --[[!
    @fqxn CFS.Windows.DataSession.Session.subscribeScroll
    @desc Registers a listener for shared scroll-position changes.
    @vis public
    @param any fListener Change listener.
    !]]
    function tSession.subscribeScroll(fListener)
        tScrollListeners[#tScrollListeners + 1] = fListener;
    end

    --[[!
    @fqxn CFS.Windows.DataSession.Session.scroll
    @desc Publishes changed horizontal and vertical scroll positions to subscribed grids.
    @vis public
    @param any nX Horizontal coordinate.
    @param any nY Vertical coordinate.
    !]]
    function tSession.scroll(nX, nY)
        if (nX == nScrollX and nY == nScrollY) then return; end
        nScrollX, nScrollY = nX, nY;
        for _, fListener in ipairs(tScrollListeners) do fListener(nX, nY); end
    end

    --[[!
    @fqxn CFS.Windows.DataSession.Private.notify
    @desc Notifies listeners of shared session changes.
    @vis private
    !]]
    local function notify()
        for _, fListener in ipairs(tListeners) do
            fListener();
        end
    end

    --[[!
    @fqxn CFS.Windows.DataSession.Session.subscribe
    @desc Registers a listener for shared data-session changes.
    @vis public
    @param any fListener Change listener.
    !]]
    function tSession.subscribe(fListener)
        tListeners[#tListeners + 1] = fListener;
    end

    --[[!
    @fqxn CFS.Windows.DataSession.Session.refresh
    @desc Rebuilds visible source-row indices using search, filtering, and stable numeric or text sorting, then notifies listeners.
    @vis public
    !]]
    function tSession.refresh()
        local tRows = tSession.source == "Final" and tSession.final or tSession.base;
        local tVisible = {};
        local sSearch = tSession.search:lower();
        local sFilter = tSession.filterText:lower();

        for nRow, tRow in ipairs(tRows) do
            local bMatch = sSearch == "";

            for _, sHeader in ipairs(tSession.headers) do
                if (tostring(tRow[sHeader] or ""):lower():find(sSearch, 1, true)) then
                    bMatch = true;
                    break;
                end
            end

            local bFilter = sFilter == "";
            if (not bFilter and tSession.filterColumn == "") then
                for _, sHeader in ipairs(tSession.headers) do
                    if (tostring(tRow[sHeader] or ""):lower():find(sFilter, 1, true)) then
                        bFilter = true;
                        break;
                    end
                end
            elseif (not bFilter) then
                bFilter = tostring(tRow[tSession.filterColumn] or ""):lower():find(sFilter, 1, true) ~= nil;
            end

            if (bMatch and bFilter) then
                tVisible[#tVisible + 1] = nRow;
            end
        end

        if (tSession.sortColumn ~= "") then
            table.sort(tVisible, function(nLeft, nRight)
                local sLeft = tostring(tRows[nLeft][tSession.sortColumn] or "");
                local sRight = tostring(tRows[nRight][tSession.sortColumn] or "");
                local vLeft, vRight = tonumber(sLeft), tonumber(sRight);

                if ((vLeft ~= nil) ~= (vRight ~= nil)) then
                    if (tSession.descending) then return vLeft == nil; end

                    return vLeft ~= nil;
                end

                if (vLeft == nil) then
                    vLeft, vRight = sLeft:lower(), sRight:lower();
                end

                if (vLeft == vRight) then
                    return nLeft < nRight;
                end

                if (tSession.descending) then
                    return vLeft > vRight;
                end

                return vLeft < vRight;
            end);
        end

        tSession.visible = tVisible;
        notify();
    end

    --[[!
    @fqxn CFS.Windows.DataSession.Session.setData
    @desc Copies matching base/final rows, resets selection and filters, and rejects reload during code editing.
    @vis public
    @param any tHeaders Ordered column headers.
    @param any tBase Base.
    @param any tFinal Final.
    @param any tCodeColumns Code columns.
    !]]
    function tSession.setData(tHeaders, tBase, tFinal, tCodeColumns)
        assert(not tSession.editing, "Cannot reload data during code editing.");
        assert(#tBase == #tFinal, "Base and final row counts must match.");
        tSession.headers, tSession.base, tSession.final = {}, {}, {};

        for nColumn, sHeader in ipairs(tHeaders) do
            tSession.headers[nColumn] = sHeader;
        end

        for nRow, tRow in ipairs(tBase) do
            tSession.base[nRow], tSession.final[nRow] = {}, {};

            for _, sHeader in ipairs(tHeaders) do
                tSession.base[nRow][sHeader] = tostring(tRow[sHeader] or "");
                tSession.final[nRow][sHeader] = tostring(tFinal[nRow][sHeader] or "");
            end
        end

        tSession.codeColumns = tCodeColumns or {};
        tSession.selected, tSession.column, tSession.dirty = nil, 1, false;
        tSession.search, tSession.filterColumn, tSession.filterText, tSession.sortColumn = "", "", "", "";
        tSession.refresh();
    end

    --[[!
    @fqxn CFS.Windows.DataSession.Session.select
    @desc Selects an existing source row and column and notifies views and the optional selection callback.
    @vis public
    @param any nSourceRow Original source-row index.
    @param any nColumn Column.
    !]]
    function tSession.select(nSourceRow, nColumn)
        assert(tSession.base[nSourceRow], "Selected source row is unavailable.");

        if (tSession.selected == nSourceRow and tSession.column == nColumn) then return; end

        tSession.selected, tSession.column = nSourceRow, nColumn;
        notify();

        if (tOptions.onSelection) then
            tOptions.onSelection(nSourceRow, nColumn);
        end
    end

    --[[!
    @fqxn CFS.Windows.DataSession.Session.save
    @desc Saves dirty base rows through the connected callback, clearing dirty state only after success.
    @vis public
    !]]
    function tSession.save()
        assert(not tSession.editing, "Finish code editing before saving.");
        assert(type(tOptions.onSave) == "function", "Saving is not connected.");

        if (not tSession.dirty) then
            return;
        end

        assert(tOptions.onSave(tSession.base) ~= false, "Saving failed.");
        tSession.dirty = false;
        notify();
    end

    --[[!
    @fqxn CFS.Windows.DataSession.addCards
    @desc Creates a batch through the processor and selects the first new card. Existing drafts are retained.
    @param number nCount Positive whole number of cards.
    !]]
    function tSession.addCards(nCount)
        if (tSession.editing) then error("Finish code editing before adding cards.", 2); end
        if (type(nCount) ~= "number" or nCount < 1 or nCount > 10000 or nCount ~= math.floor(nCount)) then
            error("Enter a quantity from 1 to 10000.", 2);
        end

        local nFirst = #tSession.base + 1;
        local tData  = tOptions.onStructure("cards", nCount);

        tSession.setData(tData.headers, tData.base, tData.final, tData.codeColumns);
        tSession.dirty = true;
        tSession.refresh();
        tSession.select(nFirst, 1);
    end


    --[[!
    @fqxn CFS.Windows.DataSession.changeColumn
    @desc Processes an added, renamed, or deleted column before committing it to both views.
    @param string sAction Add, rename, or delete operation.
    @param string sHeader Existing header or new header for an add.
    @param string sNewHeader Replacement header for a rename.
    !]]
    function tSession.changeColumn(sAction, sHeader, sNewHeader)
        if (tSession.editing) then error("Finish code editing before changing columns.", 2); end

        local nSelected = tSession.selected;
        local tData     = tOptions.onStructure(sAction, sHeader, sNewHeader);

        tSession.setData(tData.headers, tData.base, tData.final, tData.codeColumns);
        tSession.dirty = true;
        tSession.refresh();

        if (nSelected and tSession.base[nSelected]) then
            tSession.select(nSelected, 1);
        end
    end


    --[[!
    @fqxn CFS.Windows.DataSession.Session.edit
    @desc Processes a changed base cell before replacing its final row, then marks the session dirty and refreshes views.
    @vis public
    @param any nSourceRow Original source-row index.
    @param any sHeader Column header.
    @param any sValue Value text.
    !]]
    function tSession.edit(nSourceRow, sHeader, sValue)
        assert(not tSession.editing, "Finish code editing before changing data.");
        assert(type(sValue) == "string" and tSession.base[nSourceRow], "Invalid data edit.");

        if (tSession.base[nSourceRow][sHeader] == sValue) then
            return;
        end

        assert(type(tOptions.onEdit) == "function", "Data processor is not connected.");
        local tFinalRow = tOptions.onEdit(nSourceRow, sHeader, sValue);
        assert(type(tFinalRow) == "table", "Processor must return the updated final row.");
        tSession.base[nSourceRow][sHeader] = sValue;

        for _, sColumn in ipairs(tSession.headers) do
            tSession.final[nSourceRow][sColumn] = tostring(tFinalRow[sColumn] or "");
        end

        tSession.dirty = true;
        tSession.refresh();
    end

    return tSession;
end

return DataSession;
