------------------------------------- Localization
local Grid                          = Grid;
    local GetCellText               = Grid.GetCellText;
    local SetCellText               = Grid.SetCellText;
--TODO FINISH
------------------------------------- Modules
local RowFilter = require("ProcSys.CSV.RowFilter");
------------------------------->>> CSV >>>-------------------------------
------------------------------------- Enums
local _eDATATYPE                    = enum("DATATYPE", {"BASE", "FINAL"}, {"Base", "Final"}, true);
------------------------------------- Functions
local _fRowProc                     = function() end; --NOTE: DO NOT REMOVE: dead function in case initial user function is bad
------------------------------------- Numbers
local _nCurrentRow                  = 1;
local _nCurrentColumn               = 1;
local _nLastRow                     = -1;
local _nRowCount                    = -1;
local _nColumnCount                 = -1;
local _nRowProcTimerBudget          = 20; --max rows that can be processed each timer cycle
------------------------------------- Strings
local CSV_DELIMITER                 = CSV_DELIMITER;
local FILE_BUILT_IN_ROW_FILTERS     = FILE_BUILT_IN_ROW_FILTERS;
------------------------------------- Tables
local _tCSVBase                     = null; --the entire CSV file content
local _tCSVFinal                    = null; --the processed, filtered CSV content
local _tHeaders                     = null;
local _tCSVTableByType              = null;
--local _tCSVTableByType            = {[DATA_TYPE_BASE] =_tCSVBase, [DATA_TYPE_FINAL] = _tCSVFinal};
local _tRowTypes                    = {[_eDATATYPE.BASE] = "BaseRow", [_eDATATYPE.FINAL] = "FinalRow"}; --used for type in GetRow QUESTION do i need this???????
local _tRequiredColumns             = {NAME = true}; --used to create the _tColumnNoProcIDs when data changed. These columns do not fire the row processor.
local _tColumnNoProcIDs             = {}; --contains columns like "Name" that won't get processed, but direct copied instead
local _tHeadersIDMap                = {}; --indexed by uppercase column (names for unambigious access); values are column IDs
local _tHeadersCaseMap              = {}; --indices are upper case names, values are original, user-given names
local _tRows                        = {}; --repo of all processed rows
local _tDirtyRows                   = {}; --rows that need reprocessed
local _tRowFilterMap                = {}; --TODO QUESTION IS THIS USED?
local _tRestrictedColumnNames       = {   --this is checked when loading a CSV file to ensure the user is not using any of these internal column names (uppercase since column names are case insensitive)
    __INDEX         = true,     --the index of a row in the internal CSV table
    __FILTERINDEX   = true,     --the index of a row in the grid (displayed, filtered results)
};
-------------------------------<<< CSV <<<-------------------------------
--local _sCodeColumns                 = "";
local _tCodeColumns                 = {};

local _bAutoSizeGrid                = true;
local _sBaseDataGrid                = PROCSYS_GRID_BASE;
local _sFinalDataGrid               = PROCSYS_GRID_FINAL;
local _tGridByType                  = {[_eDATATYPE.BASE] = PROCSYS_GRID_BASE, [_eDATATYPE.FINAL] = PROCSYS_GRID_FINAL};
------------------------------->>> Row Filters >>>-------------------------------
local _tRowFilters                  = {};
local _sActiveRowFilter             = ROW_FILTER_DEFAULT;
-------------------------------<<< Row Filters <<<-------------------------------

local _ePane                        = PANE;
local _pAppCFG                      = FS.AppCFG;
------------------------------------- Preemptive Declarations (Local Functions)


local
--Private
ApplyRowFilter,
BuildRowMetatable,
UpdateGrids,
UpdateGridsFinalize,
UpdateGridsPrep,
ValidatewColumn,
ValidatewRow,

--Public
EnsureRowProcessed,
GetActiveRow,
GetRow,
GetCellText,
IsActiveRowDirty,
IsRowDirty,
LoadFromFile,
MarkAllRowsDirty,
MarkRowDirty,




ProcessCell,
ProcessDirtyRows,
ResetCodeCellTable,
UpdateActiveCell,
UpdateCodeColumns,
UpdateRowFilters;


--[[
██████╗ ██████╗ ██╗██╗   ██╗ █████╗ ████████╗███████╗
██╔══██╗██╔══██╗██║██║   ██║██╔══██╗╚══██╔══╝██╔════╝
██████╔╝██████╔╝██║██║   ██║███████║   ██║   █████╗
██╔═══╝ ██╔══██╗██║╚██╗ ██╔╝██╔══██║   ██║   ██╔══╝
██║     ██║  ██║██║ ╚████╔╝ ██║  ██║   ██║   ███████╗
╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚═╝  ╚═╝   ╚═╝   ╚══════╝]]


ValidatewColumn = function(vColumn, sCaller)
    local bRet      = false;
    local sMessage  = sCaller..": Unknown Error";

    if (type(vColumn) == "number") then

        if (vColumn == math.floor(vColumn)) then

            if (vColumn <= _nColumnCount and vColumn > 0) then
                bRet = true;
                sMessage = "Success";
            else
                sMessage = sCaller..": Column out of bounds";
            end

        else
            sMessage = sCaller..": Row must be an integer value. Got float.";
        end

    end

    if not (bRet) then
        Log.Warning(": Column Error |  "..sMessage);
    end

    return bRet;
end

ValidatewRow = function(vRow, sCaller)
    local bRet      = false;
    local sMessage  = sCaller..": Unknown Error";

    if (type(vRow) == "number") then

        if (vRow == math.floor(vRow)) then

            if (vRow <= _nRowCount and vRow > 0) then
                bRet = true;
                sMessage = "Success";
            else
                sMessage = sCaller..": Row out of bounds.";
            end

        else
            sMessage = sCaller..": Row must be an integer value. Got float.";
        end

    end

    if not (bRet) then
        Log.Warning(": Row Error | "..sMessage);
    end

    return bRet;
end



--[[!
@fqxn CFS.Classes.ProcSys.CSV.Methods.ApplyFilter
@desc Filters the <strong>_tCSV</strong> table rows using the active RowFilter, resets the appropriate variables, and updates the <strong>_tRowFilterMap</strong> table.
@note This function <strong><em>does not</em></strong> change the contents of the <strong>_tCSV</strong> table.
@todo Add anchors in this Dox comment.
@vis Static Private
!]]
ApplyRowFilter = function()
    --TODO ASSERTIONS
    local oRowFilter = _tRowFilters[_sActiveRowFilter];
    local fRowPredicate = oRowFilter.RowPredicate;

    --reset the row filter map
    _tRowFilterMap = {};
    --map index incrementor
    local nNextIndex = 1;

    for nRow, tRow in ipairs(_tCSV) do

        if (fRowPredicate(tRow)) then
            --save the row's ID (map index) in the map for easy access later
            _tRowFilterMap[nNextIndex] = nRow;
            --increment the map index
            nNextIndex = nNextIndex + 1;
        end

    end

