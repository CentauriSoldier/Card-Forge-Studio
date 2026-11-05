local _wx = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local _Events = require("wxLuma.Core.ControlEvents");
local _Options = require("wxLuma.Core.ControlOptions");
local _Selection = require("wxLuma.Core.ControlSelection");
local _copy = require("wxLuma.State").copy;
local _tSeverities = {trace = true, debug = true, info = true, success = true, warning = true, error = true};
local LogViewer = {};

--[[!
@fqxn wxLuma.UI.LogViewer.create
@desc Creates an owner-drawn, selectable UTF-8 action/output log. Entries have
    stable Id, required Text and optional Icon path, Severity and Timestamp text.
    Severity is disabled by default. Only visible entries are painted; layout
    and glyph widths are cached. Plain dragging selects text within one entry;
    Ctrl/Shift clicks select entries. Ctrl+A/C and a skinned context menu copy
    text or complete entries. Background supplies application/game pixels when
    Transparent is true; without it the native parent's solid color is used.
@param table tOptions Skin, Entries, Artwork (Log Viewer), OnChange; documented
    LogOptions settings all expose get/set<Property>(value, notify) methods.
!]]
function LogViewer.create(oParent, tOptions)
    assert(tOptions and tOptions.Skin, "LogViewer requires Skin.");
    local oComponent = _Surface.create(oParent, tOptions, "LogViewer");
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "Log Viewer");
    local tEvents = _Events.attach(oComponent, nil, {"entriesChanged", "entryAdded", "entryRemoved", "entryChanged",
        "cleared", "selectionChanged", "textSelectionChanged", "copied", "entryHovered", "entryLeft", "entryActivated", "followChanged"});
    local tEntries, tById, tSelected, tVisible, tRows, tGlyphs = {}, {}, {}, {}, {}, {};
    local tRowCache = {};
    local sGlyphFont;
    local tTextSelection, tDrag, tSettings, oMenu;
    local nNextId, nScrollX, nScrollY, nContentWidth, nContentHeight = 0, 0, 0, 0, 0;
    local nWidth, nHeight, nViewW, nViewH, nLineHeight = 0, 0, 1, 1, 20;
    local sPrimary, sAnchor, sHovered;
    local bDirty, bFollowing = true, true;
    local fLayout, fCommit;

    --[[!
    @fqxn wxLuma.UI.LogViewer.create.invalidate
    @desc Marks cached entry geometry dirty; rebuilding happens once on demand.
    !]]
    local function fInvalidate()
        bDirty = true;
        oComponent.refresh();
    end

    local tDefaults = {MaxEntries = 1000, Wrap = true, AutoScroll = true, PauseOnSelection = true, Transparent = false,
        SeverityEnabled = false, ShowSeverity = true, Timestamps = false, IconSize = 20,
        RowPadding = 6, EntryGap = 2, LineSpacing = 2, ScrollBarWidth = 12, ScrollStep = 40,
        FilterText = "", CaseSensitive = false, SeverityFilter = {}, MultiSelect = true,
        SelectionMode = "both", CopyTimestamps = false, CopySeverity = false, ContextMenu = true,
        AlternatingRows = false, EmptyText = "No entries"};
    local tValidators = {};
    for sName, vValue in pairs(tDefaults) do
        if (type(vValue) == "boolean") then tValidators[sName] = _Options.boolean; end
    end
    for _, sName in ipairs({"FilterText", "EmptyText"}) do tValidators[sName] = _Options.text; end
    tValidators.MaxEntries = _Options.number(1, 1000000, true);
    for _, sName in ipairs({"IconSize", "RowPadding", "EntryGap", "LineSpacing"}) do tValidators[sName] = _Options.number(0, 128, true); end
    tValidators.ScrollBarWidth = _Options.number(6, 64, true);
    tValidators.ScrollStep = _Options.number(1, 1000);
    tValidators.SelectionMode = _Options.enum({"entries", "text", "both"});
    tValidators.SeverityFilter = function(tValue)
        _Options.array(tValue);
        for _, sName in ipairs(tValue) do assert(_tSeverities[sName] or sName == "none", "Unknown severity filter."); end
        return tValue;
    end;
    tSettings = _Options.create(oComponent, tEvents, tDefaults, tValidators, tOptions, "LogOptions", function(tChanges, bNotify)
        if (fCommit and #tEntries > tSettings.MaxEntries) then fCommit(tEntries, bNotify); end
        if (not tSettings.MultiSelect and #tSelected > 1) then oComponent.setSelected(sPrimary and {sPrimary} or {}, bNotify); end
        if (tSettings.SelectionMode == "entries") then oComponent.clearTextSelection(bNotify); end
        if (oMenu and not tSettings.ContextMenu) then oMenu.close(); end
        fInvalidate();
    end);

    --[[!
    @fqxn wxLuma.UI.LogViewer.create.entry
    @desc Validates one entry and prepares its icon before committing mutations.
        Omitted IDs receive monotonic per-instance names; existing IDs never change.
    !]]
    local function fEntry(tEntry, tUsed)
        assert(type(tEntry) == "table", "Entry must be a record.");
        local tResult = {Text = _Options.text(tEntry.Text)};
        local sId = tEntry.Id;
        if (sId == nil) then
            repeat nNextId = nNextId + 1; sId = "entry-"..nNextId; until not tUsed[sId];
        end
        assert(type(sId) == "string" and sId ~= "" and not tUsed[sId], "Entry IDs must be nonempty and unique.");
        tResult.Id = sId; tUsed[sId] = true;
        if (tEntry.Severity ~= nil) then assert(_tSeverities[tEntry.Severity], "Unknown entry severity."); tResult.Severity = tEntry.Severity; end
        if (tEntry.Timestamp ~= nil) then tResult.Timestamp = _Options.text(tEntry.Timestamp); end
        if (tEntry.Icon ~= nil) then assert(type(tEntry.Icon) == "string", "Icon must be an image path."); tArt.prepare(tEntry.Icon); tResult.Icon = tEntry.Icon; end
        return tResult;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.getEntries
    @desc Returns independent entry records in insertion order.
    !]]
    function oComponent.getEntries() return _copy(tEntries); end

    --[[!
    @fqxn wxLuma.UI.LogViewer.getEntry
    @desc Returns an independent entry by stable ID, or nil if missing.
    !]]
    function oComponent.getEntry(sId) return tById[sId] and _copy(tById[sId]) or nil; end

    --[[!
    @fqxn wxLuma.UI.LogViewer.getSelected
    @desc Returns selected stable IDs in insertion order, independently of viewport.
    !]]
    function oComponent.getSelected() return _copy(tSelected); end

    --[[!
    @fqxn wxLuma.UI.LogViewer.getValue
    @desc Returns the primary selected entry ID, or nil.
    !]]
    function oComponent.getValue() return sPrimary; end

    --[[!
    @fqxn wxLuma.UI.LogViewer.setSelected
    @desc Replaces entry selection. Missing IDs are skipped for partial reloads;
        the last existing requested ID becomes primary. Notification defaults off.
    !]]
    function oComponent.setSelected(tIds, bNotify)
        assert(not oComponent.Disposed, "LogViewer is disposed."); _Options.array(tIds);
        local tWanted, sNext = {}, nil;
        for _, sId in ipairs(tIds) do
            assert(type(sId) == "string", "Selection IDs must be strings.");
            if (tById[sId]) then tWanted[sId], sNext = true, sId; end
        end
        local tNext = {};
        for _, tEntry in ipairs(tEntries) do
            if (tWanted[tEntry.Id] and (tSettings.MultiSelect or tEntry.Id == sNext)) then tNext[#tNext + 1] = tEntry.Id; end
        end
        local tOld, sOld = tSelected, sPrimary;
        if (not _Selection.same(tOld, tNext) or sOld ~= sNext) then
            tSelected, sPrimary = tNext, sNext;
            if (oComponent.clearTextSelection) then oComponent.clearTextSelection(bNotify); end
            if (#tNext > 0 and tSettings.PauseOnSelection and bFollowing) then
                bFollowing = false;
                if (bNotify) then tEvents.emit("followChanged", {Following = false, Reason = "selection"}); end
            end
            oComponent.refresh();
            if (bNotify) then
                tEvents.emit("selectionChanged", {Selected = _copy(tNext), OldSelected = _copy(tOld), Value = sNext});
                if (sOld ~= sNext) then tEvents.emit("valueChanged", {Value = sNext, OldValue = sOld}); end
                if (oComponent.OnChange) then oComponent.OnChange(sNext, oComponent, _copy(tNext)); end
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.setValue
    @desc Selects one existing entry or clears selection with nil.
    !]]
    function oComponent.setValue(sId, bNotify) return oComponent.setSelected(sId and {sId} or {}, bNotify); end

    --[[!
    @fqxn wxLuma.UI.LogViewer.getTextSelection
    @desc Returns {Id,Start,Finish}, using zero-based Unicode character boundaries.
        Start/Finish are ordered; no selection returns false (plain state data).
    !]]
    function oComponent.getTextSelection() return tTextSelection and _copy(tTextSelection) or false; end

    --[[!
    @fqxn wxLuma.UI.LogViewer.setTextSelection
    @desc Selects a character range within an entry. False clears; missing entry
        IDs are skipped. Out-of-range boundaries clamp after content changes.
    !]]
    function oComponent.setTextSelection(tRange, bNotify)
        assert(not oComponent.Disposed, "LogViewer is disposed.");
        local tNext;
        if (tRange and tRange ~= false) then
            assert(type(tRange) == "table" and type(tRange.Id) == "string", "Invalid text selection.");
            _Options.number(0, 1000000000, true)(tRange.Start); _Options.number(0, 1000000000, true)(tRange.Finish);
            local tEntry = tById[tRange.Id];
            if (not tEntry) then return oComponent; end
            local nLength = utf8.len(tEntry.Text);
            tNext = {Id = tRange.Id, Start = math.min(nLength, tRange.Start, tRange.Finish),
                Finish = math.min(nLength, math.max(tRange.Start, tRange.Finish))};
        end
        local tOld = tTextSelection;
        if (not tOld ~= not tNext or tOld and tNext and
            (tOld.Id ~= tNext.Id or tOld.Start ~= tNext.Start or tOld.Finish ~= tNext.Finish)) then
            tTextSelection = tNext; oComponent.refresh();
            if (tNext and tNext.Finish > tNext.Start and tSettings.PauseOnSelection and bFollowing) then
                bFollowing = false;
                if (bNotify) then tEvents.emit("followChanged", {Following = false, Reason = "selection"}); end
            end
            if (bNotify) then tEvents.emit("textSelectionChanged", {Selection = oComponent.getTextSelection()}); end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.clearTextSelection
    @desc Clears character selection without changing selected entries.
    !]]
    function oComponent.clearTextSelection(bNotify) return oComponent.setTextSelection(false, bNotify); end

    --[[!
    @fqxn wxLuma.UI.LogViewer.create.commit
    @desc Commits validated entries once, trims the oldest beyond MaxEntries,
        reconciles selection and releases unused icon resources before events.
    !]]
    fCommit = function(tNext, bNotify)
        local tOld = tEntries;
        local tKept = {};
        for nIndex = math.max(1, #tNext - tSettings.MaxEntries + 1), #tNext do tKept[#tKept + 1] = tNext[nIndex]; end
        if (_Options.same(tKept, tEntries)) then return; end
        local tDragEntry = tDrag and tDrag.Kind == "text" and tById[tDrag.Row.Id] or nil;
        for nIndex, tEntry in ipairs(tKept) do
            if (tById[tEntry.Id] and _Options.same(tById[tEntry.Id], tEntry)) then tKept[nIndex] = tById[tEntry.Id]; end
        end
        tEntries, tById = tKept, {};
        local tIcons = {};
        for _, tEntry in ipairs(tEntries) do tById[tEntry.Id] = tEntry; tIcons[#tIcons + 1] = {Image = tEntry.Icon}; end
        if (tDragEntry and tById[tDragEntry.Id] ~= tDragEntry) then oComponent.cancel(); end
        for sId in pairs(tRowCache) do if (not tById[sId]) then tRowCache[sId] = nil; end end
        tArt.retain(tIcons);
        local tRetainedSelection = {};
        for _, sId in ipairs(tSelected) do if (sId ~= sPrimary) then tRetainedSelection[#tRetainedSelection + 1] = sId; end end
        if (sPrimary) then tRetainedSelection[#tRetainedSelection + 1] = sPrimary; end
        oComponent.setSelected(tRetainedSelection, bNotify);
        if (sHovered and not tById[sHovered]) then
            local sOldHover = sHovered; sHovered = nil;
            if (bNotify) then tEvents.emit("entryLeft", {Id = sOldHover}); end
        end
        if (tTextSelection) then
            if (not tById[tTextSelection.Id]) then oComponent.clearTextSelection(bNotify);
            else oComponent.setTextSelection(tTextSelection, bNotify); end
        end
        fInvalidate();
        if (bNotify) then
            local tOldIds = {}; for _, tEntry in ipairs(tOld) do tOldIds[tEntry.Id] = true; end
            for _, tEntry in ipairs(tOld) do if (not tById[tEntry.Id]) then tEvents.emit("entryRemoved", {Entry = _copy(tEntry)}); end end
            for _, tEntry in ipairs(tEntries) do if (not tOldIds[tEntry.Id]) then tEvents.emit("entryAdded", {Entry = _copy(tEntry)}); end end
            tEvents.emit("entriesChanged", {Count = #tEntries, OldCount = #tOld});
        end
    end;

    --[[!
    @fqxn wxLuma.UI.LogViewer.setEntries
    @desc Validates a complete batch before replacing entries. Oldest entries
        beyond MaxEntries are discarded; stable IDs preserve applicable selection.
    !]]
    function oComponent.setEntries(tNext, bNotify)
        assert(not oComponent.Disposed, "LogViewer is disposed."); _Options.array(tNext);
        local tPrepared, tUsed = {}, {};
        for _, tEntry in ipairs(tNext) do tPrepared[#tPrepared + 1] = fEntry(tEntry, tUsed); end
        fCommit(tPrepared, bNotify); return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.addEntries
    @desc Appends a validated batch with one layout invalidation and trim pass.
        AutoScroll follows the tail only while the user has not scrolled away.
    !]]
    function oComponent.addEntries(tNext, bNotify)
        assert(not oComponent.Disposed, "LogViewer is disposed."); _Options.array(tNext);
        if (#tNext == 0) then return oComponent; end
        local tPrepared, tUsed = {}, {};
        for _, tEntry in ipairs(tEntries) do tPrepared[#tPrepared + 1] = tEntry; tUsed[tEntry.Id] = true; end
        for _, tEntry in ipairs(tNext) do tPrepared[#tPrepared + 1] = fEntry(tEntry, tUsed); end
        fCommit(tPrepared, bNotify); return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.addEntry
    @desc Appends one entry; accepts Text directly for a plain severity-free log.
    !]]
    function oComponent.addEntry(vEntry, bNotify)
        assert(type(vEntry) == "string" or type(vEntry) == "table", "Entry must be text or a record.");
        return oComponent.addEntries({type(vEntry) == "string" and {Text = vEntry} or vEntry}, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.setEntry
    @desc Replaces one entry while preserving its stable ID. Unknown IDs fail
        before mutation; changed entry data is included in entryChanged.
    !]]
    function oComponent.setEntry(sId, tEntry, bNotify)
        assert(tById[sId] and type(tEntry) == "table", "Unknown log entry.");
        local tBefore = oComponent.getEntry(sId);
        local tNext = oComponent.getEntries(); local tReplacement = _copy(tEntry);
        assert(tReplacement.Id == nil or tReplacement.Id == sId, "Entry IDs cannot change."); tReplacement.Id = sId;
        for nIndex, tOld in ipairs(tNext) do if (tOld.Id == sId) then tNext[nIndex] = tReplacement; end end
        oComponent.setEntries(tNext, bNotify);
        if (bNotify and not _Options.same(tBefore, tById[sId])) then tEvents.emit("entryChanged", {Entry = oComponent.getEntry(sId), OldEntry = tBefore}); end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.insertEntry
    @desc Inserts a validated entry at a one-based position. Retention still
        discards oldest entries beyond MaxEntries after the insertion commits.
    !]]
    function oComponent.insertEntry(nIndex, tEntry, bNotify)
        _Options.number(1, #tEntries + 1, true)(nIndex);
        local tNext = oComponent.getEntries(); table.insert(tNext, nIndex, tEntry);
        return oComponent.setEntries(tNext, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.removeEntry
    @desc Removes an existing stable ID. Missing IDs are harmless.
    !]]
    function oComponent.removeEntry(sId, bNotify)
        if (not tById[sId]) then return oComponent; end
        local tNext = {}; for _, tEntry in ipairs(tEntries) do if (tEntry.Id ~= sId) then tNext[#tNext + 1] = tEntry; end end
        fCommit(tNext, bNotify); return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.clear
    @desc Removes all entries and selection, emitting cleared only when nonempty.
    !]]
    function oComponent.clear(bNotify)
        assert(not oComponent.Disposed, "LogViewer is disposed.");
        if (#tEntries > 0) then fCommit({}, bNotify); if (bNotify) then tEvents.emit("cleared", {}); end end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.create.layout
    @desc Measures UTF-8 glyphs once, wraps entries and indexes cumulative row
        offsets. A binary search later finds visible rows without scanning history.
    !]]
    fLayout = function()
        local nW, nH = oComponent.Control:GetClientSizeWH(); nW, nH = math.max(1, nW), math.max(1, nH);
        if (not bDirty and nWidth == nW and nHeight == nH) then return; end
        nWidth, nHeight, bDirty = nW, nH, false;
        nViewW = math.max(1, nWidth - tSettings.ScrollBarWidth);
        nViewH = math.max(1, nHeight - (tSettings.Wrap and 0 or tSettings.ScrollBarWidth));
        local oDC = _wx.wxClientDC(oComponent.Control); oDC:SetFont(oComponent.Skin.Font);
        local nUnused; nUnused, nLineHeight = oDC:GetTextExtent("Ag");
        local nAdvance = nLineHeight + tSettings.LineSpacing;
        local sFont = tostring(oComponent.Skin.Font)..":"..nLineHeight;
        if (sFont ~= sGlyphFont) then tGlyphs, sGlyphFont = {}, sFont; end
        local sLayoutKey = table.concat({nViewW, nAdvance, tSettings.RowPadding, tSettings.IconSize,
            tSettings.Wrap and 1 or 0, tSettings.Timestamps and 1 or 0,
            tSettings.SeverityEnabled and 1 or 0, tSettings.ShowSeverity and 1 or 0, sFont}, ":");
        tRows, tVisible, nContentHeight, nContentWidth = {}, {}, 0, nViewW;
        local tSeverity = {}; for _, sName in ipairs(tSettings.SeverityFilter) do tSeverity[sName] = true; end
        local sFilter = tSettings.CaseSensitive and tSettings.FilterText or tSettings.FilterText:lower();
        for _, tEntry in ipairs(tEntries) do
            local sText = tSettings.CaseSensitive and tEntry.Text or tEntry.Text:lower();
            if ((sFilter == "" or sText:find(sFilter, 1, true)) and
                (#tSettings.SeverityFilter == 0 or tSeverity[tEntry.Severity or "none"])) then
                local tCached = tRowCache[tEntry.Id];
                local tRow = tCached and tCached.Row;
                if (not tCached or tCached.Entry ~= tEntry or tCached.Key ~= sLayoutKey) then
                    local sPrefix = "";
                    if (tSettings.Timestamps and tEntry.Timestamp) then sPrefix = tEntry.Timestamp.." "; end
                    if (tSettings.SeverityEnabled and tSettings.ShowSeverity and tEntry.Severity) then sPrefix = sPrefix.."["..tEntry.Severity.."] "; end
                    local nPrefix = oDC:GetTextExtent(sPrefix);
                    local nIcon = tEntry.Icon and tSettings.IconSize > 0 and tSettings.IconSize + 6 or 0;
                    tRow = {Id = tEntry.Id, Lines = {}, Prefix = sPrefix,
                        TextX = tSettings.RowPadding + nIcon + nPrefix, Chars = {}};
                    local nAvailable = math.max(16, nViewW - tRow.TextX - tSettings.RowPadding);
                    for _, nCode in utf8.codes(tEntry.Text) do tRow.Chars[#tRow.Chars + 1] = utf8.char(nCode); end
                    local nStart, nRun = 0, 0;
                    local tPositions = {[0] = 0};
                    for nIndex, sChar in ipairs(tRow.Chars) do
                        if (sChar == "\r" and tRow.Chars[nIndex + 1] == "\n") then
                            tRow.Chars[nIndex] = ""; tPositions[nIndex] = nRun;
                        elseif (sChar == "\n" or sChar == "\r") then
                            tRow.Lines[#tRow.Lines + 1] = {Start = nStart, Finish = nIndex - 1, Width = nRun, Positions = tPositions};
                            nStart, nRun, tPositions = nIndex, 0, {[nIndex] = 0};
                        else
                            if (not tGlyphs[sChar]) then tGlyphs[sChar] = oDC:GetTextExtent(sChar); end
                            local nGlyph = tGlyphs[sChar];
                            if (tSettings.Wrap and nRun > 0 and nRun + nGlyph > nAvailable) then
                                tRow.Lines[#tRow.Lines + 1] = {Start = nStart, Finish = nIndex - 1, Width = nRun, Positions = tPositions};
                                nStart, nRun, tPositions = nIndex - 1, 0, {[nIndex - 1] = 0};
                            end
                            nRun = nRun + nGlyph; tPositions[nIndex] = nRun;
                        end
                    end
                    tRow.Lines[#tRow.Lines + 1] = {Start = nStart, Finish = #tRow.Chars, Width = nRun, Positions = tPositions};
                    tRow.Height = math.max(tSettings.IconSize, #tRow.Lines * nAdvance) + tSettings.RowPadding * 2;
                    tRowCache[tEntry.Id] = {Entry = tEntry, Key = sLayoutKey, Row = tRow};
                end
                tRow.Top = nContentHeight;
                for _, tLine in ipairs(tRow.Lines) do nContentWidth = math.max(nContentWidth, tRow.TextX + tLine.Width + tSettings.RowPadding); end
                tRows[#tRows + 1] = tRow; tVisible[#tVisible + 1] = tRow.Id;
                nContentHeight = nContentHeight + tRow.Height + tSettings.EntryGap;
            end
        end
        oDC:delete();
        nScrollX = math.max(0, math.min(nScrollX, nContentWidth - nViewW));
        nScrollY = math.max(0, math.min(nScrollY, nContentHeight - nViewH));
        if (bFollowing and tSettings.AutoScroll) then nScrollY = math.max(0, nContentHeight - nViewH); end
    end;

    --[[!
    @fqxn wxLuma.UI.LogViewer.invalidateLayout
    @desc Explicitly drops measured geometry after an application mutates an
        existing Skin.Font in place. Ordinary appends reuse unchanged entry wraps.
    !]]
    function oComponent.invalidateLayout()
        assert(not oComponent.Disposed, "LogViewer is disposed.");
        tRowCache, tGlyphs = {}, {}; fInvalidate(); return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.getVisibleEntries
    @desc Returns all filter-matching entries, including those outside the viewport.
    !]]
    function oComponent.getVisibleEntries()
        fLayout(); local tResult = {}; for _, sId in ipairs(tVisible) do tResult[#tResult + 1] = _copy(tById[sId]); end; return tResult;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.getEntryCount
    @desc Returns retained entry count; getVisibleCount counts filter matches.
    !]]
    function oComponent.getEntryCount() return #tEntries; end
    function oComponent.getVisibleCount() fLayout(); return #tVisible; end

    --[[!
    @fqxn wxLuma.UI.LogViewer.getContentSize
    @desc Returns measured content width and height in pixels.
    !]]
    function oComponent.getContentSize() fLayout(); return nContentWidth, nContentHeight; end

    --[[!
    @fqxn wxLuma.UI.LogViewer.getEntryRect
    @desc Returns client-relative geometry for a filter-matching entry, including
        TextX and LineHeight for application overlays. Missing IDs return nil.
    !]]
    function oComponent.getEntryRect(sId)
        fLayout(); for _, tRow in ipairs(tRows) do if (tRow.Id == sId) then
            return {X = -nScrollX, Y = tRow.Top - nScrollY, Width = nViewW, Height = tRow.Height,
                TextX = tRow.TextX - nScrollX, LineHeight = nLineHeight + tSettings.LineSpacing};
        end end
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.getSelectedEntries
    @desc Returns full independent records for selected entries in insertion order.
    !]]
    function oComponent.getSelectedEntries()
        local tResult = {}; for _, sId in ipairs(tSelected) do tResult[#tResult + 1] = _copy(tById[sId]); end; return tResult;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.isFollowingTail
    @desc Reports whether the viewport is at the tail and will follow appends
        when AutoScroll is enabled. scrollToEnd resumes following explicitly.
    !]]
    function oComponent.isFollowingTail() return bFollowing; end

    --[[!
    @fqxn wxLuma.UI.LogViewer.getFollowingTail
    @desc Returns explicit follow policy, independently of AutoScroll. Shared
        state stores this after selection/position so reloading preserves pauses.
    !]]
    function oComponent.getFollowingTail() return bFollowing; end

    --[[!
    @fqxn wxLuma.UI.LogViewer.setFollowingTail
    @desc Pauses at the current viewport, or reveals the tail and resumes future
        appends when true. Following resumes even if entries remain selected.
    !]]
    function oComponent.setFollowingTail(bFollow, bNotify)
        assert(not oComponent.Disposed, "LogViewer is disposed."); _Options.boolean(bFollow);
        if (bFollow) then return oComponent.scrollToEnd(bNotify); end
        if (bFollowing) then bFollowing = false; if (bNotify) then tEvents.emit("followChanged", {Following = false}); end end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.getPosition
    @desc Returns horizontal and vertical scroll offsets in pixels.
    !]]
    function oComponent.getPosition() fLayout(); return nScrollX, nScrollY; end

    --[[!
    @fqxn wxLuma.UI.LogViewer.setPosition
    @desc Clamps scroll offsets, pauses tail following when scrolled away and
        optionally emits scrolled/followChanged after an actual change.
    !]]
    function oComponent.setPosition(nX, nY, bNotify)
        assert(not oComponent.Disposed, "LogViewer is disposed.");
        _Options.number(0, 1e12)(nX); _Options.number(0, 1e12)(nY); fLayout();
        local nOldX, nOldY, bOldFollow = nScrollX, nScrollY, bFollowing;
        nScrollX, nScrollY = math.min(nX, math.max(0, nContentWidth - nViewW)), math.min(nY, math.max(0, nContentHeight - nViewH));
        bFollowing = nScrollY >= math.max(0, nContentHeight - nViewH) - 1;
        if (nOldX ~= nScrollX or nOldY ~= nScrollY) then
            oComponent.refresh();
            if (bNotify) then tEvents.emit("scrolled", {X = nScrollX, Y = nScrollY, OldX = nOldX, OldY = nOldY}); end
        end
        if (bNotify and bOldFollow ~= bFollowing) then tEvents.emit("followChanged", {Following = bFollowing}); end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.scrollToEnd
    @desc Reveals the latest visible entry and resumes following future appends.
    !]]
    function oComponent.scrollToEnd(bNotify) fLayout(); return oComponent.setPosition(nScrollX, math.max(0, nContentHeight - nViewH), bNotify); end

    --[[!
    @fqxn wxLuma.UI.LogViewer.scrollToStart
    @desc Reveals the oldest filter-matching entry and resets horizontal scrolling.
    !]]
    function oComponent.scrollToStart(bNotify) return oComponent.setPosition(0, 0, bNotify); end

    --[[!
    @fqxn wxLuma.UI.LogViewer.scrollBy
    @desc Scrolls relative pixel offsets with the same clamping/follow policy.
    !]]
    function oComponent.scrollBy(nDX, nDY, bNotify)
        _Options.number(-1e12, 1e12)(nDX); _Options.number(-1e12, 1e12)(nDY);
        fLayout(); return oComponent.setPosition(math.max(0, nScrollX + nDX), math.max(0, nScrollY + nDY), bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.scrollToEntry
    @desc Reveals an existing filter-matching entry; hidden/missing IDs are skipped.
    !]]
    function oComponent.scrollToEntry(sId, bNotify)
        fLayout(); for _, tRow in ipairs(tRows) do
            if (tRow.Id == sId) then return oComponent.setPosition(nScrollX, math.max(0, tRow.Top), bNotify); end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.selectAll
    @desc Selects filter-matching entries. Text-only mode selects all characters
        of the primary entry; entry selection respects the MultiSelect setting.
    !]]
    function oComponent.selectAll(bNotify)
        fLayout();
        if (tSettings.SelectionMode == "text" and sPrimary) then
            return oComponent.setTextSelection({Id = sPrimary, Start = 0, Finish = utf8.len(tById[sPrimary].Text)}, bNotify);
        end
        return oComponent.setSelected(tSettings.MultiSelect and tVisible or (tVisible[1] and {tVisible[1]} or {}), bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.getSelectedText
    @desc Returns the selected Unicode substring, or complete selected entries
        separated by newlines. Optional copy metadata is controlled by settings.
    !]]
    function oComponent.getSelectedText()
        if (tTextSelection and tTextSelection.Start ~= tTextSelection.Finish and tById[tTextSelection.Id]) then
            local sText = tById[tTextSelection.Id].Text;
            return sText:sub(utf8.offset(sText, tTextSelection.Start + 1) or #sText + 1,
                (utf8.offset(sText, tTextSelection.Finish + 1) or #sText + 1) - 1);
        end
        local tLines = {};
        for _, sId in ipairs(tSelected) do
            local tEntry, sPrefix = tById[sId], "";
            if (tSettings.CopyTimestamps and tEntry.Timestamp) then sPrefix = tEntry.Timestamp.." "; end
            if (tSettings.CopySeverity and tEntry.Severity) then sPrefix = sPrefix.."["..tEntry.Severity.."] "; end
            tLines[#tLines + 1] = sPrefix..tEntry.Text;
        end
        return table.concat(tLines, "\n");
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.copySelected
    @desc Copies selected text/entries as Unicode. Returns success and the text;
        clipboard ownership transfers only after SetData succeeds.
    !]]
    function oComponent.copySelected()
        assert(not oComponent.Disposed, "LogViewer is disposed.");
        local sText = oComponent.getSelectedText();
        if (sText == "" or not _wx.wxTheClipboard:Open()) then return false, sText; end
        local oData = _wx.wxTextDataObject(sText);
        local bCopied = _wx.wxTheClipboard:SetData(oData); _wx.wxTheClipboard:Close();
        if (not bCopied) then oData:delete(); else tEvents.emit("copied", {Text = sText, Selected = _copy(tSelected)}); end
        return bCopied, sText;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.copyAll
    @desc Copies every filter-matching entry while preserving current selection.
    !]]
    function oComponent.copyAll()
        assert(not oComponent.Disposed, "LogViewer is disposed.");
        fLayout(); local tLines = {};
        for _, sId in ipairs(tVisible) do
            local tEntry, sPrefix = tById[sId], "";
            if (tSettings.CopyTimestamps and tEntry.Timestamp) then sPrefix = tEntry.Timestamp.." "; end
            if (tSettings.CopySeverity and tEntry.Severity) then sPrefix = sPrefix.."["..tEntry.Severity.."] "; end
            tLines[#tLines + 1] = sPrefix..tEntry.Text;
        end
        local sText = table.concat(tLines, "\n");
        if (sText == "" or not _wx.wxTheClipboard:Open()) then return false, sText; end
        local oData = _wx.wxTextDataObject(sText); local bCopied = _wx.wxTheClipboard:SetData(oData); _wx.wxTheClipboard:Close();
        if (not bCopied) then oData:delete(); else tEvents.emit("copied", {Text = sText, All = true}); end
        return bCopied, sText;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.create.hit
    @desc Binary-searches cumulative entry offsets, independent of history size.
    !]]
    local function fHit(nY)
        local nLow, nHigh = 1, #tRows; nY = nY + nScrollY;
        while (nLow <= nHigh) do
            local nMid = math.floor((nLow + nHigh) / 2); local tRow = tRows[nMid];
            if (nY < tRow.Top) then nHigh = nMid - 1;
            elseif (nY >= tRow.Top + tRow.Height + tSettings.EntryGap) then nLow = nMid + 1;
            else return tRow, nMid; end
        end
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.create.character
    @desc Maps a pointer to the nearest insertion boundary in one entry's lines.
    !]]
    local function fCharacter(tRow, nX, nY)
        local nLine = math.max(1, math.min(#tRow.Lines, math.floor((nY + nScrollY - tRow.Top - tSettings.RowPadding)
            / (nLineHeight + tSettings.LineSpacing)) + 1));
        local tLine = tRow.Lines[nLine]; local nTextX = nX + nScrollX - tRow.TextX;
        for nIndex = tLine.Start, tLine.Finish - 1 do
            if (nTextX <= ((tLine.Positions[nIndex] or 0) + (tLine.Positions[nIndex + 1] or 0)) / 2) then return nIndex; end
        end
        return tLine.Finish;
    end

    --[[!
    @fqxn wxLuma.UI.LogViewer.hitTest
    @desc Returns {Id,Character} for a visible entry under client coordinates;
        Character is a zero-based UTF-8 insertion boundary. Scrollbars are excluded.
    !]]
    function oComponent.hitTest(nX, nY)
        fLayout(); if (nX < 0 or nY < 0 or nX >= nViewW or nY >= nViewH) then return nil; end
        local tRow = fHit(nY);
        return tRow and {Id = tRow.Id, Character = fCharacter(tRow, nX, nY)} or nil;
    end

    oComponent.pointer = function(sEvent, nX, nY, tModifiers)
        fLayout(); tModifiers = tModifiers or {};
        local tRow = fHit(nY);
        local sNextHover = sEvent ~= "leave" and tRow and nX < nViewW and tRow.Id or nil;
        if (sNextHover ~= sHovered) then
            if (sHovered) then tEvents.emit("entryLeft", {Id = sHovered}); end
            sHovered = sNextHover;
            if (sHovered) then tEvents.emit("entryHovered", {Id = sHovered, Entry = oComponent.getEntry(sHovered)}); end
            oComponent.refresh();
        end
        if (sEvent == "down" and oComponent.Pressed) then
            if (nX >= nViewW and nContentHeight > nViewH) then
                tDrag = {Kind = "vertical", Start = nY, Offset = nScrollY};
                oComponent.setPosition(nScrollX, math.max(0, (nY / nViewH) * nContentHeight - nViewH / 2), true);
            elseif (nY >= nViewH and not tSettings.Wrap and nContentWidth > nViewW) then
                tDrag = {Kind = "horizontal", Start = nX, Offset = nScrollX};
                oComponent.setPosition(math.max(0, (nX / nViewW) * nContentWidth - nViewW / 2), nScrollY, true);
            elseif (tRow) then
                oComponent.clearTextSelection(true);
                local tNext = {};
                if (tModifiers.Shift and sAnchor and tSettings.MultiSelect) then
                    local nA, nB;
                    for nIndex, sId in ipairs(tVisible) do if (sId == sAnchor) then nA = nIndex; end; if (sId == tRow.Id) then nB = nIndex; end end
                    if (nA and nB) then for nIndex = math.min(nA, nB), math.max(nA, nB) do tNext[#tNext + 1] = tVisible[nIndex]; end end
                elseif (tModifiers.Command and tSettings.MultiSelect) then
                    local bFound = false;
                    for _, sId in ipairs(tSelected) do if (sId == tRow.Id) then bFound = true; else tNext[#tNext + 1] = sId; end end
                    if (not bFound) then tNext[#tNext + 1] = tRow.Id; end
                else tNext = {tRow.Id}; sAnchor = tRow.Id; end
                oComponent.setSelected(tNext, true);
                if (tSettings.SelectionMode ~= "entries" and not tModifiers.Command and not tModifiers.Shift) then
                    tDrag = {Kind = "text", Row = tRow, Anchor = fCharacter(tRow, nX, nY)};
                end
            end
        elseif (sEvent == "move" and oComponent.Pressed and tDrag) then
            if (tDrag.Kind == "text") then
                oComponent.setTextSelection({Id = tDrag.Row.Id, Start = tDrag.Anchor, Finish = fCharacter(tDrag.Row, nX, nY)}, true);
                if (nY < 0 or nY > nViewH) then oComponent.setPosition(nScrollX, math.max(0, nScrollY + (nY < 0 and -nLineHeight or nLineHeight)), true); end
            elseif (tDrag.Kind == "vertical") then oComponent.setPosition(nScrollX, math.max(0, tDrag.Offset + (nY - tDrag.Start) * nContentHeight / nViewH), true);
            else oComponent.setPosition(math.max(0, tDrag.Offset + (nX - tDrag.Start) * nContentWidth / nViewW), nScrollY, true); end
        end
    end;
    oComponent.onCancel = function() tDrag = nil; end;
    oComponent.onLayout = fInvalidate;
    oComponent.wheel = function(nSteps) fLayout(); oComponent.setPosition(nScrollX, math.max(0, nScrollY - nSteps * tSettings.ScrollStep), true); end;
    oComponent.key = function(nKey, tModifiers)
        tModifiers = tModifiers or {}; fLayout();
        if (tModifiers.Command and nKey == string.byte("A")) then oComponent.selectAll(true);
        elseif (tModifiers.Command and nKey == string.byte("C")) then oComponent.copySelected();
        elseif (nKey == _wx.WXK_ESCAPE) then oComponent.clearTextSelection(true); oComponent.setSelected({}, true);
        elseif (nKey == _wx.WXK_RETURN and sPrimary) then tEvents.emit("entryActivated", {Id = sPrimary, Entry = oComponent.getEntry(sPrimary)});
        elseif (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_RIGHT) then
            oComponent.setPosition(math.max(0, nScrollX + (nKey == _wx.WXK_LEFT and -tSettings.ScrollStep or tSettings.ScrollStep)), nScrollY, true);
        elseif (nKey == _wx.WXK_UP or nKey == _wx.WXK_DOWN or nKey == _wx.WXK_HOME or nKey == _wx.WXK_END
            or nKey == _wx.WXK_PAGEUP or nKey == _wx.WXK_PAGEDOWN) then
            local nIndex = 1; for nAt, sId in ipairs(tVisible) do if (sId == sPrimary) then nIndex = nAt; end end
            if (nKey == _wx.WXK_HOME) then nIndex = 1;
            elseif (nKey == _wx.WXK_END) then nIndex = #tVisible;
            else
                local nStep = (nKey == _wx.WXK_PAGEUP or nKey == _wx.WXK_PAGEDOWN) and math.max(1, math.floor(nViewH / (nLineHeight + tSettings.RowPadding * 2))) or 1;
                nIndex = nIndex + ((nKey == _wx.WXK_UP or nKey == _wx.WXK_PAGEUP) and -nStep or nStep);
            end
            nIndex = math.max(1, math.min(#tVisible, nIndex));
            if (tVisible[nIndex]) then
                local tNext = {tVisible[nIndex]};
                if (tModifiers.Shift and tSettings.MultiSelect) then tNext = oComponent.getSelected(); tNext[#tNext + 1] = tVisible[nIndex]; end
                oComponent.clearTextSelection(true); oComponent.setSelected(tNext, true); oComponent.scrollToEntry(tVisible[nIndex], true);
            end
        else return false; end
        return true;
    end;

    oComponent.draw = function(oDC, nW, nH)
        if (oComponent.Disposed) then return; end
        fLayout(); local sState = oComponent.getState();
        if (tOptions.Background) then tOptions.Background(oDC, oComponent);
        elseif (tSettings.Transparent) then
            local oBrush = _wx.wxBrush(oParent:GetBackgroundColour()); oDC:SetBackground(oBrush); oDC:Clear(); oBrush:delete();
        else tArt.part(oDC, "Surface "..sState, 0, 0, nW, nH); end
        local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(0, 0, nViewW, nViewH));
        oDC:SetFont(oComponent.Skin.Font); oDC:SetBackgroundMode(_wx.wxTRANSPARENT);
        local tSet = {}; for _, sId in ipairs(tSelected) do tSet[sId] = true; end
        local tFirst, nFirst = fHit(0); nFirst = nFirst or 1;
        for nIndex = nFirst, #tRows do
            local tRow = tRows[nIndex]; local nY = tRow.Top - nScrollY;
            if (nY >= nViewH) then break; end
            if (nY + tRow.Height >= 0) then
                local tEntry = tById[tRow.Id];
                local sRow = not oComponent.isEnabled() and "Disabled" or tSet[tRow.Id] and "Selected" or sHovered == tRow.Id and "Hover"
                    or tSettings.AlternatingRows and nIndex % 2 == 0 and "Alternate" or "Normal";
                if (not tSettings.Transparent or sRow ~= "Normal" and sRow ~= "Alternate") then tArt.part(oDC, "Entry "..sRow, 0, nY, nViewW, tRow.Height); end
                if (tEntry.Icon and tSettings.IconSize > 0) then tArt.image(oDC, tEntry.Icon, tSettings.RowPadding - nScrollX, nY + tSettings.RowPadding, tSettings.IconSize); end
                local sColor = not oComponent.isEnabled() and "Text Disabled"
                    or tSettings.SeverityEnabled and tEntry.Severity and "Severity "..tEntry.Severity or "Text Normal";
                oDC:SetTextForeground(tArt.color(sColor));
                local nBaseX = tSettings.RowPadding + (tEntry.Icon and tSettings.IconSize > 0 and tSettings.IconSize + 6 or 0) - nScrollX;
                oDC:DrawText(tRow.Prefix, nBaseX, nY + tSettings.RowPadding);
                for nLine, tLine in ipairs(tRow.Lines) do
                    local nTextY = nY + tSettings.RowPadding + (nLine - 1) * (nLineHeight + tSettings.LineSpacing);
                    local nTextX = tRow.TextX - nScrollX;
                    if (tTextSelection and tTextSelection.Id == tRow.Id) then
                        local nA, nB = math.max(tLine.Start, tTextSelection.Start), math.min(tLine.Finish, tTextSelection.Finish);
                        if (nA < nB) then tArt.part(oDC, "Text Selection", nTextX + (tLine.Positions[nA] or 0), nTextY,
                            (tLine.Positions[nB] or tLine.Width) - (tLine.Positions[nA] or 0), nLineHeight); end
                    end
                    oDC:DrawText(table.concat(tRow.Chars, "", tLine.Start + 1, tLine.Finish), nTextX, nTextY);
                end
            end
        end
        if (#tRows == 0) then tArt.text(oDC, tSettings.EmptyText, tSettings.RowPadding, tSettings.RowPadding, oComponent.isEnabled()); end
        oClip:delete();
        if (nContentHeight > nViewH) then
            tArt.part(oDC, "Scroll Track", nViewW, 0, tSettings.ScrollBarWidth, nViewH);
            local nThumb = math.max(16, nViewH * nViewH / nContentHeight);
            tArt.part(oDC, "Scroll Thumb "..sState, nViewW, (nViewH - nThumb) * nScrollY / math.max(1, nContentHeight - nViewH), tSettings.ScrollBarWidth, nThumb);
        end
        if (not tSettings.Wrap and nContentWidth > nViewW) then
            tArt.part(oDC, "Scroll Track", 0, nViewH, nViewW, tSettings.ScrollBarWidth);
            local nThumb = math.max(16, nViewW * nViewW / nContentWidth);
            tArt.part(oDC, "Scroll Thumb "..sState, (nViewW - nThumb) * nScrollX / math.max(1, nContentWidth - nViewW), nViewH, nThumb, tSettings.ScrollBarWidth);
        end
        if (oComponent.Control:HasFocus()) then tArt.part(oDC, "Focus", 0, 0, nW, nH); end
    end;

    oMenu = require("wxLuma.Widgets.ContextMenu").create(oComponent.Control, {Skin = tOptions.Skin, Items = {
        {Id = "copy", Text = "Copy selection"}, {Id = "all", Text = "Copy all visible entries"},
        {Id = "select", Text = "Select all"}, {Id = "clear", Text = "Clear selection"}}, OnSelect = function(tChoice)
        if (tChoice.Id == "copy") then oComponent.copySelected(); elseif (tChoice.Id == "all") then oComponent.copyAll();
        elseif (tChoice.Id == "select") then oComponent.selectAll(true);
        else oComponent.clearTextSelection(true); oComponent.setSelected({}, true); end
    end});
    oComponent.ContextMenu = oMenu;
    oComponent.on("rightClick", function(oSender, tEvent)
        if (tSettings.ContextMenu and oComponent.isEnabled()) then
            local oPoint = oComponent.Control:ClientToScreen(_wx.wxPoint(tEvent.X, tEvent.Y));
            oMenu.showAt(oPoint:GetX(), oPoint:GetY()); oPoint:delete();
        end
    end);
    oComponent.on("leftDoubleClick", function(oSender, tEvent)
        fLayout(); local tRow = fHit(tEvent.Y);
        if (tRow and oComponent.isEnabled()) then
            oComponent.setValue(tRow.Id, true);
            tEvents.emit("entryActivated", {Id = tRow.Id, Entry = oComponent.getEntry(tRow.Id)});
        end
    end);
    oComponent.onEnable = function(bEnabled) oMenu.setEnabled(bEnabled); if (not bEnabled) then oMenu.close(); end; end;
    oComponent.onDestroy = function() oMenu.destroy(); tArt.destroy(); tEntries, tById, tRows, tGlyphs, tRowCache = {}, {}, {}, {}, {}; end;
    oComponent.setEntries(tOptions.Entries or {});
    return oComponent;
end

return LogViewer;
