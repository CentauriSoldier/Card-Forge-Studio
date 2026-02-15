--[[!
    @fqxn CFS.Classes.ProcSys.Private Static Fields._tProcResolvers
    @desc TODO
!]]
local _tProcResolvers       = {}; --indexed by game name, value is proc resolver funciton
local _tExporters           = {};

--local _sActiveProcessor     = ""; --the name of the processing function (as regsitered)
local _sCSVDelimiter        = CSV_DELIMITER;
local _bAllowSave           = false;
local _pActiveCSV           = "";
local _pExportCSV           = "";
local _bAutoSizeGrid        = true;
local _sBaseDataGrid        = "grd base data";
local _sFinalDataGrid       = "grd final data";
local _bIsLoading           = false;
local _cForge               = null;
--local _RedrawOnCellChanged  = true;
local _nDescriptionMaxWidth = 100;
local class                 = class;
local _nCurrentRow          = -1;
local _nCurrentColumn       = -1;
local _sSetName             = "";
local _nLastRow             = -1;

local _tWindows             = {}; --stores windows
local bWindowsBuilt         = false;

--[[!
    @fqxn CFS.Classes.ProcSys.Enums.PANE
    @desc Identifiers for ProcSys window panes.
    <ul>
        <li>DATA_EDIT – Base data editor pane.</li>
        <li>DATA_VIEW – Final data viewer pane.</li>
    </ul>
!]]
enum("PANE", {"DATA_EDIT", "DATA_VIEW"});

--local _nCurrentRow          = 0;
--local _nCurrentColumn       = 0;

--[[!
    @fqxn CFS.Classes.ProcSys.Constants
    @desc ProcSys grid identifier constants.
    <ul>
       <li><code>GRID_BASE</code> – Identifier for the base (source) data grid.</li>
       <li><code>GRID_FINAL</code> – Identifier for the final (processed) data grid.</li>
   </ul>
!]]
constant("GRID_BASE",   _sBaseDataGrid);
constant("GRID_FINAL",  _sFinalDataGrid);


