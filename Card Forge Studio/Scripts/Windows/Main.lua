-- Native editor window. Studio and game services are connected by callbacks.
local _sSource = debug.getinfo(1, "S").source;
local _pWindows = assert(_sSource:match("^@(.+[/\\])"));
local _pRuntime = _pWindows.."../../";

package.cpath = _pRuntime.."Bin/?.dll;"..package.cpath;
local wx = require("wx");
local Main = {};
local WindowState = require("Windows.WindowState");
local _tWindowState = {
    savePosition = true,
    saveSize     = true,
    saveVisible  = false,
};
WindowState.register("Main", _tWindowState);
local _tDialogStates = {
    LoadGame = {
        savePosition = false,
        saveSize     = false,
        saveVisible  = false,
    },
    LoadCardSet = {
        savePosition = false,
        saveSize     = false,
        saveVisible  = false,
    },
};
for sName, tOptions in pairs(_tDialogStates) do WindowState.register(sName, tOptions); end
local dLog = require("Windows.Log");
local Log = require("Log");
local Welcome = require("Windows.Main.Welcome");
local DataSession = require("Windows.DataSession");
local dBaseData = require("Windows.BaseData");
local dFinalData = require("Windows.FinalData");

function Main.create(tOptions)
    tOptions = tOptions or {};
    wx.wxInitAllImageHandlers();
    local oImage;
    local nCardWidth, nCardHeight = 1, 1;
    local sTitle = "Card Forge Studio";

    if (tOptions.gameName) then
        sTitle = sTitle.." - "..tOptions.gameName;
    end

    local dFrame = wx.wxFrame(wx.NULL, wx.wxID_ANY, sTitle, wx.wxDefaultPosition, wx.wxSize(760, 940));
    local oWindowState = WindowState.bind(dFrame, "Main");
    local oIcon = wx.wxIcon(_pRuntime.."icon.ico", wx.wxBITMAP_TYPE_ICO);

    if (oIcon:IsOk()) then
        dFrame:SetIcon(oIcon);
    end

    local dPanel = wx.wxPanel(dFrame, wx.wxID_ANY);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oControls = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oFront = wx.wxButton(dPanel, wx.wxID_ANY, "Front");
    local oBack = wx.wxButton(dPanel, wx.wxID_ANY, "Back");
    local dCanvas = wx.wxPanel(dPanel, wx.wxID_ANY);
    local tState = {horizontalGuide = nil, verticalGuide = nil, overlay = true, horizontalCenter = false, verticalCenter = false, face = "front"};
    local tView = {x = 0, y = 0, width = 1, height = 1};
    local oScaled;
    local tMenus = {};
    local tMenuItems = {};
    local tWelcome = Welcome.create(_pRuntime);
    local sPage = "Welcome";
    local tDataSession = tOptions.dataSession or DataSession.create();
    local dBaseWindow, dFinalWindow, dStyleWindow, dSourceWindow, dWikiWindow;
    local showPage;
    local bDataLoaded = false;
    ProcSys.BindSession(tDataSession);

    oBack:Enable(true);
    oControls:Add(oFront, 0, wx.wxALL, 4);
    oControls:Add(oBack, 0, wx.wxALL, 4);
    oControls:Add(wx.wxStaticText(dPanel, wx.wxID_ANY, "Ctrl + click: guides   |   Ctrl + Shift + click: remove"), 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 4);
    oLayout:Add(oControls, 0, wx.wxEXPAND);
    oLayout:Add(dCanvas, 1, wx.wxEXPAND);
    dPanel:SetSizer(oLayout);
    oControls:ShowItems(false);
    dCanvas:SetBackgroundStyle(wx.wxBG_STYLE_PAINT);
    dFrame:CreateStatusBar(3);
    dFrame:SetStatusText("Welcome", 0);
    dFrame:SetMinClientSize(wx.wxSize(360, 240));

    local function reportError(sError)
        require("Errors").report(sError);
    end

    local function protect(fCallback)
        return function(...)
            local tArguments = table.pack(...);
            local bOK, sError = xpcall(function()
                fCallback(table.unpack(tArguments, 1, tArguments.n));
            end, debug.traceback);

            if (not bOK) then
                reportError(sError);
            end
        end;
    end

    local function resizeCanvas()
        local oSize = dCanvas:GetClientSize();
        local nScale = math.min(math.max(1, oSize:GetWidth() - 16) / nCardWidth, math.max(1, oSize:GetHeight() - 16) / nCardHeight);
        tView.width = math.max(1, math.floor(nCardWidth * nScale));
        tView.height = math.max(1, math.floor(nCardHeight * nScale));
        tView.x = math.floor((oSize:GetWidth() - tView.width) / 2);
        tView.y = math.floor((oSize:GetHeight() - tView.height) / 2);
        oScaled = oImage and wx.wxBitmap(oImage:Scale(tView.width, tView.height, wx.wxIMAGE_QUALITY_HIGH)) or nil;
        dCanvas:Refresh(false);
    end

    local function drawCanvas()
        if (sPage == "Welcome") then
            tWelcome.draw(dCanvas);

            return;
        end

        local oGuidePen, oCenterPen;
        local oDC = wx.wxPaintDC(dCanvas);
        oDC:SetBackground(wx.wxBrush(wx.wxColour(35, 35, 35)));
        oDC:Clear();



        if (oScaled) then
            oDC:DrawBitmap(oScaled, tView.x, tView.y, true);
        end

        if (tState.overlay) then
            oGuidePen = wx.wxPen(wx.wxColour(0, 220, 255), 1, wx.wxPENSTYLE_SOLID);
            oDC:SetPen(oGuidePen);

            if (tState.horizontalGuide) then
                local nY = tView.y + math.floor(tState.horizontalGuide * tView.height / nCardHeight);
                oDC:DrawLine(tView.x, nY, tView.x + tView.width, nY);
            end

            if (tState.verticalGuide) then
                local nX = tView.x + math.floor(tState.verticalGuide * tView.width / nCardWidth);
                oDC:DrawLine(nX, tView.y, nX, tView.y + tView.height);
            end

            oCenterPen = wx.wxPen(wx.wxColour(255, 200, 0), 1, wx.wxPENSTYLE_SOLID);
            oDC:SetPen(oCenterPen);

            if (tState.horizontalCenter) then
                local nY = tView.y + math.floor(tView.height / 2);
                oDC:DrawLine(tView.x, nY, tView.x + tView.width, nY);
            end

            if (tState.verticalCenter) then
                local nX = tView.x + math.floor(tView.width / 2);
                oDC:DrawLine(nX, tView.y, nX, tView.y + tView.height);
            end
        end

        oDC:delete();

        if (oGuidePen) then
            oGuidePen:delete();
        end

        if (oCenterPen) then
            oCenterPen:delete();
        end
    end

    local function copyText(sText)
        local oClipboard = wx.wxClipboard.Get();
        assert(oClipboard:Open(), "Clipboard is unavailable.");
        local bOK = oClipboard:SetData(wx.wxTextDataObject(sText));
        oClipboard:Close();
        assert(bOK, "Could not copy coordinates.");
    end

    local function applyClick(sButton, nX, nY, bControl, bShift)
        local sText = sButton == "right" and (nX - nCardWidth)..", "..(nY - nCardHeight) or nX..", "..nY;

        if (bControl) then
            if (sButton == "left" or sButton == "middle") then
                tState.horizontalGuide = not bShift and nY or nil;
            end

            if (sButton == "right" or sButton == "middle") then
                tState.verticalGuide = not bShift and nX or nil;
            end

            if (not bShift and sButton == "left") then
                sText = nY..", "..(nY - nCardHeight);
            elseif (not bShift and sButton == "right") then
                sText = nX..", "..(nX - nCardWidth);
            end
        end

        dCanvas:Refresh(false);

        return sText;
    end

    local function cardPosition(oEvent)
        if (sPage ~= "Editor") then
            return;
        end

        local nX, nY = oEvent:GetX() - tView.x, oEvent:GetY() - tView.y;

        if (nX < 0 or nY < 0 or nX >= tView.width or nY >= tView.height) then
            return;
        end

        return math.floor(nX * nCardWidth / tView.width), math.floor(nY * nCardHeight / tView.height);
    end

    dCanvas:Connect(wx.wxEVT_PAINT, protect(drawCanvas));
    dCanvas:Connect(wx.wxEVT_SIZE, protect(function(oEvent)
        resizeCanvas();
        oEvent:Skip();
    end));
    dCanvas:Connect(wx.wxEVT_MOTION, protect(function(oEvent)
        local nX, nY = cardPosition(oEvent);
        dFrame:SetStatusText(nX and (nX..", "..nY) or "", 1);
        dFrame:SetStatusText(nX and ((nX - nCardWidth)..", "..(nY - nCardHeight)) or "", 2);
        oEvent:Skip();
    end));

    for sButton, nEvent in pairs({left = wx.wxEVT_LEFT_DOWN, right = wx.wxEVT_RIGHT_DOWN, middle = wx.wxEVT_MIDDLE_DOWN}) do
        local sWhichButton = sButton;
        dCanvas:Connect(nEvent, protect(function(oEvent)
            dCanvas:SetFocus();
            local nX, nY = cardPosition(oEvent);

            if (nX) then
                local sCoordinates = applyClick(sWhichButton, nX, nY, oEvent:ControlDown(), oEvent:ShiftDown());
                copyText(sCoordinates);
                Log.Debug("Canvas "..sWhichButton.." click: "..sCoordinates);
            end
        end));
    end

    local function selectFace(sFace)
        if (type(tOptions.onFaceChanged) == "function") then
            tOptions.onFaceChanged(sFace);
            tState.face = sFace;
        elseif (Forge and bDataLoaded) then
            Forge.SetFace(sFace);
            tState.face = sFace;
        end
    end

    oFront:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, protect(function() selectFace("front"); end));
    oBack:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, protect(function() selectFace("back"); end));
    dCanvas:Connect(wx.wxEVT_KEY_DOWN, protect(function(oEvent)
        local nKey = oEvent:GetKeyCode();

        if (nKey == wx.WXK_LEFT) then
            selectFace("front");
        elseif (nKey == wx.WXK_RIGHT) then
            selectFace("back");
        else
            oEvent:Skip();
        end
    end));

    local oMenuBar = wx.wxMenuBar();
    local oWelcomeLinks = tWelcome.addLinks(dCanvas, protect);

    local function addMenu(sTitle, tItems)
        local oMenu = wx.wxMenu();

        for _, tItem in ipairs(tItems) do
            local nID = wx.wxNewId();
            local oItem = tItem[3] == "check" and oMenu:AppendCheckItem(nID, tItem[1]) or oMenu:Append(nID, tItem[1]);
            local fAction = tItem[2];
            tMenuItems[sTitle..":"..tItem[1]] = {item = oItem, action = fAction};
            oItem:Enable(type(fAction) == "function");

            local fChecked = tItem[4];
            if (fChecked) then
                oItem:Check(not not fChecked());
                dFrame:Connect(nID, wx.wxEVT_UPDATE_UI, protect(function(oEvent)
                    oEvent:Check(not not fChecked());
                end));
            end

            if (fAction) then
                dFrame:Connect(nID, wx.wxEVT_COMMAND_MENU_SELECTED, protect(function(...)
                    fAction(...);
                    if (fChecked) then oItem:Check(not not fChecked()); end
                end));
            end
        end

        tMenus[sTitle] = oMenu;
        oMenuBar:Append(oMenu, sTitle);
    end

    addMenu("File", {{"Export"}, {"Exit", function() dFrame:Close(); end}});
    local function selectItem(sMessage, sTitle, tNames, sStateName)
        local dDialog    = wx.wxDialog(dFrame, wx.wxID_ANY, sTitle);
        local oState     = WindowState.bind(dDialog, sStateName);
        local oLayout    = wx.wxBoxSizer(wx.wxVERTICAL);
        local oMessage   = wx.wxStaticText(dDialog, wx.wxID_ANY, sMessage);
        local oList      = wx.wxListBox(dDialog, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, tNames);
        local oDisplay   = wx.wxDisplay(0);
        local oScreen    = oDisplay:GetClientArea();
        local nWidth     = 1;
        local nRowHeight = 1;

        for _, sName in ipairs(tNames) do
            local nTextWidth, nTextHeight = oList:GetTextExtent(sName);
            nWidth = math.max(nWidth, nTextWidth);
            nRowHeight = math.max(nRowHeight, nTextHeight);
        end

        oList:SetMinSize(wx.wxSize(math.min(nWidth + 40, math.max(100, oScreen:GetWidth() - 64)), (nRowHeight + 6) * math.min(#tNames, 10) + 12));
        oList:SetSelection(0);
        oLayout:Add(oMessage, 0, wx.wxALL, 12);
        oLayout:Add(oList, 1, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 12);
        oLayout:Add(dDialog:CreateButtonSizer(wx.wxOK + wx.wxCANCEL), 0, wx.wxEXPAND + wx.wxALL, 12);
        dDialog:SetSizerAndFit(oLayout);
        oList:Connect(wx.wxEVT_COMMAND_LISTBOX_DOUBLECLICKED, function()
            dDialog:EndModal(wx.wxID_OK);
        end);

        local oSize = dDialog:GetSize();
        local nX, nY;

        if (dFrame:IsIconized() or not dFrame:IsShown()) then
            nX = oScreen:GetX() + (oScreen:GetWidth() - oSize:GetWidth()) / 2;
            nY = oScreen:GetY() + (oScreen:GetHeight() - oSize:GetHeight()) / 2;
        else
            local oPosition = dFrame:GetPosition();
            local oParentSize = dFrame:GetSize();
            nX = oPosition:GetX() + (oParentSize:GetWidth() - oSize:GetWidth()) / 2;
            nY = oPosition:GetY() + (oParentSize:GetHeight() - oSize:GetHeight()) / 2;
        end

        dDialog:Move(math.floor(nX), math.floor(nY));
        oDisplay:delete();
        local nResult = dDialog:ShowModal();
        local nSelection = nResult == wx.wxID_OK and oList:GetSelection() or -1;
        oState.close();
        dDialog:Destroy();

        return nSelection;
    end
    local function saveCardSet()
        tDataSession.save();
        dFrame:SetStatusText("Card set saved.", 0);
    end

    local function allowDiscard()
        if (not tDataSession.dirty) then
            return true;
        end

        local nAnswer = wx.wxMessageBox("You have unsaved card-set changes. Save them now?", APP_NAME, wx.wxYES_NO + wx.wxCANCEL + wx.wxICON_QUESTION, dFrame);

        if (nAnswer == wx.wxYES) then
            saveCardSet();

            return true;
        end

        return nAnswer == wx.wxNO;
    end

    local function selectGame()
        Game.Refresh();
        local tGames    = Game.GetAll();
        local tNames    = {};

        for nIndex, oGame in ipairs(tGames) do
            tNames[nIndex] = oGame.GetName();
        end

        if (#tGames == 0) then
            wx.wxMessageBox("No games were found in the configured Games folder. Check the log for discovery errors.", APP_NAME, wx.wxOK + wx.wxICON_INFORMATION, dFrame);

            return;
        end

        local nSelection = selectItem("Select a game to load.", "Load Game", tNames, "LoadGame");

        if (nSelection >= 0) then
            if (not allowDiscard()) then return; end
            if (dStyleWindow and not dStyleWindow.close()) then return; end
            if (dSourceWindow and not dSourceWindow.close()) then return; end
            local oGame = tGames[nSelection + 1];
            if (dWikiWindow and not dWikiWindow.close()) then return; end
            Game.Activate(oGame);
            bDataLoaded = false;
            tDataSession.setData({}, {}, {}, {});
            showPage("Welcome");
            dFrame:SetTitle(APP_NAME.." - "..oGame.GetName());
            dFrame:SetStatusText("Game loaded: "..oGame.GetName(), 0);
        end
    end

    local function loadCardSet(oCardSet)
        if (not allowDiscard()) then return; end
        if (dSourceWindow and not dSourceWindow.close()) then return; end
        local tData = ProcSys.LoadCardSet(oCardSet, function(nRow, nTotal)
            dFrame:SetStatusText("Processing row "..nRow.." of "..nTotal, 0);
            dFrame:GetStatusBar():Update();
        end);
        nCardWidth, nCardHeight = oCardSet.GetCardWidth(), oCardSet.GetCardHeight();
        tState.face = "front";
        bDataLoaded = true;
        showPage("Editor");
        dFrame:SetStatusText("Card set: "..oCardSet.GetName().." - "..#tData.base.." rows", 0);
        dBaseWindow = dBaseWindow or dBaseData.create(tDataSession);
        dFinalWindow = dFinalWindow or dFinalData.create(tDataSession);
        if (WindowState.isOpen("BaseData") ~= false) then dBaseWindow.show(); end
        if (WindowState.isOpen("FinalData") ~= false) then dFinalWindow.show(); end
        return tData;
    end

    tDataSession.options.onMetadataChanged = function(oCardSet)
        nCardWidth, nCardHeight = oCardSet.GetCardWidth(), oCardSet.GetCardHeight();
        Forge.SetFace(tState.face);
        dFrame:SetStatusText("Card set: "..oCardSet.GetName().." - "..#tDataSession.base.." rows", 0);
    end

    local function selectCardSet()
        local oGame = assert(Game.GetActive(), "Load a game first.");
        local tSets = oGame.GetAllCardSets();
        local tNames = {};
        for nIndex, oCardSet in ipairs(tSets) do tNames[nIndex] = oCardSet.GetName(); end
        if (#tSets == 0) then
            wx.wxMessageBox("This game has no card sets.", APP_NAME, wx.wxOK + wx.wxICON_INFORMATION, dFrame);
            return;
        end
        local nSelection = selectItem("Select a card set to load.", "Load Card Set", tNames, "LoadCardSet");
        if (nSelection >= 0) then loadCardSet(tSets[nSelection + 1]); end
    end

    addMenu("Game", {{"New"}, {"Load", selectGame}, {"Browse"}});
    addMenu("Card Set", {{"New"}, {"Load", selectCardSet}, {"Save", saveCardSet}, {"Browse"}, {"Edit CSV"}, {"Edit Source...", function()
        assert(bDataLoaded, "Load a card set first.");
        if (dSourceWindow) then dSourceWindow.show(); return; end
        dSourceWindow = require("Windows.SourceEditor").create(dFrame, {
            {name = FILESPEC_CARDSET_DRAW.Full, path = FS.CardSet.Draw, kind = "lua"},
            {name = FILESPEC_CARDSET_ROWPROC.Full, path = FS.CardSet.RowProc, kind = "lua"},
            {name = FILESPEC_CARDSET_CODECOLUMMS.Full, path = FS.CardSet.CodeColumns, kind = "text"},
            {name = FILESPEC_CARDSET_INFO.Full, path = FS.CardSet.Info, kind = "ini"},
        }, "Source Editor", {onClose = function() dSourceWindow = nil; end});
    end}});
    local bAutomaticCSV = INIFile.GetValue(FS.AppCFG, "Settings", "ExternalCSVChanges") == "automatic";
    tDataSession.options.onExternalCSV = function(bUnsaved)
        if (bAutomaticCSV) then return true end
        local sMessage = "The CSV changed outside Card Forge Studio. Reload it now?";
        if (bUnsaved) then sMessage = sMessage.."\\n\\nReloading will discard your unsaved Base Data edits."; end
        return wx.wxMessageBox(sMessage, APP_NAME, wx.wxYES_NO + wx.wxICON_QUESTION, dFrame) == wx.wxYES;
    end

    local function toggleAutomaticCSV()
        local bAutomatic = not bAutomaticCSV;
        INIFile.SetValue(FS.AppCFG, "Settings", "ExternalCSVChanges", bAutomatic and "automatic" or "prompt");
        bAutomaticCSV = bAutomatic;
        tMenuItems["Options:Automatically Reload External CSV Changes"].item:Check(bAutomaticCSV);
    end

    addMenu("Options", {{"Automatically Reload External CSV Changes", toggleAutomaticCSV, "check",}, {"Utility Overlay", function() tState.overlay = not tState.overlay; dCanvas:Refresh(false); end, "check", function() return tState.overlay; end},
        {"Horizontal Centerline", function() tState.horizontalCenter = not tState.horizontalCenter; dCanvas:Refresh(false); end, "check", function() return tState.horizontalCenter; end},
        {"Vertical Centerline", function() tState.verticalCenter = not tState.verticalCenter; dCanvas:Refresh(false); end, "check", function() return tState.verticalCenter; end}});
    tMenuItems["Options:Automatically Reload External CSV Changes"].item:Check(bAutomaticCSV);
    addMenu("Tools", {{"Rebuild Dox"}, {"Style Editor", function()
        assert(Game.GetActive(), "Load a game first.");
        if (dStyleWindow) then dStyleWindow.show(); return; end
        dStyleWindow = require("Windows.StyleEditor").create(dFrame, FS.Game.Styles, {
            onClose = function() dStyleWindow = nil; end,
        });
    end}, {"Game Wiki", function()
        assert(Game.GetActive(), "Load a game first.");
        if (dWikiWindow) then dWikiWindow.show(); return; end
        dWikiWindow = require("Windows.Wiki").create(dFrame, FS.Game.Wiki, {
            onClose = function() dWikiWindow = nil; end,
        });
    end}, {"Mechanics Viewer"}});
    addMenu("Window", {{"Base Data", function()
        dBaseWindow = dBaseWindow or dBaseData.create(tDataSession);
        dBaseWindow.show();
    end, "check", function() return dBaseWindow ~= nil and dBaseWindow.frame:IsShown(); end}, {"Final Data", function()
        dFinalWindow = dFinalWindow or dFinalData.create(tDataSession);
        dFinalWindow.show();
    end, "check", function() return dFinalWindow ~= nil and dFinalWindow.frame:IsShown(); end}, {"Log", dLog.Show, "check", dLog.IsShown}});
    local function openDocument(pFile)
        assert(wx.wxFileExists(pFile), "Documentation file is unavailable: "..pFile);
        local oFile = wx.wxFileName(pFile);
        local sURL  = wx.wxFileSystem.FileNameToURL(oFile);
        oFile:delete();
        assert(wx.wxLaunchDefaultBrowser(sURL), "Could not open the documentation browser.");
    end

    addMenu("Help", {
        {"Game Documentation", function()
            assert(Game.GetActive(), "Load a game first.");
            openDocument(FS.Game.Docs.."/"..DOX_EXPORT_FILENAME..".html");
        end,},
        {"Tutorials", function()
            local Tutorial = require("Tutorial");
            Tutorial.Init();
            openDocument(Tutorial.PATH_INDEX);
        end,},
        {"About", function() require("Windows.Main.About").show(dFrame); end,},
    });

    showPage = function(sName)
        assert(sName == "Welcome" or sName == "Editor", "Unknown Main page.");
        sPage = sName;
        oControls:ShowItems(sPage == "Editor");
        oWelcomeLinks:ShowItems(sPage == "Welcome");

        for sPath, tMenuItem in pairs(tMenuItems) do
            local bAvailable = type(tMenuItem.action) == "function";

            if (sPath:match("^Options:") and sPath ~= "Options:Automatically Reload External CSV Changes") then
                bAvailable = bAvailable and sPage == "Editor";
            end

            if (sPath == "Card Set:Load" or sPath == "Help:Game Documentation" or sPath == "Tools:Style Editor" or sPath == "Tools:Game Wiki") then bAvailable = not not Game.GetActive(); end
            if (sPath == "Card Set:Edit Source...") then bAvailable = bDataLoaded; end
            if (sPath == "Card Set:Save") then bAvailable = tDataSession.dirty and not tDataSession.editing; end

            if (sPath == "Window:Base Data" or sPath == "Window:Final Data") then
                bAvailable = sPage == "Editor" and #tDataSession.headers > 0;
            end

            tMenuItem.item:Enable(bAvailable);
        end

        dFrame:SetStatusText(sPage, 0);
        dFrame:SetStatusText("", 1);
        dFrame:SetStatusText("", 2);
        dPanel:Layout();
        resizeCanvas();
    end

    tDataSession.subscribe(function()
        tMenuItems["Card Set:Save"].item:Enable(tDataSession.dirty and not tDataSession.editing);
    end);

    local oRenderTimer = wx.wxTimer(dFrame, wx.wxNewId());
    dFrame:Connect(oRenderTimer:GetId(), wx.wxEVT_TIMER, protect(function()
        ProcSys.OnTimer();
        local bRendered = false;
        if (Forge and bDataLoaded and not tDataSession.editing) then
            local bOK, vResult = xpcall(Forge.OnTimer, debug.traceback);
            if (bOK) then bRendered = vResult;
            else require("Errors").report(vResult, true); end
        end
        if (bRendered) then
            local oBitmap = Forge.GetBitmap();
            if (oBitmap) then
                oImage = oBitmap:ConvertToImage();
                resizeCanvas();
            end
        end
    end));
    oRenderTimer:Start(FORGE_REDRAW_TIMER_INTERVAL);

    dFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        if (oEvent:CanVeto()) then
            local bOK, bContinue = pcall(allowDiscard);

            if (not bOK or not bContinue) then
                oEvent:Veto();
                if (not bOK) then reportError(bContinue); end

                return;
            end
        end

        if (dStyleWindow and not dStyleWindow.close()) then
            if (oEvent:CanVeto()) then oEvent:Veto(); end
            return;
        end

        if (dSourceWindow and not dSourceWindow.close()) then
            if (oEvent:CanVeto()) then oEvent:Veto(); end
            return;
        end
        if (dWikiWindow and not dWikiWindow.close()) then
            if (oEvent:CanVeto()) then oEvent:Veto(); end
            return;
        end
        oWindowState.close();
        oRenderTimer:Stop();
        ProcSys.Shutdown();
        if (Forge) then Forge.Release(); end
        if (dBaseWindow) then dBaseWindow.close(); end
        if (dFinalWindow) then dFinalWindow.close(); end
        dLog.Close();
        oEvent:Skip();
    end);

    dFrame:SetMenuBar(oMenuBar);
    showPage("Welcome");
    dFrame:Show(true);
    dPanel:Layout();
    resizeCanvas();
    if (WindowState.isOpen("Log")) then dLog.Show(); end
    Log.Note("Main window ready: Welcome.");

    return {frame = dFrame, canvas = dCanvas, state = tState, view = tView, menus = tMenus,
        applyClick = applyClick, resize = resizeCanvas, copyText = copyText,
        showPage = showPage, getPage = function() return sPage; end, menuItems = tMenuItems,
        dataSession = tDataSession, loadCardSet = loadCardSet};
end

if (... == nil) then
    Main.create();
    wx.wxGetApp():MainLoop();
    os.exit(0);
end

return Main;
