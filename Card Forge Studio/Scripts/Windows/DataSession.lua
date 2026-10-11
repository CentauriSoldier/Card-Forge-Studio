--[[!
@fqxn CFS.Windows.DataSession
@desc
<section aria-label="Shared Data Session overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Shared Data Session</h2><p style="font-size:1.15rem;margin:0">The shared session keeps both grids looking at the same underlying cards.</p></div>
<h3>How it fits into your work</h3><p>Sorting and filtering change visible positions while source-row identity preserves matching selections and synchronized views.</p>
<h3>Follow the handoffs</h3><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,260px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">Two grids, one set of cards</h3><p style="margin:0">Base Data presents entered values and Final Data presents processed results. Both windows use this shared session to identify the same underlying card. Selection is therefore attached to the source row rather than merely to its current position on screen.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">Why that distinction matters</h3><p style="margin:0">Sorting can move a card to the top of a view, and filtering can hide neighboring cards. The shared row identity lets the other grid highlight the corresponding card instead of a different row at the same screen position. Edits mark the session as changed and processing supplies the resulting values; saving remains a separate handoff.</p></article>
</div>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.BaseData">BaseData</a></h3><p style="margin:0">Base Data is the table of values you actually edit.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.FinalData">FinalData</a></h3><p style="margin:0">Final Data shows the results after card values and scripts have been processed.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.DataGrid">Data Grid</a></h3><p style="margin:0">The common grid supplies table controls for both data windows.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys">Processing System</a></h3><p style="margin:0">ProcSys keeps project files, card values, and the preview working together as you edit.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Visible row position and source row identity are different. Keeping that distinction avoids selecting the wrong card after sorting.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

-- Shared data and view state for Base Data and Final Data.
-- Visible row positions always map back to the original source row.
local DataSession = {};

--[[!
@fqxn CFS.Windows.DataSession.Functions.create
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
    @fqxn CFS.Windows.DataSession.Private.Functions.notify
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
