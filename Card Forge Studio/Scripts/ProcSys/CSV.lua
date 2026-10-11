--[[!
@fqxn CFS.Modules.ProcSys.CSV
@desc
<section aria-label="Card Data Processing overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Card Data Processing</h2><p style="font-size:1.15rem;margin:0">The CSV processor connects entered values with the values used to draw a card.</p></div>
<h3>How it fits into your work</h3><p>It reads source rows by column name, evaluates designated code cells, and applies the row processor. The two grids can then show source and result side by side.</p>
<figure style="margin:1.5rem 0"><figcaption style="font-weight:700;margin-bottom:.8rem">The big picture</figcaption><div role="img" aria-label="Base Data then Code cells and RowProc then Final Data" style="display:flex;flex-wrap:wrap;align-items:center;gap:.7rem"><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Base Data</span><span aria-hidden="true" style="color:var(--accent)">→</span><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Code cells and RowProc</span><span aria-hidden="true" style="color:var(--accent)">→</span><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Final Data</span></div></figure>
<h3>Follow the handoffs</h3><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,260px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">What enters and what comes out</h3><p style="margin:0">The processor receives column headings, the entered rows, the row-processing function, and the list of code columns. It produces a processed version of each row while keeping the entered values available. Base Data shows what you supplied; Final Data shows what processing produced.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">From an edit to a preview</h3><p style="margin:0">Changing a base cell runs processing for that row. If processing fails, the cell operation restores its previous base value rather than accepting a partly processed edit. Selecting a row makes its drawing values available to the user environment and Forge. The processor prepares the values; Forge turns them into artwork.</p></article>
</div>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys">Processing System</a></h3><p style="margin:0">ProcSys keeps project files, card values, and the preview working together as you edit.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.UserEnv">User Environment</a></h3><p style="margin:0">UserEnv is the shared workspace where game scripts find configuration, helper values, and the APIs Studio exposes.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.DataSession">Shared Data Session</a></h3><p style="margin:0">The shared session keeps both grids looking at the same underlying cards.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys.Save">Card Data Saving</a></h3><p style="margin:0">The save service protects the connection between edited card data and disk files.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Name is required and case-insensitive duplicate column names are rejected. Sorting or filtering a view does not rewrite stored source-row order.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual functions, inputs, and results.</p>
</section>
!]]

-- WX data processing. The retained AMS implementation below is not executed.
-- TODO Restore live-file watchers, named row filters, saving, backup, and rendering
-- when their ports are complete. This stage only reads linked game files.
local CSV = {};

