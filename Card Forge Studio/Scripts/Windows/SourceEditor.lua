-- Card-set source drafts. Fixed tabs are saved explicitly, never automatically.
local wx = require("wx");
local wxstc = wxstc;
local EditorSettings = require("Windows.EditorSettings");
local WindowState = require("Windows.WindowState");
local SourceEditor = {};
WindowState.register("SourceEditor", {savePosition = true, saveSize = true, saveVisible = false});
local function read(pFile)
    local hFile = assert(io.open(pFile, "rb"));
    local sText = assert(hFile:read("a"));
    assert(hFile:close());
    return sText;
end
local function temporary(pFile, sSuffix)
    local oFile = wx.wxFile();
    local pTemp = wx.wxFileName.CreateTempFileName(pFile..sSuffix, oFile);
    if (oFile:IsOpened()) then oFile:Close(); end
    oFile:delete();
    assert(pTemp ~= "", "Could not stage source changes.");
    return pTemp;
end
function SourceEditor.model(tFiles)
    local tModel = {files = {}};
    for _, tFile in ipairs(tFiles) do
        local sText = read(tFile.path);
        tModel.files[#tModel.files + 1] = {path = tFile.path, name = tFile.name, kind = tFile.kind, original = sText, text = sText};
    end
    function tModel.dirty()
        for _, tFile in ipairs(tModel.files) do if (tFile.text ~= tFile.original) then return true; end end
        return false;
    end
    function tModel.check()
        for _, tFile in ipairs(tModel.files) do
            if (tFile.kind == "lua") then
                local fChunk, sError = load(tFile.text:gsub("^\239\187\191", ""), "@"..tFile.path, "t", {});
                if (not fChunk) then return false, sError; end
            end
        end
        return true;
    end
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
function SourceEditor.create(dParent, tFiles, sTitle, tOptions)
    tOptions = tOptions or {};
    local tModel = SourceEditor.model(tFiles);
    local dFrame = wx.wxFrame(dParent, wx.wxID_ANY, sTitle or "Source Editor", wx.wxDefaultPosition, wx.wxSize(1000, 750));
    dFrame:SetMinSize(wx.wxSize(650, 450));
    local oState = WindowState.bind(dFrame, "SourceEditor", tOptions.stateFile);
    local dPanel = wx.wxPanel(dFrame, wx.wxID_ANY);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local dBook = wx.wxNotebook(dPanel, wx.wxID_ANY);
    local tEditors = {};
    local oStatus = wx.wxStaticText(dPanel, wx.wxID_ANY, "");
    local oSave = wx.wxButton(dPanel, wx.wxID_SAVE, "Save");
    local oClose = wx.wxButton(dPanel, wx.wxID_CLOSE, "Close");
    local oTimer = wx.wxTimer(dFrame, wx.wxNewId());
    local bClosed = false;
    local function pull()
        for nIndex, oCode in ipairs(tEditors) do tModel.files[nIndex].text = oCode:GetText(); end
    end
    local function refresh()
        pull();
        local bValid, sError = tModel.check();
        oStatus:SetLabel(bValid and "" or sError);
        oStatus:Show(not bValid);
        oSave:Enable(bValid and tModel.dirty());
        for nIndex, tFile in ipairs(tModel.files) do
            dBook:SetPageText(nIndex - 1, tFile.name..(tFile.text ~= tFile.original and " *" or ""));
        end
        dFrame:SetTitle((sTitle or "Source Editor")..(tModel.dirty() and " *" or ""));
        dPanel:Layout();
        return bValid;
    end
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
    for _, tFile in ipairs(tModel.files) do
        local oCode = wxstc.wxStyledTextCtrl(dBook, wx.wxID_ANY);
        EditorSettings.configure(oCode, tFile.kind);
        oCode:SetText(tFile.text); oCode:EmptyUndoBuffer();
        oCode:Connect(wxstc.wxEVT_STC_CHANGE, function() oTimer:StartOnce(250); end);
        tEditors[#tEditors + 1] = oCode;
        dBook:AddPage(oCode, tFile.name);
    end
    local oBar, oTheme, oFontSize, unregister = EditorSettings.bar(dPanel, tEditors);
    oLayout:Add(oBar, 0, wx.wxEXPAND + wx.wxALL, 8);
    oLayout:Add(dBook, 1, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 8);
    oStatus:SetForegroundColour(wx.wxColour(170, 25, 25));
    oLayout:Add(oStatus, 0, wx.wxEXPAND + wx.wxALL, 8);
    local oButtons = wx.wxBoxSizer(wx.wxHORIZONTAL);
    oButtons:AddStretchSpacer(); oButtons:Add(oSave, 0, wx.wxALL, 4); oButtons:Add(oClose, 0, wx.wxALL, 4);
    oLayout:Add(oButtons, 0, wx.wxEXPAND + wx.wxALL, 4);
    dPanel:SetSizer(oLayout);
    local oFrameLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    oFrameLayout:Add(dPanel, 1, wx.wxEXPAND); dFrame:SetSizer(oFrameLayout);
    local function save()
        pull(); tModel.save(); refresh();
        Log.Note("Card-set source saved. Live file monitoring will apply the changes.");
    end
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
        bClosed = true; oTimer:Stop(); unregister(); oState.close();
        if (tOptions.onClose) then tOptions.onClose(); end
        oEvent:Skip();
    end);
    refresh(); dFrame:Show(true); dFrame:Layout();
    return {frame = dFrame, book = dBook, editors = tEditors, model = tModel, theme = oTheme, fontSize = oFontSize, refresh = refresh, save = save,
        close = function() if (bClosed) then return true; end return dFrame:Close(); end,
        show = function() dFrame:Show(true); dFrame:Raise(); end};
end
return SourceEditor;