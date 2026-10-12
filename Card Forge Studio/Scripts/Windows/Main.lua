--[[!
@fqxn CFS.Windows.Main
@desc
<section aria-label="Main overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Main</h2><p style="font-size:1.15rem;margin:0">The main Studio window connects your project, preview, and editing tools.</p></div>
<h3>How it fits into your work</h3><p>Load a game and card set, open linked editors and data windows, and inspect cards in Forge.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.Game">Game</a></h3><p style="margin:0">A game is the home for a whole project: its name, shared settings, and collection of card sets.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys">Processing System</a></h3><p style="margin:0">ProcSys keeps project files, card values, and the preview working together as you edit.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Forge">Forge</a></h3><p style="margin:0">Forge is the visual workbench that turns selected card data and drawing instructions into artwork.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Options">Options</a></h3><p style="margin:0">Options puts application preferences and project information in one place.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.BaseData">BaseData</a></h3><p style="margin:0">Base Data is the table of values you actually edit.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.FinalData">FinalData</a></h3><p style="margin:0">Final Data shows the results after card values and scripts have been processed.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">The main window coordinates tools; individual services own data processing, rendering, and saving.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

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

--[[!
@fqxn CFS.Windows.Main.Functions.create
@pulsarlua function Main.create
@desc Creates Studio menus, Forge preview, linked data windows, editor launch actions, and application timer processing.
@param any tOptions Options table.
!]]
function Main.create(tOptions)
    tOptions = tOptions or {};
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
    for sKey, sSetting in pairs({backgroundColor = "ForgeBackgroundColor", canvasColor = "ForgeCanvasColor", horizontalColor = "HorizontalGuideColor", verticalColor = "VerticalGuideColor"}) do
        local sColor = INIFile.GetValue(FS.AppCFG, "Settings", sSetting);
        if (sColor:match("^#%x%x%x%x%x%x$")) then tState[sKey] = sColor; end
    end
    tState.horizontalCenterColor = tState.horizontalColor or "#FFC800";
    tState.verticalCenterColor = tState.verticalColor or "#FFC800";
    for sKey, sSetting in pairs({horizontalCenterColor = "HorizontalCenterColor", verticalCenterColor = "VerticalCenterColor"}) do
        local sColor = INIFile.GetValue(FS.AppCFG, "Settings", sSetting);
        if (sColor:match("^#%x%x%x%x%x%x$")) then tState[sKey] = sColor; end
    end
    for sKey, sSetting in pairs({overlay = "UtilityOverlay", horizontalCenter = "HorizontalCenterline", verticalCenter = "VerticalCenterline"}) do
        local sValue = INIFile.GetValue(FS.AppCFG, "Settings", sSetting);
        if (sValue == "1" or sValue == "0") then tState[sKey] = sValue == "1"; end
    end
    local tView = {x = 0, y = 0, width = 1, height = 1};
    local oScaled;
    local tMenus = {};
    local tMenuItems = {};
    local tWelcome = Welcome.create(_pRuntime);
    local sPage = "Welcome";
    local tDataSession = tOptions.dataSession or DataSession.create();
    local dBaseWindow, dFinalWindow, dStyleWindow, dSourceWindow, dGameEditorWindow, dWikiWindow, dTutorialsWindow, dManualWindow;
    local showPage;
    local bDataLoaded = false;
    local sActiveCardSetName = "";
    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.tDataSession_options_getCardSetName
    @desc Returns the active card-set display name or an empty string before loading.
    @vis private
    !]]
    tDataSession.options.getCardSetName = function() return bDataLoaded and sActiveCardSetName or ""; end
    ProcSys.BindSession(tDataSession);

    oBack:Enable(true);
    oControls:Add(oFront, 0, wx.wxALL, 4);
    oControls:Add(oBack, 0, wx.wxALL, 4);
    oControls:Add(wx.wxStaticLine(dPanel, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(2, 24), wx.wxLI_VERTICAL), 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxLEFT + wx.wxRIGHT, 8);
    local oGuides = wx.wxButton(dPanel, wx.wxID_ANY, "Options");
    oControls:Add(oGuides, 0, wx.wxALL, 4);
    local dCoordinates = wx.wxPanel(dPanel, wx.wxID_ANY);
    local oCoordinateLayout = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oCoordinates = wx.wxStaticText(dCoordinates, wx.wxID_ANY, "-, -", wx.wxDefaultPosition, wx.wxSize(96, -1), wx.wxALIGN_RIGHT + wx.wxST_NO_AUTORESIZE);
    local oNegativeCoordinates = wx.wxStaticText(dCoordinates, wx.wxID_ANY, "-, -", wx.wxDefaultPosition, wx.wxSize(96, -1), wx.wxALIGN_LEFT + wx.wxST_NO_AUTORESIZE);
    local oCoordinateDivider = wx.wxStaticLine(dCoordinates, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(2, 24), wx.wxLI_VERTICAL);
    oCoordinateLayout:Add(oCoordinates, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxRIGHT, 4);
    oCoordinateLayout:Add(oCoordinateDivider, 0, wx.wxALIGN_CENTER_VERTICAL);
    oCoordinateLayout:Add(oNegativeCoordinates, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxLEFT, 4);
    dCoordinates:SetSizerAndFit(oCoordinateLayout);
    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.positionCoordinates
    @desc Positions the coordinate overlay within the Forge panel.
    @vis private
    !]]
    local function positionCoordinates()
        local nWidth = dCoordinates:GetSize():GetWidth();
        local nX = math.floor((dPanel:GetClientSize():GetWidth() - nWidth) / 2);
        local nY = nX < oGuides:GetPosition():GetX() + oGuides:GetSize():GetWidth() + 4 and 36 or 4;
        if (oControls:GetMinSize():GetHeight() ~= nY + 28) then
            oControls:SetMinSize(wx.wxSize(-1, nY + 28)); dPanel:Layout();
        end
        dCoordinates:Move(nX, nY);
        dCoordinates:Raise();
    end
    dPanel:Connect(wx.wxEVT_SIZE, function(oEvent) positionCoordinates(); oEvent:Skip(); end);
    dCoordinates:Hide();

    oLayout:Add(oControls, 0, wx.wxEXPAND);
    oLayout:Add(dCanvas, 1, wx.wxEXPAND);
    dPanel:SetSizer(oLayout);
    oControls:ShowItems(false);
    dCanvas:SetBackgroundStyle(wx.wxBG_STYLE_PAINT);
    dFrame:CreateStatusBar(3);
    dFrame:SetStatusText("Welcome", 0);
    dFrame:SetMinClientSize(wx.wxSize(360, 240));

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.reportError
    @desc Sends an action failure to the shared error-reporting service.
    @param any sError Error.
    @vis private
    !]]
    local function reportError(sError)
        require("Errors").report(sError);
    end

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.protect
    @desc Wraps a main-window action and reports failures without propagating them into native event dispatch.
    @param any fCallback Callback.
    @vis private
    !]]
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

    oGuides:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, protect(function()
        require("Windows.Options").show(dFrame, {
            category = "Forge", state = tState,
            game = Game.GetActive(), cardSet = ProcSys.GetActiveCardSet(),
            --[[!
            @fqxn CFS.Windows.Main.Private.Functions.changed
            @desc Refreshes relevant preview or loading preferences after accepted option changes.
            @vis private
            !]]
            changed = function()
                if (Forge) then Forge.RequestCardRedraw(); end
                dCanvas:Refresh(false);
            end,
        });
    end));

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.resizeCanvas
    @desc Computes preview scale and placement from current canvas and card dimensions.
    @vis private
    !]]
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

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.drawCanvas
    @desc Paints the welcome view or card preview and enabled guides.
    @vis private
    !]]
    local function drawCanvas()
        if (sPage == "Welcome") then
            tWelcome.draw(dCanvas);

            return;
        end

        local tPens = {};
        --[[!
        @fqxn CFS.Windows.Main.Private.Functions.pen
        @desc Creates and tracks a native pen for the current canvas paint pass.
        @param any sColor Color.
        @vis private
        !]]
        local function pen(sColor)
            local oPen = wx.wxPen(wx.wxColour(sColor), 1, wx.wxPENSTYLE_SOLID);
            tPens[#tPens + 1] = oPen;
            return oPen;
        end
        local oDC = wx.wxPaintDC(dCanvas);
        oDC:SetBackground(wx.wxBrush(wx.wxColour(tState.backgroundColor or "#232323")));
        oDC:Clear();



        if (oScaled) then
            oDC:DrawBitmap(oScaled, tView.x, tView.y, true);
        end

        if (tState.overlay) then
            oDC:SetPen(pen(tState.horizontalColor or "#00DCFF"));

            if (tState.horizontalGuide) then
                local nY = tView.y + math.floor(tState.horizontalGuide * tView.height / nCardHeight);
                oDC:DrawLine(tView.x, nY, tView.x + tView.width, nY);
            end

            oDC:SetPen(pen(tState.verticalColor or "#00DCFF"));
            if (tState.verticalGuide) then
                local nX = tView.x + math.floor(tState.verticalGuide * tView.width / nCardWidth);
                oDC:DrawLine(nX, tView.y, nX, tView.y + tView.height);
            end

            oDC:SetPen(pen(tState.horizontalCenterColor));

            if (tState.horizontalCenter) then
                local nY = tView.y + math.floor(tView.height / 2);
                oDC:DrawLine(tView.x, nY, tView.x + tView.width, nY);
            end

            oDC:SetPen(pen(tState.verticalCenterColor));
            if (tState.verticalCenter) then
                local nX = tView.x + math.floor(tView.width / 2);
                oDC:DrawLine(nX, tView.y, nX, tView.y + tView.height);
            end
        end

        oDC:delete();

        for _, oPen in ipairs(tPens) do oPen:delete(); end
    end

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.copyText
    @desc Copies text to the native clipboard and reports an unavailable clipboard or failed transfer.
    @param any sText Text.
    @vis private
    !]]
    local function copyText(sText)
        local oClipboard = wx.wxClipboard.Get();
        assert(oClipboard:Open(), "Clipboard is unavailable.");
        local bOK = oClipboard:SetData(wx.wxTextDataObject(sText));
        oClipboard:Close();
        assert(bOK, "Could not copy coordinates.");
    end

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.applyClick
    @desc Formats clicked card coordinates and applies modifier-specific coordinate copying.
    @param any sButton Button.
    @param any nX X.
    @param any nY Y.
    @param any bControl Control.
    @param any bShift Shift.
    @vis private
    !]]
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

            end
        end

        dCanvas:Refresh(false);

        return sText;
    end

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.cardPosition
    @desc Converts mouse coordinates to card coordinates while the editor page is active.
    @param any oEvent Event.
    @vis private
    !]]
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
        oCoordinates:SetLabel(nX and (nX..", "..nY) or "-, -");
        oNegativeCoordinates:SetLabel(nX and ((nX - nCardWidth)..", "..(nY - nCardHeight)) or "-, -");
        dFrame:SetStatusText(nX and (nX..", "..nY) or "", 1);
        dFrame:SetStatusText(nX and ((nX - nCardWidth)..", "..(nY - nCardHeight)) or "", 2);
        oEvent:Skip();
    end));

    dCanvas:Connect(wx.wxEVT_LEAVE_WINDOW, function(oEvent)
        oCoordinates:SetLabel("-, -"); oNegativeCoordinates:SetLabel("-, -"); dFrame:SetStatusText("", 1); dFrame:SetStatusText("", 2); oEvent:Skip();
    end);

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

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.selectFace
    @desc Selects the card face through the caller callback or Forge and updates face controls.
    @param any sFace Face.
    @vis private
    !]]
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

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.addMenu
    @desc Builds a menu with separators and protected action callbacks.
    @param any sTitle Title.
    @param any tItems Items.
    @vis private
    !]]
    local function addMenu(sTitle, tItems)
        local oMenu = wx.wxMenu();

        for _, tItem in ipairs(tItems) do
            if (tItem[1] == false) then
                oMenu:AppendSeparator();
            else
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
        end

        tMenus[sTitle] = oMenu;
        oMenuBar:Append(oMenu, sTitle);
    end

    addMenu("File", {{"Exit", function() dFrame:Close(); end}});
    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.selectItem
    @desc Shows a native item-selection dialog with independent persistent window state.
    @param any sMessage Message.
    @param any sTitle Title.
    @param any tNames Names.
    @param any sStateName State name.
    @vis private
    !]]
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
    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.saveCardSet
    @desc Saves the shared data session and updates the main status text.
    @vis private
    !]]
    local function saveCardSet()
        tDataSession.save();
        dFrame:SetStatusText("Card set saved.", 0);
    end

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.allowDiscard
    @desc Offers saving, discarding, or cancellation before replacing an unsaved card set.
    @vis private
    !]]
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

    --[[!
    @fqxn CFS.Windows.Main.NewGame
    @desc Honors existing draft and child-window close checks before creating and activating a new game.
    !]]
    local function newGame()
        if (not allowDiscard()) then return; end
        if (dStyleWindow and not dStyleWindow.close()) then return; end
        if (dSourceWindow and not dSourceWindow.close()) then return; end
        if (dGameEditorWindow and not dGameEditorWindow.close()) then return; end
        if (dManualWindow and not dManualWindow.close()) then return; end
        if (dWikiWindow and not dWikiWindow.close()) then return; end

        local oGame = require("Windows.NewGame").Show(dFrame, Game.New);
        if (not oGame) then return; end

        Game.Activate(oGame);
        bDataLoaded = false;
        tDataSession.setData({}, {}, {}, {});
        showPage("Welcome");
        dFrame:SetTitle(APP_NAME.." - "..oGame.GetName());
        dFrame:SetStatusText("Game created: "..oGame.GetName(), 0);
    end


    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.selectGame
    @desc Refreshes available games and opens the styled game loader.
    @vis private
    !]]
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

        local nSelection = require("Windows.LoadGame").Show(dFrame, tGames);

        if (nSelection >= 0) then
            if (not allowDiscard()) then return; end
            if (dStyleWindow and not dStyleWindow.close()) then return; end
            if (dSourceWindow and not dSourceWindow.close()) then return; end
            if (dGameEditorWindow and not dGameEditorWindow.close()) then return; end
            local oGame = tGames[nSelection + 1];
            if (dManualWindow and not dManualWindow.close()) then return; end
            if (dWikiWindow and not dWikiWindow.close()) then return; end
            Game.Activate(oGame);
            bDataLoaded = false;
            tDataSession.setData({}, {}, {}, {});
            showPage("Welcome");
            dFrame:SetTitle(APP_NAME.." - "..oGame.GetName());
            dFrame:SetStatusText("Game loaded: "..oGame.GetName(), 0);
        end
    end

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.loadCardSet
    @desc Protects pending edits, closes the source editor if allowed, and loads the requested card set.
    @param any oCardSet Card set.
    @param any bDiscardChecked Discard checked.
    @vis private
    !]]
    local function loadCardSet(oCardSet, bDiscardChecked)
        if (not bDiscardChecked and not allowDiscard()) then return; end
        if (dSourceWindow and not dSourceWindow.close()) then return; end
        local tData = ProcSys.LoadCardSet(oCardSet, function(nRow, nTotal)
            dFrame:SetStatusText("Processing row "..nRow.." of "..nTotal, 0);
            dFrame:GetStatusBar():Update();
        end);
        nCardWidth, nCardHeight = oCardSet.GetCardWidth(), oCardSet.GetCardHeight();
        tState.face = "front";
        bDataLoaded = true;
        sActiveCardSetName = oCardSet.GetName();
        tDataSession.refresh();
        showPage("Editor");
        dFrame:SetStatusText("Card set: "..oCardSet.GetName().." - "..#tData.base.." rows", 0);
        dBaseWindow = dBaseWindow or dBaseData.create(tDataSession);
        dFinalWindow = dFinalWindow or dFinalData.create(tDataSession);
        if (WindowState.isOpen("BaseData") ~= false) then dBaseWindow.show(); end
        if (WindowState.isOpen("FinalData") ~= false) then dFinalWindow.show(); end
        return tData;
    end

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.tDataSession_options_onMetadataChanged
    @desc Refreshes the active set name, grid labels, and card dimensions after metadata changes.
    @param any oCardSet Card set.
    @vis private
    !]]
    tDataSession.options.onMetadataChanged = function(oCardSet)
        sActiveCardSetName = oCardSet.GetName();
        tDataSession.refresh();
        nCardWidth, nCardHeight = oCardSet.GetCardWidth(), oCardSet.GetCardHeight();
        Forge.SetFace(tState.face);
        dFrame:SetStatusText("Card set: "..oCardSet.GetName().." - "..#tDataSession.base.." rows", 0);
    end

    --[[!
    @fqxn CFS.Windows.Main.NewCardSet
    @desc Checks drafts before creation, refreshes game discovery and loads the new card set through the existing processing path.
    !]]
    local function newCardSet()
        local oGame = Game.GetActive();
        if (not oGame) then error("Load a game before creating a card set.", 2); end
        if (not allowDiscard()) then return; end
        if (dSourceWindow and not dSourceWindow.close()) then return; end

        local oCardSet = require("Windows.NewCardSet").Show(dFrame, function(sName, nWidth, nHeight)
            return require("CardSet").New(oGame.GetUUID(), sName, nWidth, nHeight);
        end);
        if (not oCardSet) then return; end

        oGame.UpdateCardSets();
        loadCardSet(oCardSet, true);
    end


    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.selectCardSet
    @desc Lists the active game's sets and opens the styled card-set loader.
    @vis private
    !]]
    local function selectCardSet()
        local oGame = assert(Game.GetActive(), "Load a game first.");
        local tSets = oGame.GetAllCardSets();
        local tNames = {};
        for nIndex, oCardSet in ipairs(tSets) do tNames[nIndex] = oCardSet.GetName(); end
        if (#tSets == 0) then
            wx.wxMessageBox("This game has no card sets.", APP_NAME, wx.wxOK + wx.wxICON_INFORMATION, dFrame);
            return;
        end
        local nSelection = require("Windows.LoadCardSet").Show(dFrame, tSets);
        if (nSelection >= 0) then loadCardSet(tSets[nSelection + 1]); end
    end

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.browse
    @desc Opens an existing folder through the operating system's default application.
    @param any pFolder Folder.
    @vis private
    !]]
    local function browse(pFolder)
        assert(wx.wxDirExists(pFolder), "The selected folder is unavailable.");
        assert(wx.wxLaunchDefaultApplication(pFolder), "Could not open the file explorer.");
    end
    local bAutomaticCSV = INIFile.GetValue(FS.AppCFG, "Settings", "ExternalCSVChanges") == "automatic";

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.info
    @desc Opens the requested metadata section in the main Options window.
    @param any sCategory Category.
    @vis private
    !]]
    local function info(sCategory)
        local oGame = Game.GetActive();

        require("Windows.Options").show(dFrame, {
            category = sCategory,
            game = oGame, cardSet = ProcSys.GetActiveCardSet(), state = tState,
            --[[!
            @fqxn CFS.Windows.Main.Private.Functions.changed2
            @desc Refreshes relevant preview or loading preferences after accepted option changes.
            @param any bAutomatic Automatic.
            @vis private
            !]]
            changed = function(bAutomatic)
                if (Forge) then Forge.RequestCardRedraw(); end
                bAutomaticCSV = bAutomatic;

                if (oGame) then
                    oGame.RefreshInfo();
                    dFrame:SetTitle(APP_NAME.." - "..oGame.GetName());
                end
                dCanvas:Refresh(false);
            end,
        });
    end


    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.closeCardSet
    @desc Honors pending-edit prompts, closes set tools and clears the set view while retaining the active game.
    @vis private
    !]]
    local function closeCardSet()
        if (tDataSession.exporting) then error("Wait for the export to finish before closing the card set."); end
        if (not allowDiscard()) then return false; end
        if (dSourceWindow and not dSourceWindow.close()) then return false; end
        ProcSys.CloseCardSet();
        bDataLoaded, sActiveCardSetName = false, "";
        tState.face = "front";
        if (dBaseWindow) then dBaseWindow.frame:Hide(); end
        if (dFinalWindow) then dFinalWindow.frame:Hide(); end
        showPage("Welcome");
        dFrame:SetStatusText("No card set loaded.", 0);
        return true;
    end

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.closeGame
    @desc Honors pending-edit prompts, closes game tools and returns to Welcome with no active project.
    @vis private
    !]]
    local function closeGame()
        if (tDataSession.exporting) then error("Wait for the export to finish before closing the game."); end
        if (not allowDiscard()) then return; end
        if (dSourceWindow and not dSourceWindow.close()) then return; end
        if (dStyleWindow and not dStyleWindow.close()) then return; end
        if (dGameEditorWindow and not dGameEditorWindow.close()) then return; end
        if (dManualWindow and not dManualWindow.close()) then return; end
        if (dWikiWindow and not dWikiWindow.close()) then return; end
        Game.Deactivate();
        bDataLoaded, sActiveCardSetName = false, "";
        tState.face = "front";
        if (dBaseWindow) then dBaseWindow.frame:Hide(); end
        if (dFinalWindow) then dFinalWindow.frame:Hide(); end
        showPage("Welcome");
        dFrame:SetTitle(APP_NAME);
        dFrame:SetStatusText("No game loaded.", 0);
    end

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.transferPackage
    @desc Opens game/card-set package dialogs, confirms inactive replacements and reports import/export failures through the existing error handler. Import never changes activation.
    @param string sAction Import or Export.
    @param string sKind Game or CardSet.
    @vis private
    !]]
    local function transferPackage(sAction, sKind)
        assert(not tDataSession.exporting, "Wait for the current export to finish.");
        if (sAction == "Export") then
            assert(not tDataSession.dirty, "Save the current card-set data before exporting a project package.");
        end
        local oGame = Game.GetActive();
        local oProject = sKind == "Game" and oGame or ProcSys.GetActiveCardSet();
        if (sAction == "Export") then assert(oProject, "Load the project before exporting it."); end
        if (sKind == "CardSet" and sAction == "Import") then assert(oGame, "Load the destination game first."); end
        local sExtension = sKind == "Game" and "cfsg" or "cfscs";
        local sName = sAction == "Export" and (oProject.GetName():gsub('[<>:"/\\|?*%c]', '_').."."..sExtension) or "";
        local oDialog = wx.wxFileDialog(dFrame, sAction.." "..sKind.." Package", "", sName,
            "CFS "..sKind.." packages (*."..sExtension..")|*."..sExtension,
            sAction == "Import" and (wx.wxFD_OPEN + wx.wxFD_FILE_MUST_EXIST) or wx.wxFD_SAVE);
        local nResult = oDialog:ShowModal(); local pFile = oDialog:GetPath(); oDialog:Destroy();
        if (nResult ~= wx.wxID_OK) then return; end
        if (sAction == "Export" and not pFile:lower():match("%."..sExtension.."$")) then pFile = pFile.."."..sExtension; end
        local service = require("ImportExport");
        local bOK, vResult, tReport = xpcall(function()
            if (sAction == "Export") then return service.Export(sKind, oProject, pFile); end
            return service.Import(pFile, sKind, oGame, function(sType, sProjectName)
                return wx.wxMessageBox("A "..sType.." with this ID already exists: "..sProjectName.."\n\nReplace its files? The previous files will be retained in a backup folder.", APP_NAME, wx.wxYES_NO + wx.wxNO_DEFAULT + wx.wxICON_WARNING, dFrame) == wx.wxYES;
            end);
        end, debug.traceback);
        if (not bOK) then error(vResult, 0); end
        if (sAction == "Import" and vResult) then
            wx.wxMessageBox("Import complete. Nothing was loaded automatically."..(#tReport > 0 and "\nRepairs, skipped items or backups are listed in the Log window." or ""), APP_NAME, wx.wxOK + wx.wxICON_INFORMATION, dFrame);
        end
    end

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.openDocument
    @desc Opens an existing documentation file through its native file URL.
    @param any pFile File.
    @vis private
    !]]
    local function openDocument(pFile)
        assert(wx.wxFileExists(pFile), "Documentation file is unavailable: "..pFile);
        local oFile = wx.wxFileName(pFile);
        local sURL  = wx.wxFileSystem.FileNameToURL(oFile);
        oFile:delete();
        assert(wx.wxLaunchDefaultBrowser(sURL), "Could not open the documentation browser.");
    end

    addMenu("Game", {
        {"New", newGame},
        {"Load", selectGame},
        {"Browse", function() browse(FS.Game.Root); end},
        {false},
        {"Info...", function() info("Game"); end},
        {false},
        {"Wiki", function()
        assert(Game.GetActive(), "Load a game first.");
        if (dWikiWindow) then dWikiWindow.show(); return; end
        dWikiWindow = require("Windows.Wiki").create(dFrame, FS.Game.Wiki, {
            gameRoot = FS.Game.Root,
            --[[!
            @fqxn CFS.Windows.Main.Private.Functions.onClose3
            @desc Clears the closed auxiliary-window reference so it can be created again.
            @vis private
            !]]
            onClose = function() dWikiWindow = nil; end,
        });
    end},
        {false},
        {"Manual", function()
        assert(Game.GetActive(), "Load a game first.");
        if (dManualWindow) then dManualWindow.show(); return; end
        dManualWindow = require("Windows.Manual").create(dFrame, FS.Game.Manual, {
            styles = FS.Game.Styles,
            onClose = function() dManualWindow = nil; end,
        });
    end},
        {"Style Editor", function()
        assert(Game.GetActive(), "Load a game first.");
        if (dStyleWindow) then dStyleWindow.show(); return; end
        dStyleWindow = require("Windows.StyleEditor").create(dFrame, FS.Game.Styles, {
            --[[!
            @fqxn CFS.Windows.Main.Private.Functions.onClose2
            @desc Clears the closed auxiliary-window reference so it can be created again.
            @vis private
            !]]
            onClose = function() dStyleWindow = nil; end,
        });
    end},
        {"Edit Source...", function()
        assert(Game.GetActive(), "Load a game first.");
        if (dGameEditorWindow) then dGameEditorWindow.show(); return; end
        dGameEditorWindow = require("Windows.GameEditor").create(dFrame, FS.Game.Scripts, FS.Game.ENV, FS.Game.CFG, {
            navigationFile = FS.Game.Info,
            --[[!
            @fqxn CFS.Windows.Main.Private.Functions.onClose
            @desc Clears the closed auxiliary-window reference so it can be created again.
            @vis private
            !]]
            onClose = function() dGameEditorWindow = nil; end,
        });
    end},
        {"Mechanics Viewer"},
        {false},
        {"Docs", function()
            assert(Game.GetActive(), "Load a game first.");
            openDocument(FS.Game.Docs.."/"..DOX_EXPORT_FILENAME..".html");
        end,},
        {"Rebuild Docs", function() require("Globals.ProcessDox")(); end},
        {false},
        {"Import Game...", function() transferPackage("Import", "Game"); end},
        {"Export Game...", function() transferPackage("Export", "Game"); end},
        {false},
        {"Close Game", closeGame},
    });
    addMenu("Card Set", {{"New", newCardSet}, {"Load", selectCardSet}, {"Browse", function() browse(FS.CardSet.Root); end}, {"Open CSV"}, {false}, {"Info...", function() info("Card Set"); end}, {"Edit Source...", function()
        assert(bDataLoaded, "Load a card set first.");
        if (dSourceWindow) then dSourceWindow.show(); return; end
        dSourceWindow = require("Windows.CardSetEditor").create(dFrame, {
            {name = FILESPEC_CARDSET_DRAW.Full, path = FS.CardSet.Draw, kind = "lua"},
            {name = FILESPEC_CARDSET_DRAWBACK.Full, path = FS.CardSet.DrawBack, kind = "lua"},
            {name = FILESPEC_CARDSET_ROWPROC.Full, path = FS.CardSet.RowProc, kind = "lua"},
            {name = FILESPEC_CARDSET_CODECOLUMMS.Full, path = FS.CardSet.CodeColumns, kind = "text"},
        }, "Card Set Source Editor", {notesFile = FS.CardSet.Root.."/Notes.txt", navigationFile = FS.CardSet.Info, onClose = function() dSourceWindow = nil; end});
    end}, {false}, {"Import Card Set...", function() transferPackage("Import", "CardSet"); end}, {"Export Card Set...", function() transferPackage("Export", "CardSet"); end}, {false}, {"Close Card Set", closeCardSet}});
    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.tDataSession_options_onExternalCSV
    @desc Applies automatic reload preference or asks before replacing externally changed CSV data.
    @param any bUnsaved Unsaved.
    @vis private
    !]]
    tDataSession.options.onExternalCSV = function(bUnsaved)
        if (bAutomaticCSV) then return true end
        local sMessage = "The CSV changed outside Card Forge Studio. Reload it now?";
        if (bUnsaved) then sMessage = sMessage.."\\n\\nReloading will discard your unsaved Base Data edits."; end
        return wx.wxMessageBox(sMessage, APP_NAME, wx.wxYES_NO + wx.wxICON_QUESTION, dFrame) == wx.wxYES;
    end

    addMenu("Tools", {});
    local nOptionsID = wx.wxNewId();
    local oOptionsItem = tMenus["Tools"]:Append(nOptionsID, "Options...");
    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.openOptions
    @desc Opens application options with the active game and card-set context.
    @vis private
    !]]
    local function openOptions()
        local oGame = Game.GetActive();
        require("Windows.Options").show(dFrame, {
            game = oGame, cardSet = ProcSys.GetActiveCardSet(), state = tState,
            --[[!
            @fqxn CFS.Windows.Main.Private.Functions.changed3
            @desc Refreshes relevant preview or loading preferences after accepted option changes.
            @param any bAutomatic Automatic.
            @param any sName Name.
            @vis private
            !]]
            changed = function(bAutomatic, sName)
                bAutomaticCSV = bAutomatic;
                if (Forge) then Forge.RequestCardRedraw(); end
                if (oGame and sName) then oGame.RefreshInfo(); dFrame:SetTitle(APP_NAME.." - "..oGame.GetName()); end
                dCanvas:Refresh(false);
            end,
        });
    end
    tMenuItems["Tools:Options..."] = {item = oOptionsItem, action = openOptions};
    dFrame:Connect(nOptionsID, wx.wxEVT_COMMAND_MENU_SELECTED, protect(openOptions));
    addMenu("Window", {{"Base Data", function()
        dBaseWindow = dBaseWindow or dBaseData.create(tDataSession);
        dBaseWindow.show();
    end, "check", function() return dBaseWindow ~= nil and dBaseWindow.frame:IsShown(); end}, {"Final Data", function()
        dFinalWindow = dFinalWindow or dFinalData.create(tDataSession);
        dFinalWindow.show();
    end, "check", function() return dFinalWindow ~= nil and dFinalWindow.frame:IsShown(); end}, {"Log", dLog.Show, "check", dLog.IsShown}});
    addMenu("Help", {
        {"API Docs", function()
            openDocument(APP_PATH.."/Docs/index.html");
        end,},
        {"Tutorials", function()
            if (dTutorialsWindow) then dTutorialsWindow.show(); return; end
            dTutorialsWindow = require("Windows.Tutorials").create(dFrame, {
                onClose = function() dTutorialsWindow = nil; end,
            });
        end,},
        {false},
        {"Feedback", function()
            assert(wx.wxLaunchDefaultBrowser(APP_GITHUB.."/issues"), "Could not open the GitHub Issues page.");
        end,},
        {false},
        {"Patreon", function()
            assert(wx.wxLaunchDefaultBrowser(APP_PATREON), "Could not open Patreon.");
        end,},
        {"GitHub", function()
            assert(wx.wxLaunchDefaultBrowser(APP_GITHUB), "Could not open GitHub.");
        end,},
        {"Website", function()
            assert(wx.wxLaunchDefaultBrowser("https://cardforge.studio"), "Could not open the Card Forge Studio website.");
        end,},
        {false},
        {"License", function() require("Windows.License").show(dFrame); end,},
        {"About", function() require("Windows.Main.About").show(dFrame); end,},
    });

    if (DEV_MODE) then
        tMenus["Help"]:AppendSeparator();
        local nBuildDocsID = wx.wxNewId();
        local oBuildDocsItem = tMenus["Help"]:Append(nBuildDocsID, "Build API Docs");
        --[[!
        @fqxn CFS.Windows.Main.Private.Functions.buildAPIDocs
        @desc Builds and installs Studio API documentation on an explicit development-menu request.
        @vis private
        !]]
        local function buildAPIDocs()
            require("Util").BuildAPIDocs();
        end
        tMenuItems["Help:Build API Docs"] = {item = oBuildDocsItem, action = buildAPIDocs};
        dFrame:Connect(nBuildDocsID, wx.wxEVT_COMMAND_MENU_SELECTED, protect(buildAPIDocs));
        local nBuildReleaseID = wx.wxNewId();
        local oBuildReleaseItem = tMenus["Help"]:Append(nBuildReleaseID, "Build Release...");
        --[[!
        @fqxn CFS.Windows.Main.Private.Functions.buildRelease
        @desc Prompts for a release ZIP destination using the last successful build folder. Falls back to the application folder when the saved folder is missing. Saves the folder only after packaging succeeds; cancellation and failure keep the previous setting.
        @vis private
        !]]
        local function buildRelease()
            local pFolder = INIFile.GetValue(FS.AppCFG, "Settings", "ReleaseFolder");
            if (not wx.wxDirExists(pFolder)) then pFolder = APP_PATH; end
            local oDialog = wx.wxFileDialog(dFrame, "Build Release", pFolder, "Card Forge Studio.zip", "ZIP archives (*.zip)|*.zip", wx.wxFD_SAVE);
            local bAccepted = oDialog:ShowModal() == wx.wxID_OK;
            local pZIP = oDialog:GetPath();
            oDialog:Destroy();
            if (bAccepted) then
                require("Util").BuildRelease(pZIP);
                local oFile = wx.wxFileName(pZIP);
                local pDestination = oFile:GetPath();
                oFile:delete();
                INIFile.SetValue(FS.AppCFG, "Settings", "ReleaseFolder", pDestination);
            end
        end
        tMenuItems["Help:Build Release..."] = {item = oBuildReleaseItem, action = buildRelease};
        dFrame:Connect(nBuildReleaseID, wx.wxEVT_COMMAND_MENU_SELECTED, protect(buildRelease));
    end

    --[[!
    @fqxn CFS.Windows.Main.Private.Functions.showPage
    @desc Switches between Welcome and Editor views and updates their visible controls.
    @param any sName Name.
    @vis private
    !]]
    showPage = function(sName)
        assert(sName == "Welcome" or sName == "Editor", "Unknown Main page.");
        sPage = sName;
        oControls:ShowItems(sPage == "Editor");
        dCoordinates:Show(sPage == "Editor"); positionCoordinates();
        oWelcomeLinks:ShowItems(sPage == "Welcome");

        for sPath, tMenuItem in pairs(tMenuItems) do
            local bAvailable = type(tMenuItem.action) == "function";

            if (sPath == "Card Set:Load" or sPath == "Game:Docs" or sPath == "Game:Rebuild Docs" or sPath == "Game:Style Editor" or sPath == "Game:Wiki") then bAvailable = not not Game.GetActive(); end
            if (sPath == "Card Set:Info..." or sPath == "Card Set:Edit Source...") then bAvailable = bDataLoaded; end
            if (sPath == "Card Set:New") then bAvailable = not not Game.GetActive(); end
            if (sPath == "Game:Info..." or sPath == "Game:Browse" or sPath == "Game:Edit Source...") then bAvailable = not not Game.GetActive(); end
            if (sPath == "Card Set:Browse") then bAvailable = bDataLoaded; end
            if (sPath == "Game:Export Game..." or sPath == "Card Set:Import Card Set...") then bAvailable = not not Game.GetActive() and not tDataSession.exporting; end
            if (sPath == "Card Set:Export Card Set...") then bAvailable = bDataLoaded and not tDataSession.exporting; end
            if (sPath == "Game:Import Game...") then bAvailable = not tDataSession.exporting; end
            if (sPath == "Game:Close Game") then bAvailable = not not Game.GetActive() and not tDataSession.exporting; end
            if (sPath == "Card Set:Close Card Set") then bAvailable = bDataLoaded and not tDataSession.exporting; end

            if (sPath == "Window:Base Data" or sPath == "Window:Final Data") then
                bAvailable = sPage == "Editor" and #tDataSession.headers > 0;
            end

            tMenuItem.item:Enable(bAvailable);
        end

        local tManualItem = tMenuItems["Game:Manual"];
        local bManualVisible = tMenus.Game:FindItem(tManualItem.item:GetId()) ~= nil;
        if (Game.GetActive() and not bManualVisible) then
            tMenus.Game:Insert(9, tManualItem.item);
        elseif (not Game.GetActive() and bManualVisible) then
            tMenus.Game:Remove(tManualItem.item:GetId());
        end

        oCoordinates:SetLabel("-, -");
        dFrame:SetStatusText(sPage, 0);
        dFrame:SetStatusText("", 1);
        dFrame:SetStatusText("", 2);
        dPanel:Layout();
        resizeCanvas();
    end

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
        if (dGameEditorWindow and not dGameEditorWindow.close()) then
            if (oEvent:CanVeto()) then oEvent:Veto(); end
            return;
        end
        if (dWikiWindow and not dWikiWindow.close()) then
            if (oEvent:CanVeto()) then oEvent:Veto(); end
            return;
        end
        if (dManualWindow and not dManualWindow.close()) then
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
        coordinatePanel = dCoordinates, coordinateDivider = oCoordinateDivider, guides = oGuides, coordinates = oCoordinates, negativeCoordinates = oNegativeCoordinates, dataSession = tDataSession, loadCardSet = loadCardSet};
end

if (... == nil) then
    Main.create();
    wx.wxGetApp():MainLoop();
    os.exit(0);
end

return Main;
