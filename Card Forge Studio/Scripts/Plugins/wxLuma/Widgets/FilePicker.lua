local _wx      = require("wx");
local _Editor  = require("wxLuma.Core.ControlEditor");
local _Dialog  = require("wxLuma.Containers.Dialog");
local _ListEx  = require("wxLuma.Widgets.ListEx");
local _Button  = require("wxLuma.Widgets.PushButton");
local FilePicker = {};

--[[!
@fqxn wxLuma.UI.FilePicker.create
@desc Creates a path editor with an image browse action and a fully skinned
    file/folder browser. Browsing never writes filesystem data. Cancel preserves
    the original path; OK validates the selected existing file or directory.
    The browser supports direct directory entry, Up and double-click navigation.
@param wxWindow oParent Native owner.
@param table tOptions Skin; optional Value, Mode (file/folder; default file),
    Directory (initial browse location), Artwork (File Picker), ReadOnly,
    Enabled, OnChange(path, component). Hidden filesystem entries are omitted.
@ret table oComponent Editor with Browser, BrowserList, DirectoryField,
    open/close/isOpen/navigate/getDirectory and browser event subscriptions.
!]]
function FilePicker.create(oParent, tOptions)
    local sMode = tOptions.Mode or "file";
    assert(sMode == "file" or sMode == "folder", "FilePicker Mode must be file or folder.");
    local tCopy = {};
    for sKey, vValue in pairs(tOptions) do tCopy[sKey] = vValue; end
    tCopy.Artwork = tCopy.Artwork or "File Picker";
    local oComponent, tArt, tEvents = _Editor.create(oParent, tCopy, "FilePicker");
    tEvents.extend(nil, {"opened", "closed", "directoryChanged", "navigationFailed", "validationFailed"});
    oComponent.LeadingIcon, oComponent.ActionIcon = sMode == "folder" and "Folder" or "File", "Browse";
    local sDirectory = "";
    local tEntries = {};
    local sError = "";
    local sAccepted;
    local fLayout;
    local oBrowser = _Dialog.create(oComponent.Control, {Skin = tOptions.Skin,
        Title = sMode == "folder" and "Choose folder" or "Choose file", Width = 660, Height = 480,
        OnClose = function(sResult)
            if (sResult == "ok" and sAccepted) then oComponent.setValue(sAccepted, true); end
            sAccepted = nil;
            tEvents.emit("closed", {Result = sResult, Value = oComponent.getValue()});
        end});
    oComponent.Browser = oBrowser;
    local oDirectory = _Editor.create(oBrowser.Content, {Skin = tOptions.Skin,
        Artwork = tCopy.Artwork, Hint = "Directory"}, "FilePickerDirectory");
    local oName = _Editor.create(oBrowser.Content, {Skin = tOptions.Skin,
        Artwork = tCopy.Artwork, Hint = sMode == "file" and "File name" or "Selected folder", ReadOnly = sMode == "folder"},
        "FilePickerName");
    oComponent.DirectoryField, oComponent.NameField = oDirectory, oName;
    local oList;
    local oUp = _Button.create(oBrowser.Content, {Skin = tOptions.Skin, Text = "Up", OnClick = function()
        local oPath = _wx.wxFileName.DirName(sDirectory);
        if (oPath:GetDirCount() > 0) then oPath:RemoveLastDir(); end
        local sParent = oPath:GetFullPath(); oPath:delete();
        oComponent.navigate(sParent);
    end});
    oList = _ListEx.create(oBrowser.Content, {Skin = tOptions.Skin, RowHeight = 34,
        Columns = {{Key = "Name", Type = "text", Weight = 1}, {Key = "Type", Type = "text", Width = 90}}, Items = {},
        OnChange = function(nIndex)
            local tEntry = tEntries[nIndex];
            if (tEntry) then oName.setValue(tEntry.Name); end
        end,
        OnActivate = function(nIndex)
            local tEntry = tEntries[nIndex];
            if (not tEntry) then return; end
            if (tEntry.Directory) then oComponent.navigate(tEntry.Path);
            elseif (sMode == "file") then oComponent.close(true); end
        end});
    oComponent.BrowserList, oComponent.UpButton = oList, oUp;

    --[[!
    @fqxn wxLuma.UI.FilePicker.fFailure
    @desc Displays a browser failure inline and emits its specific notification.
        No native message box or unskinned filesystem dialog is created.
    !]]
    local function fFailure(sEvent, sReason, sPath)
        sError = sReason;
        oBrowser.Content:Refresh(false);
        tEvents.emit(sEvent, {Reason = sReason, Path = sPath});
        return false;
    end

    --[[!
    @fqxn wxLuma.UI.FilePicker.navigate
    @desc Reads and sorts a directory before replacing live browser rows.
        Failed/unreadable paths leave the previous listing intact.
    @param string sPath Directory to browse.
    @ret boolean bOpened Whether the directory listing was replaced.
    !]]
    function oComponent.navigate(sPath)
        assert(not oComponent.Disposed and type(sPath) == "string", "Invalid directory path.");
        if (not _wx.wxDirExists(sPath)) then return fFailure("navigationFailed", "Directory does not exist.", sPath); end
        local oPath = _wx.wxFileName.DirName(sPath);
        oPath:MakeAbsolute();
        local sNext = oPath:GetFullPath(); oPath:delete();
        local oDir = _wx.wxDir(sNext);
        if (not oDir:IsOpened()) then oDir:delete(); return fFailure("navigationFailed", "Cannot read directory.", sPath); end
        local tNext = {};
        for _, tKind in ipairs({{Flag = _wx.wxDIR_DIRS, Directory = true}, {Flag = _wx.wxDIR_FILES, Directory = false}}) do
            if (tKind.Directory or sMode == "file") then
                local bFound, sName = oDir:GetFirst("", tKind.Flag);
                while (bFound) do
                    tNext[#tNext + 1] = {Name = sName, Path = sNext..sName, Directory = tKind.Directory,
                        Type = tKind.Directory and "Folder" or "File"};
                    bFound, sName = oDir:GetNext();
                end
            end
        end
        oDir:delete();
        table.sort(tNext, function(tLeft, tRight)
            if (tLeft.Directory ~= tRight.Directory) then return tLeft.Directory; end
            local sLeft, sRight = tLeft.Name:lower(), tRight.Name:lower();
            return sLeft == sRight and tLeft.Name < tRight.Name or sLeft < sRight;
        end);
        local sOld = sDirectory;
        sDirectory, tEntries, sError = sNext, tNext, "";
        oDirectory.setValue(sDirectory);
        oName.setValue("");
        oList.setItems(tNext);
        oList.setValue(0);
        oBrowser.Content:Refresh(false);
        if (sOld ~= sNext) then tEvents.emit("directoryChanged", {Path = sNext, OldPath = sOld}); end
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.FilePicker.getDirectory
    @desc Returns the current absolute browser directory with trailing separator.
    @ret string sDirectory Directory or empty before first open.
    !]]
    function oComponent.getDirectory() return sDirectory; end

    --[[!
    @fqxn wxLuma.UI.FilePicker.isOpen
    @desc Reports visibility of the owned browser dialog.
    @ret boolean bOpen Browser visibility.
    !]]
    function oComponent.isOpen() return oBrowser.isOpen(); end

    -- Validate before the dialog closes, so invalid selections remain editable.
    local fClose = oBrowser.close;
    oBrowser.close = function(sResult)
        if (sResult == "ok" and oBrowser.isOpen()) then
            local sName = oName.getValue();
            local sPath = sMode == "folder" and sDirectory or sDirectory..sName;
            local tSelected = tEntries[oList.getValue()];
            if (sMode == "folder" and tSelected and tSelected.Directory) then sPath = tSelected.Path; end
            local bValid = sMode == "folder" and _wx.wxDirExists(sPath) or sMode == "file" and _wx.wxFileExists(sPath);
            if (not bValid) then return fFailure("validationFailed", "Select an existing "..sMode..".", sPath); end
            local oPath = sMode == "folder" and _wx.wxFileName.DirName(sPath) or _wx.wxFileName(sPath);
            oPath:MakeAbsolute(); sAccepted = oPath:GetFullPath(); oPath:delete();
        end
        return fClose(sResult);
    end;

    --[[!
    @fqxn wxLuma.UI.FilePicker.close
    @desc Closes as cancellation by default; a committed selection must exist.
    @param boolean|nil bCommit Validate and commit the browser selection.
    @ret boolean bClosed Whether the browser is now closed.
    !]]
    function oComponent.close(bCommit)
        oBrowser.close(bCommit and "ok" or "cancel");
        return not oBrowser.isOpen();
    end

    --[[!
    @fqxn wxLuma.UI.FilePicker.open
    @desc Opens at the current path's directory, configured Directory, or cwd.
        An invalid starting directory reports failure without opening a browser.
    @ret boolean bOpened Whether the browser opened.
    !]]
    function oComponent.open()
        if (not oComponent.isEnabled() or oBrowser.isOpen()) then return false; end
        local sValue = oComponent.getValue();
        local sStart = tOptions.Directory or _wx.wxGetCwd();
        if (_wx.wxDirExists(sValue)) then sStart = sValue;
        elseif (_wx.wxFileExists(sValue)) then
            local oPath = _wx.wxFileName(sValue); sStart = oPath:GetPath(); oPath:delete();
        end
        if (not oComponent.navigate(sStart)) then return false; end
        if (sMode == "file" and _wx.wxFileExists(sValue)) then
            local oPath = _wx.wxFileName(sValue); oName.setValue(oPath:GetFullName()); oPath:delete();
        end
        -- Child creation follows Dialog's initial native layout, so no size
        -- event is guaranteed before first paint. Apply bounds before showing.
        fLayout();
        local bOpened = oBrowser.show();
        if (bOpened) then oDirectory.TextControl:SetFocus(); tEvents.emit("opened"); end
        return bOpened;
    end
    oDirectory.onTextEnter = function() oComponent.navigate(oDirectory.getValue()); end;
    oName.onTextEnter = function() oComponent.close(true); end;
    oComponent.onAction = oComponent.open;
    oComponent.onEditorKey = function(nKey)
        if (nKey == _wx.WXK_F4) then oComponent.open(); return true; end
        return false;
    end;
    oComponent.onEditorEnable = function(bEnabled)
        if (not bEnabled) then oComponent.close(false); end
        oBrowser.setEnabled(bEnabled);
    end;
    oComponent.onEditorDestroy = function()
        oList.destroy(); oDirectory.destroy(); oName.destroy(); oUp.destroy(); oBrowser.destroy();
    end;
    oBrowser.Content:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
    oBrowser.Content:Connect(_wx.wxEVT_PAINT, function()
        local oDC = _wx.wxAutoBufferedPaintDC(oBrowser.Content);
        if (not oComponent.Disposed) then
            local nWidth, nHeight = oBrowser.Content:GetClientSizeWH();
            tArt.part(oDC, "Surface Normal", 0, 0, nWidth, nHeight);
            tArt.text(oDC, sError, 4, math.max(0, nHeight - 22), true);
        end
        oDC:delete();
    end);
    --[[!
    @fqxn wxLuma.UI.FilePicker.fLayout
    @desc Sizes every browser child before first show and after content resize.
        In particular, the three-part Up button needs positive middle artwork.
    !]]
    fLayout = function()
        if (oComponent.Disposed) then return; end
        local nWidth, nHeight = oBrowser.Content:GetClientSizeWH();
        oDirectory.layout(4, 4, math.max(1, nWidth - 94), 36);
        oUp.layout(math.max(4, nWidth - 82), 4, 78, 36);
        oList.layout(4, 48, math.max(1, nWidth - 8), math.max(1, nHeight - 122));
        oName.layout(4, math.max(52, nHeight - 66), math.max(1, nWidth - 8), 36);
    end;
    oBrowser.Content:Connect(_wx.wxEVT_SIZE, function(jEvent)
        fLayout();
        jEvent:Skip();
    end);
    for _, oChild in ipairs({oDirectory, oName, oList, oUp}) do
        for _, sEvent in ipairs({"pointerEnter", "pointerLeave", "leftDown", "leftUp", "rightDown", "rightUp", "leftClick", "rightClick"}) do
            oChild.on(sEvent, function(oSource, tEvent) tEvents.emit(sEvent, {Child = oSource, NativeEvent = tEvent.NativeEvent}); end);
        end
    end
    fLayout();
    oComponent.setEnabled(tOptions.Enabled ~= false);
    return oComponent;
end

--[[!
@fqxn wxLuma.UI.FilePicker.createFolder
@desc Creates the same skinned browser restricted to existing directories.
@param wxWindow oParent Native owner.
@param table tOptions FilePicker options; Mode is fixed to folder.
@ret table oComponent Folder picker.
!]]
function FilePicker.createFolder(oParent, tOptions)
    local tCopy = {};
    for sKey, vValue in pairs(tOptions) do tCopy[sKey] = vValue; end
    tCopy.Mode = "folder";
    return FilePicker.create(oParent, tCopy);
end

return FilePicker;
