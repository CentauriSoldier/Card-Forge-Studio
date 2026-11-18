local _wx       = require("wx");
local _Theme    = require("wxLuma.Core.ControlTheme");
local _Surface  = require("wxLuma.Core.ControlSurface");
local _Events   = require("wxLuma.Core.ControlEvents");
local _Table    = require("wxLuma.Widgets.Table");
local _Button   = require("wxLuma.Widgets.PushButton");
local _Field    = require("wxLuma.Widgets.TextField");
local _Search   = require("wxLuma.Widgets.SearchField");
local _Checkbox = require("wxLuma.Widgets.Checkbox");
local _Label    = require("wxLuma.Widgets.Label");
local _Selection = require("wxLuma.Core.ControlSelection");
local _State    = require("wxLuma.State");
local _copy     = _State.copy;
local _Options  = require("wxLuma.Core.ControlOptions");
local FileBrowser = {};
local _tColumns = {"Name", "Type", "Size", "Modified"};
local _bWindows = package.config:sub(1, 1) == "\\";

--[[!
@fqxn wxLuma.UI.FileBrowser.pathKey
@desc Compares normalized Windows paths without case-sensitive duplicates.
!]]
local function pathKey(sPath)
    return _bWindows and sPath:lower() or sPath;
end

--[[!
@fqxn wxLuma.UI.FileBrowser.directoryPath
@desc Resolves a directory against an explicit base without changing process
    working directory. Normalized results retain their trailing separator.
!]]
local function directoryPath(sPath, sBase)
    assert(type(sPath) == "string" and sPath ~= "" and not sPath:find("\0", 1, true), "Directory must be a nonempty path.");
    local oPath = _wx.wxFileName.DirName(sPath);
    oPath:MakeAbsolute(sBase or _wx.wxGetCwd());
    local bValid = oPath:Normalize(_wx.wxPATH_NORM_DOTS + _wx.wxPATH_NORM_TILDE + _wx.wxPATH_NORM_ABSOLUTE);
    local sResult = oPath:GetFullPath(); oPath:delete();
    assert(bValid, "Cannot normalize directory path.");
    return sResult;
end