end


--[[!
@fqxn CFS.Classes.ProcSys.CSV.Methods.BuildRowMetatable
@desc When a CVS file is loaded, this function is called for each row. In each iteration, a decoy row table is created and a metatable applied to it.<br>
Each row also has a metatable applied to it with only one metamethod; <strong>__call</strong>. This metamethod returns the row's decoy table for safe use in the user env.
<h2>Metamethods Applied to Each Row's Decoy Table</h2>
<ul class="list-unstyled">
    <li class="list-unstyled mb-3">
        <div class="card">
            <div class="card-body">
                <h6 class="card-title mb-2">__bnot</h6>
                <p class="card-text mb-0">
                    Returns this rows index in the table (NOT in the grid).
                </p>
            </div>
        </div>
    </li>
    <li class="list-unstyled mb-3">
        <div class="card">
            <div class="card-body">
                <h6 class="card-title mb-2">__index</h6>
                <p class="card-text mb-0">
                    Returns the content of the cell at the column specified.
                    The column can be either the case-insensitive column name or it's numeric index.
                </p>
            </div>
        </div>
    </li>
    <li class="list-unstyled mb-3">
        <div class="card">
            <div class="card-body">
                <h6 class="card-title mb-2">__len</h6>
                <p class="card-text mb-0">
                    Returns the number of columns.
                </p>
            </div>
        </div>
    </li>
    <li class="list-unstyled mb-3">
        <div class="card">
            <div class="card-body">
                <h6 class="card-title mb-2">__newindex</h6>
                <p class="card-text mb-0">
                    Throw an error.
                </p>
            </div>
        </div>
    </li>
    <li class="list-unstyled mb-3">
        <div class="card">
            <div class="card-body">
                <h6 class="card-title mb-2">__pairs</h6>
                <p class="card-text mb-0">
                    An iterator returning the Column Index <em>(number)</em>, Column Name <em>(string)</em>, and Cell Content <em>(string)</em>.
                </p>
            </div>
        </div>
    </li>
    <li class="list-unstyled mb-3">
        <div class="card">
            <div class="card-body">
                <h6 class="card-title mb-2">__type</h6>
                <p class="card-text mb-0">
                    Which type the data table is, either the value of the constant PROCSYS_GRID_BASE or PROCSYS_GRID_FINAL.
                </p>
            </div>
        </div>
    </li>
</ul>
@param number nRow The row's index.
@param table tRow The row itself.
@param string sType The type of row, whether PROCSYS_GRID_BASE or PROCSYS_GRID_FINAL.
@note This function <strong><em>does not</em></strong> change the contents of the <strong>_tCSV</strong> table.
@todo Add anchors in this Dox comment.
@vis Static Private
!]]
BuildRowMetatable = function(nRow, tRow, tCSV)

    local tRowMeta  = {
        __bnot = function()
            return nRow;
        end,
        __index = function(t, k)
            local vRet;
            local nColumn;
            local sColumn;

            local zK = rawtype(k);

            if (zK == "number") then
                nColumn = math.floor(k);

                if (nColumn <= _nColumnCount) then
                    sColumn = _tHeaders[nColumn];
                    vRet = tRow[sColumn];
                end

            elseif (zK == "string") then
                sColumn = _tHeadersCaseMap[k:upper()];

                if (sColumn ~= nil) then
                    vRet = tRow[sColumn];
                end

            end

            return vRet;
        end,
        __newindex = function() error("Attempt to write to read-only \"".._tRowTypes[sType].."\" at index "..nRow..".") end,
        __pairs = function(t) --TODO FIX NOT WORKING, MATH WRONG
            local nColumn = 0;
            local nMax   = #_tHeaders;

            return function()
                nColumn = nColumn + 1;

                if (nColumn <= nMax) then
                    local sColumn = _tHeaders[nColumn];
                    return nColumn, sColumn, tRow[sColumn];
                end

            end

        end,
        __len = function()
            return _nColumnCount;
        end,
        __type = _tRowTypes[sType],
    };
    local tRowDecoy = {};

    --set the metatable for the decoy row table used in the user env
    setmetatable(tRowDecoy, tRowMeta);

    --set the metatable for row (used to retrieve the decoy table created above)
    setmetatable(tRow, {
        __call = function()
            return tRowDecoy;
        end,
    });

end