--[[!
    @fqxn CFS.Classes.ProcSys.StaticPrivate.Methods.TryDrawCard
    @desc Attempts to draw the card for the given row using the resolved processor.
    @param class cProc Processor class providing the DrawCard method.
    @param number nRow Row index being drawn.
    @param table tRow Final grid row data for the card.
    @note
        <ul>
            <li>Sets Forge orientation based on row data.</li>
            <li>Optionally exports the card when the corresponding menu option is enabled.</li>
        </ul>
!]]
local function TryDrawCard(cProc, nRow, tRow)

    if (cProc and type(cProc.DrawCard) == "function" and nRow > 0) then

        --make sure there's data in the row
        if (#tRow > 0) then
            --set the Forge's orientation
            local nOrientation = tonumber(tRow.IsVertical);
            local nOrientation = (type(nOrientation) == "number" and nOrientation == HOR) and HOR or VER;
            _cForge.SetOrientation(nOrientation);

            --check for export call
            local fExport = _tExporters[_sGame][_pActiveCSV];
            local bExport = MainMenu.IsChecked("Options:>Draw:>Export Selected Card") and rawtype(fExport) == "function";

            --tell Forge to draw (and possibly export) the card
            _cForge.DrawCard(cProc, tRow, bExport, fExport);
        end

    end

end





local function PrepUpdateGrids()
    Status.Set("");
    Grid.SetRedraw(_sBaseDataGrid, false);
    Grid.SetRedraw(_sFinalDataGrid, false);
end

local function UpdateGrids()--TODO FINISH MOVE Color stuff out to a theme system
    --adjust/refresh the appropriate grids QUESTION SHould this be after the refresh?
    --Grid.ExpandColumnsToFit(_sBaseDataGrid,     true, true);
    --Grid.ExpandColumnsToFit(_sFinalDataGrid,    true, true);
    --local nColumnID = Grid.GetColumnIDByName(_sBaseDataGrid, "Description");
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
    			nColor =Grid.MakeColorRGB(nRed, nGreen, nBlue);
    		end

    	end

    	return nColor;
    end

    local tGrids = {
    	[_sBaseDataGrid]   = tostring(PANE.DATA_EDIT),
    	[_sFinalDataGrid]  = tostring(PANE.DATA_VIEW),
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

        for nRow = 1, Grid.GetRowCount(sObject) do
            local bIsEven = nRow % 2 == 0;

            if (bIsEven) then

                for nColumn = 0, nColumns - 1 do
                    Grid.SetCellColors(sObject, nRow, nColumn, tProps, false);
                end

            end

        end

    end

    --local nColumnID             = Grid.GetColumnIDByName(_sBaseDataGrid, "ID");
    local nColumnDescription    = Grid.GetColumnIDByName(_sBaseDataGrid, "Description");

    --Grid.AutoSizeColumns(_sBaseDataGrid, GVS_DEFAULT, false);
    --Grid.AutoSizeColumns(_sFinalDataGrid, GVS_DEFAULT, false);
    Grid.Refresh(_sBaseDataGrid);
    Grid.SetRedraw(_sBaseDataGrid, true);
    Grid.Refresh(_sFinalDataGrid);
    Grid.SetRedraw(_sFinalDataGrid, true);
    Grid.SetColumnWidth(_sBaseDataGrid, nColumnDescription, 100);--TODO magick number THIS SHOULD NOT BE DONE HERE
    Grid.SetColumnWidth(_sFinalDataGrid, nColumnDescription, 100);--TODO magick number
    --Grid.SetColumnWidth(_sBaseDataGrid, nColumnID, 40);--TODO magick number
    --Grid.SetColumnWidth(_sFinalDataGrid, nColumnID, 40);--TODO magick number
end




--[[!
    @fqxn CFS.Classes.ProcSys.StaticPrivate.Methods.ProcessCell
    @desc Processes a single base grid cell into the final grid and returns data for redraw/export.
    @param number nRow Row index of the cell being processed.
    @param number nColumn Column index of the cell being processed.
    @return class cProc Resolved processor class for the row.
    @return table tRow Final grid row data after the cell is updated.
    @note
        <ul>
            <li>Calls the processor's public static <code>ProcessCell</code> when available; otherwise copies base text through.</li>
            <li>Provides <code>fGetFinalValue</code> to the processor to read processed values from prior columns.</li>
        </ul>
!]]
local function ProcessCell(nRow, nColumn)
    local cProc     = ProcSys.GetProc(nRow, _sBaseDataGrid);
    local sNewText  = Grid.GetCellText(_sBaseDataGrid, nRow, nColumn);
    local sProcText = sNewText;
    local tBaseRow  = Grid.GetRow(_sBaseDataGrid, nRow);

    --try to call the row's custom cell processor
    if (cProc and class.haspublicmember(cProc, "ProcessCell")) then
        local sColumn = Grid.GetCellText(_sBaseDataGrid, 0, nColumn);

        --may be used by the proc's cell processor to get final values
        local function GetFinalValue(sColumn)
            return Grid.GetCellText(_sFinalDataGrid, nRow, Grid.GetColumnIDByName(_sFinalDataGrid, sColumn));
        end

        sProcText = cProc.ProcessCell(nRow, nColumn, sColumn, tBaseRow, sNewText, GetFinalValue) or sNewText;
    end

    ---update the cell's text
    Grid.SetCellText(_sFinalDataGrid, nRow, nColumn, sProcText);
    --get the row after modifications
    local tFinalRow = Grid.GetRow(_sFinalDataGrid, nRow);

    --send back info for the card redraw attempt
    return cProc, tFinalRow;
end


--[[!
    @fqxn CFS.Classes.ProcSys.StaticPrivate.Methods.LoadFileToGrid
    @desc Loads a CSV into the base grid, rebuilds the final grid by processing all cells, and refreshes the UI.
    @param string pFile Path to the CSV to load.
    @note Disables saving while loading and re-enables normal editing after completion.
!]]

local function LoadFileToGrid(pFile)
    _bIsLoading = true;
    PrepUpdateGrids();

    local tGrids = {
        [1] = {
            Name = _sBaseDataGrid,
            File = pFile,
        },
        [2] = {
            Name = _sFinalDataGrid,
        }
    };

    --confgure the grids and load the file(s)
    for _, tGrid in ipairs(tGrids) do
        local sGrid = tGrid.Name;
        Grid.DeleteAllItems(        sGrid);
        Grid.LoadFromFile(          sGrid, tGrids[1].File, _sCSVDelimiter, _bAutoSizeGrid);
        Grid.SetFixedRowCount(      sGrid, 1);
        --Grid.SetFixedColumnCount(   sGrid, 1);
        Grid.SetToolTipsEnabled(    sGrid, false);
        --Grid.SetHeaderSort(         sGrid, false);
        --Grid.SetListMode(           sGrid, true);
        --Grid.ExpandColumnsToFit(    sGrid, true, true);
        --local nColumnID = Grid.GetColumnIDByName(_sBaseDataGrid, "Description");
        --Grid.SetColumnWidth(sGrid, nColumnID, _nDescriptionMaxWidth);
    end



    for nRow = 1, Grid.GetRowCount(_sBaseDataGrid) - 1 do

        for nColumn = 1, Grid.GetColumnCount(_sBaseDataGrid) - 1 do
            ProcessCell(nRow, nColumn);
        end

    end

    UpdateGrids();

    --set loading to finished
    _bAllowSave = false;
    xButton.SetEnabled("btn save data", false);
    _bIsLoading = false;
end


--[[!
    @fqxn CFS.Classes.ProcSys.StaticPrivate.Methods.TryBackupFile
    @desc Creates a timestamped backup of a CSV file when backup rules allow.
    @param string pFile Path to the source CSV file.
    @return boolean bWritten True if a new backup file was created.
    @note
        <ul>
            <li>Backups are stored per CSV in a dedicated folder.</li>
            <li>Backup creation is gated by minimum time interval and max file count.</li>
            <li>Oldest backups are deleted when retention limits are exceeded.</li>
        </ul>
!]]
local function TryBackupFile(pFile)--tFiles)
    --local pFile = tFiles[1];
    local tParts = String.SplitPath(pFile);

    --create this csv's backup folder (if it doesn't exist)
    local sFilename = tParts.Filename;
    local pFolder = _pCSVBackup.."\\"..sFilename;

    if not (Folder.DoesExist(pFolder)) then
        Folder.Create(pFolder);
    end

    --find all the csv files in this folder
    local tFiles        = File.Find(pFolder.."\\", "*.csv", false, false, nil, nil);--FoundCallback);
    local bWriteFile    = true;
    local bDeleteFile   = false;

    --get the current timestamp (removing the seconds)
    local nCurrentTimestamp     = isotominutes(System.GetDate(DATE_FMT_ISO)..System.GetTime(TIME_FMT_MIL));

    if (tFiles and #tFiles > 0) then
        --sort the dates
        table.sort(tFiles);

        local nFiles = #tFiles;
        --get the current timestamp of the latest file (removing the seconds), using safety here in case of nil
        local nLatestFileTimestamp  = tonumber(String.SplitPath(tFiles[nFiles]).Filename) or nCurrentTimestamp;
        bWriteFile            = math.abs(nCurrentTimestamp - nLatestFileTimestamp) > BACKUP_MINIMUM_INTERVAL;
        bDeleteFile           = bWriteFile and (nFiles >= BACKUP_MAX_FILE_COUNT) or false;
    end

    --delete the oldest backup if needed
    if (bDeleteFile) then
        File.Delete(tFiles[1], false, false, true, nil);
    end

    --write the backup if needed
    if (bWriteFile) then
        File.Copy(pFile, pFolder.."\\"..nCurrentTimestamp..".csv", true, true, false, true, nil);
    end

    return bWriteFile;
end


--[[!
    @fqxn CFS.Classes.ProcSys
    @desc <h2>ProcSys</h2>

    <p>
      Coordinates the CSV editing pipeline between a <strong>Base Data</strong> grid and a <strong>Final Data</strong> grid.
      When data is loaded, each cell in <strong>Base Data</strong> grid is processed and moved to the <strong>Final Data</strong> grid.
      The <strong>Final Data</strong> grid is what is output, while the <strong>Base Data</strong> grid preserves the original input.
    </p>

    <h3>What it does</h3>
    <ul>
      <li><strong>Loads</strong> a CSV into the base grid, then builds the final grid by processing every cell.</li>
      <li><strong>Processes</strong> individual cell edits and keeps the final grid in sync immediately.</li>
      <li><strong>Refreshes</strong> the grids efficiently (batch redraw off/on) to avoid flicker and slow updates.</li>
      <li><strong>Draws</strong> the current row’s card when selection changes or when a cell edit occurs (when enabled).</li>
      <li><strong>Saves</strong> the updated base CSV when requested.</li>
      <li><strong>Backs up</strong> source CSVs to a per-file backup folder using a timestamp + retention rules.</li>
    </ul>

    <h3>How processing works</h3>
    <p>
      Each row can resolve to a processor object. If that processor provides a cell-processing hook, the system calls it during
      initial load and on edits. If the hook returns nothing, the original text is copied through unchanged.
    </p>

    <h3>Workflow</h3>
    <ol>
      <li><strong>Load</strong> a CSV (from a path or a file picker).</li>
      <li><strong>Backup</strong> the CSV if enough time has passed since the last backup.</li>
      <li><strong>Populate</strong> both grids and build the final grid by iterating all rows and columns.</li>
      <li><strong>Edit</strong> cells in the base grid; changes are processed and mirrored into the final grid.</li>
      <li><strong>Preview</strong> by selecting rows; the current row is used to trigger a draw attempt.</li>
      <li><strong>Save</strong> both the base and final outputs when changes are allowed.</li>
    </ol>

    <h3>Notes</h3>
    <ul>
      <li><em>Base grid</em> = source/original values.</li>
      <li><em>Final grid</em> = processed/export-ready values.</li>
      <li>Saving is disabled during bulk loading and enabled after edits.</li>
    </ul>
!]]
return class("ProcSys",
    {},--METAMETHODS
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --ProcSys = function(this, sAuthCode) end, --static constructor (runs after class object creation)
        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.CreateImagePath
            @desc Builds a deterministic card image path using the card set's folder structure.
            @param string sMime   File extension (with or without dot).
            @return string sPath  Full image path.
        !]]
        --[[CreateImagePath = function(sName, sMime)
            return _pCards.."\\"..sName..'.'..sMime:gsub('%.', '');
        end,]]


        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.GetForge
            @desc Returns the active Forge instance.
            @return Forge oForge The current Forge object.
        !]]
        GetForge = function()
            return _cForge;
        end,

