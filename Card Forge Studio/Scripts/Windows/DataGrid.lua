-- Native grid window shared by the editable and processed data views.
-- TODO Required window persistence: independently save Base Data and Final Data
-- position and size on move, resize, and close; restore each on reopening.
local wx = require("wx");
local dCodeEditor = require("Windows.CodeEditor");
local dLog = require("Windows.Log");
local Log = require("Log");
local DataGrid = {};

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
    local oActions      = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oReprocess    = wx.wxButton(dPanel, wx.wxID_ANY, "Reprocess Row");
    local oSave         = wx.wxButton(dPanel, wx.wxID_ANY, "Save");
    local oEditCode     = wx.wxButton(dPanel, wx.wxID_ANY, "Edit Code");
    local bRefreshing   = false;
    local bClosed       = false;
    local tLastVisible  = nil;
    local tLastHeaders  = nil;
    local tCellValues   = {};

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
    oActions:Add(oReprocess, 0, wx.wxALL, 4);

    if (not bFinal) then
        oActions:Add(oSave, 0, wx.wxALL, 4);
        oActions:Add(oEditCode, 0, wx.wxALL, 4);
    else
        oSave:Hide();
        oEditCode:Hide();
    end

    oLayout:Add(oTools, 0, wx.wxEXPAND + wx.wxALL, 4);
    oLayout:Add(oGrid, 1, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 8);
    oLayout:Add(oActions, 0, wx.wxEXPAND + wx.wxALL, 4);
    dPanel:SetSizer(oLayout);
    local oFrameLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    oFrameLayout:Add(dPanel, 1, wx.wxEXPAND);
    dFrame:SetSizer(oFrameLayout);
    dFrame:Layout();

    local function protect(fAction)
        return function(...)
            local tArguments = table.pack(...);
            local bOK, sError = xpcall(function()
                fAction(table.unpack(tArguments, 1, tArguments.n));
            end, debug.traceback);

            if (not bOK) then
                Log.Error(sError);
                wx.wxMessageBox(sError, sTitle.." - Error", wx.wxOK + wx.wxICON_ERROR, dFrame);
            end
        end
    end

    local function refresh()
        if (bClosed) then
            return;
        end

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
                        oGrid:SetCellBackgroundColour(nVisible - 1, nColumn - 1, wx.wxColour(nVisible % 2 == 1 and 255 or 234, nVisible % 2 == 1 and 255 or 234, nVisible % 2 == 1 and 255 or 234));
                        oGrid:SetReadOnly(nVisible - 1, nColumn - 1, bFinal or tSession.codeColumns[sHeader] ~= nil or type(tSession.options.onEdit) ~= "function");
                    end
                    if (nColumn == 1) then oGrid:SetRowLabelValue(nVisible - 1, tostring(nSource)); end
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

        oGrid:ClearSelection();

        if (nSelected and nColumns > 0) then
            oGrid:SetGridCursor(nSelected, math.min(tSession.column, nColumns) - 1);
            oGrid:SelectRow(nSelected);
        end

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
        oReprocess:Enable(tSession.selected ~= nil and type(tSession.options.onReprocess) == "function");
        oSave:Enable(tSession.dirty and type(tSession.options.onSave) == "function");
        dFrame:SetStatusText(nRows.." of "..#tSession.base.." rows"..(bFinal and " | Read-only" or ""));
        bRefreshing = false;
    end

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
        sortHeader(oEvent:GetCol());
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

    local function editCode()
        local nSource = tSession.selected;
        local sHeader = tSession.headers[tSession.column];
        assert(not bFinal and nSource and tSession.codeColumns[sHeader] ~= nil, "Select a base code cell.");
        tSession.editing = true;
        local bOK, sResult = pcall(dCodeEditor.edit, dFrame,
            tSession.base[nSource][sHeader], "Code Editor - "..sHeader.." - Row "..nSource);
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
        tSession.options.onSave(tSession.base);
        tSession.dirty = false;
        refresh();
    end));
    dFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        if (oEvent:CanVeto()) then dFrame:Hide(); oEvent:Veto();
        else bClosed = true; oEvent:Skip(); end
    end);
    tSession.subscribe(refresh);
    refresh();

    return {frame = dFrame, grid = oGrid, search = oSearch,
        filterColumn = oFilterColumn, filterText = oFilterText, sort = oSort,
        descending = oDescending, editCode = editCode, sortHeader = sortHeader,
        show = function() dFrame:Show(true); dFrame:Layout(); dPanel:Layout(); dFrame:Raise(); end,
        close = function() bClosed = true; dFrame:Destroy(); end};
end

return DataGrid;


