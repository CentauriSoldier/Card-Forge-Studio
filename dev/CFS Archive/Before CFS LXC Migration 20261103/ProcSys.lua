--[[!
@fqxn CFS.Modules.ProcSys
@desc
<section aria-label="Processing System overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Processing System</h2><p style="font-size:1.15rem;margin:0">ProcSys keeps project files, card values, and the preview working together as you edit.</p></div>
<h3>How it fits into your work</h3><p>Loading a set reads the CSV and scripts, prepares the environment, processes rows, and connects drawing callbacks. Later file changes are queued and applied by the processing timer.</p>
<figure style="margin:1.5rem 0"><figcaption style="font-weight:700;margin-bottom:.8rem">The big picture</figcaption><div role="img" aria-label="Project files then User environment then Processed rows then Selected card then Forge preview" style="display:flex;flex-wrap:wrap;align-items:center;gap:.7rem"><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Project files</span><span aria-hidden="true" style="color:var(--accent)">→</span><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">User environment</span><span aria-hidden="true" style="color:var(--accent)">→</span><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Processed rows</span><span aria-hidden="true" style="color:var(--accent)">→</span><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Selected card</span><span aria-hidden="true" style="color:var(--accent)">→</span><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Forge preview</span></div></figure>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.Game">Game</a></h3><p style="margin:0">Game activation selects the project and clears the previous card-set state.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.CardSet">Card Set</a></h3><p style="margin:0">The selected set supplies metadata and the file locations for loading.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.UserEnv">User Environment</a></h3><p style="margin:0">ProcSys loads shared Config and Environment values before evaluating set scripts.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys.CSV">Card Data Processing</a></h3><p style="margin:0">The CSV processor evaluates code cells and row instructions to create final values.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.LiveFileRepo">Live File Repository</a></h3><p style="margin:0">The watcher reports file edits; ProcSys queues and applies the resulting reloads.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.DataSession">Shared Data Session</a></h3><p style="margin:0">The shared session connects source and final values to both grids.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Forge">Forge</a></h3><p style="margin:0">ProcSys supplies drawing callbacks and the selected processed row, then requests redraws.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys.Save">Card Data Saving</a></h3><p style="margin:0">The saving service handles source rows and code-column definitions with conflict checks.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Base Data is the source and Final Data is its processed result. A watcher notification is not itself an immediate redraw.</p></aside>
<h3>What happens after an edit?</h3><p>Changing a source value and saving a drawing script are different events, but both need to reach the same preview. ProcSys keeps that handoff orderly: it identifies the changed input, updates the affected processing or drawing instructions, and asks Forge to display the selected card again.</p><p>The two grids are views of one working set. Their selection remains tied to the original source card even when the visible rows are sorted or filtered.</p>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

-- Module.
local ProcSys = {};

-- Dependencies.
local LiveFileRepo  = require("LiveFileRepo");
local wx            = require("wx");

-- Active game and card-set objects.
local _oActiveCardSet   = false;
local _oActiveGame      = false;

-- Processed data and its bound grid session.
local _tData    = nil;
local _tSession = nil;

-- CSV paths and the last saved file contents.
local _pActiveBackup;
local _pActiveCSV;
local _sCSVOriginal;
local _sCodeColumnsOriginal;

-- Card currently selected for rendering.
local _nSelectedRow;

-- Live-file processing state.
local _bLiveBusy    = false;
local _oLiveFiles   = LiveFileRepo();
local _tLiveChanges = {};


--[[!
@fqxn CFS.Modules.ProcSys.Private.Functions.captureWatchFiles
@desc Rebuilds the active game and card-set watch list and starts its LiveFileRepo timers.
@note Watcher callbacks queue changes by category; OnTimer applies those changes separately.
!]]
local function captureWatchFiles()
    -- Stop the previous watch list before registering the new game and card-set files.
    _oLiveFiles.Reset();
    _tLiveChanges = {};

    local tFiles = {
        [(FS.GetResourceRoot().."/Styles.ini")] = "Styles",
    };

    if (_oActiveCardSet) then
        tFiles[FS.CardSet.Draw]         = "Draw";
        tFiles[FS.CardSet.DrawBack]     = "DrawBack";
        tFiles[FS.CardSet.RowProc]      = "RowProc";
        tFiles[FS.CardSet.CodeColumns]  = "CodeColumns";
        tFiles[FS.CardSet.Data]         = "Data";

        if (FS.CardSet.Info) then
            tFiles[FS.CardSet.Info] = "Info";
        end

    end

    -- Include Lua scripts recursively so edits to ENV and CFG helpers trigger a reload.
    --[[!
    @fqxn CFS.Modules.ProcSys.Private.Functions.scripts
    @desc Collects Lua source records from a native directory.
    @param any pFolder Folder.
    @vis private
    !]]
    local function scripts(pFolder)
        local oFolder = wx.wxDir(pFolder);

        if (oFolder:IsOpened()) then
            local bFound, sName = oFolder:GetFirst("*.lua", wx.wxDIR_FILES);

            while (bFound) do
                tFiles[pFolder.."/"..sName] = "Environment";
                bFound, sName = oFolder:GetNext();
            end

            local bDirectory, sDirectory = oFolder:GetFirst("", wx.wxDIR_DIRS);

            while (bDirectory) do
                scripts(pFolder.."/"..sDirectory);
                bDirectory, sDirectory = oFolder:GetNext();
            end
        end
        oFolder:delete();
    end

    scripts((FS.GetResourceRoot().."/Scripts"));

    -- File timers only queue changes; the application timer performs the actual update.
    local nID = 0;

    for pFile, sKind in pairs(tFiles) do
        nID             = nID + 1;
        local sCategory = sKind;

        _oLiveFiles.Add(tostring(nID), pFile, PROCSYS_LIVE_FILE_REPO_TIMER_INTERVAL, function(tFile, sOldText, sNewText)
            _tLiveChanges[sCategory] = sNewText;
        end);
    end

    _oLiveFiles.StartAll();
end


--[[!
@fqxn CFS.Modules.ProcSys.Private.Functions.readFile
@desc Reads a source file as bytes and checks both reading and closing errors.
@param string pFile Source path.
@return string sText Complete file contents.
!]]
local function readFile(pFile)
    local hFile                 = assert(io.open(io.normalizepath(pFile), "rb"));
    local sText, sError         = hFile:read("a");
    local bClosed, sCloseError  = hFile:close();

    assert(sText, sError);
    assert(bClosed, sCloseError);

    return sText;
end


--[[!
@fqxn CFS.Modules.ProcSys.Functions.BindSession
@pulsarlua function ProcSys.BindSession
@desc Connects grid editing, selection, saving, and export callbacks to the active processing state.
@param table tSession Data session whose options receive callbacks.
!]]
function ProcSys.BindSession(tSession)
    _tSession = tSession;

    -- Export status state shared by the bound grid windows.
    local sExportStatus     = "";
    local tExportListeners  = {};

    -- Declare every local helper before assigning functions in alphabetical order.
    local exportStatus;

    -- Expose card names, metadata path, and dimensions to export controls.
    --[[!
    @fqxn CFS.Modules.ProcSys.Private.Functions.tSession_options_exportContext
    @desc Returns the active card-set export metadata and card names, or nil when no set is loaded.
    @vis private
    !]]
    tSession.options.exportContext = function()
        if (not _oActiveCardSet or not _tData) then
            return nil;
        end

        local tNames = {};

        for nRow, tRow in ipairs(tSession.base) do
            tNames[nRow] = tostring(tRow.Name or tRow.NAME or "Card");
        end

        return {
            info   = FS.CardSet.Info,
            names  = tNames,
            headers = _tData.headers,
            final   = _tData.final,
            width  = _oActiveCardSet.GetCardWidth(),
            height = _oActiveCardSet.GetCardHeight()
        };
    end


    -- Broadcast the latest status to every subscribed grid window.
    --[[!
    @fqxn CFS.Modules.ProcSys.Private.Functions.exportStatus
    @desc Publishes the current export status to registered listeners.
    @param any sText Text.
    @vis private
    !]]
    exportStatus = function(sText)
        sExportStatus = sText;

        for fListener in pairs(tExportListeners) do
            fListener(sText);
        end

    end


    -- Apply an edit to the processed model and refresh the selected card data.
    --[[!
    @fqxn CFS.Modules.ProcSys.Private.Functions.tSession_options_onEdit
    @desc Processes one edited source cell and refreshes the selected render row when needed.
    @param any nRow Row.
    @param any sHeader Header.
    @param any sValue Value.
    @vis private
    !]]
    tSession.options.onEdit = function(nRow, sHeader, sValue)
        local tResult = assert(_tData, "No card set is loaded.").edit(nRow, sHeader, sValue);

        if (tSession.selected == nRow) then
            _tData.select(nRow);
        end

        return tResult;
    end


    -- Export the requested source rows and restore the previously selected card, including on failure.
    --[[!
    @fqxn CFS.Modules.ProcSys.Private.Functions.tSession_options_onExport
    @desc Builds and executes the selected format's export plan with progress updates.
    @param any tRows Rows.
    @param any pDirectory Directory.
    @param any tSettings Settings.
    @vis private
    !]]
    tSession.options.onExport = function(tRows, pDirectory, tSettings)
        assert(_tData and _oActiveCardSet, "No card set is loaded.");
        assert(not tSession.editing, "Finish editing before exporting.");
        assert(not tSession.exporting, "An export is already running.");

        local service   = require("Exporter").get(tSettings.type);
        local tContext  = tSession.options.exportContext();
        local nRestore  = _nSelectedRow;

        -- Shared busy state blocks both grids; cleanup runs after every export outcome.
        tSession.exporting = true;
        local bOK, nCount = xpcall(function()
            tSession.refresh();
            exportStatus("Preparing "..tSettings.type.." export...");
            local tPlan = service.plan(tRows, tSettings, tContext.names, #_tData.final, tContext.width, tContext.height, tContext);

            return service.run(pDirectory, tPlan, function(nRow, sFace, pFile)
                _tData.select(nRow);
                service.render(sFace, pFile, tSettings.scale or 100);
            end, function(sPhase, nDone, nTotal, tFile)
                local sCard         = tFile and tFile.row and (" | Row "..tFile.row.." - "..tContext.names[tFile.row].." | "..tFile.face) or "";
                local nCompleted    = sPhase == "Writing" and (nTotal + nDone) or nDone;
                local nPercent      = math.floor(100 * nCompleted / (2 * nTotal));

                exportStatus(sPhase.." "..tSettings.type.." output files: "..nDone.." / "..nTotal.." | "..nPercent.."%"..sCard);
            end);
        end, debug.traceback);

        local bRestored, sRestoreError = pcall(function()
            if (nRestore) then _tData.select(nRestore); end
        end);
        tSession.exporting = false;
        tSession.refresh();
        if (bOK and not bRestored) then bOK, nCount = false, sRestoreError; end

        if (not bOK) then

            exportStatus(tSettings.type.." export failed. See Log for details.");
            error(nCount, 0);

        end

        exportStatus("Export complete: "..nCount.." "..tSettings.type.." output files.");
        Log.Note(tSettings.type.." export completed: "..nCount.." output files.");

        return nCount;
    end


    -- Reprocess one source row and update its displayed final values.
    --[[!
    @fqxn CFS.Modules.ProcSys.Private.Functions.tSession_options_onReprocess
    @desc Reprocesses a source row and returns updated final values.
    @param any nRow Row.
    @vis private
    !]]
    tSession.options.onReprocess = function(nRow)
        local tFinalRow = assert(_tData, "No card set is loaded.").processRow(nRow);

        for _, sHeader in ipairs(tSession.headers) do
            tSession.final[nRow][sHeader] = tostring(tFinalRow[sHeader] or "");
        end

        if (tSession.selected == nRow) then
            _tData.select(nRow);
        end

        tSession.refresh();
    end


    -- Save CSV with conflict protection and backup support; retain the new file baseline.
    --[[!
    @fqxn CFS.Modules.ProcSys.Private.Functions.tSession_options_onSave
    @desc Saves base CSV rows and code-column definitions and updates the saved-source snapshot.
    @param any tRows Rows.
    @vis private
    !]]
    tSession.options.onSave = function(tRows)
        assert(_oActiveCardSet and _pActiveCSV, "No card set is loaded.");
        _sCSVOriginal = require("ProcSys.Save").write(_pActiveCSV, _pActiveBackup, tSession.headers, tRows, _sCSVOriginal, {path = FS.CardSet.CodeColumns, original = _sCodeColumnsOriginal, columns = tSession.codeColumns});
        _sCodeColumnsOriginal = readFile(FS.CardSet.CodeColumns);
        pcall(Log.Note, "Card set saved: ".._oActiveCardSet.GetName().." ("..#tRows.." rows).");

        return true;
    end


    -- Keep the renderer's active row in sync with grid selection.
    --[[!
    @fqxn CFS.Modules.ProcSys.Private.Functions.tSession_options_onSelection
    @desc Updates the selected source row and drawing environment when selection changes.
    @param any nRow Row.
    @vis private
    !]]
    tSession.options.onSelection = function(nRow)
        if (_tData and _nSelectedRow ~= nRow) then
            _nSelectedRow = nRow;
            _tData.select(nRow);
        end
    end


    -- Reload saved structural changes and restore a valid card selection.
    --[[!
    @fqxn CFS.Modules.ProcSys.Private.Functions.tSession_options_onReloadStructure
    @desc Reloads the active set after structural changes and restores a valid previous row selection.
    @vis private
    !]]
    tSession.options.onReloadStructure = function()
        local nSelected = tSession.selected;

        ProcSys.LoadCardSet(_oActiveCardSet);

        if (nSelected and tSession.base[nSelected]) then
            tSession.select(nSelected, 1);
        end
    end


    -- Build and process candidate rows; failure never replaces the active model.
    --[[!
    @fqxn CFS.Modules.ProcSys.Private.Functions.tSession_options_onStructure
    @desc Builds and processes draft card or column changes before committing the resulting structure.
    @param any sAction Action.
    @param any vHeader Header.
    @param any sNewHeader New header.
    @vis private
    !]]
    tSession.options.onStructure = function(sAction, vHeader, sNewHeader)
        if (not _tData) then error("No card set is loaded.", 2); end

        local tBase    = {};
        local tCodes   = {};
        local tHeaders = {};

        for nColumn, sHeader in ipairs(_tData.headers) do
            tHeaders[nColumn] = sHeader;
        end

        for sHeader, bCode in pairs(_tData.codeColumns) do
            tCodes[sHeader] = bCode;
        end

        for nRow, tRow in ipairs(_tData.base) do
            tBase[nRow] = {};

            for _, sHeader in ipairs(tHeaders) do
                tBase[nRow][sHeader] = tRow[sHeader];
            end
        end

        if (sAction == "cards") then
            local sNameHeader;
            local tNames = {};

            for _, sHeader in ipairs(tHeaders) do
                if (sHeader:upper() == "NAME") then sNameHeader = sHeader; end
            end

            for _, tRow in ipairs(tBase) do
                tNames[tostring(tRow[sNameHeader]):upper()] = true;
            end

            local nSuffix = 1;

            for nNew = 1, vHeader do
                local sName;

                repeat
                    sName = "UNNAMED_"..nSuffix;
                    nSuffix = nSuffix + 1;
                until not tNames[sName]

                local tRow = {};

                for _, sHeader in ipairs(tHeaders) do
                    tRow[sHeader] = "";
                end
                tRow[sNameHeader] = sName;
                tNames[sName] = true;
                tBase[#tBase + 1] = tRow;
            end
        else
            if (sAction ~= "add" and sAction ~= "rename" and sAction ~= "delete") then
                error("Unknown column operation.", 2);
            end
            if (type(vHeader) ~= "string" or vHeader == "" or vHeader:find("[%c]")) then
                error("Enter a column name without control characters.", 2);
            end
            if (sAction ~= "add" and vHeader:upper() == "NAME") then
                error("The required Name column cannot be renamed or deleted.", 2);
            end

            local nExisting;
            local sTarget = sAction == "rename" and sNewHeader or vHeader;

            if (sAction ~= "delete" and (type(sTarget) ~= "string" or not sTarget:match("%S") or sTarget:find("[%c]"))) then
                error("Enter a valid column name.", 2);
            end

            for nColumn, sHeader in ipairs(tHeaders) do
                if (sHeader == vHeader) then nExisting = nColumn; end
                if (sAction ~= "delete" and sHeader:upper() == sTarget:upper() and
                    (sAction == "add" or sHeader ~= vHeader)) then
                    error("A column with that name already exists.", 2);
                end
            end

            if (sAction == "rename" and sNewHeader == vHeader) then
                return _tData;
            end

            if (sAction == "add") then
                tHeaders[#tHeaders + 1] = vHeader;

                for _, tRow in ipairs(tBase) do
                    tRow[vHeader] = "";
                end
            else
                if (not nExisting) then error("Column is unavailable.", 2); end

                if (sAction == "rename") then
                    tHeaders[nExisting] = sNewHeader;
                    tCodes[sNewHeader] = tCodes[vHeader];
                else
                    table.remove(tHeaders, nExisting);
                end
                tCodes[vHeader] = nil;

                for _, tRow in ipairs(tBase) do
                    if (sAction == "rename") then tRow[sNewHeader] = tRow[vHeader]; end
                    tRow[vHeader] = nil;
                end
            end
        end

        local tCandidate = _tData.rebuild(tHeaders, tBase, tCodes);

        _tData = tCandidate;
        require("Autocomplete").SetHeaders(tCandidate.headers);
        _nSelectedRow = nil;

        return tCandidate;
    end


    -- Register a status listener and return its unsubscribe function.
    --[[!
    @fqxn CFS.Modules.ProcSys.Private.Functions.tSession_options_subscribeExportStatus
    @desc Registers an export-status listener, immediately publishes current status, and returns an unsubscribe callback.
    @param any fListener Listener.
    @vis private
    !]]
    tSession.options.subscribeExportStatus = function(fListener)
        tExportListeners[fListener] = true;
        fListener(sExportStatus);

        return function()
            tExportListeners[fListener] = nil;
        end

    end

    -- TODO Restore batched dirty-row processing.
end


--[[!
@fqxn CFS.Modules.ProcSys.Functions.GetActiveCardSet
@pulsarlua function ProcSys.GetActiveCardSet
@desc Returns the currently loaded card set.
@return CardSet|boolean oCardSet Active card set, or false when none is loaded.
!]]
function ProcSys.GetActiveCardSet()
    return _oActiveCardSet;
end


--[[!
@fqxn CFS.Modules.ProcSys.Functions.GetActiveGame
@pulsarlua function ProcSys.GetActiveGame
@desc Returns the currently prepared game.
@return Game|boolean oGame Active game, or false when none is prepared.
!]]
function ProcSys.GetActiveGame()
    return _oActiveGame;
end


--[[!
@fqxn CFS.Modules.ProcSys.Functions.LoadCardSet
@pulsarlua function ProcSys.LoadCardSet
@desc Loads game scripts, row processing, CSV data, and drawing functions, then rebuilds file monitoring.
@param CardSet oCardSet Card set to activate.
@param function|nil fProgress Optional processing progress callback.
@return table tData Processed CSV model.
@note Requires an active game and refuses to replace an active code-editing session.
!]]
function ProcSys.LoadCardSet(oCardSet, fProgress)
    assert(_oActiveGame, "Load a game first.");
    assert(not (_tSession and _tSession.editing), "Finish code editing first.");

    FS.CardSet.Prep(oCardSet);
    local ImportSystem = require("Globals.ImportSystem");

    Import = ImportSystem.Import;

    FontStyle = FontStyle or require("FontStyle");
    FontStyle.UpdateINI((FS.GetResourceRoot().."/Styles.ini"));

    Forge = Forge or require("Forge");

    UserEnv = UserEnv or require("Globals.UserEnv");
    UserEnv.UserUpdateENV({});
    UserEnv.ProcSysUpdateRoot({
        STYLE        = STYLE,
        _TABLE       = PROCSYS_TO_TABLE,
        _NUMBER      = PROCSYS_TO_NUMBER,
        _sCardSetName = oCardSet.GetName(),
        _nCardWidth   = oCardSet.GetCardWidth(),
        _nCardHeight  = oCardSet.GetCardHeight(),
    }, true);

    --[[!
    @fqxn CFS.Modules.ProcSys.Private.Functions.runFile
    @desc Loads and executes a game or card-set Lua source file in the user environment.
    @param any pFile File.
    @vis private
    !]]
    local function runFile(pFile)
        return assert(load(readFile(pFile), "@"..pFile, "t", UserEnv.Get()))();
    end

    local tCFG = runFile((FS.GetResourceRoot().."/Scripts").."/"..FILESPEC_GAME_CFG.Full);

    assert(rawtype(tCFG) == "table", "CFG must return a table.");
    UserEnv.UserUpdateCFG(tCFG);

    local tENV = runFile((FS.GetResourceRoot().."/Scripts").."/"..FILESPEC_GAME_ENV.Full);

    assert(rawtype(tENV) == "table", "ENV must return a table.");
    UserEnv.UserUpdateENV(tENV);

    local fRowProc = runFile(FS.CardSet.RowProc);

    assert(rawtype(fRowProc) == "function", "RowProc must return a function.");

    local sCSVOriginal      = readFile(FS.CardSet.Data);
    local tBase, tHeaders   = FTCSV.parse(sCSVOriginal, CSV_DELIMITER, {loadFromString = true});

    -- A trailing record separator is misread as an extra row in one-column files.
    if (#tHeaders == 1 and not sCSVOriginal:gsub("^\239\187\191", ""):match('^"?[Nn][Aa][Mm][Ee]"?[\r\n]+$')) then
        tBase, tHeaders = FTCSV.parse(sCSVOriginal:gsub("\r?\n$", ""), CSV_DELIMITER, {loadFromString = true});
    end

    -- FTCSV reports an empty row for a header-only, single-column CSV.
    if (#tHeaders == 1 and sCSVOriginal:gsub("^\239\187\191", ""):match('^"?[Nn][Aa][Mm][Ee]"?[\r\n]+$')) then
        tBase = {};
    end

    local tCodeColumns      = {};
    local sColumns          = readFile(FS.CardSet.CodeColumns);

    for sColumn in sColumns:gmatch("[^\r\n]+") do
        sColumn = sColumn:match("^%s*(.-)%s*$");

        for _, sHeader in ipairs(tHeaders) do

            if (sHeader:upper() == sColumn:upper()) then
                tCodeColumns[sHeader] = true;
            end

        end

    end

    Forge.SetActiveCardSet(oCardSet);
    Forge.SetDrawFunction(runFile(FS.CardSet.Draw));
    Forge.SetDrawBackFunction(runFile(FS.CardSet.DrawBack));

    local CSV   = require("ProcSys.CSV");
    local tData = CSV.create(tHeaders, tBase, fRowProc, tCodeColumns, UserEnv, fProgress);

    if (_tSession) then
        _tSession.setData(tHeaders, tBase, tData.final, tCodeColumns);
    end

    _tData, _oActiveCardSet   = tData, oCardSet;
    _pActiveCSV, _sCSVOriginal = FS.CardSet.Data, sCSVOriginal;
    _sCodeColumnsOriginal   = sColumns;
    _pActiveBackup           = FS.Game.CSVBackup.."/"..oCardSet.GetUUID();

    captureWatchFiles();
    Log.Note("Card set loaded: "..oCardSet.GetName().." ("..#tBase.." rows).");

    _nSelectedRow = #tBase > 0 and 1 or nil;

    if (_nSelectedRow) then
        tData.select(_nSelectedRow);
    end

    require("Autocomplete").SetHeaders(tHeaders);
    require("Autocomplete").Flush();
    return tData;
end


--[[!
@fqxn CFS.Modules.ProcSys.Functions.OnTimer
@pulsarlua function ProcSys.OnTimer
@desc Applies queued file changes to the active data, user environment, metadata, and Forge renderer.
@note Skips processing while busy or editing. External CSV reload follows the session policy; errors are logged and the busy flag is cleared.
!]]
function ProcSys.OnTimer()
    if (not _bLiveBusy and not (_tSession and (_tSession.editing or _tSession.exporting))) then
        require("Autocomplete").Flush();
    end
    if (_bLiveBusy or (_tSession and _tSession.editing) or next(_tLiveChanges) == nil) then
        return;
    end
    _bLiveBusy = true;
    local tChanged = _tLiveChanges;

    _tLiveChanges = {};
    local bOK, sError = xpcall(function()
        -- Evaluate the selected script in UserEnv and use its returned value.
        --[[!
        @fqxn CFS.Modules.ProcSys.Private.Functions.runFile2
        @desc Loads and executes a game or card-set Lua source file in the user environment.
        @param any pFile File.
        @vis private
        !]]
        local function runFile(pFile)

            return assert(load(readFile(pFile), "@"..pFile, "t", UserEnv.Get()))();
        end

        -- Ask the session before replacing CSV data, preserving unsaved edits when reload is declined.
        if (tChanged.Data and tChanged.Data ~= _sCSVOriginal and _oActiveCardSet) then
            local bReload = true;

            if (_tSession and _tSession.options.onExternalCSV) then
                bReload = _tSession.options.onExternalCSV(_tSession.dirty);

            elseif (_tSession and _tSession.dirty) then
                bReload = false;

            end

            if (bReload) then
                local nSelected = _tSession and _tSession.selected;

                ProcSys.LoadCardSet(_oActiveCardSet);

                if (nSelected and _tSession and _tSession.base[nSelected]) then

                    _tSession.select(nSelected, 1);

                end

                Log.Note("External CSV changes loaded.");

                return;
            end
            Log.Warning("External CSV changed; current edits were retained.");
        end

        -- Refresh metadata and logical card dimensions before reprocessing rows.
        if (tChanged.Info) then
            _oActiveCardSet.RefreshInfo();
            UserEnv.ProcSysUpdateRoot({
                _sCardSetName = _oActiveCardSet.GetName(),
                _nCardWidth   = _oActiveCardSet.GetCardWidth(),
                _nCardHeight  = _oActiveCardSet.GetCardHeight(),
            });

            Forge.SetActiveCardSet(_oActiveCardSet);

            if (_tSession and _tSession.options.onMetadataChanged) then
                _tSession.options.onMetadataChanged(_oActiveCardSet);
            end

            Log.Note("Card-set metadata updated: ".._oActiveCardSet.GetName());
        end

        if (tChanged.Styles and FontStyle) then

            FontStyle.UpdateINI((FS.GetResourceRoot().."/Styles.ini"));

        end

        if (not _tData) then
            return;
        end

        -- Reload CFG before ENV, using the same private user environment as card scripts.
        if (tChanged.Environment) then
            local tCFG = runFile((FS.GetResourceRoot().."/Scripts").."/"..FILESPEC_GAME_CFG.Full);

            assert(rawtype(tCFG) == "table", "CFG must return a table.");
            UserEnv.UserUpdateCFG(tCFG);

            local tENV = runFile((FS.GetResourceRoot().."/Scripts").."/"..FILESPEC_GAME_ENV.Full);

            assert(rawtype(tENV) == "table", "ENV must return a table.");
            UserEnv.UserUpdateENV(tENV);
        end

        if (tChanged.RowProc) then
            _tData.setRowProcessor(runFile(FS.CardSet.RowProc));
        end

        -- Rebuild the set of code-column headers from the edited text file.
        if (tChanged.CodeColumns) then
            local tCodeColumns = {};

            for sColumn in tChanged.CodeColumns:gmatch("[^\\r\\n]+") do
                sColumn = sColumn:match("^%s*(.-)%s*$");

                for _, sHeader in ipairs(_tData.headers) do

                    if (sHeader:upper() == sColumn:upper()) then
                        tCodeColumns[sHeader] = true;
                    end

                end

            end

            for sHeader in pairs(_tData.codeColumns) do
                _tData.codeColumns[sHeader] = nil;
            end

            for sHeader in pairs(tCodeColumns) do
                _tData.codeColumns[sHeader] = true;
            end

            if (_tSession) then
                _tSession.codeColumns = _tData.codeColumns;
            end

        end

        -- Reprocess affected rows, then copy their displayed values into the bound grid session.
        if (tChanged.Environment or tChanged.RowProc or tChanged.Styles or tChanged.CodeColumns or tChanged.Info) then

            for nRow in ipairs(_tData.base) do
                _tData.processRow(nRow);
            end

            if (_tSession) then

                for nRow, tRow in ipairs(_tData.final) do

                    for _, sHeader in ipairs(_tData.headers) do
                        _tSession.final[nRow][sHeader] = tostring(tRow[sHeader] or "");
                    end

                end

                _tSession.refresh();
            end

        end

        -- Swap drawing callbacks and request a fresh preview after applying all queued changes.
        if (tChanged.Draw) then
            Forge.SetDrawFunction(runFile(FS.CardSet.Draw));
        end

        if (tChanged.DrawBack) then
            Forge.SetDrawBackFunction(runFile(FS.CardSet.DrawBack));
        end

        local nRow = _tSession and _tSession.selected or 1;

        if (nRow and _tData.final[nRow]) then
            _tData.select(nRow);
        end

        Forge.RequestCardRedraw();
        Log.Note("Live card scripts or styles updated.");

    end, debug.traceback);
    _bLiveBusy = false;

    if (bOK) then require("Autocomplete").Flush(); end

    if (not bOK) then
        Log.Error(sError);
    end

end


--[[!
@fqxn CFS.Modules.ProcSys.Functions.PrepGame
@pulsarlua function ProcSys.PrepGame
@desc Resets an existing user environment to its built-ins for game loading, sets the active game, clears card-set state, rebuilds monitoring, and releases the previous Forge card.
@param Game oGame Game to activate.
!]]
function ProcSys.PrepGame(oGame)
    assert(type(oGame) == "Game", "ProcSys.PrepGame requires a Game object.");

    Import = require("Globals.ImportSystem").Import;
    FontStyle = FontStyle or require("FontStyle");
    FontStyle.UpdateINI(FS.GetResourceRoot().."/Styles.ini");
    Forge = Forge or require("Forge");
    UserEnv = UserEnv or require("Globals.UserEnv");
    UserEnv.Refresh();

    require("Autocomplete").SetActive(true);
    require("Autocomplete").Flush();
    _oActiveGame                        = oGame;
    _oActiveCardSet, _tData, _nSelectedRow = false, nil, nil;
    _pActiveCSV, _pActiveBackup, _sCSVOriginal = nil, nil, nil;
    Log.Note("ProcSys: active game prepared.");
    captureWatchFiles();

    if (Forge) then
        Forge.Release();
    end
    -- Metadata changes are applied through the live-file timer.
end


--[[!
@fqxn CFS.Modules.ProcSys.Functions.Shutdown
@pulsarlua function ProcSys.Shutdown
@desc Stops file monitoring and clears queued changes.
!]]
function ProcSys.Shutdown()
    _oLiveFiles.Reset();
    _tLiveChanges = {};
end

--[[!
@fqxn CFS.Modules.ProcSys.Functions.CloseCardSet
@pulsarlua function ProcSys.CloseCardSet
@desc Clears the active card set, data, drawing environment and set watchers while retaining the active game.
!]]
function ProcSys.CloseCardSet()
    assert(not (_tSession and _tSession.exporting), "Wait for the export to finish before closing the card set.");
    _oActiveCardSet, _tData, _nSelectedRow = false, nil, nil;
    _pActiveCSV, _pActiveBackup, _sCSVOriginal, _sCodeColumnsOriginal = nil, nil, nil, nil;
    if (UserEnv) then UserEnv.ProcSysUpdateRoot({}, true); end
    FS.CardSet.Clear();
    if (Forge) then Forge.Release(); end
    if (_tSession) then _tSession.setData({}, {}, {}, {}); end
    if (_oActiveGame) then captureWatchFiles(); else ProcSys.Shutdown(); end
    require("Autocomplete").SetHeaders({});
    if (_oActiveGame) then require("Autocomplete").Flush(); end
    Log.Note("Card set closed: no active card set.");
end

--[[!
@fqxn CFS.Modules.ProcSys.Functions.CloseGame
@pulsarlua function ProcSys.CloseGame
@desc Clears active processing and script state and stops all project file watchers without deleting files.
!]]
function ProcSys.CloseGame()
    assert(not (_tSession and _tSession.exporting), "Wait for the export to finish before closing the game.");
    require("Autocomplete").SetActive(false);
    _oActiveGame = false;
    ProcSys.CloseCardSet();
    if (UserEnv) then
        UserEnv.UserUpdateENV({});
        UserEnv.UserUpdateCFG({});
    end
end

return ProcSys;
