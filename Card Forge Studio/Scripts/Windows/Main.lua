-- Native editor window. Studio and game services are connected by callbacks.
-- TODO Required window persistence: save position and size on move, resize, and
-- close; restore them when this window is reopened. Apply to every application window.
local _sSource = debug.getinfo(1, "S").source;
local _pWindows = assert(_sSource:match("^@(.+[/\\])"));
local _pRuntime = _pWindows.."../../";

package.cpath = _pRuntime.."Bin/?.dll;"..package.cpath;
local wx = require("wx");
local Main = {};
local dLog = require("Windows.Log");
local Log = require("Log");
local Welcome = require("Windows.Main.Welcome");
local DataSession = require("Windows.DataSession");
local dBaseData = require("Windows.BaseData");
local dFinalData = require("Windows.FinalData");

function Main.create(tOptions)
    tOptions = tOptions or {};
    wx.wxInitAllImageHandlers();
    local oImage = wx.wxImage(tOptions.imagePath or (_pRuntime.."card-test.png"), wx.wxBITMAP_TYPE_PNG);
    assert(oImage:IsOk(), "Editor preview image could not be loaded.");
    local nCardWidth, nCardHeight = oImage:GetWidth(), oImage:GetHeight();
    local sTitle = "Card Forge Studio";

    if (tOptions.gameName) then
        sTitle = sTitle.." - "..tOptions.gameName;
    end

    local dFrame = wx.wxFrame(wx.NULL, wx.wxID_ANY, sTitle, wx.wxDefaultPosition, wx.wxSize(760, 940));
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
    local dBaseWindow, dFinalWindow;
    local showPage;
    local bDataLoaded = false;
    ProcSys.BindSession(tDataSession);

    oBack:Enable(type(tOptions.onFaceChanged) == "function");
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
        Log.Error(sError);
        dLog.Show();
        local hLog = assert(io.open(_pRuntime.."editor-errors.log", "a"));
        hLog:write(sError.."\n");
        hLog:close();
        wx.wxMessageBox(sError, "Card Forge Studio - Error", wx.wxOK + wx.wxICON_ERROR, dFrame);
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
        oScaled = wx.wxBitmap(oImage:Scale(tView.width, tView.height, wx.wxIMAGE_QUALITY_HIGH));
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

        if (bDataLoaded) then
            oDC:SetTextForeground(wx.wxColour(235, 235, 235));
            oDC:DrawText("Card set loaded. Card rendering is not connected yet.", 16, 16);
            oDC:delete();
            return;
        end

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
        elseif (sFace == "front") then
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
    local oWelcomeLinks = tWelcome.addLinks(dPanel, oLayout, protect);

    local function addMenu(sTitle, tItems)
        local oMenu = wx.wxMenu();

        for _, tItem in ipairs(tItems) do
            local nID = wx.wxNewId();
            local oItem = oMenu:Append(nID, tItem[1]);
            local fAction = tItem[2];
            tMenuItems[sTitle..":"..tItem[1]] = {item = oItem, action = fAction};
            oItem:Enable(type(fAction) == "function");

            if (fAction) then
                dFrame:Connect(nID, wx.wxEVT_COMMAND_MENU_SELECTED, protect(fAction));
            end
        end

        tMenus[sTitle] = oMenu;
        oMenuBar:Append(oMenu, sTitle);
    end

    addMenu("File", {{"Export"}, {"Exit", function() dFrame:Close(); end}});
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

        local nSelection = wx.wxGetSingleChoiceIndex("Select a game to load.", "Load Game", tNames, dFrame);

        if (nSelection >= 0) then
            assert(not tDataSession.dirty, "Close and reopen the application before discarding unsaved test edits.");
            local oGame = tGames[nSelection + 1];
            Game.Activate(oGame);
            bDataLoaded = false;
            tDataSession.setData({}, {}, {}, {});
            showPage("Welcome");
            dFrame:SetTitle(APP_NAME.." - "..oGame.GetName());
            dFrame:SetStatusText("Game loaded: "..oGame.GetName(), 0);
        end
    end

    local function loadCardSet(oCardSet)
        assert(not tDataSession.dirty, "Close and reopen the application before discarding unsaved test edits.");
        local tData = ProcSys.LoadCardSet(oCardSet, function(nRow, nTotal)
            dFrame:SetStatusText("Processing row "..nRow.." of "..nTotal, 0);
            dFrame:GetStatusBar():Update();
        end);
        bDataLoaded = true;
        showPage("Editor");
        dFrame:SetStatusText("Card set: "..oCardSet.GetName().." - "..#tData.base.." rows", 0);
        dBaseWindow = dBaseWindow or dBaseData.create(tDataSession);
        dFinalWindow = dFinalWindow or dFinalData.create(tDataSession);
        dBaseWindow.show();
        dFinalWindow.show();
        return tData;
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
        local nSelection = wx.wxGetSingleChoiceIndex("Select a card set to load.", "Load Card Set", tNames, dFrame);
        if (nSelection >= 0) then loadCardSet(tSets[nSelection + 1]); end
    end

    addMenu("Game", {{"New"}, {"Load", selectGame}, {"Browse"}});
    addMenu("Card Set", {{"New"}, {"Load", selectCardSet}, {"Save"}, {"Browse"}, {"Edit CSV"}});
    addMenu("Filters", {{"Filters"}});
    addMenu("Options", {{"Utility Overlay", function() tState.overlay = not tState.overlay; dCanvas:Refresh(false); end},
        {"Horizontal Centerline", function() tState.horizontalCenter = not tState.horizontalCenter; dCanvas:Refresh(false); end},
        {"Vertical Centerline", function() tState.verticalCenter = not tState.verticalCenter; dCanvas:Refresh(false); end}});
    addMenu("Tools", {{"Rebuild Dox"}, {"Style Editor"}, {"Mechanics Viewer"}});
    addMenu("Window", {{"Base Data", function()
        dBaseWindow = dBaseWindow or dBaseData.create(tDataSession);
        dBaseWindow.show();
    end}, {"Final Data", function()
        dFinalWindow = dFinalWindow or dFinalData.create(tDataSession);
        dFinalWindow.show();
    end}, {"Log", dLog.Show}});
    addMenu("Help", {{"Game Documentation"}, {"Draw API"}, {"Tutorials"}, {"About"}});

    showPage = function(sName)
        assert(sName == "Welcome" or sName == "Editor", "Unknown Main page.");
        sPage = sName;
        -- TODO Restore card controls when the real renderer is connected.
        oControls:ShowItems(sPage == "Editor" and not bDataLoaded);
        oWelcomeLinks:ShowItems(sPage == "Welcome");

        for sPath, tMenuItem in pairs(tMenuItems) do
            local bAvailable = type(tMenuItem.action) == "function";

            if (sPath:match("^Options:")) then
                bAvailable = bAvailable and sPage == "Editor" and not bDataLoaded;
            end

            if (sPath == "Card Set:Load") then bAvailable = not not Game.GetActive(); end

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

    dFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
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





