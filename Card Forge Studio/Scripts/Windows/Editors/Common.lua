--[[!
@fqxn CFS.Windows.Editors.Common
@desc Source-file draft validation and transactional saving shared by game and card-set editors.
!]]

-- Shared source draft, saving, and editor controls for the two source windows.
local wx = require("wx");
local wxstc = wxstc;
local EditorSettings = require("Windows.EditorSettings");
local WindowState = require("Windows.WindowState");
local Common = {};

--[[!
@fqxn CFS.Windows.Editors.Common.Private.read
@desc Reads the complete source file in binary mode and checks read and close success.
@vis private
@param any pFile File path.
!]]
local function read(pFile)
    local hFile = assert(io.open(pFile, "rb"));
    local sText = assert(hFile:read("a"));
    assert(hFile:close());
    return sText;
end
--[[!
@fqxn CFS.Windows.Editors.Common.Private.temporary
@desc Creates and closes a temporary file beside the target for staged source changes.
@vis private
@param any pFile File path.
@param any sSuffix Suffix.
!]]
local function temporary(pFile, sSuffix)
    local oFile = wx.wxFile();
    local pTemp = wx.wxFileName.CreateTempFileName(pFile..sSuffix, oFile);
    if (oFile:IsOpened()) then oFile:Close(); end
    oFile:delete();
    assert(pTemp ~= "", "Could not stage source changes.");
    return pTemp;
