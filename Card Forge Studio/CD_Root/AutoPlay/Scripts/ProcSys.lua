-------------------------------- Localization
local class                     = class;
-------------------------------- General
local _pAppCFG                  = FS.AppCFG;
local _bReady                   = false; --prevents timer executions until a selection has been made
local _bAllowSave               = false;
local _nUserFileRepoInterval    = USER_FILE_REPO_TIMER_INTERVAL;
-------------------------------- Windows
local _tWindows                 = {}; --stores windows
local _bWindowsBuilt            = false;
local _ePane                    = PANE;
-------------------------------- Grid
local _bAutoSizeGrid            = true;
local _sBaseDataGrid            = PROCSYS_GRID_BASE;
local _sFinalDataGrid           = PROCSYS_GRID_FINAL;
local _bIsLoading               = false;
local _nCurrentRow              = -1;
local _nCurrentColumn           = -1;
local _nLastRow                 = -1;
-------------------------------- Export
local _tExporters               = {};
-------------------------------- CSV
local _bDataChanged             = false;
local _sCSVDelimiter            = CSV_DELIMITER;
local _pActiveCSV               = "";
local _pExportCSV               = "";
-------------------------------- RowProc / Special Procs
local _tReprocRows              = {};
local _oRowProcLiveFileRepo     = LiveFileRepo();
local _bRowProcChanged          = false;
local _sRowProcCode             = "";
local _fRowProc                 = false;

local _bRowProcChanged          = false;
-------------------------------- Draw (Draw function doesn't get stored here as it's sent to Forge upon creation)
local _oDrawLiveFileRepo        = LiveFileRepo(); --QUESTION SHOULD THIS BE IN THE FORGE MODULE?
local _bDrawChanged             = false;
local _sDrawCode                = "";
-------------------------------- Game Including CGF & ENV
local _oGameLiveFileRepo        = LiveFileRepo();
local _oActiveGame              = null;
local _sGameName                = "";
local _bCFGChanged              = false;
local _bENVChanged              = false;
local _sCFGCode                 = "";
local _sENVCode                 = "";
local _tCFG                     = null;
local _tENV                     = null;
-------------------------------- Card Set
local _oCardSetLiveFileRepo     = LiveFileRepo();
local _oActiveCardSet           = false;
local _sCardSetName             = "";
local _nCardWidth               = 0;
local _nCardHeight              = 0;
-------------------------------- Timers
local _nFileSyncTimerID         = PROCSYS_FILE_SYNC_TIMER_ID;
local _nFileSyncTimerInterval   = PROCSYS_FILE_SYNC_TIMER_INTERVAL;
-------------------------------- File Specs
local _tFileSpecCFG             = FILESPEC_GAME_CFG;
local _tFileSpecENV             = FILESPEC_GAME_ENV; --TODO add all neede file specs here
local _tFileSpecDraw            = FILESPEC_CARDSET_DRAW;
local _tFileSpecRowProc         = FILESPEC_CARDSET_ROWPROC;
-------------------------------- Preemptive Declarations
local ProcessCell;
local PrepUpdateGrids;
local TryDrawCard;
local UpdateGrids;
----------------------------------------------------------------------------------------------------------------------
--TODO Clean these up
local _nDescriptionMaxWidth = 100;
--local _tRowCRC          = {};
--local _nDrawCRC         = -1;
--local _nRowProcCRC     = -1;
--local _bDrawUpdated     = false;
--local _bRowProcUpdated = false;

--local _tRedrawRows      = {};  --tracks which rows need reprocessed/redrawn

--may be used by the proc's cell processor to get final values
--local _nFinalValueRow = -1; --TODO QUESTION is the ever used?
--local function GetFinalValue(sColumn)
--    return Grid.GetCellText(_sFinalDataGrid, _nFinalValueRow, Grid.GetColumnIDByName(_sFinalDataGrid, sColumn));
--end

--[[--when changes occur
Data            - Reload Set +
CFG/UserEnv     - Reinit game +
Cell/RowProc - Reproc All Rows (on demand ofc)
Draw            - Redraw Current Row
]]
-----------------------------------------------------------------------------------------------------------------------


local function BuildCardSetFunction(sName, sChunk)
    local sChunkName = _sCardSetName..' '..sName;

    local fChunk, sError = load(sChunk, sChunkName, "t", UserEnv.Get());
    if not (fChunk) then
        error("Error loading '"..sName.."' function for CardSet, '".._sCardSetName.."'.\r\n"..sError, 2);
    end

    local bOK, fRetOrErr = pcall(fChunk);
    if not (bOK) then
        error("Error running '"..sName.."' chuck (function) for CardSet, '".._sCardSetName.."'.\r\n"..fRetOrErr, 2);
    end

    if not (rawtype(fRetOrErr) == "function") then
        error("Error building '"..sName.."' function for CardSet, '".._sCardSetName.."'.\r\nExpected return type function. Got "..rawtype(fRetOrErr)..'.', 2);
    end

    return fRetOrErr;
end