--[[!
@fqxn CFS.Modules.ProcSys.CSV.Functions.create
@pulsarlua function CSV.create
@desc Processes base rows and code cells into final data, returning editing, row processing, selection, and processor replacement operations.
@param any tHeaders Ordered column headers.
@param any tBase Base.
@param any fRowProc Row proc.
@param any tCodeColumns Code columns.
@param any UserEnv User env.
@param any fProgress Progress.
!]]
function CSV.create(tHeaders, tBase, fRowProc, tCodeColumns, UserEnv, fProgress)
    local tData = {
        headers     = tHeaders,
        base        = tBase,
        final       = {},
        codeColumns = tCodeColumns,
        codeReturns = {},
    };
    local tHeaderMap = {};

    for _, sHeader in ipairs(tHeaders) do
        assert(not tHeaderMap[sHeader:upper()], "Duplicate case-insensitive column: "..sHeader);
        tHeaderMap[sHeader:upper()] = sHeader;
    end

    assert(tHeaderMap.NAME, "The CSV requires a Name column.");

    --[[!
    @fqxn CFS.Modules.ProcSys.CSV.Private.Functions.rowView
    @desc Creates a read-only row view supporting numeric and named column access.
    @param any tRow Row.
    @param any nRow Row.
    @vis private
    !]]
    local function rowView(tRow, nRow)
        return setmetatable({}, {
            __index = function(t, vKey)
                local sHeader = rawtype(vKey) == "number" and tHeaders[vKey] or tHeaderMap[tostring(vKey):upper()];
                return sHeader and tRow[sHeader];
            end,
            __newindex = function() error("Cannot modify a processing row.", 2); end,
            __len = function() return #tHeaders; end,
            __bnot = function() return nRow; end,
            __pairs = function()
                local nColumn = 0;
                return function()
                    nColumn = nColumn + 1;
                    local sHeader = tHeaders[nColumn];
                    if (sHeader) then return nColumn, sHeader, tRow[sHeader]; end
                end
            end,
        });
    end

    -- Build a replacement model before committing structural changes.
    --[[!
    @fqxn CFS.Modules.ProcSys.CSV.Data.rebuild
    @desc Creates a newly processed data object using the replacement headers, rows, and code-column definitions.
    @param any tNewHeaders New headers.
    @param any tNewBase New base.
    @param any tNewCodeColumns New code columns.
    @vis public
    !]]
    function tData.rebuild(tNewHeaders, tNewBase, tNewCodeColumns)
        return CSV.create(tNewHeaders, tNewBase, fRowProc, tNewCodeColumns, UserEnv);
    end


    --[[!
    @fqxn CFS.Modules.ProcSys.CSV.Data.processRow
    @desc Processes base values and code-cell results into one final row and retains code return values for rendering.
    @param any nRow Row.
    @vis public
    !]]
    function tData.processRow(nRow)
        local tBaseRow   = assert(tBase[nRow], "Source row is unavailable.");
        local tFinalRow  = {};
        local tReturns   = {};
        local wUser      = UserEnv.Get();
        local tOldRow    = wUser._tRow;
        local tRow       = rowView(tBaseRow, nRow);

        UserEnv.ProcSysUpdateRoot({_tRow = tRow});
        local bOK, sError = xpcall(function()
            for nColumn, sHeader in ipairs(tHeaders) do
                local sText = tBaseRow[sHeader] or "";

                if (sHeader:upper() == "NAME") then
                    tFinalRow[sHeader] = sText;
                elseif (tCodeColumns[sHeader]) then
                    if (sText == "") then
                        tFinalRow[sHeader] = "";
                    else
                        local bCodeOK, vCodeResult = xpcall(function()
                            local sCode = base64.dec(sText);
                            local fChunk, sCompileError = load(sCode, "Code cell - row "..nRow.." - "..sHeader, "t", wUser);
                            assert(fChunk, sCompileError);
                            local fCode = fChunk();
                            assert(rawtype(fCode) == "function", "Code cell must return a function.");
                            return fCode();
                        end, debug.traceback);
                        if (bCodeOK) then
                            tReturns[sHeader] = vCodeResult;
                            tFinalRow[sHeader] = "COMPILED";
                        else
                            tFinalRow[sHeader] = "ERROR";
                            Log.Warning(vCodeResult);
                        end
                    end
                else
                    --[[!
                    @fqxn CFS.Modules.ProcSys.CSV.Private.Functions.getFinalValue
                    @desc Resolves a final column value for code-cell evaluation, rejecting unknown column names.
                    @param any sColumn Column.
                    @param any vCoerce Coerce.
                    @vis private
                    !]]
                    local function getFinalValue(sColumn, vCoerce)
                        local sActual = assert(tHeaderMap[sColumn:upper()], "Unknown final column: "..sColumn);
                        local sValue = tFinalRow[sActual] or "";
                        if (vCoerce == PROCSYS_TO_NUMBER) then
                            return tonumber((sValue:collapse())) or sValue;
                        end
                        return sValue;
                    end

                    local vResult = fRowProc(nRow, nColumn, sHeader, tRow, sText, getFinalValue);
                    -- Preserve the original processor's string-return contract.
                    tFinalRow[sHeader] = rawtype(vResult) == "string" and vResult or sText;
                end
            end
        end, debug.traceback);
        wUser._tRow = tOldRow;
        assert(bOK, sError);
        tData.final[nRow] = tFinalRow;
        tData.codeReturns[nRow] = tReturns;
        return tFinalRow;
    end

    --[[!
    @fqxn CFS.Modules.ProcSys.CSV.Data.setRowProcessor
    @desc Replaces the row processor after validating that it is callable.
    @param any fProcessor Processor.
    @vis public
    !]]
    function tData.setRowProcessor(fProcessor)
        assert(rawtype(fProcessor) == "function", "RowProc must return a function.");
        fRowProc = fProcessor;
    end

    --[[!
    @fqxn CFS.Modules.ProcSys.CSV.Data.edit
    @desc Processes a changed source cell and restores its old base value if processing fails.
    @param any nRow Row.
    @param any sHeader Header.
    @param any sValue Value.
    @vis public
    !]]
    function tData.edit(nRow, sHeader, sValue)
        assert(tHeaderMap[sHeader:upper()] == sHeader, "Unknown editable column.");
        local sOldValue = tBase[nRow][sHeader];
        tBase[nRow][sHeader] = sValue;
        local bOK, tResult = pcall(tData.processRow, nRow);
        if (not bOK) then
            tBase[nRow][sHeader] = sOldValue;
            error(tResult, 0);
        end
        return tResult;
    end

    --[[!
    @fqxn CFS.Modules.ProcSys.CSV.Data.select
    @desc Builds the selected render row using code return values and publishes it to UserEnv and Forge.
    @param any nRow Row.
    @vis public
    !]]
    function tData.select(nRow)
        local tFinalRow = assert(tData.final[nRow]);
        local tRenderRow = {};
        for _, sHeader in ipairs(tHeaders) do
            if (tCodeColumns[sHeader]) then
                tRenderRow[sHeader] = tData.codeReturns[nRow][sHeader];
            else
                tRenderRow[sHeader] = tFinalRow[sHeader];
            end
        end
        local tRow = rowView(tRenderRow, nRow);
        UserEnv.ProcSysUpdateRoot({_tRow = tRow});
        Forge.SetActiveRow(tRow);

    end

    local nLastProgress = os.clock();
    if (fProgress) then fProgress(0, #tBase); end
    for nRow in ipairs(tBase) do
        tData.processRow(nRow);
        if (fProgress and (nRow == #tBase or os.clock() - nLastProgress >= 0.1)) then
            fProgress(nRow, #tBase);
            nLastProgress = os.clock();
        end
    end

    return tData;
end

return CSV;
