-- Shared data and view state for Base Data and Final Data.
-- Visible row positions always map back to the original source row.
local DataSession = {};

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
    local tListeners = {};

    local function notify()
        for _, fListener in ipairs(tListeners) do
            fListener();
        end
    end

    function tSession.subscribe(fListener)
        tListeners[#tListeners + 1] = fListener;
    end

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

            if (bMatch and (tSession.filterColumn == "" or
                tostring(tRow[tSession.filterColumn] or ""):lower():find(sFilter, 1, true))) then
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

    function tSession.select(nSourceRow, nColumn)
        assert(tSession.base[nSourceRow], "Selected source row is unavailable.");

        if (tSession.selected == nSourceRow and tSession.column == nColumn) then return; end

        tSession.selected, tSession.column = nSourceRow, nColumn;
        notify();

        if (tOptions.onSelection) then
            tOptions.onSelection(nSourceRow, nColumn);
        end
    end

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