--[[
        GetImagePath = function(nRow) --TODO ERROR WRONG...ambiguous,...what image? WHYA R ETHERE TWO OF THESE METHODS
            local sRet;
            local tRow = Grid.GetRow(_sFinalDataGrid, nRow, true);

            if (#tRow > 0) then
                local cProc = ResolveProc() or nil;

                if (cProc) then
                    sRet = cProc.ImagePath.."\\"..cProc.ImagePrefix..sCardName..".png";
                end

            end

            return sRet;
        end,
        GetImagePath = function(nRow)
            local vRet;
            local tRow = Grid.GetRow(sGrid, nRow);

            if (#tRow > 0 and tRow.Family and tRow.Class and tRow.Type and tRow.Name) then
                vRet = ProcSys.CreateImagePath(tRow.Family, tRow.Class, tRow.Type, tRow.Name, "png"); --TODO FIX HARD-CODED MINES IN THIS MODULE
            end

            return vRet;
        end,
]]

        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.GetProc
            @desc Returns the processor class for a given row and grid.
            @param number nRow Row index.
            @param string|nil vGrid Grid identifier (base or final); defaults to base when nil or invalid.
            @return class cProc The processor class for the row or nil if none exists.
        !]]
        GetProc = function(nRow, vGrid)
            local cRet;
            local bInputValid = (rawtype(vGrid) == "string" and (vGrid == _sBaseDataGrid or vGrid == _sFinalDataGrid));
            local sGrid = bInputValid and vGrid or _sBaseDataGrid;
            local tRow = Grid.GetRow(sGrid, nRow);

            --check if this game has a proc resolver
            if (type(_tProcResolvers[_sGame]) == "function") then
                cRet = _tProcResolvers[_sGame](_sSetName, tRow);
                cRet = type(cRet) == "class" and cRet or nil;
            end

            return cRet;
        end,


        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.GetSetName
            @desc Returns the active card set name.
            @return string sSetName Active card set identifier.
        !]]
        GetSetName = function()
            return _sSetName;
        end,

        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.LoadSet
            @desc Loads a card set CSV into the Base and Final grids.
            @param string|nil vFile Optional CSV file path; prompts when omitted or invalid.
        !]]
        LoadSet = function(vFile)

            if (_bAllowSave) then
                local nYesNoCancel = Dialog.Message("Warning!", "You have unsaved changes.\r\nWould you like to save them now?", MB_YESNOCANCEL, MB_ICONEXCLAMATION, MB_DEFBUTTON1);

                if (nYesNoCancel == IDNO) then
                    _bAllowSave = false;
                elseif (nYesNoCancel == IDYES) then
                    ProcSys.SaveCSVs();
                    Application.Sleep(500);
                end

            end

            --set defaults
            _pActiveCSV = "";
            _bAllowSave = false;
            xButton.SetEnabled("btn save data", false);
            local pFile;

            --load csv
            if (type(vFile) == "string") then
                pFile = File.DoesExist(vFile) and vFile or nil;
            end

            if not (pFile) then
                local tFiles = Dialog.FileBrowse(true, "Load CSV File", _pCSVSource, "CSV Files (*.csv)|*.csv|", "", "csv", false, true);

                if (rawtype(tFiles) == "table" and #tFiles > 0 and File.DoesExist(tFiles[1])) then
                    pFile = tFiles[1];
                end

            end

            if (pFile) then
                --backup the file (if needed)
                TryBackupFile(pFile);

                --store the set name
                _sSetName = String.SplitPath(pFile).Filename;

                LoadFileToGrid(pFile);

                --set the save file variables
                _pActiveCSV = pFile;
            end

        end,

        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.OnCellChanged
            @desc Handles base grid cell edits, synchronizes processed output, and updates save and preview state. This function is called whenever a cell in the Base Data Grid is modified.
            @param number nRow Row index in the base grid.
            @param number nColumn Column index in the base grid.
            @param string sOldText Previous cell value.
            @param string sNewText New cell value.
            @note
                <ul>
                    <li>Column 1 is always the card name column and triggers an on-disk image rename.</li>
                    <li>Invalid name edits are rejected and reverted.</li>
                    <li>Enables saving when a valid edit is processed.</li>
                    <li>Triggers a redraw only when the corresponding menu option is checked.</li>
                </ul>
        !]]
        OnCellChanged = function(nRow, nColumn, sOldText, sNewText)
            local bIsLoadingOrBadCell   = _bIsLoading or nRow < 1 or nColumn < 1;
            local bTextUnchanged        = sOldText == sNewText;
            local bProcess              = not (bIsLoadingOrBadCell or bTextUnchanged);

            if (not bProcess) then
                return;
            end

            if (nColumn == 1) then--Grid.GetColumnIDByName("Name")) then --TODO cache this value

                --handle the name
                if (sNewText:isempty() or not sNewText:isfilesafe()) then
                    Status.Set("Could not rename card. Name is not filesafe.");
                    Grid.SetCellText(_sBaseDataGrid, nRow, nColumn, sOldText);
                    bProcess = false;
                else
                    local tRow = Grid.GetRow(_sBaseDataGrid, nRow);
                    local cProc = ProcSys.GetProc(nRow);

                    if (type(cProc) == "class" and class.haspublicmember(cProc, "ImagePath")) then
                        local pOld = cProc.ImagePath.."\\"..sOldText..'.png';
                        local pNew = cProc.ImagePath.."\\"..sNewText..'.png';

                        --TODO STATUS ERRORS AND SKIP ON BAD FILE (NEW OR OLD)
                        File.Rename(pOld, pNew);
                    else
                        Status.Set("Could not rename card. No registered proc class for row.");
                        Grid.SetCellText(_sBaseDataGrid, nRow, nColumn, sOldText);
                        bProcess = false;
                    end

                end

            end

            if (bProcess) then
                --process the cell change
                PrepUpdateGrids();
                local cProc, tRow = ProcessCell(nRow, nColumn);
                UpdateGrids();

                --update saveability
                _bAllowSave = true;
                xButton.SetEnabled("btn save data", true);

                --update the draw call
                if (MainMenu.IsChecked("Options:>Draw:>Redraw On Cell Changed")) then
                    TryDrawCard(cProc, nRow, tRow);
                end

            end

        end,


        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.OnShow
            @desc Initializes and restores the ProcSys data editor and viewer windows on Forge page OnShow event.
            @param string sPage Page identifier triggering the show event. Not currently used for anything but provided in case of future changes.
            @note
               <ul>
                   <li>Creates the base and final data grid windows once per application lifetime.</li>
                   <li>Restores window size and position from INI using pane identifiers as section keys.</li>
                   <li>Restoration order is size, fill, then position.</li>
                   <li>Missing or invalid INI values fall back to defaults.</li>
               </ul>
        !]]
        OnShow = function(sPage)

            --create the game's windows table
            if not (bWindowsBuilt) then
                local tWindows = _tWindows;

                local function OnReadyGrids(hWnd, sObject)
            	       Grid.SetVisible(sObject, true);
                end

                --create the data editor first
                local oDataEdit = WinAMS(OBJECT_GRID, "Base Data Editor", 0, 0, 800, 1000, "grd base data", nil, OnReadyGrids)--TODO get values from INI, CHANGE NAME
                tWindows[PANE.DATA_EDIT] = {
                    Object = oDataEdit,
                    WindowHandle = oDataEdit.GetWindowHandle(),
                };

                --then the data viewer
                local oDataView = WinAMS(OBJECT_GRID, "Final Data Viewer", 1400, 0, 800, 1000, "grd final data", nil, OnReadyGrids)--TODO get values from INI
                tWindows[PANE.DATA_VIEW] = {
                    Object = oDataView,
                    WindowHandle = oDataView.GetWindowHandle(),
                };

                local tPaneByHandle = {
                    [tWindows[PANE.DATA_EDIT].WindowHandle] = PANE.DATA_EDIT,
                    [tWindows[PANE.DATA_VIEW].WindowHandle] = PANE.DATA_VIEW,
                };

                local function RestoreWindow(hWnd)
                    local ePane     = tPaneByHandle[hWnd];
                    local sSection  = tostring(ePane);
                    local nX        = tonumber(INIFile.GetValue(_pAppCFG, sSection, "X"))       or 0;
                    local nY        = tonumber(INIFile.GetValue(_pAppCFG, sSection, "Y"))       or 0;
                    local nWidth    = tonumber(INIFile.GetValue(_pAppCFG, sSection, "Width"))   or 800;
                    local nHeight   = tonumber(INIFile.GetValue(_pAppCFG, sSection, "Height"))  or 1000; --TODO MAGIC NUMBERS use defaults?

                    Window.SetSize(hWnd, nWidth, nHeight);
                    tWindows[ePane].Object.FillWindow();
                    Window.SetPos(hWnd, nX, nY);

                    if not (INIFile.GetValueBoolean(_pAppCFG, tostring(ePane), "Visible")) then
                        Window.Hide(hWnd);
                    end

                end

                local fCurrentOnResizeStop = oDataEdit.GetCallback(WinSys.EVENT.OnResizeStop);
                local function OnResizeStop(hWnd, nWidth, nHeight)
                    fCurrentOnResizeStop(hWnd, nWidth, nHeight);

                    --save the window's dimensions
                    local sSection = tostring(tPaneByHandle[hWnd]);
                    INIFile.SetValue(_pAppCFG, sSection, "Width", tostring(nWidth));
                    INIFile.SetValue(_pAppCFG, sSection, "Height", tostring(nHeight));

                    --save the window's location
                    local tPos = Window.GetPos(hWnd);
                    INIFile.SetValue(_pAppCFG, sSection, "X", tostring(tPos.X));
                    INIFile.SetValue(_pAppCFG, sSection, "Y", tostring(tPos.Y));
                end

                local fCurrentOnClose = oDataEdit.GetCallback(WinSys.EVENT.OnClose);
                local function OnClose(hWnd)
                    local ePane = tPaneByHandle[hWnd];
                    INIFile.SetValue(_pAppCFG, tostring(ePane), "Visible", "false");
                    fCurrentOnClose(hWnd);
                end

                --update the callbacks
                oDataEdit.SetCallback(WinSys.EVENT.OnResizeStop,    OnResizeStop);
                oDataView.SetCallback(WinSys.EVENT.OnResizeStop,    OnResizeStop);
                oDataEdit.SetCallback(WinSys.EVENT.OnClose,         OnClose);
                oDataView.SetCallback(WinSys.EVENT.OnClose,         OnClose);


                RestoreWindow(tWindows[PANE.DATA_EDIT].WindowHandle);
                RestoreWindow(tWindows[PANE.DATA_VIEW].WindowHandle);

                bWindowsBuilt = true;
            end

        end,


        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.OnExit
            @desc Handles application exit, prompting to save when unsaved changes exist.
            @note
                <ul>
                    <li>Prompts the user to save if edits are pending.</li>
                    <li>Selecting Yes attempts to save before exiting.</li>
                    <li>Selecting No exits without saving.</li>
                    <li>Selecting Cancel aborts the exit.</li>
                </ul>
        !]]
        OnExit = function()

            if (_bAllowSave) then
                local nYesNoCancel = Dialog.Message("Warning!", "You have unsaved changes.\r\nWould you like to save them now?", MB_YESNOCANCEL, MB_ICONEXCLAMATION, MB_DEFBUTTON1);

                if (nYesNoCancel == IDNO) then
                    _bAllowSave = false;
                    Application.Exit(0);
                elseif (nYesNoCancel == IDYES) then
                    ProcSys.SaveCSVs();
                    Application.Sleep(2000);
                    Application.Exit(0);
                end

            else
                Application.Exit(0);
            end

        end,


        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.OnSelectionChanged
            @desc Called whenever one of the girds registers a cell selection change.<br>Draws (or attempts to draw) the card for the given row. Before drawing the card, it calls the row's processor method of the same name, if present, and updates the cell (<em>if text if the sBase and sFinal text values are sent back by the processor</em>).
            @param string sGrid The name of the grid.
            @param number nRow The row index of the cell selected.
            @param number nColumn The column index of the cell selected.
        !]]
        OnSelectionChanged = function(sGrid, nRow, nColumn)
            --ELProfiler.start(period, stack_depth)

            local cProc = ProcSys.GetProc(nRow);

            --update the current selection
            _nCurrentRow    = nRow;
            _nCurrentColumn = nColumn;

            if (cProc and class.haspublicmember(cProc, "OnSelectionChanged")) then
                local tBaseRow      = Grid.GetRow(_sBaseDataGrid, nRow);
                local sColumn       = Grid.GetCellText(_sBaseDataGrid, 0, nColumn);
                local sBase, sFinal = cProc.OnSelectionChanged(nRow, nColumn, sColumn, tBaseRow);

                if (rawtype(sBase) == "string" and rawtype(sFinal) == "string") then
                    Grid.SetCellText(_sBaseDataGrid,    nRow, nColumn, sBase);
                    Grid.SetCellText(_sFinalDataGrid,   nRow, nColumn, sFinal);
                end

            end

            --get the card's row
            local tRow  = Grid.GetRow(_sFinalDataGrid, nRow);
            --try to draw the card
            if (_nLastRow ~= nRow) then
                TryDrawCard(cProc, nRow, tRow);
                --local sProfile = ELProfiler.stop();
                --TextFile.WriteFromString(_ExeFolder.."\\profile.txt", ELProfiler.format(sProfile))
                _nLastRow = nRow;
            end
            --ELProfiler.format()
        end,


        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.ProcessActiveRow
            @desc Reprocesses all editable cells in the currently selected row and redraws its card.
            @note
                <ul>
                    <li>Processes each column of the active row.</li>
                    <li>Always redraws the card after processing.</li>
                    <li>Intended for user-initiated manual reprocessing of the selected row from the GUI.</li>
                </ul>
        !]]
        ProcessActiveRow = function()
            local nRow = _nCurrentRow;

            for nColumn = 1, Grid.GetColumnCount(_sBaseDataGrid) - 1 do
                ProcessCell(nRow, nColumn);
            end

            --redraw the card
            local cProc = ProcSys.GetProc(nRow);
            local tRow  = Grid.GetRow(_sFinalDataGrid, nRow);
            TryDrawCard(cProc, nRow, tRow);
        end,

        --TODO put in examplke and show the args for the callback
        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.RegisterExporter
            @desc Registers or removes an exporter function for a specific export file.<br>Generally defined within the InitForge.lua file for the game.
            @param string pFile Path to the export target file.
            @param function fExport Exporter function; passing a non-function unregisters it.
            @note
                <ul>
                    <li>Exporters are registered per active game.</li>
                    <li>Requires the target file to exist.</li>
                    <li>Exporter function contract is user-defined.</li>
                </ul>
        !]]
        RegisterExporter = function(pFile, fExport)

            if not (File.DoesExist(pFile)) then
                error("BAD THINGS HERE", 2);--TODO THROW ERROR
            end

            if (rawtype(fExport) == "function") then
                --store the exporter function
                _tExporters[_sGame][pFile] = fExport;
            else
                --delete any exporter function
                _tExporters[_sGame][pFile] = nil;
            end

        end,

        RegisterProcResolver = function(fProcResolver)
            type.assert["function"](fProcResolver, "ProcSys.RegisterProcResolver: argument 1 must be of type function. Got "..type(fProcResolver)..'.');
            _tProcResolvers[_sGame] = fProcResolver;
        end,

        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.SaveCSVs
            @desc Saves the active CSV when saving is allowed.
        !]]
        SaveCSVs = function()

            if (_bAllowSave) then
                --save the original data
                Grid.SaveToFile(_sBaseDataGrid, _pActiveCSV);

                --save the export data
                --Grid.SaveToFile(_sFinalDataGrid, _pExportCSV);

                _bAllowSave = false;
                xButton.SetEnabled("btn save data", false);
            end

        end,


        SaveDraft = function(sID, sCode)--TODO FIX and FINISH
            local wEnv = setmetatable({
                sID     = sID,
                string  = string,
            }, { __index = _G });

            local fChunk, sError = load(TextFile.ReadToString(_pDrafts), "Drafts.lua", "t", wEnv);

            if not (fChunk) then
                --error(sError, 3);
            end

            local bOk, vDraftsOrErr = pcall(fChunk);
            local tDrafts = vDraftsOrErr;

            if not (bOk) then
                --error(sChunkName..": "..tostring(vDraftsOrErr), 3);
                tDrafts = nil;
            end

            --Process here
            if type.istable(tDrafts) then
                tDrafts[sID] = base64.enc(sCode);
                TextFile.WriteFromString(_pDrafts, serialize(tDrafts), false);
            end

        end,


        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.PrepActiveGame
            @desc Ensures the exporter and processor registries exist for the active game.
        !]]
        PrepActiveGame = function()
            --ensure the processor and exporter tables exist for the current game and clear them
            _tExporters[_sGame]         = {};
             _tProcResolvers[_sGame]    = nil;
        end,


        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.SetForge
            @desc Sets the active Forge instance used by ProcSys.
            @param Forge oForge Forge instance to bind.
        !]]
        SetForge = function(cForge)
            --TODO assertions
            _cForge     = cForge;
            --_pStyles    = cForge;
        end,


        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.SetWindowVisible
            @desc Shows or hides a ProcSys tool window.
            @param number eTool Tool/window identifier.
            @param boolean vFlag Visibility state.
        !]]
        SetWindowVisible = function(eTool, vFlag)
            --TODO assertions
            local bFlag = type(vFlag) == "boolean" and vFlag or false;
            local tWindows = _tWindows;

            if (bFlag) then
                Window.Show(tWindows[eTool].WindowHandle);
            else
                Window.Hide(tWindows[eTool].WindowHandle);
            end
        end,


        GetWindowHandle = function(eTool)
            --TODO assertions
            return _tWindows[eTool].WindowHandle;
        end,
    },
    {--PRIVATE
        ProcSys = function(this, cdat) end,
    },
    {},--PROTECTED
    {},--PUBLIC
    nil,   --extending class
    true, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