--[[!
    @fqxn CFS.Classes.ProcSys.Methods.BuildUserTable
    @desc TODO
    @vis Static Private
!]]
local function BuildUserTable(sGame, tFileSpec)
    --TODO FIX FINISH THIS SHOULD NOT BE CALLED HERE WITHOUT SAFE ENV
    --Load any config and user environment that may exist TODO BUG FIX - FINISH - USE PROTECTED environment for loading this
    --local sInitChunk    = _oActiveCardSet.GetCallCode("RowProc");
    --TODO IT CAN BE USED IN THINGS LIKE oGame.RefreshCFG() and oGame.RefreshEnv() or just oGame.ReInit()
    local sInitChunk = TextFile.ReadToString(FS.Scripts.."\\"..tFileSpec.Full);
    --TODO CHECK AND ERROR on bad file
    --TODO Clear/Refresh UserEnv

    local sName = tFileSpec.Filename;

    --the error message in case things go south
    local sChunkName = sGame.." "..sName;

    --try to load the chuck
    local fChunk, sError = load(sInitChunk, sChunkName, "t", UserEnv.Get());
    if not (fChunk) then
        error("Error running "..sName.." file for Game "..sGame..".\r\n"..sError, 2);
    end

    --try to call the chunk
    local bOK, sRetOrError = pcall(fChunk);

    if not (bOK) then
        error("Error running "..sName.." file for Game "..sGame..".\r\n"..sRetOrError, 2);
    end

    local tUserTable = sRetOrError;

    if not (type(tUserTable) == "table") then
        error("Error in return from "..sName.." file for Game "..sGame..".\r\nExpected type table, Got "..type(tUserTable)..'.', 2);
    end

    return tUserTable;
end


--[[!
    @fqxn CFS.Classes.ProcSys.Methods.BuildWindows
    @desc <p>Creates ProcSys’s auxiliary editor/viewer windows once, wires custom window callbacks, restores prior window state from the app INI, and registers ProcSys root conversions into the UserEnv.</p>
        <p>This function is <strong>static</strong> and <strong>private</strong> to the ProcSys module.<br>
        It builds the base data editor and final data viewer grids, captures each window’s original callbacks, then wraps OnClose/OnMaximize/OnResizeStop/OnRestore to both forward events and persist window geometry, visibility, and maximized state back to the INI.</p>
    @vis Static Private
!]]
local function BuildWindows()

    if not (_bWindowsBuilt) then
        local tWindows = _tWindows;

        local function OnReadyGrids(hWnd, sObject)
            Grid.SetVisible(sObject, true);
        end

        --store the card/main window (mainly for the forge)
        tWindows[_ePane.MAIN] = {
            WindowHandle = HWND_APP,
        };

        --create the data editor first
        local oDataEdit = WinAMS(OBJECT_GRID, "Base Data Editor", 0, 0, 800, 1000, "grd base data", nil, OnReadyGrids)--TODO get values from INI, CHANGE NAME
        tWindows[_ePane.DATA_EDIT] = {
            Object = oDataEdit,
            WindowHandle = oDataEdit.GetWindowHandle(),
            Callback        = {
                OnClose         = oDataEdit.GetCallback(WinSys.EVENT.OnClose),
                OnMaximize      = oDataEdit.GetCallback(WinSys.EVENT.OnMaximize),
                OnResizeStop    = oDataEdit.GetCallback(WinSys.EVENT.OnResizeStop),
                OnRestore       = oDataEdit.GetCallback(WinSys.EVENT.OnRestore),
            },
        };

        --then the data viewer
        local oDataView = WinAMS(OBJECT_GRID, "Final Data Viewer", 1400, 0, 800, 1000, "grd final data", nil, OnReadyGrids)--TODO get values from INI
        tWindows[_ePane.DATA_VIEW] = {
            Object          = oDataView,
            WindowHandle    = oDataView.GetWindowHandle(),
            Callback        = {
                OnClose         = oDataView.GetCallback(WinSys.EVENT.OnClose),
                OnMaximize      = oDataView.GetCallback(WinSys.EVENT.OnMaximize),
                OnResizeStop    = oDataView.GetCallback(WinSys.EVENT.OnResizeStop),
                OnRestore       = oDataView.GetCallback(WinSys.EVENT.OnRestore),
            },
        };

        local tPaneByHandle = {
            [tWindows[_ePane.DATA_EDIT].WindowHandle] = _ePane.DATA_EDIT,
            [tWindows[_ePane.DATA_VIEW].WindowHandle] = _ePane.DATA_VIEW,
        };

        local function RestoreWindow(hWnd)
            local ePane         = tPaneByHandle[hWnd];
            local sSection      = tostring(ePane);
            local nX            = tonumber(INIFile.GetValue(_pAppCFG, sSection, "X"))           or 0;
            local nY            = tonumber(INIFile.GetValue(_pAppCFG, sSection, "Y"))           or 0;
            local nWidth        = tonumber(INIFile.GetValue(_pAppCFG, sSection, "Width"))       or 800;
            local nHeight       = tonumber(INIFile.GetValue(_pAppCFG, sSection, "Height"))      or 1000; --TODO MAGIC NUMBERS use defaults?
            local bMaximized    = INIFile.GetValueBoolean(  _pAppCFG, sSection, "Maximized")    or false;

            Window.SetSize(hWnd, nWidth, nHeight);
            tWindows[ePane].Object.FillWindow();
            Window.SetPos(hWnd, nX, nY);

            if (bMaximized) then
                Window.Maximize(hWnd);
            end

            if not (INIFile.GetValueBoolean(_pAppCFG, tostring(ePane), "Visible")) then
                Window.Hide(hWnd);
            end

        end

        local function OnClose(hWnd)
            local ePane = tPaneByHandle[hWnd];

            --fire the original callback
            tWindows[ePane].Callback.OnClose(hWnd, nWidth, nHeight);

            INIFile.SetValue(_pAppCFG, tostring(ePane), "Visible", "false");
            --fCurrentOnClose(hWnd);
        end

        local function FireAndSaveWindowInfo(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight, sCallback)
            local ePane = tPaneByHandle[hWnd];
            --fire the original callback
            tWindows[ePane].Callback[sCallback](hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight);

            --save the window's dimensions
            local sSection = tostring(ePane);
            INIFile.SetValue(_pAppCFG, sSection, "Width", tostring(nWidth));
            INIFile.SetValue(_pAppCFG, sSection, "Height", tostring(nHeight));

            INIFile.SetValue(_pAppCFG, sSection, "X", tostring(nX));
            INIFile.SetValue(_pAppCFG, sSection, "Y", tostring(nY));

            --update whether the window is maximized
            INIFile.SetValue(_pAppCFG, sSection, "Maximized", tostring(sCallback == "OnMaximize"));
        end

        local function OnMaximize(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight)
            FireAndSaveWindowInfo(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight, "OnMaximize");
        end

        local function OnResizeStop(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight)
            FireAndSaveWindowInfo(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight, "OnResizeStop");
        end

        local function OnRestore(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight)
            FireAndSaveWindowInfo(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight, "OnRestore");
        end

        --update the callbacks
        oDataEdit.SetCallback(WinSys.EVENT.OnClose,         OnClose);
        oDataEdit.SetCallback(WinSys.EVENT.OnMaximize,      OnMaximize);
        oDataEdit.SetCallback(WinSys.EVENT.OnResizeStop,    OnResizeStop);
        oDataEdit.SetCallback(WinSys.EVENT.OnRestore,       OnRestore);
        oDataView.SetCallback(WinSys.EVENT.OnClose,         OnClose);
        oDataView.SetCallback(WinSys.EVENT.OnMaximize,      OnMaximize);
        oDataView.SetCallback(WinSys.EVENT.OnResizeStop,    OnResizeStop);
        oDataView.SetCallback(WinSys.EVENT.OnRestore,       OnRestore);


        RestoreWindow(tWindows[_ePane.DATA_EDIT].WindowHandle);
        RestoreWindow(tWindows[_ePane.DATA_VIEW].WindowHandle);

        _bWindowsBuilt = true;

        UserEnv.ProcSysUpdateRoot ({
            _TABLE          = PROCSYS_TO_TABLE,
            _NUMBER         = PROCSYS_TO_NUMBER,
        }, true);
    end