--[[!
@fqxn wxLuma.UI.FileBrowser.patterns
@desc Compiles semicolon-separated filename globs (* and ?) into anchored Lua
    patterns. Other punctuation stays literal; folders are never pattern-hidden.
!]]
local function patterns(sValue)
    assert(type(sValue) == "string" and sValue ~= "", "Pattern must be a nonempty glob list.");
    local tResult = {};
    for sPart in (sValue..";"):gmatch("(.-);") do
        sPart = sPart:match("^%s*(.-)%s*$");
        if (sPart ~= "") then
            local tChars = {"^"};
            for sChar in sPart:lower():gmatch(".") do
                tChars[#tChars + 1] = sChar == "*" and ".*" or sChar == "?" and "."
                    or sChar:find("[%^%$%(%)%%%.%[%]%+%-%*%?]") and "%"..sChar or sChar;
            end
            tChars[#tChars + 1] = "$"; tResult[#tResult + 1] = table.concat(tChars);
        end
    end
    assert(#tResult > 0, "Pattern must contain a filename glob.");
    return tResult;
end

--[[!
@fqxn wxLuma.UI.FileBrowser.browserState
@desc Copies and validates a complete browser model without reading a directory.
    Missing history targets remain valid saved locations until revisited.
!]]
local function browserState(tValue)
    assert(type(tValue) == "table", "Browser state must be a record.");
    local tNext = _copy(tValue);
    local tFields = {Directory = true, Filter = true, Pattern = true, ShowHidden = true, MultiSelect = true,
        Sort = true, Selected = true, Top = true, Back = true, Forward = true, Enabled = true};
    for sKey in pairs(tNext) do assert(tFields[sKey], "Unknown browser state property."); end
    assert(type(tNext.Filter) == "string", "Invalid saved name filter."); patterns(tNext.Pattern);
    for _, sName in ipairs({"ShowHidden", "MultiSelect", "Enabled"}) do
        assert(type(tNext[sName]) == "boolean", "Saved browser flags must be boolean.");
    end
    local tSort = tNext.Sort;
    assert(type(tSort) == "table" and (tSort.Column == "Name" or tSort.Column == "Type" or tSort.Column == "Size" or tSort.Column == "Modified")
        and (tSort.Direction == "ascending" or tSort.Direction == "descending"), "Invalid saved browser sort.");
    for sKey in pairs(tSort) do assert(sKey == "Column" or sKey == "Direction", "Unknown saved sort property."); end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.browserState.fLocation
    @desc Validates one history/current location, normalizing only its directory.
        Selection membership is resolved against the destination's live snapshot.
    !]]
    local function fLocation(tLocation)
        assert(type(tLocation) == "table", "Invalid saved browser location.");
        tLocation.Directory = directoryPath(tLocation.Directory);
        _Options.array(tLocation.Selected);
        for _, sPath in ipairs(tLocation.Selected) do
            assert(type(sPath) == "string" and sPath ~= "" and not sPath:find("\0", 1, true), "Invalid saved selection path.");
        end
        assert(tLocation.Top == nil or type(tLocation.Top) == "string", "Invalid saved top-row anchor.");
    end
    fLocation(tNext);
    assert(tNext.MultiSelect or #tNext.Selected <= 1, "Saved selection exceeds single-selection mode.");
    for _, sStack in ipairs({"Back", "Forward"}) do
        _Options.array(tNext[sStack]);
        assert(#tNext[sStack] <= 128, "Saved history exceeds its bound.");
        for _, tLocation in ipairs(tNext[sStack]) do
            for sKey in pairs(tLocation) do assert(sKey == "Directory" or sKey == "Selected" or sKey == "Top", "Unknown history location property."); end
            fLocation(tLocation);
        end
    end
    return tNext;
end

--[[!
@fqxn wxLuma.UI.FileBrowser.readDirectory
@desc Reads one level of entries and metadata before any UI mutation. Native
    log suppression prevents modal filesystem error boxes. Unknown metadata is
    nil, never a fabricated zero. Does not recursively enumerate or write files.
!]]
local function readDirectory(sPath, bHidden)
    if (not _wx.wxDirExists(sPath)) then return nil, "Directory does not exist or cannot be accessed."; end
    local oQuiet = _wx.wxLogNull();
    local oDir = _wx.wxDir(sPath);
    if (not oDir:IsOpened()) then oDir:delete(); oQuiet:delete(); return nil, "Cannot read directory."; end
    local tEntries = {};
    local bOK, sError = xpcall(function()
        local nFlags = _wx.wxDIR_FILES + _wx.wxDIR_DIRS + (bHidden and _wx.wxDIR_HIDDEN or 0);
        local bFound, sName = oDir:GetFirst("", nFlags);
        while (bFound) do
            if (sName ~= "." and sName ~= "..") then
                local sFull = sPath..sName;
                local bDirectory = _wx.wxDirExists(sFull);
                local oFile = bDirectory and _wx.wxFileName.DirName(sFull) or _wx.wxFileName(sFull);
                local sFullPath = oFile:GetFullPath();
                local sExtension = bDirectory and "" or oFile:GetExt();
                local tEntry = {Name = sName, Path = sFullPath, Directory = bDirectory,
                    Type = bDirectory and "Folder" or sExtension ~= "" and sExtension:upper().." file" or "File"};
                if (not bDirectory and oFile:FileExists()) then
                    local oSize = oFile:GetSize();
                    local nHi, nLo = oSize:GetHi(), oSize:GetLo(); oSize:delete();
                    if (nHi ~= 4294967295 or nLo ~= 4294967295) then tEntry.Size = nHi * 4294967296 + nLo; end
                end
                local oModified = oFile:GetModificationTime();
                if (oModified:IsValid()) then
                    tEntry.Modified = oModified:GetTicks(); tEntry.ModifiedText = oModified:Format("%Y-%m-%d %H:%M");
                end
                oModified:delete(); oFile:delete(); tEntries[#tEntries + 1] = tEntry;
            end
            bFound, sName = oDir:GetNext();
        end
    end, debug.traceback);
    oDir:delete(); oQuiet:delete();
    if (not bOK) then return nil, "Directory could not be read completely."; end
    return tEntries;
end

--[[!
@fqxn wxLuma.UI.FileBrowser.create
@desc Creates an embedded directory browser from existing themed controls.
    Navigation reads before committing; failure preserves directory, listing,
    selection and history. Selected paths identify entries across sort/refresh.
    All filesystem access is read-only. Activation emits data, never launches.
@param table tOptions Directory (cwd), Filter (literal name substring), Pattern
    (*; semicolon-separated globs), ShowHidden (false), MultiSelect (true), Skin,
    Enabled, OnChange(directory,component), OnSelect(paths,component),
    OnActivate(entry,component). Size/time columns sort by numeric source values.
    Setters and navigation are silent unless notify is true; failures always
    emit navigationFailed and display their reason inline.
!]]
function FileBrowser.create(oParent, tOptions)
    tOptions = _Theme.options(tOptions, oParent);
    local sFilter, sPattern = tOptions.Filter or "", tOptions.Pattern or "*";
    assert(type(sFilter) == "string", "Filter must be a string.");
    local tPatterns = patterns(sPattern);
    for _, sName in ipairs({"ShowHidden", "MultiSelect"}) do
        assert(tOptions[sName] == nil or type(tOptions[sName]) == "boolean", sName.." must be boolean.");
    end
    local bHidden, bMulti = tOptions.ShowHidden == true, tOptions.MultiSelect ~= false;
    local sDirectory = directoryPath(tOptions.Directory or tOptions.Value or _wx.wxGetCwd());
    local tInitial, sInitialError = readDirectory(sDirectory, bHidden);
    assert(tInitial, sInitialError);
    local oComponent = _Surface.create(oParent, tOptions, "FileBrowser");
    local tEvents = _Events.attach(oComponent, nil, {"directoryChanged", "navigationFailed", "selectionChanged",
        "fileActivated", "entriesChanged", "filterChanged", "sortChanged", "showHiddenChanged", "multiSelectChanged"});
    local tOwned, tAll, tVisible, tById = {}, tInitial, {}, {};
    local tBack, tForward, tError, tLastSelection = {}, {}, nil, {};
    local sSort, sDirection, bInternal = "Name", "ascending", false;
    local oList, oAddress, oSearch, oHidden, oStatus, oBack, oForward, oUp, oReload;
    local fApply, fStatus;

    --[[!
    @fqxn wxLuma.UI.FileBrowser.fOwn
    @desc Creates and records an existing themed child for ordered disposal.
    !]]
    local function fOwn(oModule, tChildOptions)
        tChildOptions.Skin = oComponent.Skin;
        local oChild = oModule.create(oComponent.Control, tChildOptions);
        tOwned[#tOwned + 1] = oChild; return oChild;
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.fAlive
    @desc Rejects calls which would access disposed native child controls.
    !]]
    local function fAlive() assert(not oComponent.Disposed, "FileBrowser is disposed."); end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.getDirectory
    @desc Returns the normalized absolute current directory, with separator.
    !]]
    function oComponent.getDirectory() return sDirectory; end
    oComponent.getValue = oComponent.getDirectory;

    --[[!
    @fqxn wxLuma.UI.FileBrowser.getEntries
    @desc Returns independent entry snapshots in displayed order. With true,
        returns the complete unfiltered snapshot of the current directory.
    !]]
    function oComponent.getEntries(bAll) return _copy(bAll and tAll or tVisible); end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.getSelected
    @desc Returns selected absolute paths in display order, including folders.
    !]]
    function oComponent.getSelected()
        fAlive(); local tPaths = {};
        for _, sId in ipairs(oList.getSelected()) do
            if (tById[sId]) then tPaths[#tPaths + 1] = tById[sId].Path; end
        end
        return tPaths;
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.fSelection
    @desc Coalesces child selection changes and emits independent path arrays.
    !]]
    local function fSelection(bNotify)
        local tNext = oComponent.getSelected();
        local tNextIds, tOldIds = {}, {};
        for nIndex, sPath in ipairs(tNext) do tNextIds[nIndex] = pathKey(sPath); end
        for nIndex, sPath in ipairs(tLastSelection) do tOldIds[nIndex] = pathKey(sPath); end
        local bChanged = not _Selection.same(tNextIds, tOldIds);
        local tOld = tLastSelection; tLastSelection = tNext;
        fStatus();
        if (bChanged and bNotify) then
            tEvents.emit("selectionChanged", {Selected = _copy(tNext), OldSelected = _copy(tOld)});
            if (tOptions.OnSelect) then tOptions.OnSelect(_copy(tNext), oComponent); end
        end
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.fFailure
    @desc Restores the address to the actual directory and reports a failed read
        inline. Navigation/history/selection are untouched.
    !]]
    local function fFailure(sPath, sReason)
        tError = {Path = sPath, Reason = sReason};
        oAddress.setValue(sDirectory); fStatus();
        tEvents.emit("navigationFailed", _copy(tError)); return false;
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.getError
    @desc Returns an independent last navigation error, or nil after success.
    !]]
    function oComponent.getError() return tError and _copy(tError) or nil; end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.fSnapshot
    @desc Saves one bounded history location with selection and top visible row.
    !]]
    local function fSnapshot()
        local nTop = oList.TableControl:GetTopItem();
        return {Directory = sDirectory, Selected = oComponent.getSelected(),
            Top = tVisible[nTop + 1] and pathKey(tVisible[nTop + 1].Path)};
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.fPush
    @desc Bounds each navigation stack to 128 snapshots.
    !]]
    local function fPush(tStack, tLocation)
        tStack[#tStack + 1] = tLocation;
        if (#tStack > 128) then table.remove(tStack, 1); end
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.fCommit
    @desc Publishes a completed read before notifications. Same-directory reads
        retain selection/scroll; other navigation restores the target snapshot.
    !]]
    local function fCommit(sNext, tEntries, tLocation, bNotify)
        local sOld = sDirectory;
        sDirectory, tAll, tError = sNext, tEntries, nil; oComponent.Value = sNext;
        oAddress.setValue(sDirectory);
        fApply(tLocation.Selected, tLocation.Top);
        fSelection(bNotify);
        if (bNotify) then
            tEvents.emit("entriesChanged", {Directory = sDirectory, Count = #tVisible, Total = #tAll});
            if (pathKey(sOld) ~= pathKey(sDirectory)) then
                tEvents.emit("valueChanged", {Value = sDirectory, OldValue = sOld});
                tEvents.emit("directoryChanged", {Path = sDirectory, OldPath = sOld});
                if (oComponent.OnChange) then oComponent.OnChange(sDirectory, oComponent); end
            end
        end
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.navigate
    @desc Opens an absolute path or path relative to the current directory.
        New successful navigation clears forward history; same-path navigation
        refreshes without adding history. Returns false on filesystem failure.
    !]]
    function oComponent.navigate(sPath, bNotify)
        fAlive(); local sNext = directoryPath(sPath, sDirectory);
        local tEntries, sError = readDirectory(sNext, bHidden);
        if (not tEntries) then return fFailure(sNext, sError); end
        local tCurrent = fSnapshot();
        local bSame = pathKey(sNext) == pathKey(sDirectory);
        if (not bSame) then fPush(tBack, tCurrent); tForward = {}; end
        return fCommit(sNext, tEntries, bSame and tCurrent or {Selected = {}}, bNotify);
    end
    oComponent.setValue = oComponent.navigate;

    --[[!
    @fqxn wxLuma.UI.FileBrowser.canGoBack
    @desc Reports whether a back-history target exists; it may have been removed
        externally and will be validated when visited.
    !]]
    function oComponent.canGoBack() return #tBack > 0; end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.canGoForward
    @desc Reports whether a forward-history target exists.
    !]]
    function oComponent.canGoForward() return #tForward > 0; end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.fHistory
    @desc Reads a history destination before popping/pushing either stack.
        Failed history traversal keeps both stacks and the current view intact.
    !]]
    local function fHistory(tFrom, tTo, bNotify)
        fAlive(); local tTarget = tFrom[#tFrom];
        if (not tTarget) then return false; end
        local tEntries, sError = readDirectory(tTarget.Directory, bHidden);
        if (not tEntries) then return fFailure(tTarget.Directory, sError); end
        local tCurrent = fSnapshot();
        table.remove(tFrom); fPush(tTo, tCurrent);
        return fCommit(tTarget.Directory, tEntries, tTarget, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.goBack
    @desc Restores the previous successfully visited directory and surviving selection.
    !]]
    function oComponent.goBack(bNotify) return fHistory(tBack, tForward, bNotify); end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.goForward
    @desc Restores the next directory after a successful back traversal.
    !]]
    function oComponent.goForward(bNotify) return fHistory(tForward, tBack, bNotify); end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.goUp
    @desc Opens the parent without treating a filesystem root as its own history step.
    !]]
    function oComponent.goUp(bNotify)
        fAlive(); local sParent = directoryPath("..", sDirectory);
        if (pathKey(sParent) == pathKey(sDirectory)) then return false; end
        return oComponent.navigate(sParent, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.reload
    @desc Refreshes current metadata, preserving surviving selection and history.
    !]]
    function oComponent.reload(bNotify) return oComponent.navigate(sDirectory, bNotify); end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.setSelected
    @desc Selects visible absolute entry paths atomically. More than one requires
        MultiSelect. Filtering/removal drops hidden or missing selections.
    !]]
    function oComponent.setSelected(tPaths, bNotify)
        fAlive(); assert(type(tPaths) == "table", "Selected paths must be an array.");
        -- Validate the complete caller array before ipairs can truncate a hole.
        tPaths = _Selection.validate(tPaths, function(sPath)
            return type(sPath) == "string" and tById[pathKey(sPath)] ~= nil;
        end, true);
        local tIds = {};
        for nIndex, sPath in ipairs(tPaths) do
            assert(type(sPath) == "string" and tById[pathKey(sPath)], "Unknown visible file-browser selection.");
            tIds[nIndex] = pathKey(sPath);
        end
        -- Complete count/deduplication validation before suppressing child
        -- callbacks. Rejected selections must not leave suppression enabled.
        tIds = _Selection.validate(tIds, function(sId) return tById[sId] ~= nil; end, bMulti);
        bInternal = true; oList.setSelected(tIds); bInternal = false;
        fSelection(bNotify); return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.getFilter
    @desc Returns the literal case-insensitive filename substring filter.
    !]]
    function oComponent.getFilter() return sFilter; end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.setFilter
    @desc Filters the existing snapshot without another filesystem read.
    !]]
    function oComponent.setFilter(sValue, bNotify)
        fAlive(); assert(type(sValue) == "string", "Filter must be a string.");
        if (sFilter ~= sValue) then
            local tSelected, tOld = oComponent.getSelected(), sFilter;
            sFilter = sValue; oSearch.setValue(sValue); fApply(tSelected); fSelection(bNotify);
            if (bNotify) then tEvents.emit("filterChanged", {Filter = sFilter, OldFilter = tOld, Pattern = sPattern}); end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.getPattern
    @desc Returns the semicolon-separated filename glob list.
    !]]
    function oComponent.getPattern() return sPattern; end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.setPattern
    @desc Filters files by validated globs; folder rows remain navigable.
    !]]
    function oComponent.setPattern(sValue, bNotify)
        fAlive(); local tNext = patterns(sValue);
        if (sPattern ~= sValue) then
            local tSelected, sOld = oComponent.getSelected(), sPattern;
            sPattern, tPatterns = sValue, tNext; fApply(tSelected); fSelection(bNotify);
            if (bNotify) then tEvents.emit("filterChanged", {Pattern = sPattern, OldPattern = sOld, Filter = sFilter}); end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.isShowHiddenEnabled
    @desc Reports whether hidden entries are included in directory reads.
    !]]
    function oComponent.isShowHiddenEnabled() return bHidden; end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.setShowHiddenEnabled
    @desc Reads the proposed hidden-entry policy before committing it. Failure
        retains both the policy and current view. Returns success as a boolean.
    !]]
    function oComponent.setShowHiddenEnabled(bValue, bNotify)
        fAlive(); assert(type(bValue) == "boolean", "ShowHidden must be boolean.");
        if (bValue == bHidden) then return true; end
        local tEntries, sError = readDirectory(sDirectory, bValue);
        if (not tEntries) then oHidden.setValue(bHidden); return fFailure(sDirectory, sError); end
        local tLocation, bOld = fSnapshot(), bHidden;
        bHidden = bValue; oHidden.setValue(bHidden); fCommit(sDirectory, tEntries, tLocation, bNotify);
        if (bNotify) then tEvents.emit("showHiddenChanged", {Enabled = bHidden, OldEnabled = bOld}); end
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.isMultiSelectEnabled
    @desc Reports whether multiple entry paths may be selected.
    !]]
    function oComponent.isMultiSelectEnabled() return bMulti; end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.setMultiSelectEnabled
    @desc Changes native selection mode without rebuilding the table. Disabling
        retains its primary row and optionally emits selection/mode changes.
    !]]
    function oComponent.setMultiSelectEnabled(bValue, bNotify)
        fAlive(); assert(type(bValue) == "boolean", "MultiSelect must be boolean.");
        if (bMulti ~= bValue) then
            bMulti = bValue; bInternal = true; oList.setMultiSelectEnabled(bValue); bInternal = false;
            fSelection(bNotify);
            if (bNotify) then tEvents.emit("multiSelectChanged", {Enabled = bMulti}); end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.getSort
    @desc Returns Column (Name/Type/Size/Modified) and ascending/descending Direction.
    !]]
    function oComponent.getSort() return {Column = sSort, Direction = sDirection}; end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.sortBy
    @desc Orders numeric size/time or case-insensitive name/type, keeping folders
        first in either direction and preserving selected stable paths.
    !]]
    function oComponent.sortBy(sColumn, sValue, bNotify)
        fAlive(); assert(sColumn == "Name" or sColumn == "Type" or sColumn == "Size" or sColumn == "Modified", "Unknown sort column.");
        assert(sValue == "ascending" or sValue == "descending", "Unknown sort direction.");
        if (sSort ~= sColumn or sDirection ~= sValue) then
            local tSelected, tOld = oComponent.getSelected(), oComponent.getSort();
            sSort, sDirection = sColumn, sValue; fApply(tSelected); fSelection(bNotify);
            if (bNotify) then tEvents.emit("sortChanged", {Sort = oComponent.getSort(), OldSort = tOld}); end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.activate
    @desc Navigates into a visible folder or emits fileActivated/OnActivate with
        a copied file entry. Revalidates existence; never opens external apps.
    !]]
    function oComponent.activate(sPath, bNotify)
        fAlive(); assert(type(sPath) == "string", "Activation requires an entry path.");
        local tEntry = tById[pathKey(sPath)];
        if (not tEntry) then return false; end
        if (tEntry.Directory) then return oComponent.navigate(tEntry.Path, bNotify); end
        if (not _wx.wxFileExists(tEntry.Path)) then return fFailure(tEntry.Path, "File no longer exists or cannot be accessed."); end
        if (bNotify) then
            tEvents.emit("fileActivated", {Entry = _copy(tEntry), Path = tEntry.Path});
            if (tOptions.OnActivate) then tOptions.OnActivate(_copy(tEntry), oComponent); end
        end
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.getBrowserState
    @desc Captures a detached browser model including filters, sort, selection,
        bounded history, top-row anchor and enabled policy. Inline errors, row
        metadata and private child-control values are transient and omitted.
    !]]
    function oComponent.getBrowserState()
        fAlive(); local tLocation = fSnapshot();
        return _copy({Directory = sDirectory, Filter = sFilter, Pattern = sPattern, ShowHidden = bHidden,
            MultiSelect = bMulti, Sort = oComponent.getSort(), Selected = tLocation.Selected, Top = tLocation.Top,
            Back = tBack, Forward = tForward, Enabled = oComponent.Control:IsThisEnabled()});
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.setBrowserState
    @desc Silently restores the model and all derived children together. Validates
        the full record and reads the target directory before changing anything.
        Missing/filtered selected entries are dropped. Failed reads raise without
        changing the view, history, address, error display or notifying listeners.
    !]]
    function oComponent.setBrowserState(tValue)
        fAlive(); local tNext = browserState(tValue);
        local tNextPatterns = patterns(tNext.Pattern);
        local tEntries, sError = readDirectory(tNext.Directory, tNext.ShowHidden);
        assert(tEntries, sError);
        sDirectory, sFilter, sPattern, tPatterns = tNext.Directory, tNext.Filter, tNext.Pattern, tNextPatterns;
        bHidden, bMulti, sSort, sDirection = tNext.ShowHidden, tNext.MultiSelect, tNext.Sort.Column, tNext.Sort.Direction;
        tAll, tBack, tForward, tError = tEntries, tNext.Back, tNext.Forward, nil;
        oComponent.Value = sDirectory;
        oAddress.setValue(sDirectory); oSearch.setValue(sFilter); oHidden.setValue(bHidden);
        bInternal = true; oList.setMultiSelectEnabled(bMulti); bInternal = false;
        fApply(tNext.Selected, tNext.Top); fSelection(false);
        oComponent.setEnabled(tNext.Enabled); fStatus();
        return oComponent;
    end

    -- Controls are composed once; refreshes replace data, not native widgets.
    oBack = fOwn(_Button, {Text = "Back", OnClick = function() oComponent.goBack(true); end});
    oForward = fOwn(_Button, {Text = "Next", OnClick = function() oComponent.goForward(true); end});
    oUp = fOwn(_Button, {Text = "Up", OnClick = function() oComponent.goUp(true); end});
    oReload = fOwn(_Button, {Text = "Reload", OnClick = function() oComponent.reload(true); end});
    oAddress = fOwn(_Field, {Value = sDirectory, Hint = "Directory", OnEnter = function(sPath) oComponent.navigate(sPath, true); end});
    oSearch = fOwn(_Search, {Value = sFilter, Hint = "Filter names", Debounce = 120, OnSearch = function(sValue) oComponent.setFilter(sValue, true); end});
    oHidden = fOwn(_Checkbox, {Text = "Hidden", Selected = bHidden, OnChange = function(bValue) oComponent.setShowHiddenEnabled(bValue, true); end});
    oList = fOwn(_Table, {Columns = {{Text = "Name", Width = 240}, {Text = "Type", Width = 115},
        {Text = "Size (bytes)", Width = 110}, {Text = "Modified", Width = 150}}, MultiSelect = bMulti, Items = {}});
    oStatus = fOwn(_Label, {Value = "", Wrap = true});
    oComponent.BrowserList, oComponent.DirectoryField, oComponent.FilterField, oComponent.HiddenCheckbox = oList, oAddress, oSearch, oHidden;
    oComponent.BackButton, oComponent.ForwardButton, oComponent.UpButton, oComponent.ReloadButton = oBack, oForward, oUp, oReload;
    oComponent.StatusLabel = oStatus;

    --[[!
    @fqxn wxLuma.UI.FileBrowser.fStatus
    @desc Updates navigation availability and inline result/error feedback.
    !]]
    fStatus = function()
        if (oComponent.Disposed) then return; end
        -- Ancestors supply inherited disabling natively. Keep each button's own
        -- availability intact so restoring beneath a disabled parent is stable.
        local bEnabled = oComponent.Control:IsThisEnabled();
        oBack.setEnabled(bEnabled and #tBack > 0); oForward.setEnabled(bEnabled and #tForward > 0);
        oUp.setEnabled(bEnabled and pathKey(directoryPath("..", sDirectory)) ~= pathKey(sDirectory));
        oStatus.setValue(tError and tError.Reason or string.format("%d of %d entries · %d selected · %s %s",
            #tVisible, #tAll, #oComponent.getSelected(), sSort, sDirection));
    end;

    --[[!
    @fqxn wxLuma.UI.FileBrowser.fApply
    @desc Filters/sorts snapshots, replaces native rows in one frozen batch, and
        restores surviving selected paths and the requested top-row anchor.
    !]]
    fApply = function(tSelected, sTop)
        local tNext, tNextIds = {}, {};
        for _, tEntry in ipairs(tAll) do
            local bPattern = tEntry.Directory;
            if (not bPattern) then
                for _, sGlob in ipairs(tPatterns) do if (tEntry.Name:lower():match(sGlob)) then bPattern = true; break; end end
            end
            if (bPattern and tEntry.Name:lower():find(sFilter:lower(), 1, true)) then
                tNext[#tNext + 1] = tEntry; tNextIds[pathKey(tEntry.Path)] = tEntry;
            end
        end
        table.sort(tNext, function(tLeft, tRight)
            if (tLeft.Directory ~= tRight.Directory) then return tLeft.Directory; end
            local vLeft, vRight = tLeft[sSort], tRight[sSort];
            if (vLeft == nil or vRight == nil) then
                if (vLeft ~= vRight) then return vLeft ~= nil; end
            elseif (vLeft ~= vRight) then
                if (type(vLeft) == "string") then vLeft, vRight = vLeft:lower(), vRight:lower(); end
                if (vLeft ~= vRight) then return sDirection == "ascending" and vLeft < vRight or sDirection == "descending" and vLeft > vRight; end
            end
            local sLeft, sRight = tLeft.Name:lower(), tRight.Name:lower();
            return sLeft == sRight and tLeft.Name < tRight.Name or sLeft < sRight;
        end);
        local tRows, tKeep, nTop = {}, {}, nil;
        for nIndex, tEntry in ipairs(tNext) do
            local sId = pathKey(tEntry.Path);
            tRows[nIndex] = {Id = sId, Cells = {tEntry.Name, tEntry.Type,
                tEntry.Size and string.format("%.0f", tEntry.Size) or "", tEntry.ModifiedText or ""}};
            if (sId == sTop) then nTop = nIndex - 1; end
        end
        for _, sPath in ipairs(tSelected or {}) do if (tNextIds[pathKey(sPath)]) then tKeep[#tKeep + 1] = pathKey(sPath); end end
        tKeep = _Selection.validate(tKeep, function(sId) return tNextIds[sId] ~= nil; end, true);
        if (not bMulti and #tKeep > 1) then tKeep = {tKeep[#tKeep]}; end
        tVisible, tById = tNext, tNextIds;
        bInternal = true; oList.setItems(tRows); oList.setSelected(tKeep); bInternal = false;
        if (nTop) then oList.TableControl:EnsureVisible(nTop); end
        fStatus();
    end;
    oList.on("selectionChanged", function() if (not bInternal) then fSelection(true); end end);
    oList.on("itemActivated", function(oSource, tEvent)
        local tEntry = tById[tEvent.Id];
        if (oComponent.isEnabled() and tEntry) then oComponent.activate(tEntry.Path, true); end
    end);
    -- Consume the native header event here so Table's lexical sorter cannot
    -- briefly reorder byte counts as text before the browser's numeric sort.
    oList.TableControl:Connect(_wx.wxEVT_COMMAND_LIST_COL_CLICK, function(oEvent)
        if (not oComponent.isEnabled()) then return; end
        local sColumn = _tColumns[oEvent:GetColumn() + 1];
        if (sColumn) then oComponent.sortBy(sColumn, sColumn == sSort and sDirection == "ascending" and "descending" or "ascending", true); end
    end);

    --[[!
    @fqxn wxLuma.UI.FileBrowser.handleNavigationKey
    @desc Handles F5 reload and Alt-left/right/up navigation on owned children.
        Plain editing/list keys remain with their native controls.
    !]]
    function oComponent.handleNavigationKey(nKey, tModifiers)
        if (not oComponent.isEnabled()) then return false; end
        tModifiers = tModifiers or {};
        if (nKey == _wx.WXK_F5 and not tModifiers.Command and not tModifiers.Alt) then oComponent.reload(true);
        elseif (tModifiers.Alt and nKey == _wx.WXK_LEFT) then oComponent.goBack(true);
        elseif (tModifiers.Alt and nKey == _wx.WXK_RIGHT) then oComponent.goForward(true);
        elseif (tModifiers.Alt and nKey == _wx.WXK_UP) then oComponent.goUp(true);
        else return false; end
        return true;
    end
    for _, oTarget in ipairs({oList.TableControl, oAddress.TextControl, oSearch.TextControl}) do
        oTarget:Connect(_wx.wxEVT_KEY_DOWN, function(oEvent)
            if (not oComponent.handleNavigationKey(oEvent:GetKeyCode(), {Alt = oEvent:AltDown(), Command = oEvent:ControlDown() or oEvent:MetaDown()})) then oEvent:Skip(); end
        end);
    end

    --[[!
    @fqxn wxLuma.UI.FileBrowser.onLayout
    @desc Wraps the address below navigation at narrow widths. Native report
        columns retain horizontal scrolling; child dimensions remain positive.
    !]]
    oComponent.onLayout = function(nWidth, nHeight)
        local nY, nW = 4, math.max(1, nWidth - 8);
        local nButtonWidth = math.max(1, math.min(54, math.floor((nW - 12) / 4)));
        for nIndex, oButton in ipairs({oBack, oForward, oUp, oReload}) do
            oButton.layout(4 + (nIndex - 1) * (nButtonWidth + 4), 4, nButtonWidth, 32);
        end
        if (nWidth >= 440) then oAddress.layout(240, 4, math.max(1, nWidth - 244), 32); nY = 44;
        else oAddress.layout(4, 44, nW, 32); nY = 84; end
        if (nWidth >= 240) then
            oSearch.layout(4, nY, math.max(1, nW - 110), 32); oHidden.layout(nWidth - 106, nY, 102, 32);
            nY = nY + 40;
        else
            oSearch.layout(4, nY, nW, 32); oHidden.layout(4, nY + 40, nW, 32); nY = nY + 80;
        end
        oList.layout(4, nY, nW, math.max(1, nHeight - nY - 38));
        oStatus.layout(4, math.max(nY + 1, nHeight - 32), nW, 28);
    end;

    --[[!
    @fqxn wxLuma.UI.FileBrowser.onEnable
    @desc Propagates enabled state to all children and recalculates navigation
        availability rather than enabling an unavailable history destination.
    !]]
    oComponent.onEnable = function(bEnabled)
        for _, oChild in ipairs(tOwned) do oChild.setEnabled(bEnabled); end
        fStatus();
    end;

    --[[!
    @fqxn wxLuma.UI.FileBrowser.onDestroy
    @desc Disposes children in reverse creation order before releasing snapshots.
        Parent/native window lifetime remains owned by wxWidgets.
    !]]
    oComponent.onDestroy = function()
        for nIndex = #tOwned, 1, -1 do tOwned[nIndex].destroy(); end
        tAll, tVisible, tById, tBack, tForward, tLastSelection = {}, {}, {}, {}, {}, {};
    end;
    oComponent.Value = sDirectory; fApply({});
    oComponent.onEnable(tOptions.Enabled ~= false);
    oComponent.onLayout(oComponent.Control:GetClientSizeWH());
    _Theme.finish(oComponent, tOptions);
    return oComponent;
end

_State.register("wxLuma.UI.FileBrowser", {
    OwnsChildren = true,
    capture = function(oComponent) return oComponent.getBrowserState(); end,
    validate = function(tValue) browserState(tValue); end,
    restore = function(oComponent, tValue) oComponent.setBrowserState(tValue); end,
});

return FileBrowser;
