--[[!
@fqxn CFS.Windows.DataGrid
@desc Native grid controls and common actions for base and final data views.
!]]

-- Native grid window shared by the editable and processed data views.
local wx = require("wx");
local GridStyle = require("Windows.GridStyle");
local dCodeEditor = require("Windows.CodeEditor");
local dLog = require("Windows.Log");
local Log = require("Log");
local DataGrid = {};
local WindowState = require("Windows.WindowState");
local _tWindowStates = {
    BaseData = {
        savePosition = true,
        saveSize     = true,
        saveVisible  = true,
    },
    FinalData = {
        savePosition = true,
        saveSize     = true,
        saveVisible  = true,
    },
};
for sName, tOptions in pairs(_tWindowStates) do WindowState.register(sName, tOptions); end

--[[!
@fqxn CFS.Windows.DataGrid.create
@pulsarlua function DataGrid.create
@desc Creates a base or final data grid bound to a shared session, including filtering, sorting, export, selection, and synchronized scrolling.
@param any tSession Session.
@param any bFinal Final.
!]]
function DataGrid.create(tSession, bFinal)
    local sTitle        = bFinal and "Final Data" or "Base Data";
    local dFrame        = wx.wxFrame(wx.NULL, wx.wxID_ANY, sTitle, wx.wxDefaultPosition, wx.wxSize(900, 650));
    local dPanel        = wx.wxPanel(dFrame, wx.wxID_ANY);
    local oLayout       = wx.wxBoxSizer(wx.wxVERTICAL);
    local oTools        = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oSearch       = wx.wxTextCtrl(dPanel, wx.wxID_ANY, "");
    local sSource       = bFinal and "Final" or "Base";
    local oFilterColumn = wx.wxChoice(dPanel, wx.wxID_ANY);
    local oFilterText   = wx.wxTextCtrl(dPanel, wx.wxID_ANY, "");
    local oSort         = wx.wxChoice(dPanel, wx.wxID_ANY);
    local oDescending   = wx.wxCheckBox(dPanel, wx.wxID_ANY, "Descending");
    local oGrid         = wx.wxGrid(dPanel, wx.wxID_ANY);
    local oActions      = wx.wxBoxSizer(wx.wxVERTICAL);
    local oActionLine   = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oLeftActions  = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oExportActions = wx.wxBoxSizer(wx.wxHORIZONTAL);
    --[[!
    @fqxn CFS.Windows.DataGrid.Private.readableButton
    @desc Builds a bitmap-backed button with readable native-font text.
    @param any sLabel Label.
    @vis private
    !]]
    local function readableButton(sLabel)
        local oFont = wx.wxSystemSettings.GetFont(wx.wxSYS_DEFAULT_GUI_FONT);
        --[[!
        @fqxn CFS.Windows.DataGrid.Private.bitmap
        @desc Draws the button label into a padded bitmap using the requested text color.
        @param any sColor Color.
        @vis private
        !]]
        local function bitmap(sColor)
            local oDC = wx.wxMemoryDC(); oDC:SetFont(oFont);
            local nWidth, nHeight = oDC:GetTextExtent(sLabel);
            local oBitmap = wx.wxBitmap(nWidth + 12, nHeight + 8, 32);
            oDC:SelectObject(oBitmap); oDC:SetBackground(wx.wxBrush(wx.wxSystemSettings.GetColour(wx.wxSYS_COLOUR_BTNFACE))); oDC:Clear();
            oDC:SetTextForeground(wx.wxColour(sColor)); oDC:DrawText(sLabel, 6, 4);
            oDC:SelectObject(wx.wxNullBitmap); oDC:delete(); return oBitmap;
        end
        local oButton = wx.wxBitmapButton(dPanel, wx.wxID_ANY, bitmap("#202020"));
        oButton:SetBitmapDisabled(bitmap("#777777")); oButton:SetLabel(sLabel); oButton:SetName(sLabel); oButton:SetToolTip(sLabel);
        return oButton;
    end
    local oNew          = readableButton("New");
    local oColumns      = readableButton("Columns...");
    local oReprocess    = readableButton("Reprocess Row");
    local oSave         = readableButton("Save");
    local oEditCode     = readableButton("Edit Code");
    local oExportType = wx.wxChoice(dPanel, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, {"PNG"}); oExportType:SetSelection(0);
    local oExportOptions = readableButton("Export Options");
    local tExportButtons = {};
    for _, sScope in ipairs({"Filtered", "Selected", "All"}) do tExportButtons[sScope] = readableButton("Export "..sScope); end
    local oWindowState  = WindowState.bind(dFrame, bFinal and "FinalData" or "BaseData");
    local bRefreshing   = false;
    local bClosed       = false;
    local tLastVisible  = nil;
    local tLastHeaders  = nil;
    local sLastColors   = nil;
    local nLastSelected = nil;
    local tCellValues   = {};
    local oScrollTimer;
    local sExportStatus = "";
    local unregisterExportStatus;

    dFrame:SetMinSize(wx.wxSize(700, 400));
    dFrame:CreateStatusBar();
    oGrid:CreateGrid(0, 0);
    oGrid:DisableDragRowSize();
    oGrid:EnableEditing(not bFinal and type(tSession.options.onEdit) == "function");
    oSearch:SetToolTip("Search all columns in this window.");
    oFilterText:SetToolTip("Keep rows whose selected column contains this text.");


    for _, tControl in ipairs({{"Search", oSearch},
        {"Filter", oFilterColumn}, {"Contains", oFilterText}, {"Sort", oSort}}) do
        oTools:Add(wx.wxStaticText(dPanel, wx.wxID_ANY, tControl[1]), 0,
            wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 4);
        oTools:Add(tControl[2], 1, wx.wxALL, 4);
    end

    oTools:Add(oDescending, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 4);
    oLeftActions:Add(oNew, 0, wx.wxALL, 4);

    if (not bFinal) then
        oLeftActions:Add(oColumns, 0, wx.wxALL, 4);
    else
        oColumns:Hide();
    end

    oLeftActions:Add(oReprocess, 0, wx.wxALL, 4);

    if (not bFinal) then
        oLeftActions:Add(oSave, 0, wx.wxALL, 4);
        oLeftActions:Add(oEditCode, 0, wx.wxALL, 4);
    else
        oSave:Hide();
        oEditCode:Hide();
    end

    oActionLine:Add(oLeftActions, 0); oActionLine:AddStretchSpacer();
    oExportActions:Add(oExportType, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 4);
    oExportActions:Add(oExportOptions, 0, wx.wxALL, 4);
    oExportActions:Add(wx.wxStaticLine(dPanel, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(2, 24), wx.wxLI_VERTICAL), 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 6);
    for _, sScope in ipairs({"Filtered", "Selected", "All"}) do oExportActions:Add(tExportButtons[sScope], 0, wx.wxALL, 4); end
    oActionLine:Add(oExportActions, 0); oActions:Add(oActionLine, 0, wx.wxEXPAND);
    local bExportWrapped = false;
    dPanel:Connect(wx.wxEVT_SIZE, function(oEvent)
        local bWrap = dPanel:GetClientSize():GetWidth() < oLeftActions:GetMinSize():GetWidth() + oExportActions:GetMinSize():GetWidth() + 16;
        if (bWrap ~= bExportWrapped) then
            if (bWrap) then oActionLine:Detach(oExportActions); oActions:Add(oExportActions, 0, wx.wxALIGN_RIGHT);
            else oActions:Detach(oExportActions); oActionLine:Add(oExportActions, 0); end
            bExportWrapped = bWrap; dPanel:Layout();
        end
        oEvent:Skip();
    end);
    oLayout:Add(oTools, 0, wx.wxEXPAND + wx.wxALL, 4);
    oLayout:Add(oGrid, 1, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 8);
    oLayout:Add(oActions, 0, wx.wxEXPAND + wx.wxALL, 4);
    dPanel:SetSizer(oLayout);
    local oFrameLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    oFrameLayout:Add(dPanel, 1, wx.wxEXPAND);
    dFrame:SetSizer(oFrameLayout);
    dFrame:Layout();

    --[[!
    @fqxn CFS.Windows.DataGrid.Private.protect
    @desc Wraps a grid action and reports failures through the error service.
    @param any fAction Action.
    @vis private
    !]]
    local function protect(fAction)
        return function(...)
            local tArguments = table.pack(...);
            local bOK, sError = xpcall(function()
                fAction(table.unpack(tArguments, 1, tArguments.n));
            end, debug.traceback);

            if (not bOK) then
                require("Errors").report(sError);
            end
        end
    end

    oNew:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, protect(function()
        local nCount = require("Windows.NewCards").Show(dFrame);

        if (nCount) then tSession.addCards(nCount); end
    end));
    oColumns:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, protect(function()
        require("Windows.Columns").Show(dFrame, tSession);
    end));

    --[[!
    @fqxn CFS.Windows.DataGrid.Private.refresh
    @desc Rebuilds grid values and controls from the shared session while preserving source-row identity.
    @vis private
    !]]
    local function refresh()
        if (bClosed) then
            return;
        end
        local sCardSetName = tSession.options.getCardSetName and tSession.options.getCardSetName() or "";
        dFrame:SetTitle(sTitle..(sCardSetName ~= "" and (" - "..sCardSetName) or ""));

        bRefreshing = true;
        oGrid:BeginBatch();

        local nRows, nColumns = #tSession.visible, #tSession.headers;
        local nOldRows, nOldColumns = oGrid:GetNumberRows(), oGrid:GetNumberCols();

        if (nOldRows > nRows) then oGrid:DeleteRows(nRows, nOldRows - nRows); end
        if (nOldRows < nRows) then oGrid:AppendRows(nRows - nOldRows); end
        if (nOldColumns > nColumns) then oGrid:DeleteCols(nColumns, nOldColumns - nColumns); end
        if (nOldColumns < nColumns) then oGrid:AppendCols(nColumns - nOldColumns); end

        local tRows = bFinal and tSession.final or tSession.base;
        local nSelected;

        local tColors        = GridStyle.get();
        local sColors        = table.concat({tColors.primary, tColors.secondary, tColors.primaryText, tColors.secondaryText, tColors.index, tColors.indexText}, "|");
        local bColorsChanged = sColors ~= sLastColors;

        oGrid:SetLabelBackgroundColour(wx.wxColour(tColors.index));
        oGrid:SetLabelTextColour(wx.wxColour(tColors.indexText));

        local bViewChanged = tLastVisible ~= tSession.visible;
        local bHeadersChanged = tLastHeaders ~= tSession.headers;

        for nColumn, sHeader in ipairs(tSession.headers) do
            local bColumnChanged = bHeadersChanged or nOldRows ~= nRows;
            if (bHeadersChanged) then oGrid:SetColLabelValue(nColumn - 1, sHeader); end

            for nVisible, nSource in ipairs(tSession.visible) do
                if (bViewChanged or bHeadersChanged) then
                    local tValues = tCellValues[nVisible] or {};
                    local sValue = tRows[nSource][sHeader];
                    if (bHeadersChanged or tValues[nColumn] ~= sValue) then
                        oGrid:SetCellValue(nVisible - 1, nColumn - 1, sValue);
                        tValues[nColumn] = sValue;
                        bColumnChanged = true;
                    end
                    tCellValues[nVisible] = tValues;
                    if (bHeadersChanged or nVisible > nOldRows) then
                        oGrid:SetReadOnly(nVisible - 1, nColumn - 1, bFinal or tSession.codeColumns[sHeader] ~= nil or type(tSession.options.onEdit) ~= "function");
                    end
                    if (nColumn == 1) then oGrid:SetRowLabelValue(nVisible - 1, tostring(nSource)); end
                end

                -- Preference changes repaint both views without rebuilding their data.
                if (bColorsChanged or bHeadersChanged or nVisible > nOldRows) then
                    oGrid:SetCellBackgroundColour(nVisible - 1, nColumn - 1,
                        wx.wxColour(nVisible % 2 == 1 and tColors.primary or tColors.secondary));
                    oGrid:SetCellTextColour(nVisible - 1, nColumn - 1,
                        wx.wxColour(nVisible % 2 == 1 and tColors.primaryText or tColors.secondaryText));
                end

                if (nSource == tSession.selected) then nSelected = nVisible - 1; end
            end
            if (bColumnChanged) then
                if (tSession.codeColumns[sHeader]) then
                    oGrid:AutoSizeColLabelSize(nColumn - 1);
                else
                    oGrid:AutoSizeColumn(nColumn - 1, false);
                end
            end
        end

        for nRow = nRows + 1, #tCellValues do tCellValues[nRow] = nil; end

        if (bViewChanged or bHeadersChanged) then oGrid:ClearSelection(); end

        -- Shared source identity remains correct after sorting and filtering.
        if ((bViewChanged or bHeadersChanged or nSelected ~= nLastSelected) and nSelected and nColumns > 0) then
            oGrid:SetGridCursor(nSelected, math.min(tSession.column, nColumns) - 1);
            oGrid:ClearSelection();
            oGrid:SelectRow(nSelected);
        end

        sLastColors, nLastSelected = sColors, nSelected;

        oGrid:EndBatch();
        if (bViewChanged or bHeadersChanged) then
        local bActive = tSession.source == sSource;
        oSearch:ChangeValue(bActive and tSession.search or "");
        oFilterText:ChangeValue(bActive and tSession.filterText or "");

        oDescending:SetValue(bActive and tSession.descending or false);
        if (bHeadersChanged) then
            oFilterColumn:Clear();
            oSort:Clear();
            oFilterColumn:Append("All columns");
            oSort:Append("Source order");
            for _, sHeader in ipairs(tSession.headers) do
                oFilterColumn:Append(sHeader);
                oSort:Append(sHeader);
            end
        end
        oFilterColumn:SetSelection(0);
        oSort:SetSelection(0);

        for nColumn, sHeader in ipairs(tSession.headers) do
            if (bActive and sHeader == tSession.filterColumn) then oFilterColumn:SetSelection(nColumn); end
            if (bActive and sHeader == tSession.sortColumn) then oSort:SetSelection(nColumn); end
        end
        end
        tLastVisible, tLastHeaders = tSession.visible, tSession.headers;

        local sHeader = tSession.headers[tSession.column];
        oEditCode:Enable(not bFinal and tSession.selected ~= nil and
            sHeader ~= nil and tSession.codeColumns[sHeader] ~= nil and type(tSession.options.onEdit) == "function");
        oNew:Enable(#tSession.headers > 0 and not tSession.editing and type(tSession.options.onStructure) == "function");
        oColumns:Enable(#tSession.headers > 0 and not tSession.editing and type(tSession.options.onStructure) == "function");
        oReprocess:Enable(tSession.selected ~= nil and type(tSession.options.onReprocess) == "function");
        oSave:Enable(tSession.dirty and type(tSession.options.onSave) == "function");
        local tExport = tSession.options.exportContext and tSession.options.exportContext();
        local bExport = tExport ~= nil and type(tSession.options.onExport) == "function";
        oExportType:Enable(bExport); oExportOptions:Enable(bExport);
        for sScope, oButton in pairs(tExportButtons) do oButton:Enable(bExport and (sScope == "All" and #tSession.base > 0 or sScope ~= "All" and nRows > 0)); end
        dFrame:SetStatusText(sExportStatus ~= "" and sExportStatus or (nRows.." of "..#tSession.base.." rows"..(bFinal and " | Read-only" or "")));
        bRefreshing = false;
    end

    --[[!
    @fqxn CFS.Windows.DataGrid.Private.exportRows
    @desc Collects all, visible, or selected source rows and invokes the connected export callback.
    @param any sScope Scope.
    @vis private
    !]]
    local function exportRows(sScope)
        local tRows = {};
        if (sScope == "All") then for nRow = 1, #tSession.base do tRows[#tRows + 1] = nRow; end
        elseif (sScope == "Filtered") then for _, nRow in ipairs(tSession.visible) do tRows[#tRows + 1] = nRow; end
        else
            for nVisible, nRow in ipairs(tSession.visible) do
                local bSelected = false;
                for nColumn = 0, oGrid:GetNumberCols() - 1 do if (oGrid:IsInSelection(nVisible - 1, nColumn)) then bSelected = true; break; end end
                if (bSelected) then tRows[#tRows + 1] = nRow; end
            end
            if (#tRows == 0 and oGrid:GetGridCursorRow() >= 0) then local nRow = tSession.visible[oGrid:GetGridCursorRow() + 1]; if (nRow) then tRows[1] = nRow; end end
        end
        return tRows;
    end
    oExportOptions:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, protect(function()
        local tContext = assert(tSession.options.exportContext(), "Load a card set first.");
        require("Windows.ExportOptions").show(dFrame, tContext.info, tContext.names, tContext.width, tContext.height);
    end));
    oExportType:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, protect(function()
        local tContext = assert(tSession.options.exportContext(), "Load a card set first.");
        local tModel = require("Exporter").get("PNG").model(tContext.info); tModel.saveOptions(tModel.options);
    end));
    for sScope, oButton in pairs(tExportButtons) do
        oButton:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, protect(function()
            if (oGrid:IsCellEditControlEnabled()) then oGrid:SaveEditControlValue(); oGrid:DisableCellEditControl(); end
            local tContext = assert(tSession.options.exportContext(), "Load a card set first.");
            local tRows = exportRows(sScope); assert(#tRows > 0, "No selected cards to export.");
            local tExportModel = require("Exporter").get("PNG").model(tContext.info);
            local pInitial = tExportModel.options.directory;

            -- Each card set keeps its destination; first use starts in the game exports folder.
            if (pInitial == "" or not wx.wxDirExists(pInitial)) then
                pInitial = FS.Game.Exports;
            end
            local oDialog = wx.wxDirDialog(dFrame, "Choose an empty folder for PNG export", pInitial, wx.wxDD_DEFAULT_STYLE);
            local nResult = oDialog:ShowModal(); local pDirectory = oDialog:GetPath(); oDialog:Destroy();
            if (nResult ~= wx.wxID_OK) then return; end
            tExportModel.options.directory = pDirectory; tExportModel.saveOptions(tExportModel.options);
            local nCount = tSession.options.onExport(tRows, pDirectory, tExportModel.options);
            if (not tSession.options.subscribeExportStatus) then dFrame:SetStatusText("Exported "..nCount.." PNG images."); end
        end));
    end
    --[[!
    @fqxn CFS.Windows.DataGrid.Private.updateView
    @desc Copies search, filter, and sort controls into the session and refreshes the shared view.
    @vis private
    !]]
    local function updateView()
        if (bRefreshing) then return; end
        tSession.search = oSearch:GetValue();
        tSession.source = sSource;
        tSession.filterColumn = tSession.headers[oFilterColumn:GetSelection()] or "";
        tSession.filterText = oFilterText:GetValue();
        tSession.sortColumn = tSession.headers[oSort:GetSelection()] or "";
        tSession.descending = oDescending:GetValue();
        tSession.refresh();
    end

    for _, oControl in ipairs({oSearch, oFilterText}) do
        oControl:Connect(wx.wxEVT_COMMAND_TEXT_UPDATED, protect(updateView));
    end
    for _, oControl in ipairs({oFilterColumn, oSort}) do
        oControl:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, protect(updateView));
    end
    oDescending:Connect(wx.wxEVT_COMMAND_CHECKBOX_CLICKED, protect(updateView));
    --[[!
    @fqxn CFS.Windows.DataGrid.Private.sortHeader
    @desc Selects a clicked column for sorting and toggles its direction when clicked again.
    @param any nColumn Column.
    @vis private
    !]]
    local function sortHeader(nColumn)
        local sHeader = tSession.headers[nColumn + 1];
        if (not sHeader) then return; end
        local bDescending = tSession.source == sSource and tSession.sortColumn == sHeader and not tSession.descending;
        if (tSession.source ~= sSource) then
            tSession.search, tSession.filterColumn, tSession.filterText = "", "", "";
        end
        tSession.source, tSession.sortColumn, tSession.descending = sSource, sHeader, bDescending;
        tSession.refresh();
    end
    oGrid:Connect(wx.wxEVT_GRID_LABEL_LEFT_CLICK, protect(function(oEvent)
        if (oEvent:GetCol() < 0 and oEvent:GetRow() >= 0) then
            local nSource = tSession.visible[oEvent:GetRow() + 1];

            if (nSource) then
                tSession.select(nSource, 1);
            end
        else
            sortHeader(oEvent:GetCol());
        end
    end));
    oGrid:Connect(wx.wxEVT_GRID_SELECT_CELL, protect(function(oEvent)
        if (not bRefreshing) then
            local nSource = tSession.visible[oEvent:GetRow() + 1];
            if (nSource) then tSession.select(nSource, oEvent:GetCol() + 1); end
        end
        oEvent:Skip();
    end));
    oGrid:Connect(wx.wxEVT_GRID_CELL_CHANGED, protect(function(oEvent)
        if (bRefreshing or bFinal) then return; end
        local nSource = tSession.visible[oEvent:GetRow() + 1];
        local sHeader = tSession.headers[oEvent:GetCol() + 1];
        local sValue = oGrid:GetCellValue(oEvent:GetRow(), oEvent:GetCol());
        local bOK, sError = pcall(tSession.edit, nSource, sHeader, sValue);
        if (not bOK) then
            tCellValues, tLastVisible = {}, nil;
            refresh();
            error(sError, 0);
        end
    end));

    --[[!
    @fqxn CFS.Windows.DataGrid.Private.editCode
    @desc Opens the selected base code cell in the modal code editor and applies accepted changes through the session.
    @vis private
    !]]
    local function editCode()
        local nSource = tSession.selected;
        local sHeader = tSession.headers[tSession.column];
        assert(not bFinal and nSource and tSession.codeColumns[sHeader] ~= nil, "Select a base code cell.");
        tSession.editing = true;
        local bOK, sResult = pcall(dCodeEditor.edit, dFrame,
            tSession.base[nSource][sHeader], "Code Editor - Row "..nSource.." - "..tSession.base[nSource].Name.." - "..sHeader);
        tSession.editing = false;
        assert(bOK, sResult);
        if (sResult ~= nil) then tSession.edit(nSource, sHeader, sResult); end
    end

    oEditCode:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, protect(editCode));
    oGrid:Connect(wx.wxEVT_GRID_CELL_LEFT_DCLICK, protect(function(oEvent)
        local sHeader = tSession.headers[oEvent:GetCol() + 1];
        if (not bFinal and tSession.codeColumns[sHeader] ~= nil) then
            tSession.select(tSession.visible[oEvent:GetRow() + 1], oEvent:GetCol() + 1);
            editCode();
        else
            oEvent:Skip();
        end
    end));
    oReprocess:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, protect(function()
        tSession.options.onReprocess(tSession.selected);
    end));
    oSave:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, protect(function()
        tSession.save();
    end));
    dFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        if (oEvent:CanVeto()) then dFrame:Hide(); oEvent:Veto();
        else bClosed = true; oScrollTimer:Stop(); oWindowState.close(); oEvent:Skip(); end
    end);
    oScrollTimer = wx.wxTimer(dFrame, wx.wxNewId());
    local nLastX, nLastY = oGrid:GetViewStart();
    --[[!
    @fqxn CFS.Windows.DataGrid.Private.syncScroll
    @desc Updates native grid scroll position from the shared session.
    @param any nX X.
    @param any nY Y.
    @vis private
    !]]
    local function syncScroll(nX, nY)
        if (bClosed) then return; end
        oGrid:Scroll(nX, nY);
        nLastX, nLastY = oGrid:GetViewStart();
    end
    tSession.subscribeScroll(syncScroll);
    dFrame:Connect(oScrollTimer:GetId(), wx.wxEVT_TIMER, function()
        if (bClosed or bRefreshing or not dFrame:IsShown()) then return; end
        local nX, nY = oGrid:GetViewStart();
        if (nX ~= nLastX or nY ~= nLastY) then
            nLastX, nLastY = nX, nY;
            tSession.scroll(nX, nY);
        end
    end);
    oScrollTimer:Start(30);
    if (tSession.options.subscribeExportStatus) then
        unregisterExportStatus = tSession.options.subscribeExportStatus(function(sText)
            if (bClosed) then return; end
            sExportStatus = sText;
            dFrame:SetStatusText(sText);
            dFrame:GetStatusBar():Update();
        end);
        dFrame:Connect(wx.wxEVT_DESTROY, function(oEvent)
            if (oEvent:GetId() == dFrame:GetId() and unregisterExportStatus) then unregisterExportStatus(); end
            oEvent:Skip();
        end);
    end
    tSession.subscribe(refresh);
    GridStyle.subscribe(refresh);
    refresh();

    return {frame = dFrame, grid = oGrid, search = oSearch,
        filterColumn = oFilterColumn, filterText = oFilterText, sort = oSort,
        exportType = oExportType, exportOptions = oExportOptions, exportButtons = tExportButtons, exportRows = exportRows, descending = oDescending, editCode = editCode, sortHeader = sortHeader,
        --[[!
        @fqxn CFS.Windows.DataGrid.Private.show
        @desc Shows and raises the data window.
        @vis private
        !]]
        show = function() dFrame:Show(true); dFrame:Layout(); dPanel:Layout(); dFrame:Raise(); end,
        --[[!
        @fqxn CFS.Windows.DataGrid.Private.close
        @desc Closes the data window through its native close handling.
        @vis private
        !]]
        close = function() if (unregisterExportStatus) then unregisterExportStatus(); end oScrollTimer:Stop(); oWindowState.close(); bClosed = true; dFrame:Destroy(); end};
end

return DataGrid;