end


--[[!
    @fqxn CFS.Classes.ProcSys.Methods.LoadFileToGrid
    @desc Loads a CSV into the base grid, rebuilds the final grid by processing all cells, and refreshes the UI.
    @param string pFile Path to the CSV to load.
    @note Disables saving while loading and re-enables normal editing after completion.
    @vis Static Private
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
    MainMenu.SetEnabled("Card Set:>Save", false);
    _bIsLoading = false;
end


--[[!
    @fqxn CFS.Classes.ProcSys.Static Private.Methods.PrepUpdateGrids
    @desc TODO
!]]
PrepUpdateGrids = function()
    Status.Set("");
    Grid.SetRedraw(_sBaseDataGrid, false);
    Grid.SetRedraw(_sFinalDataGrid, false);
end


--[[!
    @fqxn CFS.Classes.ProcSys.Static Private.Methods.ProcessCell
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
ProcessCell = function(nRow, nColumn) --TODO LEFT OFF HERE 1
    local sColumn       = Grid.GetCellText(_sBaseDataGrid, 0, nColumn);
    local sText         = Grid.GetCellText(_sBaseDataGrid, nRow, nColumn);

    local function fGetFinalValue(sColumn, vCoerce)
        local vRet = Grid.GetCellText(_sFinalDataGrid, nRow, Grid.GetColumnIDByName(_sFinalDataGrid, sColumn));
        local nCoerce = rawtype(vCoerce) == "number" and vCoerce or nil;

        if (nCoerce == PROCSYS_TO_NUMBER) then
            local vRetCollapsed = vRet:collapse();
            vRet = tonumber(vRetCollapsed) or vRet; --TODO QUESTION SHOULD THIS FAIL with error msg INSTEAD???
        --elseif (nCoerce == PROCSYS_TO_TABLE) then TODO

        end

        return vRet;
    end

    --try to call the chunk
    --local bOk, vProcRet = pcall(_fRowProc, nRow, nColumn, sColumn, Grid.GetRow(_sBaseDataGrid, nRow), sText, fGetFinalValue);
    local vProcRet = _fRowProc(nRow, nColumn, sColumn, Grid.GetRow(_sBaseDataGrid, nRow), sText, fGetFinalValue);

    --if not (bOk) then
    --    error("ProcSys Error: ProcessCell for Row: "..nRow..", Column: '"..sColumn.."'.\r\n"..vProcRet);--TODO LOG and display
    --end

    if (vProcRet) then
        ---update the cell's text
        Grid.SetCellText(_sFinalDataGrid, nRow, nColumn, vProcRet);
    else
        Grid.SetCellText(_sFinalDataGrid, nRow, nColumn, sText);
    end

    --TODO Also, be sure to add function to the env that indicates if a given column as been processed (basically if Column_A.index Column_< B.index)

    --get the row after modifications
    local tFinalRow = Grid.GetRow(_sFinalDataGrid, nRow);

    --send back info for the card redraw attempt
    return tFinalRow;
end


local function SetReprocRows(vFlag)

    local nRows = Grid.GetRowCount(_sBaseDataGrid);
    local bFlag = rawtype(vFlag) == "boolean" and vFlag or false;

    for nRow = 0, nRows - 1 do
        _tReprocRows[nRow] = bFlag;
    end

end


--[[!
    @fqxn CFS.Classes.ProcSys.Static Private.Methods.TryBackupFile
    @desc TODO
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
    @fqxn CFS.Classes.ProcSys.Static Private.Methods.TryDrawActiveCard
    @desc TODO
!]]
local function TryDrawActiveCard()

    if (_bReady) then
        local tRow = Grid.GetRow(_sFinalDataGrid, _nCurrentRow);
        --Forge.SetActiveRow();

    end

end

--TODO clean all these functions up...params are messy
--[[!
    @fqxn CFS.Classes.ProcSys.Methods.TryDrawCard
    @desc Attempts to draw the card for the given row using the resolved processor.
    @param class cProc Processor class providing the DrawCard method.
    @param number nRow Row index being drawn.
    @param table tRow Final grid row data for the card.
    @note
        <ul>
            <li>Sets Forge orientation based on row data.</li>
            <li>Optionally exports the card when the corresponding menu option is enabled.</li>
        </ul>
    @vis Static Private
!]]
--local function TryDrawCard(cProc, nRow, tRow)
TryDrawCard = function(tRow)

    --if (cProc and type(cProc.DrawCard) == "function" and nRow > 0) then

        --make sure there's data in the row
        if (#tRow > 0) then
            --check for export call
            --local fExport = _tExporters[_sGame][_pActiveCSV];
            --local bExport = MainMenu.IsChecked("Options:>Draw:>Export Selected Card") and rawtype(fExport) == "function"; --TODO FINISH use new/custom exporter system BUT dnot here...do not draw for every export, simply export

            --tell Forge to draw (and possibly export) the card
            Forge.SetActiveRow(tRow);
            Forge.RequestCardRedraw();
        end

    --end

end


--[[!
    @fqxn CFS.Classes.ProcSys.Methods.UpdateCardSetLiveFileRepo
    @desc TODO
    @vis Static Private
!]]
local function UpdateCardSetLiveFileRepo() --TODO FINISH
    local oCardSet      = _oActiveCardSet;
    local oLiveFileRepo = _oCardSetLiveFileRepo;
    local pCardSet      = oCardSet.GetPath();

    --reset the old repo
    oLiveFileRepo.Reset();--vID, pFile, nTimerInterval, fCallback
    oLiveFileRepo.Add("RowProc", pCardSet.."\\".._tFileSpecRowProc.Full, _nUserFileRepoInterval,
    function(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        _sRowProcCode       = sNewText;
        _bRowProcChanged    = true;
    end);

    --TODO all the special procs

    oLiveFileRepo.Add("Draw", pCardSet.."\\".._tFileSpecDraw.Full, _nUserFileRepoInterval,
    function(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        _sDrawCode      = sNewText;
        _bDrawChanged   = true;
    end);

    oLiveFileRepo.StartAll();
end


--[[local function UpdateCardSetFunctions()
    local oCardSet      = _oActiveCardSet;
    local oLiveFileRepo = _oCardSetLiveFileRepo;
    local pCardSet      = oCardSet.GetPath();

    _fRowProc = BuildCardSetFunction("RowProc", TextFile.ReadToString(pCardSet.."\\".._tFileSpecRowProc.Full));
end]]


--[[!
    @fqxn CFS.Classes.ProcSys.Static Private.Methods.UpdateGameLiveFileRepo
    @desc TODO
!]]
local function UpdateGameLiveFileRepo()
    local sGame         = _oActiveGame;
    local oLiveFileRepo = _oGameLiveFileRepo;

    --reset the live file repo
    oLiveFileRepo.Reset();

    --CFG Files
    local function NotifyCFGChanged(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        _sCFGCode       = sNewText;
        _bCFGChanged    = true;
    end

    oLiveFileRepo.Add("CFG", FS.Scripts.."\\".._tFileSpecCFG.Full, _nUserFileRepoInterval, NotifyCFGChanged);
    local tCFGFiles = File.Find(FS.CFG.."\\", "*.lua", false, false, nil, nil);

    if (type(tCFGFiles) == "table") then

        for nIndex, pFile in pairs(tCFGFiles) do
            oLiveFileRepo.Add("CFG_"..tostring(nIndex):format("%02d"), pFile, _nUserFileRepoInterval, NotifyCFGChanged);
        end

    end

    --ENV Files
    local function NotifyENVChanged(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        _sENVCode       = sNewText;
        _bENVChanged    = true;
    end

    oLiveFileRepo.Add("ENV", FS.Scripts.."\\".._tFileSpecENV.Full, _nUserFileRepoInterval, NotifyENVChanged);
    local tENVFiles = File.Find(FS.ENV.."\\", "*.lua", false, false, nil, nil);

    if (type(tENVFiles) == "table") then

        for nIndex, pFile in pairs(tENVFiles) do
            oLiveFileRepo.Add("ENV_"..tostring(nIndex):format("%02d"), pFile, _nUserFileRepoInterval, NotifyENVChanged);
        end

    end

    _oGameLiveFileRepo.StartAll();
end


--[[!
    @fqxn CFS.Classes.ProcSys.Static Private.Methods.UpdateGrids
    @desc TODO
!]]
UpdateGrids = function ()--TODO FINISH MOVE Color stuff out to a theme system
    Application.SetRedraw(false);
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
    Grid.SetColumnWidth(_sBaseDataGrid, nColumnDescription, 100);--TODO magick number THIS SHOULD NOT BE DONE HERE, THIS SHOULD BE GOTTEN FROM SET INI
    Grid.SetColumnWidth(_sFinalDataGrid, nColumnDescription, 100);--TODO magick number
    --Grid.SetColumnWidth(_sBaseDataGrid, nColumnID, 40);--TODO magick number
    --Grid.SetColumnWidth(_sFinalDataGrid, nColumnID, 40);--TODO magick number
    Application.SetRedraw(true);
    Page.Redraw();
end














local function UpdateCardSetDrawRepo()
--TODO LEFT OFF HERE
end

local function UpdateDraw()
    --get the chunk from the active card set
    local sDrawChunk = _oDrawLiveFileRepo.Text;

    --the error message in case things go south
    local sCardSetName  = oCardSet.GetName(); --TODO cache this value
    local sChunkName    = sCardSetName.." Draw";

    --try to load the chuck
    local fChunk, sError = load(sDrawChunk, sChunkName, "t", UserEnv.Get());
    if not (fChunk) then
        error("Error loading Draw file for CardSet "..sCardSetName..".\r\n"..sError, 2); --TODO LOG/display
    end

    --try to call the chunk
    local bOk, vReturnOrError = pcall(fChunk);

    if not (bOk) then --TODO are drafts gettging loaded back in? Are they even needed...?
        error("ERror 539 - Forge: "..vReturnOrError)
        --error(sChunkName..": "..tostring(vDescOrErr), 3); TODO LOG and display
    else
        fSetOnImageDraw = vReturnOrError;--(this, tRow, nWidth, nHeight);
    end

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
      <li><strong>Refreshes</strong> the grids efficiently to avoid flicker and slow updates.</li>
      <li><strong>Draws</strong> the current row’s card when selection changes or when a cell edit occurs (when enabled).</li>
      <li><strong>Saves</strong> the updated base CSV when requested.</li>
      <li><strong>Backs up</strong> source CSVs to a per-file backup folder using timestamp and retention rules.</li>
    </ul>

    <h3>How processing works</h3>
    <p>
      Each row resolves to a processor object. As that processor provides a processing hook, the system calls it during
      initial load and on edits. If the hook returns nothing, the original text is copied through, unchanged.
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
        ForceRedraw = TryDrawActiveCard,
        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.CreateImagePath
            @desc Builds a deterministic card image path using the card set's folder structure.
            @param string sMime   File extension (with or without dot).
            @return string sPath  Full image path.
        !]]
        --[[CreateImagePath = function(sName, sMime)
            return _pCards.."\\"..sName..'.'..sMime:gsub('%.', '');
        end,]]
        GetActiveCardSet = function() --TODO QUESTION IS THIS EVER USED???
            return _oActiveCardSet;
        end,

        PrepGame = function(oGame)

            if not (type(oGame) == "Game") then
                error("ProcSys.PrepGame: Error prepping game. Expected Game object. Got "..type(oGame)..'.');
            end

            _oActiveGame = oGame;
            _sGameName   = oGame.GetName();

            --load in the user's CFG table
            local _tCFG = BuildUserTable(_sGameName, _tFileSpecCFG);
            UserEnv.UserUpdateCFG(_tCFG);

            --load in the user's ENV table
            local _tEnv = BuildUserTable(_sGameName, _tFileSpecENV);
            UserEnv.UserUpdateENV(_tEnv);

            UpdateGameLiveFileRepo();
        end,
        --[[! TODO FIX REDO
            @fqxn CFS.Classes.ProcSys.Methods.GetSetName
            @desc Returns the active card set name.
            @return string sSetName Active card set identifier.
        !]]
        GetSetName = function()
            return _sCardSetName;
        end,

        --[[!TODO FINISH UPDATE
            @fqxn CFS.Classes.ProcSys.Methods.LoadCardSet
            @desc Loads a card set CSV into the Base and Final grids.
            @param string|nil vFile Optional CSV file path; prompts when omitted or invalid.
        !]]
        LoadCardSet = function(oCardSet)
            --TODO assert type
            _oActiveCardSet = oCardSet;

            --reset the update status for each row
            SetReprocRows(_tReprocRows, false);

            local pCardSet = oCardSet.GetPath();

            local fDraw = BuildCardSetFunction("Draw", TextFile.ReadToString(pCardSet.."\\".._tFileSpecDraw.Full));
            Forge.SetDrawFunction(fDraw);

            _fRowProc = BuildCardSetFunction("RowProc", TextFile.ReadToString(pCardSet.."\\".._tFileSpecRowProc.Full));

            UpdateCardSetLiveFileRepo();

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
            _pActiveCSV     = "";
            _bAllowSave     = false;
            _sCardSetName   = oCardSet.GetName();
            _nCardWidth     = oCardSet.GetCardWidth();
            _nCardHeight    = oCardSet.GetCardHeight();

            UserEnv.ProcSysUpdateRoot {
                --Count     =  TODO
                _nCardWidth     = _nCardWidth,
                _nCardHeight    = _nCardHeight,
            };

            --disable the save system
            MainMenu.SetEnabled("Card Set:>Save", false);

            local pData = oCardSet.GetDataPath();

            if (pData) then
                --backup the file (if needed)
                --TryBackupFile(pData); --TODO FIX uncomment this when ready!!

                --store the set name
                --_sCardSetName = oCardSet.GetName();--String.SplitPath(pData).Filename; --TODO remove/update

                LoadFileToGrid(pData);

                --set the save file variables
                _pActiveCSV = pData;

                --MainMenu.SetEnabled("Set:>Save", true);
                MainMenu.SetEnabled("Card Set:>Browse", true);
            end

            Forge.SetActiveCardSet(oCardSet);

--[[
            local function LiveFileUpdateCallback(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)

                if (tLiveFile.IsActive) then
                    local nRows = Grid.GetRowCount(_sBaseDataGrid);
                    _tRowUpdate[tLiveFile.ID] = {};
                    local tUpdate =_tRowUpdate[tLiveFile.ID];

                    for nRow = 0, nRows - 1 do
                        tUpdate[nRow] = true;--tLiveFile.HasChanged;
                    end

                end

            end
]]
            --params for callbacks (if needed) -> tLiveFile, sOldText, sNewText, nOldCRC, nCRC
            --LiveFile.SetCallback("RowProc", function() _bRowProcChanged = true; end);
            --LiveFile.SetCallback("Draw",     function() _bDrawChanged    = true; end);

            --LiveFile.SetCallback();
            --tLiveFile, sOldText, sNewText, nOldCRC, nCRC



            --[[local nRows     = Grid.GetRowCount(_sBaseDataGrid);
            for nRow = 0, nRows - 1 do
                _tRowUpdate.RowProc[nRow] = lRowProc.HasChanged;
                _tRowUpdate.Draw[nRow]     = lDraw.HasChanged;
            end]]

            --Page.StartTimer(_nFileSyncTimerInterval, _nFileSyncTimerID);
            --oCardSet.SetActive(true);

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

            if (nColumn == 1 and 5 == 8) then--Grid.GetColumnIDByName("Name")) then --TODO cache this value

                --handle the name
                if (sNewText:isempty() or not sNewText:isfilesafe()) then
                    Status.Set("Could not rename card. Name is not filesafe.");
                    Grid.SetCellText(_sBaseDataGrid, nRow, nColumn, sOldText);
                    bProcess = false;
                else

                    local tRow = Grid.GetRow(_sBaseDataGrid, nRow);
                    local cProc = ProcSys.GetProc(nRow);

                    if (type(cProc) == "class" and class.haspublicmember(cProc, "ImagePath")) then --TODO BUG FIX get the image path from somewhere else now...
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

                local tRow = ProcessCell(nRow, nColumn);
                UserEnv.ProcSysUpdateRoot {
                    _tRow = tRow;
                };

                UpdateGrids();

                --update saveability
                _bAllowSave = true;
                MainMenu.SetEnabled("Card Set:>Save", true);

                --update the draw call
                if (MainMenu.IsChecked("Options:>Draw:>Redraw On Cell Changed")) then
                    TryDrawCard(tRow);
                end

            end

        end,


        OnExit = function() --TODO RENAME THIS AN PUT IT I NTHE PROPER PACES TOO...such as OnShutdown
            --TODO FIX kill all global timers!
            if (_bAllowSave) then
                local nYesNoCancel = Dialog.Message("Warning!", "You have unsaved changes.\r\nWould you like to save them now?", MB_YESNOCANCEL, MB_ICONEXCLAMATION, MB_DEFBUTTON1);

                if (nYesNoCancel == IDNO) then
                    _bAllowSave = false;
                    Application.Exit(0);
                elseif (nYesNoCancel == IDYES) then
                    ProcSys.SaveCSVs();
                    Application.Sleep(1500);
                    Application.Exit(0);
                end

            else
                Application.Exit(0);
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
            BuildWindows();

            --load last card set if present
            local sLastCardSetUUID  = INIFile.GetValue(FS.Info, "SESSION", "LastCardSet");

            local oLastCardSet = _oActiveGame.GetCardSet(sLastCardSetUUID);

            if (type(oLastCardSet) == "CardSet") then
                ProcSys.LoadCardSet(oLastCardSet);
            end

            _oGameLiveFileRepo.StartAll();

            Page.StartTimer(_nFileSyncTimerInterval, _nFileSyncTimerID);
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



        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.OnSelectionChanged
            @desc Called whenever one of the girds registers a cell selection change.<br>Draws (or attempts to draw) the card for the given row. Before drawing the card, it calls the row's processor method of the same name, if present, and updates the cell (<em>if text if the sBase and sFinal text values are sent back by the processor</em>).
            @param string sGrid The name of the grid.
            @param number nRow The row index of the cell selected.
            @param number nColumn The column index of the cell selected.
        !]]
        OnSelectionChanged = function(sGrid, nRow, nColumn)
            --update the current selection
            _nCurrentRow    = nRow;
            _nCurrentColumn = nColumn;
            --local bRedrawn = false;

            if (_nLastRow ~= nRow or _tReprocRows[_nCurrentRow]) then


                local tRow = Grid.GetRow(_sFinalDataGrid, nRow);
                UserEnv.ProcSysUpdateRoot {_tRow = tRow};

                if not (_fRowProc) then --first functions load
                    --UpdateCardSetFunctions();
                    _fRowProc = BuildCardSetFunction("RowProc", TextFile.ReadToString(_oActiveCardSet.GetPath().."\\".._tFileSpecRowProc.Full));
                end

                ProcSys.ProcessActiveRow(not _bReady);
                _nLastRow = nRow;
                _tReprocRows[_nCurrentRow] = false;
                _bReady = true;
            end

            --TryDrawCard(tRow);


--[[


            --THIS IS the special column proc section
            --TODO FINISH REMOVE THIS--this should not check if this column is a LuaEditor columns (in the Set ini file) and run the editor on it if so.
            if (cProc and class.haspublicmember(cProc, "OnSelectionChanged")) then
                local tBaseRow      = Grid.GetRow(_sBaseDataGrid, nRow);
                local sColumn       = Grid.GetCellText(_sBaseDataGrid, 0, nColumn);
                local sBase, sFinal = cProc.OnSelectionChanged(nRow, nColumn, sColumn, tBaseRow);

                if (rawtype(sBase) == "string" and rawtype(sFinal) == "string") then
                    Grid.SetCellText(_sBaseDataGrid,    nRow, nColumn, sBase);
                    Grid.SetCellText(_sFinalDataGrid,   nRow, nColumn, sFinal);
                end

            end

            --check if the user has updated any relevant files
            local bRowProcCRCMismatch  = _tRowUpdate.RowProc[nRow];
            local bDrawCRCMismatch      = _tRowUpdate.Draw[nRow];
            local bProcessed            = false;

            if (bRowProcCRCMismatch) then
                ProcSys.ProcessActiveRow();
                _tRowUpdate.RowProc[nRow] = false;
                bProcessed = true;
            end

            --try to draw the card
            if (_nLastRow ~= nRow or bRowProcCRCMismatch or bDrawCRCMismatch) then

                if not (bProcessed) then
                    _nLastRow = nRow;
                    --get the card's row
                    local tRow  = Grid.GetRow(_sFinalDataGrid, nRow);
                    UserEnv.ProcSysUpdateRoot {_tRow = tRow};
                    TryDrawCard(tRow);
                end

                if (bDrawCRCMismatch) then
                    _tRowUpdate.Draw[nRow] = false;
                end

            end]]
            --ELProfiler.format()
        end,

        OnTimer = function(nID)

            if (nID == _nFileSyncTimerID and _bReady) then
                local bResetRows    = _bDataChanged or _bCFGChanged or _bENVChanged or _bRowProcChanged;
                local bRedraw       = bResetRows or _bDrawChanged;

                if (_bDataChanged) then
                    _bDataChanged = false;
                    MainMenu.SetEnabled("Card Set:>Save", false);
                    LoadFileToGrid(pData); --TODO BUG FIX this...get the proper data path, this is nil here
                    --TODO Reselect row
                end

                if (_bCFGChanged) then
                    _bCFGChanged = false;
                    UserEnv.UserUpdateCFG(BuildUserTable(_sGameName, _tFileSpecCFG));
                end

                if (_bENVChanged) then
                    _bENVChanged = false;
                    UserEnv.UserUpdateENV(BuildUserTable(_sGameName, _tFileSpecENV));
                end

                if (_bRowProcChanged) then
                    _bRowProcChanged = false;
                    _fRowProc = BuildCardSetFunction("RowProc", _sRowProcCode);
                end

                if (bResetRows) then
                    SetReprocRows(true);
                    ProcSys.ProcessActiveRow(true);
                    _tReprocRows[_nCurrentRow] = false;
                end

                if (_bDrawChanged) then
                    _bDrawChanged = false;
                    local fDraw = BuildCardSetFunction("Draw", _sDrawCode);
                    Forge.SetDrawFunction(fDraw);
                end

                if (bRedraw) then
                    _bDrawChanged = false;
                    TryDrawCard(Grid.GetRow(_sFinalDataGrid, _nCurrentRow));
                end

                --[[
                if (_oActiveCardSet) then
                    local nRowProcCRC  = _oActiveCardSet.GetLiveFile("RowProc").CRC;
                    local nDrawCRC      = _oActiveCardSet.GetLiveFile("Draw").CRC;
                    local bProcessed    = false;

                    if (nRowProcCRC ~= _nRowProcCRC) then
                        _nRowProcCRC = nRowProcCRC;

                        if (_nCurrentRow ~= -1) then
                            ProcSys.ProcessActiveRow();
                            _tRowCRC.RowProc[_nCurrentRow] = _nRowProcCRC;
                            --_tRowCRC.RowProc[_nCurrentRow] = false;
                            _tRowCRC.Draw[_nCurrentRow]     = nDrawCRC;
                            bProcessed = true;
                        end

                    end

                    if (nDrawCRC ~= _nDrawCRC) then
                        _nDrawCRC = nDrawCRC;

                        if (not bProcessed and _nCurrentRow ~= -1) then
                            _tRowCRC.Draw[_nCurrentRow] = _nDrawCRC;
                            TryDrawCard(Grid.GetRow(_sFinalDataGrid, _nCurrentRow));
                        end

                    end

                end]]

            end

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
        ProcessActiveRow = function(bSkipRedraw)
            local nRow = _nCurrentRow;

            --reprocess the row
            --Grid.SetRedraw(_sBaseDataGrid, false); --TODO this may work, check it out
            for nColumn = 1, Grid.GetColumnCount(_sBaseDataGrid) - 1 do
                ProcessCell(nRow, nColumn);
            end
            --Grid.SetRedraw(_sBaseDataGrid, true);

            --get the final row
            local tRow  = Grid.GetRow(_sFinalDataGrid, nRow);
            --update the final row in the UserEnv
            UserEnv.ProcSysUpdateRoot {_tRow = tRow};
            --redraw the card
            Forge.SetActiveRow(tRow);

            if not (bSkipRedraw) then
                Forge.RequestCardRedraw();
            end

            --TryDrawCard(tRow);--TODO QUESTION...should this be drawing here? Seems like it's doing more than the name suggests.
        end,

        --TODO put in examplke and show the args for the callback
        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.RegisterExporter
            @desc Registers or removes an exporter function for a specific export file.<br>Generally defined within the Init.lua file for the game.
            @param string pFile Path to the export target file.
            @param function fExport Exporter function; passing a non-function unregisters it.
            @note
                <ul>
                    <li>Exporters are registered per active game.</li>
                    <li>Requires the target file to exist.</li>
                    <li>Exporter function contract is user-defined.</li>
                </ul>
        !]]
        --[[RegisterExporter = function(pFile, fExport)

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
]]
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
                MainMenu.SetEnabled("Card Set:>Save", false);
            end

        end,


        --[[SaveDraft = function(sID, sCode)--TODO FIX and FINISH
            local wEnv = setmetatable({
                sID     = sID,
                string  = string,
            }, { __index = _G });

            local fChunk, sError = load(TextFile.ReadToString(FS.Drafts), "Drafts.lua", "t", wEnv); --TODO QUESTION IS THIS EVEN BEING USED ANYMORE???

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

        end,]]


        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.PrepActiveGame
            @desc Ensures the exporter and processor registries exist for the active game.
        !]]
        --[[PrepActiveGame = function()
            --ensure the processor and exporter tables exist for the current game and clear them
            _tExporters[_sGame]         = {};
             _tProcResolvers[_sGame]    = nil;
        end,]]


        --[[SetIsValid = function(pFolder)
            local function CheckFile(sFile)
                return File.DoesExist((pFolder.."\\"..sFile):gsub("\\\\", "\\"));
            end
--TODO check other things as needed
            local bFilesAreValid =
                rawtype(pFolder) == "string"        and
                Folder.DoesExist(pFolder)           and
                Path.GetEndFolder(pFolder):isuuid() and
                CheckFile("Data.csv")               and
                CheckFile("Draw.lua")               and
                CheckFile("Info.cfg")               and
                CheckFile("Proc.lua")

            local pSetID = bFilesAreValid and Path.GetEndFolder(pFolder) or "NO_SET_FOUND";
            return bFilesAreValid, pSetID;
        end,]]

        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.SetWindowVisible
            @desc Shows or hides a ProcSys tool window.
            @param number eTool Tool/window identifier.
            @param boolean vFlag Visibility state.
        !]]
        SetWindowVisible = function(eTool, vFlag)
            --TODO assertions
            local bFlag     = rawtype(vFlag) == "boolean" and vFlag or false;
            local tWindows  = _tWindows;

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