--[[!
@fqxn CFS.Classes.ProcSys.CSV.Methods.UpdateGrids
@desc Loads the specified CSV file into the Base and Final data grids, rebuilds the column lookup tables, processes all data rows, refreshes the grids, and resets save state.
@param string pFile Full path to the CSV file to load.
@note Both grids are cleared and reloaded from the same source file. Row 0 is treated as the header row and is used to rebuild the column name and column ID maps. All data rows are processed immediately after loading, and the processed row cache and dirty row table are reset.
@vis Static Private
@todo redo this text as it needs updated to reflect the recent CSV changes
!]] --TODO SPLIT THIS FUNCTION into two...UpdateGrids
UpdateGrids = function(pFile)
    _bIsLoading     = true;
    UpdateGridsPrep();

    local tGrids = {
        [1] = {
            Name        = _sBaseDataGrid,
            File        = pFile,
            CSVTable    = _tCSVBase,
        },
        [2] = {
            Name = _sFinalDataGrid,
            CSVTable    = _tCSVFinal,
        }
    };

    --TODO next, apply row filter ALL (unless there's a previously-loaded filter)

    --configure the grids and load the data file
    for _, tGrid in ipairs(tGrids) do
        local sGrid = tGrid.Name;
        Grid.DeleteAllItems(sGrid);

        --TODO LEFT OFF HERE I need to manually load each row, checking it against the active row filter
        --apply row filter
        --_ActiveRowFilter
        Grid.SetFixedRowCount(      sGrid, 1);
        --Grid.SetFixedColumnCount(   sGrid, 1);
        Grid.SetRowCount(sGrid, _nRowCount);
        Grid.SetColumnCount(sGrid, _nColumnCount);
        Grid.SetToolTipsEnabled(    sGrid, false); --TODO at some point, allow user to set tooltips for rows in Info file
        --Grid.SetHeaderSort(         sGrid, false);
        --Grid.SetListMode(           sGrid, true);
        --Grid.ExpandColumnsToFit(    sGrid, true, true);
        --local nColumnID = _tHeadersIDMap["Description"];
        --Grid.SetColumnWidth(sGrid, nColumnID, _nDescriptionMaxWidth);

        --load the header row
        for nColumn, sColumn in ipairs(_tHeaders) do
            Grid.SetCellText(sGrid, 0, nColumn - 1, sColumn, false);
        end

        --load all the other rows
        for nRow, tRow in ipairs(tGrid.CSVTable) do

            for sColumn, sText in pairs(tRow) do
                local nColumn = _tHeadersIDMap[sColumn:upper()];
                Grid.SetCellText(sGrid, nRow, nColumn - 1, sText, false);
            end

        end

    end


    UpdateGridsFinalize();

    --set loading to finished
    MainMenu.SetEnabled("CardSet:>Save",        false);
    MainMenu.SetEnabled("CardSet:>Edit CSV",    true);
    _bAllowSave     = false;
    _bIsLoading     = false;
end


--[[!
@fqxn CFS.Classes.ProcSys.Methods.UpdateGridsPrep
@desc Prepares the Base and Final grids for a bulk update by clearing the status message and temporarily disabling redraw on both grids.
@note This prevents visual flicker and improves performance when many grid updates are about to occur.
@vis Static Private
!]]
UpdateGridsPrep = function()
    Grid.SetRedraw(_sBaseDataGrid, false);
    Grid.SetRedraw(_sFinalDataGrid, false);
end


--[[!
@fqxn CFS.Classes.ProcSys.Methods.UpdateGridsFinalize
@desc Applies the current grid visual settings, refreshes the Base and Final data grids, restores redraw, and requests a page redraw.
@note Grid colors and visual properties are loaded from the application INI using the pane sections for the Base and Final grid windows. Alternate row background colors are applied to even-numbered rows. The Description column width is explicitly set after refresh using the current column name map.
@vis Static Private
!]]
UpdateGridsFinalize = function ()--TODO FINISH MOVE Color stuff out to a theme system
    Application.SetRedraw(false);
    --adjust/refresh the appropriate grids QUESTION SHould this be after the refresh?
    --Grid.ExpandColumnsToFit(_sBaseDataGrid,     true, true);
    --Grid.ExpandColumnsToFit(_sFinalDataGrid,    true, true);
    --local nColumnID = _tColumnNameIDMap["Description"];
    --Grid.SetColumnWidth(_sBaseDataGrid, nColumnID, _nDescriptionMaxWidth);--TODO magick number
    --Grid.SetColumnWidth(_sFinalDataGrid, nColumnID, _nDescriptionMaxWidth);
    local nColumns = Grid.GetColumnCount(_sBaseDataGrid);


    local tAltColor = {
        [_sBaseDataGrid]    = -1,
        [_sFinalDataGrid]   = -1,
    };

    local function LoadColor(sSection, sColorValue)
    	local nColor;
    	local sColor = INIFile.GetValue(_pAppCFG, sSection, sColorValue):collapse();
    	local tColor = sColor:totable(',');

    	if (type(tColor) == "table" and #tColor == 3) then
    		local nRed 		= tonumber(tColor[1]);
    		local nGreen 	= tonumber(tColor[2]);
    		local nBlue 	= tonumber(tColor[3]);

    		if (nRed and nGreen and nBlue) then
    			nColor = Grid.MakeColorRGB(nRed, nGreen, nBlue);
    		end

    	end

    	return nColor;
    end

    local tGrids = {
    	[_sBaseDataGrid]   = tostring(_ePane.DATA_EDIT),
    	[_sFinalDataGrid]  = tostring(_ePane.DATA_VIEW),
    };

    local tItems = {
    	TextColor				= true,
    	TextBackgroundColor		= true,
        TextAltBackgroundColor  = true,
    	FixedTextColor			= true,
    	FixedBackgroundColor	= true,
    	GridLineColor			= true,
    	GridBackgroundColor		= true,
    	TitleTipBackgroundColor	= true,
    	TitleTipTextColor 		= true,
    };

    for sObject, sSection in pairs(tGrids) do
    	local tProps = {};

    	for sValue, __ in pairs(tItems) do

            if (sValue == "TextAltBackgroundColor") then
                tAltColor[sObject] = LoadColor(sSection, sValue);

            else
                tProps[sValue] = LoadColor(sSection, sValue);
            end


    	end

    	Grid.SetProperties(sObject, tProps);
    end

    for sObject, sSection in pairs(tGrids) do
        local tProps = {Background = tAltColor[sObject]};

        for nRow = 1, _nRowCount do--Grid.GetRowCount(sObject) do
            local bIsEven = nRow % 2 == 0;

            if (bIsEven) then

                for nColumn = 0, nColumns - 1 do
                    Grid.SetCellColors(sObject, nRow, nColumn, tProps, false);
                end

            end

        end

    end

    --local nColumnID             = _tColumnNameIDMap["ID"];
    local nColumnDescription    = _tHeadersIDMap["Description"]-- _tColumnNameIDMap["Description"];--TODO BUG FIX FINISH this muct be applied to ALL code columns

    --Grid.AutoSizeColumns(_sBaseDataGrid, GVS_DEFAULT, false);
    --Grid.AutoSizeColumns(_sFinalDataGrid, GVS_DEFAULT, false);
    Grid.Refresh(_sBaseDataGrid);
    Grid.SetRedraw(_sBaseDataGrid, true);
    Grid.Refresh(_sFinalDataGrid);
    Grid.SetRedraw(_sFinalDataGrid, true);
    Grid.SetColumnWidth(_sBaseDataGrid, nColumnDescription, 100);--TODO magick number THIS SHOULD NOT BE DONE HERE, THIS SHOULD BE GOTTEN FROM SET INI
    Grid.SetColumnWidth(_sFinalDataGrid, nColumnDescription, 100);--TODO magick number
    --Grid.SetColumnWidth(_sBaseDataGrid, nColumnID, 40);--TODO magick number
    --Grid.SetColumnWidth(_sFinalDataGrid, nColumnID, 40);--TODO magick number
    Application.SetRedraw(true);
    Page.Redraw();
end




--[[
██████╗ ██╗   ██╗██████╗ ██╗     ██╗ ██████╗
██╔══██╗██║   ██║██╔══██╗██║     ██║██╔════╝
██████╔╝██║   ██║██████╔╝██║     ██║██║
██╔═══╝ ██║   ██║██╔══██╗██║     ██║██║
██║     ╚██████╔╝██████╔╝███████╗██║╚██████╗
╚═╝      ╚═════╝ ╚═════╝ ╚══════╝╚═╝ ╚═════╝]]

--[[!
@fqxn CFS.Classes.ProcSys.Methods.EnsureRowProcessed
@desc Ensures the specified row has been processed and cached. If the row is marked dirty it will be reprocessed before returning the cached row table.
@param number nRow Row index to ensure is processed.
@return table tRow The processed row table from the internal row cache.
@note If the row is marked dirty it is processed immediately using ProcessRow and then removed from the dirty row table.
@vis Static Private
!]]
EnsureRowProcessed = function(nRow)

    if (_tDirtyRows[nRow]) then
        ProcessRow(nRow, true);
        _tDirtyRows[nRow] = nil;
    end

    return _tRows[nRow];
end


--[[!
@fqxn CFS.Classes.ProcSys.Methods.GetActiveRow
@desc Ensures
@param number nRow Row
@return table tRow The
!]]
GetActiveRow = function()--TODO DO i need type here? Yes. FIX
    local tRow = _tCSVFinal[_nCurrentRow];
    local tRowDecoy = tRow();
    return tRowDecoy;
end

--TODO LEFT OFF HERE...I redid this to use new system but all application of it use old access methods. Decide how to do this.
GetCellText = function(sType, vRow, vColumn)
    local nRow      = type(vRow) == "number"
    local nColumn   = vColumn

    if (type(sType) == "DATATYPE") then

        local bSuccessRow       = ValidatewRow(vRow - 1,        "CSV.GetCellText");
        local bSuccessColumn    = ValidatewColumn(vColumn - 1,  "CSV.GetCellText");

        if (bSuccessRow and bSuccessColumn) then
            --local tCSV = _tCSVTableByType[sType];
            --local tRow = tCSV[vRow];
        end

    else
        Log.Warning("CSV.GetCellText: Argument 1 must be of type 'DATATYPE'. Got "..type(sType)..'.');
    end

end


--[[!
@fqxn CFS.Classes.ProcSys.Methods.GetRow
@desc Builds and returns a read-only row table for the specified grid row. The returned table supports lookup by column index or column name and also supports reverse lookup of column names and indices through its call metamethod.
@param string sGrid Name of the grid to read from.
@param number nRow Row index to read.
@return table tRow Read-only row table exposing values by column index and upper-case column name.
@note The returned row table is backed by a metatable that prevents writes. Numeric indexing returns cell text by column index. String indexing returns cell text by upper-case column name. Calling the table with a number returns the upper-case column name for that index, and calling it with a string returns the column index for that name.
@example
    local tRow = GetRow(_sBaseDataGrid, 5)

    local sName = tRow["NAME"]
    local sType = tRow[2]

    local sColumnName = tRow(2)
    local nColumnID = tRow("Name")
@vis Static Private
!]]--TODO clean this up and remove useless table runs. Most of the internal tables can be deleted
GetRow = function(eDataType, nRow)
    local vRet;

    if (ValidatewRow(nRow, "CSV.GetRow") and type(eDataType) == "DATATYPE") then  --TODO create ValidteDataType function so it can show an error when failing

        if (nRow <= _nRowCount and nRow > 0) then
            vRet = _tCSVTableByType[eDataType][nRow];
        end

    end

    return vRet;
end



--[[!
@fqxn CFS.Classes.ProcSys.Methods.GetRowOLD
@desc Builds and returns a read-only row table for the specified grid row. The returned table supports lookup by column index or column name and also supports reverse lookup of column names and indices through its call metamethod.
@param string sGrid Name of the grid to read from.
@param number nRow Row index to read.
@return table tRow Read-only row table exposing values by column index and upper-case column name.
@note The returned row table is backed by a metatable that prevents writes. Numeric indexing returns cell text by column index. String indexing returns cell text by upper-case column name. Calling the table with a number returns the upper-case column name for that index, and calling it with a string returns the column index for that name.
@example
    local tRow = GetRow(_sBaseDataGrid, 5)

    local sName = tRow["NAME"]
    local sType = tRow[2]

    local sColumnName = tRow(2)
    local nColumnID = tRow("Name")
@vis Static Private
!]]--TODO clean this up and remove useless table runs. Most of the internal tables can be deleted
GetRowOLD = function(sGrid, nRow)
    local tRet      = {};

    local tByColumnID       = {};
    local tByColumnName     = {};
    local tColumns          = {};
    local tColumnIDsByName  = {};

    if _nColumnCount > 0 then

        for nColumn = 0, _nColumnCount - 1 do
            local sCellText             = GetCellText(sGrid, nRow, nColumn);
            --local sColumn               = --_tHeaders[nColumn]:upper();
            tByColumnID[nColumn]        = sCellText;
            tByColumnName[sColumn]      = sCellText;
            tColumns[nColumn]           = sColumn;
            tColumnIDsByName[sColumn]   = nColumn;
        end

    end

    local tRetMeta = {
        --returns the name or index of a column given the index or name
        __call = function(t, v)
            local zV = rawtype(v);

            if (zV == "number") then
                return tColumns[v] or nil;
            elseif (zV == "string") then
                return tColumnIDsByName[v:upper()];
            end
        end,
        __index = function(t, k)
            local vRet;
            local zK = type(k);
            local nColumn;
            local sColumn;

            --try to get the column name and number
            if (zK == "number") then
                --sRet = tByColumnID[k] or nil;
                nColumn = k;
                --sColumn = _tHeaders[nColumn];
            elseif (zK == "string") then
                sColumn = _tHeadersCaseMap[k:upper()];

                if (sColumn) then
                    nColumn = _tHeadersIDMap[sColumn];
                end
                --sRet = tByColumnName[k:upper()] or nil;
            end

            --if the column name and number are valid
            if (nColumn and sColumn) then
                 local tCodeColumn = _tCodeColumns[sColumn];

                if (tCodeColumn and tCodeColumn[nRow]) then--if it's a code column
                    --Log.Note(sColumn);
                    --Log.Note(type(_tCodeColumns[sColumn].CallReturn))
                    vRet = _tCodeColumns[sColumn][nRow].CallReturn;
                else --otherwise
                    vRet = tByColumnID[nColumn];
                end

            end

            return vRet;
        end,
        __newindex = function() error("Cannot write to read-only row table for grid \""..sGrid.."\" at row index "..nRow..".") end,
        __pairs = function(t) --TODO FIX NOT WORKING, MATH WRONG
            local nIndex = 0;
            local nMax   = #tByColumnID;

            return function()
                nIndex = nIndex + 1;

                if (nIndex <= nMax) then
                    return nIndex, tColumns[nIndex], tByColumnID[nIndex];
                end

            end

        end,
        __len = function()
            return _nColumnCount;
        end,
        __type = _tRowTypes[sGrid],
    };
    setmetatable(tRet, tRetMeta);

    return tRet;
end




--[[
IsCodeColumn = function(nColumn)
    ValidatewColumn(vColumn, "CSV.IsCodeColumn")
    local _tHeaders[nColumn];
    _tCodeColumns
    local tCodeColumn   = _tCodeColumns[sHeader];
end
]]

IsRowDirty = function(nRow)
    return _tDirtyRows[nRow] ~= nil;
end

IsActiveRowDirty = function(nRow)
    return _tDirtyRows[_nCurrentRow] ~= nil;
end




--[[!
@fqxn CFS.Classes.ProcSys.CSV.Methods.LoadFromFile
@desc Loads the specified CSV file into the _tCSV and _tHeaders table.
@param string pFile Full path to the CSV file to load.
@note --Assumes file path if good (for now). May change later
@vis Static Private
!]]
LoadFromFile = function(pFile)
    --load the CSV file
    _tCSVBase, _tHeaders = FTCSV.parse(pFile);

    --reset the final csv table
    _tCSVFinal          = {};
    _tCSVTableByType    = {[_eDATATYPE.BASE] = _tCSVBase, [_eDATATYPE.FINAL] = _tCSVFinal};

    --update the card set's grid values
    _nRowCount          = #_tCSVBase;
    _nColumnCount       = #_tHeaders;

    --reset the rows, dirty rows, and header case/ID map tables
    --_tRows      = {}; --TODO QUESTION..IS THIS NEEDED?
    _tDirtyRows         = {};
    _tHeadersCaseMap    = {};
    _tHeadersIDMap      = {};

    --create the header maps
    for nColumn, sColumn in ipairs(_tHeaders) do
        local sHeaderUpper              = sColumn:upper();
        _tHeadersCaseMap[sHeaderUpper]  = sColumn;
        --p(type(sHeaderUpper), type(sColumn))
        _tHeadersIDMap[sHeaderUpper]    = nColumn;
        --_tHeadersIDMap[sColumn] = nColumnID;

        --check the headers for restricted column names
        for sRestrictedColumn, _ in pairs(_tRestrictedColumnNames) do

            --throw an error and stop loading the CSV if any restricted column names are being used
            if (sRestrictedColumn == sHeaderUpper) then
                error("CSV.LoadFromFile: Error loading CSV at path '"..pFile.."'.\r\nContains restricted column name, '"..sColumn.."'.");
            end

        end

    end


    --build NoProc column ID map (case-insensitive) and check required columns
    _tColumnNoProcIDs = {};

    for sColumnUpper, bRequired in pairs(_tRequiredColumns) do
        local sColumn = _tHeadersCaseMap[sColumnUpper];

        if not (sColumn) then
            error("Required column, '"..sColumnUpper.."', not found in CSV file at path '"..pFile.."'.", 2);
        end

        local nColumnID = _tHeadersIDMap[sColumnUpper];

        if (nColumnID ~= nil and nColumnID ~= -1) then
            _tColumnNoProcIDs[nColumnID] = true;
        end

    end

    --process all rows
    for nRow, tRow in ipairs(_tCSVBase) do
        --build the metatable for the row in the base csv table
        BuildRowMetatable(nRow, tRow, _tCSVBase);

        --create the first entry of this row in the final csv table
        _tCSVFinal[nRow] = {};

        for nColumn, sColumn in ipairs(_tHeaders) do
            _tCSVFinal[nRow][sColumn] = '';
        end
        BuildRowMetatable(nRow, _tCSVFinal[nRow], _tCSVFinal);

        --process the row
        ProcessRow(nRow, true);
    end

    return _nRowCount, _nColumnCount;
end






--[[!
@fqxn CFS.Classes.ProcSys.Methods.MarkAllRowsDirty
@desc Marks all data rows as dirty so they will be reprocessed during the next processing cycle.
@note The dirty row table is reset and every data row index is inserted. Header row 0 is excluded and rows are marked from 1 through the last data row.
@vis Static Private
!]]
MarkAllRowsDirty = function()
    _tDirtyRows = {};

    for nRow = 1, _nRowCount do
        _tDirtyRows[nRow] = true;
    end

end


--[[!
@fqxn CFS.Classes.ProcSys.Methods.MarkRowDirty
@desc Marks a single data row as dirty so it will be reprocessed during the next processing cycle.
@param number nRow Row index to mark dirty.
@note The row index must be within the valid data range (1 through the last data row). An error is raised if the argument is not a number or falls outside the valid range.
@vis Static Private
!]]
MarkRowDirty = function(nRow)

    if (rawtype(nRow) ~= "number") then
        error("ProcSys - MarkRowDirty: row index must be number. Got "..rawtype(nRow)..".", 2);
    end

    if (nRow < 1 or nRow >= _nRowCount) then
        error("ProcSys - MarkRowDirty: row index out of range. Got "..tostring(nRow)..", expected 1-"..tostring(_nRowCount - 1)..".", 2);
    end

    _tDirtyRows[nRow] = true;
end




--TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO
--[[!
    @fqxn CFS.Classes.ProcSys.Methods.ProcessCell
    @desc Processes a single base grid cell into the final grid and returns data for redraw/export.
    @param number nRow Row index of the cell being processed.
    @param number nColumn Column index of the cell being processed.
    @note
        <ul>
            <li>Calls the processor's public static <code>ProcessCell</code> when available; otherwise copies base text through.</li>
            <li>Provides <code>fGetFinalValue</code> to the processor to read processed values from prior columns.</li>
        </ul>
    @vis Static Private
!]]
ProcessCell = function(nRow, nColumn)
    local sHeader       = _tHeaders[nColumn];
    local sText         = _tCSVBase[nRow][sHeader]--GetCellText(_sBaseDataGrid, nRow, nColumn);
    local tCodeColumn   = _tCodeColumns[sHeader];

--    if not (rawtype(sText) == "string") then --QUESTION IS THIS REQUIRED? Won't there always be text except for out of bounds which can't happen here?
    --    return;
    --end

    --handle no proc columns
    if (_tColumnNoProcIDs[nColumn]) then
        --SetCellText(_sFinalDataGrid, nRow, nColumn, sText);
        _tCSVFinal[nRow][sHeader] = sText;
    --handle code columns
    elseif (tCodeColumn) then
        local tCodeCell = tCodeColumn[nRow];
--Log.Note(UserEnv.Get()._tRow.Name)
        --check if the cell text has changed
        if (tCodeCell.Text ~= sText) then

            if (sText:isempty()) then
                --if empty, reset the code cell's values
                ResetCodeCellTable(nRow, sHeader);
            else
                --if not empty, attempt to create the function
                local sCode = dec(sText);
                local fChunk, sError = load(sCode, "Code Column Error for Card: \""..GetCellText(_sBaseDataGrid, nRow, _tHeadersIDMap["NAME"]).."\" ".."(Row "..tostring(nRow)..", CodeColumn '"..sHeader.."').", "t", UserEnv.Get());

                tCodeCell.Code        = sCode;
                tCodeCell.Column      = sHeader;
                tCodeCell.Error       = sError or "";
                tCodeCell.Function    = false;
                tCodeCell.IsValid     = false;
                tCodeCell.Row         = nRow;
                tCodeCell.Text        = sText;



                if (sError) then
                    tCodeCell.Error = sError;
                    Log.Warning(sError); --warn the user of bad code
                    SetCellText(_sFinalDataGrid, nRow, nColumn, "ERROR");
                else
                    local bOK, vReturnOrError = xpcall(fChunk, XPCallError);

                    if (bOK and rawtype(vReturnOrError) == "function") then
                        tCodeCell.Function    = vReturnOrError;
                        tCodeCell.IsValid     = true;
                        SetCellText(_sFinalDataGrid, nRow, nColumn, "COMPILED");
                    else
                        tCodeCell.Error = bOK and "Code column must return a function." or vReturnOrError;
                        Log.Warning(tCodeCell.Error);
                        SetCellText(_sFinalDataGrid, nRow, nColumn, "ERROR");
                    end

                end

            end

            --call the function if it's valid
            tCodeCell = tCodeColumn[nRow];
            if tCodeCell.IsValid then

                --get the active row and store it
                local tOldRow = UserEnv.Get()._tRow;            --FIX Attempt: code columns were using other (old) row data. Hopefully this fixes it.
                --get this cell's row base data
                local tMyRow  = _tCSVBase[nRow]; --GetRow(_sBaseDataGrid, nRow);   --FIX Attempt: code columns were using other (old) row data. Hopefully this fixes it.
                --update the user env to use this cell's row
                UserEnv.ProcSysUpdateRoot({_tRow = tMyRow});    --FIX Attempt: code columns were using other (old) row data. Hopefully this fixes it.
                --execute the column code function
                local bOK, vReturnOrError = xpcall(tCodeCell.Function, XPCallError);
                --put the user env back the way we found it
                UserEnv.ProcSysUpdateRoot({_tRow = tOldRow});   --FIX Attempt: code columns were using other (old) row data. Hopefully this fixes it.

                if bOK then
                    tCodeCell.CallReturn = vReturnOrError
                else
                    Log.Warning(vReturnOrError);
                end

            else
                tCodeCell.CallReturn = nil;
            end

        end

    else
        local function GetFinalValue(sHeader, vCoerce)
            local sHeaderUpper = sHeader:upper();

            if not (_tHeadersIDMap[sHeaderUpper]) then
                error("GetFinalValue: Expected existing column. Got "..tostring(sHeader)..' ('..rawtype(sHeader)..').', 2);
            end

            local vRet = GetCellText(_sFinalDataGrid, nRow, _tHeadersIDMap[sHeaderUpper]);
            local nCoerce = rawtype(vCoerce) == "number" and vCoerce or nil;

            if (nCoerce == PROCSYS_TO_NUMBER) then
                local vRetCollapsed = vRet:collapse();
                vRet = tonumber(vRetCollapsed) or vRet; --TODO QUESTION SHOULD THIS FAIL with error msg INSTEAD???
            --elseif (nCoerce == PROCSYS_TO_TABLE) then TODO

            end

            return vRet;
        end

        local vProcRet = _fRowProc(nRow, nColumn, sHeader, GetRow(_eDATATYPE.BASE, nRow), sText, GetFinalValue);

        if (rawtype(vProcRet) == "string") then
            ---update the cell's text
            Grid.SetCellText(_sFinalDataGrid, nRow, nColumn, vProcRet);
        else
            Grid.SetCellText(_sFinalDataGrid, nRow, nColumn, sText);
        end

    end

    --TODO Also, be sure to add function to the env that indicates if a given column as been processed (basically if Column_A.index Column_< B.index)
end

--[[
[ERROR > 2026-08-05 @ 20:29:35]
Error: attempt to index a nil value (local 'tRow')

Stack Traceback:

1: [string "Unit RowProc"] Line: 6 in function '_fRowProc'
2: [.\AutoPlay\Scripts\ProcSys\CSV.lua] Line: 1004 in function 'ProcessCell'
3: [.\AutoPlay\Scripts\ProcSys\CSV.lua] Line: 1194 in function 'ProcessRow'
4: [.\AutoPlay\Scripts\ProcSys\CSV.lua] Line: 549 in function 'EnsureRowProcessed'
5: [.\AutoPlay\Scripts\ProcSys.lua] Line: 991 in function 'OnSelectionChanged'
6: [Forge -> grd Base data -> On Selection Changed] Line: 1 in main chunk
]]

ProcessCellOLD = function(nRow, nColumn)
    local sColumn       = _tHeaders[nColumn];
    local sHeader       = _tHeaders[nRow];
    local sText         = _tCSVBase[sHeader]--GetCellText(_sBaseDataGrid, nRow, nColumn);
    local tCodeColumn   = _tCodeColumns[sColumn];

--    if not (rawtype(sText) == "string") then --QUESTION IS THIS REQUIRED? Won't there always be text except for out of bounds which can't happen here?
    --    return;
    --end


    --handle no proc columns
    if (_tColumnNoProcIDs[nColumn]) then
        --SetCellText(_sFinalDataGrid, nRow, nColumn, sText);
        _tCSVFinal[nRow][sHeader] = sText;
    --handle code columns
    elseif (tCodeColumn) then
        local tCodeCell = tCodeColumn[nRow];
--Log.Note(UserEnv.Get()._tRow.Name)
        --check if the cell text has changed
        if (tCodeCell.Text ~= sText) then

            if (sText:isempty()) then
                --if empty, reset the code cell's values
                ResetCodeCellTable(nRow, sColumn);
            else
                --if not empty, attempt to create the function
                local sCode = dec(sText);
                local fChunk, sError = load(sCode, "Code Column Error for Card: \""..GetCellText(_sBaseDataGrid, nRow, _tHeadersIDMap["NAME"]).."\" ".."(Row "..tostring(nRow)..", CodeColumn '"..sColumn.."').", "t", UserEnv.Get());

                tCodeCell.Code        = sCode;
                tCodeCell.Column      = sColumn;
                tCodeCell.Error       = sError or "";
                tCodeCell.Function    = false;
                tCodeCell.IsValid     = false;
                tCodeCell.Row         = nRow;
                tCodeCell.Text        = sText;



                if (sError) then
                    tCodeCell.Error = sError;
                    Log.Warning(sError); --warn the user of bad code
                    SetCellText(_sFinalDataGrid, nRow, nColumn, "ERROR");
                else
                    local bOK, vReturnOrError = xpcall(fChunk, XPCallError);

                    if (bOK and rawtype(vReturnOrError) == "function") then
                        tCodeCell.Function    = vReturnOrError;
                        tCodeCell.IsValid     = true;
                        SetCellText(_sFinalDataGrid, nRow, nColumn, "COMPILED");
                    else
                        tCodeCell.Error = bOK and "Code column must return a function." or vReturnOrError;
                        Log.Warning(tCodeCell.Error);
                        SetCellText(_sFinalDataGrid, nRow, nColumn, "ERROR");
                    end

                end

            end

            --call the function if it's valid
            tCodeCell = tCodeColumn[nRow];
            if tCodeCell.IsValid then

                --get the active row and store it
                local tOldRow = UserEnv.Get()._tRow;            --FIX Attempt: code columns were using other (old) row data. Hopefully this fixes it.
                --get this cell's row base data
                local tMyRow  = GetRow(_eDATATYPE.BASE, nRow);   --FIX Attempt: code columns were using other (old) row data. Hopefully this fixes it.
                --update the user env to use this cell's row
                UserEnv.ProcSysUpdateRoot({_tRow = tMyRow});    --FIX Attempt: code columns were using other (old) row data. Hopefully this fixes it.
                --execute the column code function
                local bOK, vReturnOrError = xpcall(tCodeCell.Function, XPCallError);
                --put the user env back the way we found it
                UserEnv.ProcSysUpdateRoot({_tRow = tOldRow});   --FIX Attempt: code columns were using other (old) row data. Hopefully this fixes it.

                if bOK then
                    tCodeCell.CallReturn = vReturnOrError
                else
                    Log.Warning(vReturnOrError);
                end

            else
                tCodeCell.CallReturn = nil;
            end

        end

    else
        local function GetFinalValue(sColumn, vCoerce)

            if not (_tHeadersIDMap[sColumn]) then --TODO FIX DFO't I need upper here and below?
                error("GetFinalValue: Expected existing column. Got "..tostring(sColumn)..' ('..rawtype(sColumn)..').', 2);
            end

            local vRet = GetCellText(_sFinalDataGrid, nRow, _tHeadersIDMap[sColumn]);
            local nCoerce = rawtype(vCoerce) == "number" and vCoerce or nil;

            if (nCoerce == PROCSYS_TO_NUMBER) then
                local vRetCollapsed = vRet:collapse();
                vRet = tonumber(vRetCollapsed) or vRet; --TODO QUESTION SHOULD THIS FAIL with error msg INSTEAD???
            --elseif (nCoerce == PROCSYS_TO_TABLE) then TODO

            end

            return vRet;
        end

        local vProcRet = _fRowProc(nRow, nColumn, sColumn, GetRow(_eDATATYPE.BASE, nRow), sText, GetFinalValue);

        if (rawtype(vProcRet) == "string") then
            ---update the cell's text
            Grid.SetCellText(_sFinalDataGrid, nRow, nColumn, vProcRet);
        else
            Grid.SetCellText(_sFinalDataGrid, nRow, nColumn, sText);
        end

    end

    --TODO Also, be sure to add function to the env that indicates if a given column as been processed (basically if Column_A.index Column_< B.index)
end




--[[!
@fqxn CFS.Classes.ProcSys.Methods.ProcessDirtyRows
@desc Processes rows that have been marked dirty, rebuilding their processed values and updating the cached row table.
@note The currently selected row is processed first if it is dirty and does not count toward the processing budget. Remaining dirty rows are processed until the timer budget is exhausted, and each processed row is removed from the dirty row table.
@vis Static Private
!]]
ProcessDirtyRows = function()
    local nBudget = _nRowProcTimerBudget;

    --check if current row is dirty first
    if (_tDirtyRows[_nCurrentRow]) then
        ProcessRow(_nCurrentRow);
    end

    for nRow in pairs(_tDirtyRows) do
        ProcessRow(nRow, true);

        nBudget = nBudget - 1;
        if (nBudget <= 0) then
            break;
        end

    end

end









--[[!
@fqxn CFS.Classes.ProcSys.Methods.ProcessRow
@desc Reprocesses a single data row by executing the cell processing logic for each column, rebuilding the processed row data, and updating the internal row cache.
@param number nRow Row index to process.
@param boolean bSkipExtUpdate When true, the UserEnv and Forge active row are not updated after processing.
@note The row is removed from the dirty row table before processing begins. Each column in the row is processed using ProcessCell, and the resulting final grid row is cached in the internal row table for fast lookup.
@vis Static Private
!]]
ProcessRow = function(nRow, bSkipExtUpdate)
    --inform the system that this row has been processed
    _tDirtyRows[nRow] = nil;

    --reprocess the row
    --Grid.SetRedraw(_sBaseDataGrid, false); --TODO this may work to speed things up a bit, check it out
    for nColumn = 1, _nColumnCount - 1 do
        ProcessCell(nRow, nColumn);
    end
    --Grid.SetRedraw(_sBaseDataGrid, true);

    --get the final row
    local tRow  = GetRow(_eDATATYPE.FINAL, nRow);

    --store the row for later, quick lookup
    _tRows[nRow] = tRow;

    if not (bSkipExtUpdate) then
        --update the final row in the UserEnv
        UserEnv.ProcSysUpdateRoot {_tRow = tRow};
        --update the Forge's active row
        Forge.SetActiveRow(tRow);
    end

end


ResetCodeCellTable = function(nRow, sCodeColumn)

    if not (_tCodeColumns[sCodeColumn]) then
        _tCodeColumns[sCodeColumn] = {};
    end

    _tCodeColumns[sCodeColumn][nRow] = {
        CallReturn  = nil,
        Code        = false,
        Column      = sCodeColumn,
        Error       = false,
        Function    = false,
        IsValid     = false,
        Row         = nRow,
        Text        = "",
    };

    SetCellText(_sFinalDataGrid, nRow, _tHeadersIDMap[sCodeColumn], ""); --TODO FIX Use Uppercase here?
end


OnSelectionChanged = function(nRow, nColumn)
    local bSuccessRow       = ValidatewRow(nRow,        "CSV.OnSelectionChanged");
    local bSuccessColumn    = ValidatewColumn(nColumn,  "CSV.OnSelectionChanged");

    if (bSuccessRow and bSuccessColumn) then
        _nCurrentRow    = nRow;
        _nCurrentColumn = nColumn;

        --update the current row and column if needed
        if (_nCurrentRow >= _nRowCount) then
            _nCurrentRow = _nRowCount;
        end

        if (_nCurrentColumn >= _nColumnCount) then
            _nCurrentColumn = _nColumnCount;
        end

        --if it's a special column, fire up the editor
        local sColumn = _tHeaders[nColumn];
        local tCodeColumn = _tCodeColumns[sColumn];

        if (tCodeColumn) then
            local pScratch = FS.Game.Scratch;
            --prep the temp file and load the editor
            local sOldCode = GetCellText(_sBaseDataGrid, nRow, nColumn);
            sOldCode = sOldCode:isempty() and sOldCode or dec(sOldCode);
            TextFile.WriteFromString(pScratch, sOldCode, false);--TODO FILE ERROR CHECK
            --Application.Sleep(200);
            --open the editor
            File.Run(_pLiteXL, '"'..pScratch..'"', FS.Game.Temp, SW_SHOWNORMAL, true);
            --TODO LEFT OFF HERE
            --get the new code from the temp file and write it the cell
            local sNewCode = TextFile.ReadToString(pScratch); --TODO FILE ERROR CHECK
            SetCellText(_sBaseDataGrid, nRow, nColumn, enc(sNewCode));
        end

    end

end





--TODO FINISH SET COLUMN WIDTH IN GRID FOR EACH CODE COLUMN using AppCFG Settings>CodeColumnWidth or 100
--[[!
@fqxn CFS.Classes.ProcSys.Methods.UpdateCodeColumns
@desc Rebuilds the internal code column registry based on the current CodeColumns definition file and regenerates compiled code entries for each referenced column.
@note The CodeColumns definition is parsed from the live file contents and matched against existing grid column names using the column name case map. Columns no longer referenced are removed from the internal registry. Each referenced column is rebuilt by scanning all data rows and updating the compiled code cell entries.
@vis Static Private
!]]
UpdateCodeColumns = function(sCodeColumns)
    local tCodeColumns = sCodeColumns:totable("\n");

    if not (rawtype(tCodeColumns) == "table" and #tCodeColumns > 0) then
        _tCodeColumns = {};
        MarkAllRowsDirty();
        return;
    end

    local tReferenced = {};

    for _, sKey in pairs(tCodeColumns) do
        local sColumn = _tHeadersCaseMap[sKey:upper()];

        if (sColumn) then
            tReferenced[sColumn] = true;
        end
    end

    for sCodeColumn in pairs(_tCodeColumns) do
        if not (tReferenced[sCodeColumn]) then
            _tCodeColumns[sCodeColumn] = nil;
        end
    end

    for sCodeColumn in pairs(tReferenced) do
        local nColumn = _tHeadersIDMap[sCodeColumn]; --TODO FIX Use uppercase here?

        if (nColumn ~= nil and nColumn ~= -1) then
            --_tCodeColumns[sCodeColumn] = {};

            for nRow = 1, _nRowCount - 1 do
                ResetCodeCellTable(nRow, sCodeColumn);
            end

        end
    end

    MarkAllRowsDirty();
end






--TODO FINISH DOX
UpdateRowFilters = function()
    --initialize the _tRowFilters table and include built-in row filters
    local pFile = FILE_BUILT_IN_ROW_FILTERS;
    local sBuiltInRowFilters = TextFile.ReadToString(pFile);
    _tRowFilters = RowFilter.BuildAllFromString(sBuiltInRowFilters, "Built-in");

    --include user row filters
    pFile = FS.Game.RowFilters;
    if not (File.DoesExist(pFile)) then
        error("Error building row filters from file, '"..pFile.."'. File not found.");
    end

    local sUserRowFilters = TextFile.ReadToString(pFile);
    local tUserRowFilters = RowFilter.BuildAllFromString(sUserRowFilters, "User");

    for _, oRowFilter in ipairs(tUserRowFilters) do
        --_tRowFilters[#_tRowFilters + 1] = oRowFilter;
        _tRowFilters[oRowFilter.Name] = oRowFilter;
    end

    --sort the filters by name
    table.sort(_tRowFilters,
        function(a, b)
            return a.Name < b.Name;
        end
    )

    --update filters menu
    MainMenu.RefreshRowFilters(_tRowFilters);
end

--ASSUMES function!
UpdateRowProc = function(fRowProc)
    _fRowProc = fRowProc;
end

local tCSV = {
    DATATYPE            = _eDATATYPE,
    ApplyRowFilter      = ApplyRowFilter,
    EnsureRowProcessed  = EnsureRowProcessed,
    GetActiveRow        = GetActiveRow,
    GetRow              = GetRow,
    IsActiveRowDirty    = IsActiveRowDirty,
    IsRowDirty          = IsRowDirty,
    LoadFromFile        = LoadFromFile,
    MarkAllRowsDirty    = MarkAllRowsDirty,
    MarkRowDirty        = MarkRowDirty,
    OnSelectionChanged  = OnSelectionChanged ,
    ProcessCell         = ProcessCell,
    ProcessDirtyRows    = ProcessDirtyRows,
    UpdateActiveCell    = UpdateActiveCell,
    UpdateCodeColumns   = UpdateCodeColumns,
    UpdateGrids         = UpdateGrids,
    UpdateRowFilters    = UpdateRowFilters,
    UpdateRowProc       = UpdateRowProc,
};

return setmetatable({}, {
    __index = function(t, k)
        return tCSV[k] or nil;
    end,
    __newindex = function(t, k, v)
        error("Error: attempt to write to read-only CSV module.", 2);
    end,
    __metatable = false,
});