end
--[[!
@fqxn CFS.Windows.Editors.Common.model
@pulsarlua function Common.model
@desc Loads source records into an in-memory draft model with syntax checks and transactional saves.
@param any tFiles Source-file records.
!]]
function Common.model(tFiles)
    local tModel = {files = {}};
    for _, tFile in ipairs(tFiles) do
        local sText = read(tFile.path);
        tModel.files[#tModel.files + 1] = {path = tFile.path, name = tFile.name, kind = tFile.kind, group = tFile.group, original = sText, text = sText};
    end
    --[[!
    @fqxn CFS.Windows.Editors.Common.Model.dirty
    @desc Reports whether any source draft differs from its original contents.
    @vis public
    !]]
    function tModel.dirty()
        for _, tFile in ipairs(tModel.files) do if (tFile.text ~= tFile.original) then return true; end end
        return false;
    end
    --[[!
    @fqxn CFS.Windows.Editors.Common.Model.check
    @desc Compiles Lua drafts without executing them; returns the first syntax error or true.
    @vis public
    !]]
    function tModel.check()
        for _, tFile in ipairs(tModel.files) do
            if (tFile.kind == "lua") then
                local fChunk, sError = load(tFile.text:gsub("^\239\187\191", ""), "@"..tFile.path, "t", {});
                if (not fChunk) then return false, sError; end
            end
        end
        return true;
    end
    --[[!
    @fqxn CFS.Windows.Editors.Common.Model.save
    @desc Checks syntax and external changes, stages modified files with recovery copies, and restores attempted replacements on failure.
    @vis public
    !]]
    function tModel.save()
        local bValid, sError = tModel.check(); assert(bValid, sError);
        local tPending = {};
        local bOK, sFailure = xpcall(function()
            for _, tFile in ipairs(tModel.files) do
                if (tFile.text ~= tFile.original) then
                    assert(read(tFile.path) == tFile.original, tFile.name.." changed externally. Close and reopen the editor before saving.");
                    local tSave = {file = tFile};
                    tPending[#tPending + 1] = tSave;
                    tSave.stage = temporary(tFile.path, ".source-draft-");
                    local hFile = assert(io.open(tSave.stage, "wb"));
                    local bWrite, sWriteError = hFile:write(tFile.text);
                    local bClose, sCloseError = hFile:close();
                    assert(bWrite, sWriteError); assert(bClose, sCloseError);
                    tSave.recovery = temporary(tFile.path, ".source-recovery-");
                    assert(wx.wxCopyFile(tFile.path, tSave.recovery, true), "Could not preserve "..tFile.name..".");
                end
            end
            for _, tSave in ipairs(tPending) do
                assert(read(tSave.file.path) == tSave.file.original, tSave.file.name.." changed while saving.");
            end
            for _, tSave in ipairs(tPending) do
                tSave.attempted = true;
                assert(wx.wxRenameFile(tSave.stage, tSave.file.path, true), "Could not replace "..tSave.file.name..".");
                tSave.replaced = true;
            end
        end, debug.traceback);
        local tRecoveryErrors = {};
        if (not bOK) then
            for _, tSave in ipairs(tPending) do
                if (tSave.attempted and tSave.recovery) then
                    if (not wx.wxCopyFile(tSave.recovery, tSave.file.path, true)) then
                        tSave.retain = true;
                        tRecoveryErrors[#tRecoveryErrors + 1] = "Original retained at "..tSave.recovery;
                    end
                end
            end
        end
        for _, tSave in ipairs(tPending) do
            if (tSave.stage and wx.wxFileExists(tSave.stage)) then wx.wxRemoveFile(tSave.stage); end
            if (tSave.recovery and not tSave.retain and wx.wxFileExists(tSave.recovery)) then wx.wxRemoveFile(tSave.recovery); end
        end
        assert(bOK, tostring(sFailure)..(#tRecoveryErrors > 0 and "\n"..table.concat(tRecoveryErrors, "\n") or ""));
        for _, tSave in ipairs(tPending) do tSave.file.original = tSave.file.text; end
        return true;
    end
    return tModel;
end
--[[!
@fqxn CFS.Windows.Editors.Common.create
@pulsarlua function Common.create
@desc Creates a source editor with shared preferences, file tabs, validation, protected saving, and optional persistent navigation.
@param any dParent Parent window.
@param any tFiles Source-file records.
@param any sTitle Display title.
@param any tOptions Options table.
!]]
function Common.create(dParent, tFiles, sTitle, tOptions)
    tOptions = tOptions or {};
    local tModel = Common.model(tFiles);
    local dFrame = wx.wxFrame(dParent, wx.wxID_ANY, sTitle or "Source Editor", wx.wxDefaultPosition, wx.wxSize(1000, 750));
    dFrame:SetMinSize(wx.wxSize(650, 450));
    local sState = tOptions.windowState or "SourceEditor";
    WindowState.register(sState, {savePosition = true, saveSize = true, saveVisible = false});
    local oState = WindowState.bind(dFrame, sState, tOptions.stateFile);
    local dPanel = wx.wxPanel(dFrame, wx.wxID_ANY);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local tBooks, tBarIndicators = {}, {};
    for nIndex = 1, #(tOptions.groups or {"Source"}) do
        tBooks[nIndex] = tOptions.groups and wxaui.wxAuiNotebook(dPanel, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize,
            wxaui.wxAUI_NB_TOP + wxaui.wxAUI_NB_SCROLL_BUTTONS) or wx.wxNotebook(dPanel, wx.wxID_ANY);
        if (tOptions.groups) then tBooks[nIndex]:SetArtProvider(wxaui.wxAuiDefaultTabArt()); end
    end
    local dBook = tBooks[1];
    local tEditors, tFileEditors, tPages = {}, {}, {};
    local dEditingArea = tOptions.groups and wx.wxPanel(dPanel, wx.wxID_ANY) or nil;
    local oEditingLayout = dEditingArea and wx.wxBoxSizer(wx.wxVERTICAL) or nil;
    local nActiveFile;
    local openFile;
    local tNewButtons = {};
    if (dEditingArea) then dEditingArea:SetSizer(oEditingLayout); end
    local oStatus = wx.wxStaticText(dPanel, wx.wxID_ANY, "");
    local oSave = wx.wxButton(dPanel, wx.wxID_SAVE, "Save");
    local oClose = wx.wxButton(dPanel, wx.wxID_CLOSE, "Close");
    local oTimer = wx.wxTimer(dFrame, wx.wxNewId());
    local bClosed = false;
    --[[!
    @fqxn CFS.Windows.Editors.Common.Private.pull
    @desc Copies text from instantiated editor controls into their source drafts.
    @vis private
    !]]
    local function pull()
        for nIndex, oCode in pairs(tFileEditors) do tModel.files[nIndex].text = oCode:GetText(); end
    end
    --[[!
    @fqxn CFS.Windows.Editors.Common.Private.refresh
    @desc Synchronizes drafts, syntax status, dirty tab labels, Save enablement, and the frame title.
    @vis private
    !]]
    local function refresh()
        pull();
        local bValid, sError = tModel.check();
        oStatus:SetLabel(bValid and "" or sError);
        oStatus:Show(not bValid);
        oSave:Enable(bValid and tModel.dirty());
        for nIndex, tFile in ipairs(tModel.files) do
            local tPage = tPages[nIndex];
            tPage.book:SetPageText(tPage.index, tFile.name..(tFile.text ~= tFile.original and " *" or ""));
        end
        local sFile = nActiveFile and (" - "..tOptions.groups[tModel.files[nActiveFile].group].." / "..tModel.files[nActiveFile].name) or "";
        dFrame:SetTitle((sTitle or "Source Editor")..sFile..(tModel.dirty() and " *" or ""));
        dPanel:Layout();
        return bValid;
    end
    --[[!
    @fqxn CFS.Windows.Editors.Common.Private.protect
    @desc Wraps an editor action so failures are logged and displayed in the status area.
    @vis private
    @param any fAction Action.
    !]]
    local function protect(fAction)
        return function(...)
            local tArgs = table.pack(...);
            local bOK, sError = xpcall(function() return fAction(table.unpack(tArgs, 1, tArgs.n)); end, debug.traceback);
            if (not bOK) then
                oStatus:SetLabel(tostring(sError)); oStatus:Show(true); dPanel:Layout();
                require("Errors").report(sError);
            end
        end;
    end
    --[[!
    @fqxn CFS.Windows.Editors.Common.Private.createCode
    @desc Creates an editor for one draft and connects delayed validation after text changes.
    @vis private
    @param any nIndex Index.
    @param any dParent Parent window.
    !]]
    local function createCode(nIndex, dParent)
        local tFile = tModel.files[nIndex];
        local oCode = wxstc.wxStyledTextCtrl(dParent, wx.wxID_ANY);
        EditorSettings.configure(oCode, tFile.kind);
        oCode:SetText(tFile.text); oCode:EmptyUndoBuffer();
        oCode:Connect(wxstc.wxEVT_STC_CHANGE, function() oTimer:StartOnce(250); end);
        tEditors[#tEditors + 1] = oCode; tFileEditors[nIndex] = oCode;
        return oCode;
    end
    for nIndex, tFile in ipairs(tModel.files) do
        local oBook = assert(tBooks[tFile.group or 1], "Unknown source group.");
        local dPage = tOptions.groups and wx.wxPanel(oBook, wx.wxID_ANY) or createCode(nIndex, oBook);
        tPages[nIndex] = {book = oBook, index = oBook:GetPageCount(), panel = dPage};
        oBook:AddPage(dPage, tFile.name);
    end
    local oBar, oTheme, oFontSize, unregister = EditorSettings.bar(dPanel, tEditors);
    oLayout:Add(oBar, 0, wx.wxEXPAND + wx.wxALL, 8);
    --[[!
    @fqxn CFS.Windows.Editors.Common.Private.ensurePage
    @desc Activates the selected group, lazily creates its editor, and updates group indicators and editor visibility.
    @vis private
    @param any oBook Book.
    !]]
    local function ensurePage(oBook)
        for _, oOther in ipairs(tBooks) do
            tBarIndicators[oOther]:SetBackgroundColour(wx.wxColour(oOther == oBook and "#4598D5" or "#173451"));
            tBarIndicators[oOther]:Refresh();
            oOther:GetArtProvider():SetColour(wx.wxColour("#D8D8D8"));
            oOther:GetArtProvider():SetActiveColour(wx.wxColour(oOther == oBook and "#A6CEF0" or "#D8D8D8"));
            oOther:Refresh();
        end
        local nSelection = oBook:GetSelection();
        for nIndex, tPage in ipairs(tPages) do
            if (tPage.book == oBook and tPage.index == nSelection) then
                if (not tFileEditors[nIndex]) then
                    local oCode = createCode(nIndex, dEditingArea);
                    oEditingLayout:Add(oCode, 1, wx.wxEXPAND);
                    EditorSettings.apply(oCode);
                end
                for nFile, oCode in pairs(tFileEditors) do oCode:Show(nFile == nIndex); end
                nActiveFile = nIndex; dEditingArea:Layout(); refresh();
                break;
            end
        end
    end
    for nIndex, oBook in ipairs(tBooks) do
        if (tOptions.groups) then
            local oIndicator = wx.wxPanel(dPanel, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(5, 34));
            tBarIndicators[oBook] = oIndicator;
            oBook:SetTabCtrlHeight(30);
            local nHeight = 34;
            oBook:SetMinSize(wx.wxSize(-1, nHeight)); oBook:SetMaxSize(wx.wxSize(-1, nHeight));
            oBook:Connect(wxaui.wxEVT_COMMAND_AUINOTEBOOK_PAGE_CHANGED, protect(function(oEvent) ensurePage(oBook); oEvent:Skip(); end));
            --[[!
            @fqxn CFS.Windows.Editors.Common.Private.activate
            @desc Activates the clicked source group and propagates the mouse event.
            @vis private
            @param any oEvent Event.
            !]]
            local function activate(oEvent) ensurePage(oBook); oEvent:Skip(); end
            oBook:Connect(wx.wxEVT_LEFT_UP, protect(activate));
            local oNode = oBook:GetChildren():GetFirst();
            while (oNode) do
                local oChild = oNode:GetData();
                if (oChild:GetClassInfo():GetClassName() == "wxAuiTabCtrl") then oChild:DynamicCast("wxWindow"):Connect(wx.wxEVT_LEFT_UP, protect(activate)); end
                oNode = oNode:GetNext();
            end
        end
        if (tOptions.groups) then
            local oTabRow = wx.wxBoxSizer(wx.wxHORIZONTAL);
            oTabRow:Add(tBarIndicators[oBook], 0, wx.wxEXPAND + wx.wxRIGHT, 3);
            oTabRow:Add(oBook, 1, wx.wxEXPAND);
            if (tOptions.newFile) then
                local oNew = wx.wxButton(dPanel, wx.wxID_ANY, "New..."); tNewButtons[nIndex] = oNew;
                oTabRow:Add(oNew, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxLEFT, 6);
                oNew:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, protect(function()
                    local tFile = tOptions.newFile(dFrame, nIndex);
                    if (tFile) then openFile(tFile); end
                end));
            end
            oLayout:Add(oTabRow, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 8);
        else
            oLayout:Add(oBook, 1, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 8);
        end
    end
    --[[!
    @fqxn CFS.Windows.Editors.Common.Private.openFile
    @desc Selects an open file or creates a missing file without overwriting, then appends and activates its tab.
    @vis private
    @param any tFile File.
    !]]
    openFile = function(tFile)
        local oBook = assert(tBooks[tFile.group], "Unknown source group.");
        for nIndex, tExisting in ipairs(tModel.files) do
            if (tExisting.path:gsub("\\", "/"):lower() == tFile.path:gsub("\\", "/"):lower()) then
                oBook:SetSelection(tPages[nIndex].index); ensurePage(oBook); return nIndex;
            end
        end
        if (not wx.wxFileExists(tFile.path)) then
            local oFile = wx.wxFile(); local bCreated = oFile:Create(tFile.path, false);
            if (bCreated) then oFile:Close(); end; oFile:delete();
            assert(bCreated, "Could not create source file. Existing files are never overwritten.");
        end
        local nIndex = #tModel.files + 1;
        tModel.files[nIndex] = Common.model({tFile}).files[1];
        local dPage = wx.wxPanel(oBook, wx.wxID_ANY);
        tPages[nIndex] = {book = oBook, index = oBook:GetPageCount(), panel = dPage};
        oBook:AddPage(dPage, tFile.name); oBook:SetSelection(tPages[nIndex].index); ensurePage(oBook);
        return nIndex;
    end
    if (dEditingArea) then
        oLayout:Add(dEditingArea, 1, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 8);
        ensurePage(tBooks[1]);
    end
    oStatus:SetForegroundColour(wx.wxColour(170, 25, 25));
    oLayout:Add(oStatus, 0, wx.wxEXPAND + wx.wxALL, 8);
    local oButtons = wx.wxBoxSizer(wx.wxHORIZONTAL);
    oButtons:AddStretchSpacer(); oButtons:Add(oSave, 0, wx.wxALL, 4); oButtons:Add(oClose, 0, wx.wxALL, 4);
    oLayout:Add(oButtons, 0, wx.wxEXPAND + wx.wxALL, 4);
    dPanel:SetSizer(oLayout);
    local oFrameLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    oFrameLayout:Add(dPanel, 1, wx.wxEXPAND); dFrame:SetSizer(oFrameLayout);
    --[[!
    @fqxn CFS.Windows.Editors.Common.Private.save
    @desc Pulls drafts, applies save-time preferences, saves the source transaction, and refreshes dirty indicators.
    @vis private
    !]]
    local function save()
        pull();
        for nIndex, tFile in ipairs(tModel.files) do
            tFile.text = tFileEditors[nIndex] and EditorSettings.cleanControl(tFileEditors[nIndex]) or EditorSettings.prepareSave(tFile.text);
        end
        tModel.save(); refresh();
        Log.Note(tOptions.savedMessage or "Card-set source saved. Live file monitoring will apply the changes.");
    end
    --[[!
    @fqxn CFS.Windows.Editors.Common.Private.allowClose
    @desc Asks whether unsaved drafts should be saved, discarded, or kept open.
    @vis private
    !]]
    local function allowClose()
        pull();
        if (not tModel.dirty()) then return true; end
        local nAnswer = tOptions.confirm and tOptions.confirm() or wx.wxMessageBox("Save your source changes? No discards the draft.", "Source Editor", wx.wxYES_NO + wx.wxCANCEL + wx.wxICON_QUESTION, dFrame);
        if (nAnswer == wx.wxYES) then save(); return true; end
        return nAnswer == wx.wxNO;
    end
    oSave:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, protect(save));
    oClose:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function() dFrame:Close(); end);
    dFrame:Connect(oTimer:GetId(), wx.wxEVT_TIMER, protect(refresh));
    dFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        local bOK, bContinue = pcall(allowClose);
        if (not bOK or not bContinue) then
            if (oEvent:CanVeto()) then oEvent:Veto(); end
            if (not bOK) then require("Errors").report(bContinue); oStatus:SetLabel(tostring(bContinue)); oStatus:Show(true); dPanel:Layout(); end
            return;
        end
        if (tOptions.navigationFile) then
            local nFile = nActiveFile or (dBook:GetSelection() + 1);
            local tFile = tModel.files[nFile];
            local bSaved, sError = pcall(function()
                local tNavigation = Common.model({{path = tOptions.navigationFile, name = "Editor navigation", kind = "ini"}});
                local sText = tNavigation.files[1].original;
                local sNewline = sText:find("\r\n", 1, true) and "\r\n" or "\n";
                local tLines, bSection, bWritten = {}, false, false;
                --[[!
                @fqxn CFS.Windows.Editors.Common.Private.append
                @desc Adds the active-file key to the navigation INI section once.
                @vis private
                !]]
                local function append()
                    if (bSection and not bWritten) then tLines[#tLines + 1] = "ActiveFile="..tostring(tFile.group or 1)..":"..tFile.name; bWritten = true; end
                end
                for sLine in (sText:gsub("\r\n", "\n").."\n"):gmatch("(.-)\n") do
                    local sSection = sLine:match("^%s*%[([^%]]+)%]%s*$");
                    if (sSection) then append(); bSection = sSection:lower() == "editor.navigation"; end
                    if (bSection and sLine:match("^%s*[Aa][Cc][Tt][Ii][Vv][Ee][Ff][Ii][Ll][Ee]%s*=")) then
                        sLine = "ActiveFile="..tostring(tFile.group or 1)..":"..tFile.name; bWritten = true;
                    end
                    tLines[#tLines + 1] = sLine;
                end
                append();
                if (not bWritten) then tLines[#tLines + 1] = "[Editor.Navigation]"; bSection = true; append(); end
                tNavigation.files[1].text = table.concat(tLines, sNewline); tNavigation.save();
            end);
            if (not bSaved) then require("Errors").report(sError); if (oEvent:CanVeto()) then oEvent:Veto(); end; return; end
        end
        bClosed = true; oTimer:Stop(); unregister(); oState.close();
        if (tOptions.onClose) then tOptions.onClose(); end
        oEvent:Skip();
    end);
    if (tOptions.navigationFile) then
        local sActive = INIFile.GetValue(tOptions.navigationFile, "Editor.Navigation", "ActiveFile");
        for nIndex, tFile in ipairs(tModel.files) do
            if (sActive == tostring(tFile.group or 1)..":"..tFile.name) then
                local tPage = tPages[nIndex]; tPage.book:SetSelection(tPage.index);
                if (dEditingArea) then ensurePage(tPage.book); end
                break;
            end
        end
    end
    refresh(); dFrame:Show(true); dFrame:Layout();
    return {frame = dFrame, book = dBook, books = tBooks, barIndicators = tBarIndicators, newButtons = tNewButtons, openFile = openFile, editors = tEditors, fileEditors = tFileEditors, editingArea = dEditingArea, model = tModel, theme = oTheme, fontSize = oFontSize, refresh = refresh, save = save,
        --[[!
        @fqxn CFS.Windows.Editors.Common.Private.close
        @desc Closes through unsaved-draft protection; returns immediately if already closed.
        @vis private
        !]]
        close = function() if (bClosed) then return true; end return dFrame:Close(); end,
        --[[!
        @fqxn CFS.Windows.Editors.Common.Private.show
        @desc Shows and raises the source editor frame.
        @vis private
        !]]
        show = function() dFrame:Show(true); dFrame:Raise(); end};
end
return Common;