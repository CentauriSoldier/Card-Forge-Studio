------------------------------------- Localization
local Grid                          = Grid;
    local GetCellText               = Grid.GetCellText;
    local SetCellText               = Grid.SetCellText;

local class                         = class;
local base64                        = base64;
    local enc                       = base64.enc;
    local dec                       = base64.dec;
--TODO FINISH LOCALIZATION
------------------------------------- Module Localization
local _pLiteXL                      = FILE_LITEXL;
local FS                            = FS;
local CSV                           = require("ProcSys.CSV");
------------------------------------- General
local _pAppCFG                      = FS.AppCFG;
local _bAllowSave                   = false;
local _nLiveFileRepoTimerInterval   = PROCSYS_LIVE_FILE_REPO_TIMER_INTERVAL;
local _bSelectionMade               = false;
------------------------------------- Windows
local _tWindows                     = {}; --stores windows
local _bWindowsBuilt                = false;
local _ePane                        = PANE;
------------------------------------- Export
local _tExporters                   = {};
------------------------------------- RowProc / Special Procs
local _oRowProcLiveFileRepo         = LiveFileRepo();
local _bRowProcChanged              = false;
local _sRowProcCode                 = "";
local _bRowProcChanged              = false;
------------------------------------- Draw (Draw function doesn't get stored here as it's sent to Forge upon creation)
local _oDrawLiveFileRepo            = LiveFileRepo(); --QUESTION SHOULD THIS BE IN THE FORGE MODULE?
local _bDrawChanged                 = false;
local _sDrawCode                    = "";
local _bDrawBackChanged             = false;
local _sDrawBackCode                = "";
------------------------------------- Font Styles
local _bFontStylesChanged           = false;
local _sFontStyleINI                = "";
------------------------------------- Game Including CGF & ENV
local _oGameLiveFileRepo            = LiveFileRepo();
local _oActiveGame                  = null;
local _sGameName                    = "";
local _sCFGCode                     = "";
local _sENVCode                     = "";
local _tCFG                         = null;
local _tENV                         = null;
------------------------------------- Grid
local _bAutoSizeGrid                = true;
local _sBaseDataGrid                = PROCSYS_GRID_BASE;
local _sFinalDataGrid               = PROCSYS_GRID_FINAL;
local _tGridByType                  = {[DATA_TYPE_BASE] = PROCSYS_GRID_BASE, [DATA_TYPE_FINAL] = PROCSYS_GRID_FINAL};
local _bIsLoading                   = false;
local _nCurrentRow                  = 1;
local _nCurrentColumn               = 1;
------------------------------------- CSV
local _pActiveCSV                   = "";
local _pExportCSV                   = "";
------------------------------------- Exporters
local _oUserExportersLiveFileRepo   = LiveFileRepo();
local _tUserExporters               = {};
--local _bExportersChanged            = true;
local _tChangedUserExporterIDs      = {};
------------------------------------- CardSet
local _oCardSetLiveFileRepo         = LiveFileRepo();
local _oActiveCardSet               = false;
local _sCardSetName                 = "";
local _nCardWidth                   = 0;
local _nCardHeight                  = 0;
local _sInfo                        = "";       --TODO FINISH THIS SYSTEM!!
------------------------------------- Timer Stuff
local _nFileSyncTimerID             = PROCSYS_SYNC_TIMER_ID;
local _nFileSyncTimerInterval       = PROCSYS_SYNC_TIMER_INTERVAL;
local _bSyncBlocked                 = false;
local _bSyncBusy                    = false;
------------------------------------- Timer Tracker Variables
local _bCFGChanged                  = false;
local _bENVChanged                  = false;
local _bDataChanged                 = false;
local _bInfoChanged                 = false;    --TODO FINISH THIS SYSTEM!!
local _bRowFiltersChanged           = false;
local _bCodeColumnsChanged          = false;
------------------------------------- File Specs
local _tFileSpecCFG                 = FILESPEC_GAME_CFG;
local _tFileSpecENV                 = FILESPEC_GAME_ENV; --TODO add all neede file specs here
local _tFileSpecDraw                = FILESPEC_CARDSET_DRAW;
local _tFileSpecRowProc             = FILESPEC_CARDSET_ROWPROC;
local _tFileSpecRowFilters          = FILESPEC_ROWFILTERS;
------------------------------------- Preemptive Declarations (Local Functions)
local
BuildFunction,
BuildUserTable,
BuildWindows,
TryBackupFile,
TryDrawCard,
UpdateCardSetLiveFileRepo,
UpdateCodeCell,
UpdateGameLiveFileRepo,
UpdateUserExporter,
UpdateUserExporters,
XPCallError;
----------------------------------------------------------------------------------------------------------------------
--TODO Clean these up
local _nDescriptionMaxWidth         = 100;
--local _tRowCRC          = {};
--local _nDrawCRC         = -1;
--local _nRowProcCRC     = -1;
--local _bDrawUpdated     = false;
--local _bRowProcUpdated = false;

--local _tRedrawRows      = {};  --tracks which rows need reprocessed/redrawn

--may be used by the proc's cell processor to get final values
--local _nFinalValueRow = -1; --TODO QUESTION is the ever used?
--local function GetFinalValue(sColumn)
--    return GetCellText(_sFinalDataGrid, _nFinalValueRow, _tColumnNameIDMap[sColumn]);
--end

--[[--when changes occur
Data            - Reload Set +
CFG/UserEnv     - Reinit game +
Cell/RowProc - Reproc All Rows (on demand ofc)
Draw            - Redraw Current Row
]]
-----------------------------------------------------------------------------------------------------------------------

UpdateUserExporter = function(sID)

end

UpdateUserExportersFileRepo = function()
    local oLiveFileRepo = _oUserExportersLiveFileRepo;

    --reset the repo
    oLiveFileRepo.Reset();
    --clear the exporters tables
    _tUserExporters             = {};
    _tChangedUserExporterIDs    = {};

    local tExporterFolderNames = Exporters.GetAllNames();

    for _, sName in pairs(tExporterFolderNames) do
        local pFolder = FS["UserExporters"..sName];
        local tFiles  = File.Find(pFolder.."\\", "*.lua", false, false, nil, nil);

        if (rawtype(tFiles) == "table" and #tFiles > 0) then

            for __, pFile in pairs(tFiles) do
                local tParts            = String.SplitPath(pFile);
                local sUserExporterName = tParts.Filename;
                local sID               = sName..sUserExporterName;

                --watch each user exporter file
                oLiveFileRepo.Add(sID, pFile, _nLiveFileRepoTimerInterval,
                function(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
                    _tChangedUserExporterIDs[sID] = sNewText;
                    --_bExportersChanged = true;
                end);

                --read in the exporter initially
                _tChangedUserExporterIDs[sID] = TextFile.ReadToString(pFile);
            end

        end

    end

    oLiveFileRepo.StartAll();
end




--[[
██╗      ██████╗  ██████╗ █████╗ ██╗         ███████╗██╗   ██╗███╗   ██╗ ██████╗████████╗██╗ ██████╗ ███╗   ██╗███████╗
██║     ██╔═══██╗██╔════╝██╔══██╗██║         ██╔════╝██║   ██║████╗  ██║██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
██║     ██║   ██║██║     ███████║██║         █████╗  ██║   ██║██╔██╗ ██║██║        ██║   ██║██║   ██║██╔██╗ ██║███████╗
██║     ██║   ██║██║     ██╔══██║██║         ██╔══╝  ██║   ██║██║╚██╗██║██║        ██║   ██║██║   ██║██║╚██╗██║╚════██║
███████╗╚██████╔╝╚██████╗██║  ██║███████╗    ██║     ╚██████╔╝██║ ╚████║╚██████╗   ██║   ██║╚██████╔╝██║ ╚████║███████║
╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝]]


--[[!
@fqxn CFS.Classes.ProcSys.Methods.BuildFunction
@desc Compiles and executes a Lua chunk that returns a function used by the active card set. The chunk is loaded inside the UserEnv environment and must return a callable function.
@param string sCaller A convenience name given for easy isolation of erros.
@param string sName Logical name of the function being built (for example "Draw" or "RowProc"). Used for chunk identification and error reporting.
@param string sChunk Lua source code that returns the function implementation.
@return function fFunction The function returned by the executed chunk.
@note The chunk executes inside the UserEnv environment. The chunk must return a function or an error is raised. Errors during loading or execution include the card set name for context.
@example
    local sCode = "[".."[" ..
        "return function(nRow, nColumn, sColumn, tRow, sText)\n" ..
        "    return sText:upper()\n" ..
        "end" ..
    "]".."]"

    local fProc = BuildFunction("RowProc", sCode)
    local sValue = fProc(1, 2, "Name", {}, "test")
    -- sValue == "TEST"
@vis Static Private
!]]
BuildFunction = function (vCaller, sName, sChunk)
    local bCallerIsString = rawtype(vCaller);--QUESTION ??? is this isupposed to check if it's a string?
    local sCaller = bCallerIsString and vCaller or "Unknown Caller";

    if not (rawtype(sName) == "string" and not sName:isempty()) then
        error(sCaller..": Argument 1 (function name) must be non-empty string. Got "..rawtype(sName)..".", 2);
    end

    if not (bCallerIsString and not vCaller:isempty()) then
        error(sCaller..": Argument 1 (function name) must be non-empty string. Got "..rawtype(sName)..".", 2);
    end

    if not (rawtype(sChunk) == "string" and not sChunk:isempty()) then
        error(sCaller..": Argument 2 (function chunk) must be non-empty string. Got "..rawtype(sChunk)..".", 2);
    end

    local sChunkName = _sCardSetName..' '..sName;

    local fChunk, sError = load(sChunk, sChunkName, "t", UserEnv.Get());
    if not (fChunk) then
        error("Error loading '"..sName.."' function.\r\n"..sError, 1);
    end

    local bOK, fRetOrErr = pcall(fChunk);
    if not (bOK) then
        error("Error running '"..sName.."' chuck (function).\r\n"..fRetOrErr, 1);
    end

    if not (rawtype(fRetOrErr) == "function") then
        error("Error building '"..sName.."' function.\r\nExpected return type function. Got "..rawtype(fRetOrErr)..'.', 1);
    end

    return fRetOrErr;
end




BuildExporterFunction = function(sID, sChunk)

end


--[[!
@fqxn CFS.Classes.ProcSys.Methods.BuildUserTable
@desc Loads, compiles, and executes a Lua file for the specified game and returns the table produced by that file. The file is executed inside the UserEnv environment.
@param string sGame Name of the active game used for contextual error reporting.
@param table tFileSpec File specification table describing the script file to load.
@return table tUserTable The table returned by the executed Lua file.
@note The file is read from the Scripts directory using the provided file specification. The chunk is loaded with the UserEnv environment and executed safely using pcall. The script must return a table or an error is raised.
@vis Static Private
!]]
BuildUserTable = function(sGame, tFileSpec)
    local sInitChunk = TextFile.ReadToString(FS.Game.Scripts.."\\"..tFileSpec.Full);
    --TODO CHECK AND ERROR on bad file

    local sName = tFileSpec.Filename;

    --the error message in case things go south
    local sChunkName = sGame.." "..sName;

    --try to load the chuck
    local fChunk, sError = load(sInitChunk, sChunkName, "t", UserEnv.Get());
    if not (fChunk) then
        error("Error running '"..sName.."' file for Game '"..sGame.."'.\r\n"..sError, 2);
    end

    --try to call the chunk
    local bOK, sRetOrError = pcall(fChunk);

    if not (bOK) then
        error("Error running '"..sName.."' file for Game '"..sGame.."'.\r\n"..sRetOrError, 2);
    end

    local tUserTable = sRetOrError;

    if not (type(tUserTable) == "table") then
        error("Error in return from '"..sName.."' file for Game '"..sGame.."'.\r\nExpected type table, Got "..type(tUserTable)..'.', 2);
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
BuildWindows = function()

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
        local oDataEdit = WinAMS(OBJECT_GRID, "Base Data Editor", 0, 0, 800, 1000, PROCSYS_GRID_BASE, nil, OnReadyGrids)--TODO get values from INI, CHANGE NAME
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
        local oDataView = WinAMS(OBJECT_GRID, "Final Data Viewer", 1400, 0, 800, 1000, PROCSYS_GRID_FINAL, nil, OnReadyGrids)--TODO get values from INI
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












local function ForceWriteFinalData()

end










--converts the (filtered) row index shown in the grid to the mapped row index in the actual data table
FilterIndexToActual = function(nRow)
    _tRowFilterMap[nRow] = 999999999999999999999999 --TODO
end



-- TODO TODO TODO TODO TODO TODO TURN BACK ON, FIX STORAGE LOCATION, AND UPDATE DOX
--[[!
@fqxn CFS.Classes.ProcSys.Methods.TryBackupFile
@desc Creates a timestamped backup of the specified CSV file in the ProcSys backup directory if the configured backup interval has elapsed.
@param string pFile Full path to the CSV file to back up.
@return boolean bWriteFile True if a new backup file was written, false if no backup was needed.
@note Backups are stored in a folder named after the CSV file inside the ProcSys backup directory. The timestamp is generated using the current ISO date and military time collapsed to minute precision. If the backup interval has not elapsed since the latest backup, no new file is written. When the maximum backup count is reached, the oldest backup file is deleted before writing a new one.
@vis Static Private
!]]
TryBackupFile = function(pFile)--tFiles)
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
@fqxn CFS.Classes.ProcSys.Methods.TryDrawCard
@desc Requests Forge to render the card represented by the provided processed row table.
@param table tRow Processed row table containing the final grid values for the card.
@note Rendering occurs only if the row contains data. The row is first assigned as the active Forge row and then a redraw request is issued.
@vis Static Private
!]]
TryDrawCard = function(tRow)
    --make sure there's data in the row
    if (#tRow > 0) then
        Forge.SetActiveRow(tRow);
        Forge.RequestCardRedraw();
    end

end


--[[!
@fqxn CFS.Classes.ProcSys.Methods.UpdateCardSetLiveFileRepo
@desc Configures and starts the live file repository for the active card set, registering watchers for all card set files that can trigger runtime updates.
@note The repository is reset before watchers are added. Each watched file updates its associated state variables and change flags when modifications are detected. These flags are later processed by the ProcSys timer system to rebuild functions, reload configuration, or reprocess rows as needed.
@vis Static Private
!]]
UpdateCardSetLiveFileRepo = function()
    local oCardSet      = _oActiveCardSet;
    local oLiveFileRepo = _oCardSetLiveFileRepo;

    --reset the repo
    oLiveFileRepo.Reset();

    --watch the RowProc file
    oLiveFileRepo.Add("RowProc", FS.CardSet.RowProc, _nLiveFileRepoTimerInterval,
    function(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        _sRowProcCode       = sNewText;
        _bRowProcChanged    = true;
    end);

    --watch the Draw file
    oLiveFileRepo.Add("Draw", FS.CardSet.Draw, _nLiveFileRepoTimerInterval,
    function(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        _sDrawCode      = sNewText;
        _bDrawChanged   = true;
    end);

    --watch the DrawBack file
    oLiveFileRepo.Add("DrawBack", FS.CardSet.DrawBack, _nLiveFileRepoTimerInterval,
    function(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        _sDrawBackCode      = sNewText;
        _bDrawBackChanged   = true;
    end);

    --watch the Info file
    oLiveFileRepo.Add("Info", FS.CardSet.Info, _nLiveFileRepoTimerInterval,
    function(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        _sInfo          = sNewText;
        _bInfoChanged   = true;
    end);

    --watch the Code Columns file
    oLiveFileRepo.Add("CodeColumns", FS.CardSet.CodeColumns, _nLiveFileRepoTimerInterval,
    function(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        _sCodeColumns           = sNewText;
        _bCodeColumnsChanged    = true;
    end);

    --watch the Data file
    oLiveFileRepo.Add("Data", FS.CardSet.Data, _nLiveFileRepoTimerInterval,
    function(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        _bDataChanged = true;
    end);

    oLiveFileRepo.StartAll();
end




--[[!
@fqxn CFS.Classes.ProcSys.Methods.UpdateGameLiveFileRepo
@desc Configures and starts the live file repository for the active game, registering watchers for game configuration, environment scripts, and style files.
@note The repository is reset before watchers are added. Changes to CFG or ENV files update their cached source code and set change flags so the ProcSys timer can rebuild the corresponding runtime tables. The Styles.ini file watcher updates the cached style definition and marks the font style system for refresh.
@vis Static Private
!]]
UpdateGameLiveFileRepo = function()
    local sGame         = _oActiveGame;
    local oLiveFileRepo = _oGameLiveFileRepo;

    --reset the live file repo
    oLiveFileRepo.Reset();

    --CFG Files
    local function NotifyCFGChanged(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        _sCFGCode       = sNewText;
        _bCFGChanged    = true;
    end

    oLiveFileRepo.Add("CFG", FS.Game.Scripts.."\\".._tFileSpecCFG.Full, _nLiveFileRepoTimerInterval, NotifyCFGChanged);
    local tCFGFiles = File.Find(FS.Game.CFG.."\\", "*.lua", false, false, nil, nil);

    if (type(tCFGFiles) == "table") then

        for nIndex, pFile in pairs(tCFGFiles) do
            oLiveFileRepo.Add("CFG_"..tostring(nIndex):format("%02d"), pFile, _nLiveFileRepoTimerInterval, NotifyCFGChanged);
        end

    end

    --ENV Files
    local function NotifyENVChanged(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        _sENVCode       = sNewText;
        _bENVChanged    = true;
    end

    oLiveFileRepo.Add("ENV", FS.Game.Scripts.."\\".._tFileSpecENV.Full, _nLiveFileRepoTimerInterval, NotifyENVChanged);
    local tENVFiles = File.Find(FS.Game.ENV.."\\", "*.lua", false, false, nil, nil);

    if (type(tENVFiles) == "table") then

        for nIndex, pFile in pairs(tENVFiles) do
            oLiveFileRepo.Add("ENV_"..tostring(nIndex):format("%02d"), pFile, _nLiveFileRepoTimerInterval, NotifyENVChanged);
        end

    end

    --Styles.ini
    local function NotifyFontStylesChanged(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        _sFontStyleINI      = sNewText;
        _bFontStylesChanged = true;
    end

    oLiveFileRepo.Add("Styles", FS.Game.Styles, _nLiveFileRepoTimerInterval, NotifyFontStylesChanged);

    --RowFilters
    local function NotifyRowFiltersChanged(tLiveFile, sOldText, sNewText, nOldCRC, nCRC)
        _bRowFiltersChanged = sNewText;
        _bRowFiltersChanged = true;
    end

    oLiveFileRepo.Add("RowFilters", FS.Game.RowFilters, _nLiveFileRepoTimerInterval, NotifyRowFiltersChanged);

    oLiveFileRepo.StartAll();
end







--[[!
@fqxn CFS.Classes.ProcSys.Methods.XPCallError
@desc Formats an error value into a stack traceback string suitable for use with xpcall error handlers.
@param any vErr Error value passed by xpcall.
@return string sTraceback Traceback string containing the error message and call stack.
@note The traceback starts two stack levels above the handler so that the handler itself is omitted from the reported stack.
@vis Static Private
!]]
XPCallError = function(vErr)
    return debug.traceback(tostring(vErr), 2);
end

--TODO MAKE SURE NAME IS UNIQUE BEFORE ALLOWING CHANGE IN TABLE!!!!!!!!!!!!!!!!!!!!! FINISH CODE RELIES ON UNIQUNESS!!!!!!

--[[
██████╗██╗      █████╗ ███████╗███████╗
██╔════╝██║     ██╔══██╗██╔════╝██╔════╝
██║     ██║     ███████║███████╗███████╗
██║     ██║     ██╔══██║╚════██║╚════██║
╚██████╗███████╗██║  ██║███████║███████║
 ╚═════╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝]]
--[[!
@fqxn CFS.Classes.ProcSys
@desc <h2>ProcSys</h2>

<p>
Coordinates the full ProcSys CSV workflow between the <strong>Base Data</strong> and <strong>Final Data</strong> grids.
The <strong>Base Data</strong> grid preserves the original source values exactly as authored, while the
<strong>Final Data</strong> grid stores the processed output generated from those values.
</p>

<p>
ProcSys also acts as the runtime bridge between grid data, the active card set, the active game,
<strong>UserEnv</strong>, and <strong>Forge</strong>. It is responsible for loading and processing CSV data,
caching processed rows, tracking rows that must be rebuilt, reacting to live file changes, and ensuring the
currently selected row can be previewed and redrawn correctly.
</p>

<h3>Core Responsibilities</h3>
<ul>
<li><strong>Loads</strong> card set CSV data into both the Base and Final grids.</li>
<li><strong>Processes</strong> each data row through the active row-processing logic and stores the result in the Final grid.</li>
<li><strong>Caches</strong> processed rows internally for fast lookup and preview.</li>
<li><strong>Tracks</strong> dirty rows so changed or invalidated rows can be rebuilt only when needed.</li>
<li><strong>Synchronizes</strong> runtime state with UserEnv and Forge for preview, redraw, and tool behavior.</li>
<li><strong>Monitors</strong> live game and card set files so RowProc, Draw, DrawBack, CFG, ENV, Styles, and CSV data can refresh at runtime.</li>
<li><strong>Builds</strong> and restores the auxiliary <strong>Base Data Editor</strong> and <strong>Final Data Viewer</strong> windows.</li>
<li><strong>Saves</strong> the active source CSV when saving is allowed.</li>
<li><strong>Backs up</strong> source CSV files according to the configured retention and interval rules.</li>
</ul>

<h3>Data Model</h3>
<ul>
<li><strong>Base Data grid</strong> = authoritative source/original values.</li>
<li><strong>Final Data grid</strong> = authoritative processed/export-ready cell values.</li>
<li><strong>_tRows</strong> = cached processed row tables built from the Final Data grid.</li>
<li><strong>_tDirtyRows</strong> = row indices that must be reprocessed before their cached data can be trusted.</li>
</ul>

<h3>How Processing Works</h3>
<p>
When a card set is loaded, ProcSys reads the CSV into both grids, rebuilds its column lookup tables, then processes
every data row into the Final grid and internal row cache. After the initial load, rows do not need to be rebuilt
blindly. Instead, ProcSys marks rows dirty when data or processing logic changes, then reprocesses them either
during timer-driven background work or immediately when the active row is required.
</p>

<p>
This lets ProcSys avoid unnecessary work while still guaranteeing that the currently selected row can be previewed
with fresh processed data. The active row may therefore be processed on demand, while the remaining dirty rows are
rebuilt incrementally according to the timer budget.
</p>

<h3>Runtime Synchronization</h3>
<p>
ProcSys continuously watches game and card set files through live file repositories. When relevant files change,
it updates cached source text, raises the corresponding change flags, and lets the timer system apply the required
rebuild steps in a controlled order.
</p>

<ul>
<li><strong>Data changes</strong> trigger a CSV reload.</li>
<li><strong>RowProc changes</strong> invalidate processed rows.</li>
<li><strong>CFG and ENV changes</strong> rebuild UserEnv runtime tables.</li>
<li><strong>Draw and DrawBack changes</strong> rebuild Forge draw functions.</li>
<li><strong>Style changes</strong> refresh font/style state and utility redraws.</li>
<li><strong>Code column changes</strong> rebuild the internal compiled code-column registry.</li>
</ul>

<h3>Workflow</h3>
<ol>
<li><strong>Prep</strong> the active game and initialize live repositories for game-level files.</li>
<li><strong>Load</strong> the active card set and register its live file watchers.</li>
<li><strong>Load</strong> the card set CSV into both grids.</li>
<li><strong>Process</strong> all data rows into the Final grid and processed row cache.</li>
<li><strong>Select</strong> a row to synchronize UserEnv and Forge with the ensured processed row.</li>
<li><strong>Edit</strong> data, rebuild affected rows, and optionally redraw preview output.</li>
<li><strong>React</strong> to live file changes through the timer synchronization cycle.</li>
<li><strong>Save</strong> the Base Data CSV when editing is complete.</li>
</ol>

<h3>Selection and Preview</h3>
<p>
When the user selects a row, ProcSys records the current selection, ensures the selected row has been processed,
updates the ProcSys root state in UserEnv, pushes the processed row into Forge as the active row, and requests
a redraw of the card preview.
</p>

<h3>Notes</h3>
<ul>
<li>ProcSys treats row <strong>0</strong> as the grid header row and data rows as <strong>1..n</strong>.</li>
<li>Saving is disabled during bulk loading and enabled only when editable data has changed.</li>
<li>Processed row caching allows Forge and related systems to consume row data without repeatedly rebuilding it.</li>
<li>Dirty-row processing keeps background synchronization efficient while preserving correct active-row previews.</li>
<li>ProcSys owns both data-grid windows and persists their size, position, visibility, and maximized state in the app INI.</li>
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
        BuildExport = function()

        end,
        GetActiveCardSet = function() --TODO QUESTION IS THIS EVER USED???
            return _oActiveCardSet;
        end,

        PrepGame = function(oGame)

            if not (type(oGame) == "Game") then
                error("ProcSys.PrepGame: Error prepping game. Expected Game object. Got "..type(oGame)..'.');
            end

            Log.Note("ProcSys.PrepGame: Updating user environment.");
            _sFontStyleINI      = TextFile.ReadToString(FS.Game.Styles);

            _oActiveGame        = oGame;
            _sGameName          = oGame.GetName();

            _bCFGChanged        = true;
            _bENVChanged        = true;
            _bFontStylesChanged = true;

            Log.Note("ProcSys.PrepGame: Updating LiveFile repository.");
            UpdateGameLiveFileRepo();
        end,
        --[[! TODO FIX REDO
            @fqxn CFS.Classes.ProcSys.Methods.GetCardSetName
            @desc Returns the active card set name.
            @return string sSetName Active card set identifier.
        !]]
        GetCardSetName = function()
            return _sCardSetName;
        end,

        --[[!TODO FINISH UPDATE
            @fqxn CFS.Classes.ProcSys.Methods.LoadCardSet
            @desc Loads a card set CSV into the Base and Final grids.
            @param string|nil vFile Optional CSV file path; prompts when omitted or invalid.
        !]]
        LoadCardSet = function(oCardSet)
            _bSelectionMade = false;

            local sCardSetName = oCardSet.GetName();
            Log.Note("ProcSys.LoadCardSet: Loading CardSet, '"..sCardSetName.."'.");

            --TODO assert type
            _oActiveCardSet = oCardSet;

            if (_bAllowSave) then
                local nYesNoCancel = Dialog.Message("Warning!", "You have unsaved changes.\r\nWould you like to save them now?", MB_YESNOCANCEL, MB_ICONEXCLAMATION, MB_DEFBUTTON1);

                if (nYesNoCancel == IDNO) then
                    _bAllowSave = false;
                elseif (nYesNoCancel == IDYES) then
                    ProcSys.SaveCSVs();
                    Application.Sleep(500);
                end

            end

            --backup the file (if needed)
            --TryBackupFile(pData); --TODO FIX uncomment and place where appropriate this when ready!!

            --set defaults
            FS.CardSet.Prep(oCardSet);

            _bAllowSave     = false;
            _pActiveCSV     = FS.CardSet.Data;
            _sDrawCode      = TextFile.ReadToString(FS.CardSet.Draw);
            _sDrawBackCode  = TextFile.ReadToString(FS.CardSet.DrawBack);
            _sRowProcCode   = TextFile.ReadToString(FS.CardSet.RowProc);
            _sCodeColumns   = TextFile.ReadToString(FS.CardSet.CodeColumns);
            _sCardSetName   = sCardSetName;
            _nCardWidth     = oCardSet.GetCardWidth();
            _nCardHeight    = oCardSet.GetCardHeight();

            UserEnv.ProcSysUpdateRoot {
                --Count     =  TODO
                _sCardSetName   = _sCardSetName,
                _nCardWidth     = _nCardWidth,
                _nCardHeight    = _nCardHeight,
            };

            --disable the save system
            MainMenu.SetEnabled("CardSet:>Save", false);
            --enable system directory browsing
            MainMenu.SetEnabled("CardSet:>Browse", true);

            UpdateCardSetLiveFileRepo();

            _bDataChanged           = true;
            _bRowProcChanged        = true;
            _bDrawChanged           = true;
            _bDrawBackChanged       = true;
            _bCodeColumnsChanged    = true;
            _bRowFiltersChanged     = true;

            Forge.SetActiveCardSet(oCardSet);
            Log.Note("ProcSys.LoadCardSet: CardSet, '"..sCardSetName.."', Loaded.");
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
            local bIndexOutOfBounds     = nRow < 1 or nColumn < 1;
            local bTextUnchanged        = sOldText == sNewText;
            local bProcess              = not (_bIsLoading or bIndexOutOfBounds or bTextUnchanged);

            if (bProcess) then
                --mark the row for reprocessing
                CSV.MarkRowDirty(nRow);
                --update saveability
                _bAllowSave = true;
                MainMenu.SetEnabled("CardSet:>Save", true);
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
        OnExit = function() --TODO RENAME THIS AND PUT IT IN THE PROPER PAGES TOO...such as OnShutdown
            --TODO FIX kill all global timers!
            if (_bAllowSave) then
                local nYesNoCancel = Dialog.Message("Warning!", "You have unsaved changes.\r\nWould you like to save them now?", MB_YESNOCANCEL, MB_ICONEXCLAMATION, MB_DEFBUTTON1);

                if (nYesNoCancel == IDNO) then
                    _bAllowSave = false;
                    Application.Exit(0);
                elseif (nYesNoCancel == IDYES) then
                    ProcSys.SaveCSVs();
                    Application.Sleep(1200);
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

            --start watchers/timer
            _oGameLiveFileRepo.StartAll(); --TODO add counter part to stop all in OnExit/OnClose
            Page.StartTimer(_nFileSyncTimerInterval, _nFileSyncTimerID);
        end,
        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.OnSelectionChanged
            @desc Called whenever one of the girds registers a cell selection change.<br>Draws (or attempts to draw) the card for the given row. Before drawing the card, it calls the row's processor method of the same name, if present, and updates the cell (<em>if text if the sBase and sFinal text values are sent back by the processor</em>).
            @param string sGrid The name of the grid.
            @param number nRow The row index of the cell selected.
            @param number nColumn The column index of the cell selected.
        !]]
        OnSelectionChanged = function(sGrid, nRow, nColumn)
            _bSelectionMade = true;

            --update the current selection
            --_nCurrentRow    = nRow;
            --_nCurrentColumn = nColumn;
            CSV.OnSelectionChanged(nRow + 1, nColumn + 1);

            if (_nLastRow ~= nRow) then
                --set the last row
                _nLastRow = nRow;
                --get the row (ensuring processing first)
                local tRow = CSV.EnsureRowProcessed(nRow + 1);
                --update the env
                UserEnv.ProcSysUpdateRoot {_tRow = tRow};
                --request card redraw
                TryDrawCard(tRow);
            end

            --local bRedrawn = false;


            --local sColumn = _tColumnNameIDMap[nColumn];

            --if (_tCodeColumns[sColumn]) then

            --end
            --if (_nLastRow ~= nRow) then
            --File.Run(_Bin.."\\lite-xl\\lite-xl.exe", _pTempFile, _TempFolder, SW_SHOWNORMAL, true);

            -- or [_nCurrentRow]) then-- or isspecial column) then
                --_fRowProc = BuildFunction("RowProc", TextFile.ReadToString(_oActiveCardSet.GetPath().."\\".._tFileSpecRowProc.Full));

                --_bReady = true;
                --ProcessRowDEDEDED(_nCurrentRow);

                --local tRow = GetRow(_sFinalDataGrid, nRow);
            --    UserEnv.ProcSysUpdateRoot {_tRow = tRow};
            --end

            --[[--THIS IS the special column proc section
            --TODO FINISH REMOVE THIS--this should not check if this column is a LuaEditor columns (in the Set ini file) and run the editor on it if so.
            if (cProc and class.haspublicmember(cProc, "OnSelectionChanged")) then
                local tBaseRow      = Grid.GetRow(_sBaseDataGrid, nRow);
                local sColumn       = GetCellText(_sBaseDataGrid, 0, nColumn);
                local sBase, sFinal = cProc.OnSelectionChanged(nRow, nColumn, sColumn, tBaseRow);

                if (rawtype(sBase) == "string" and rawtype(sFinal) == "string") then
                    Grid.SetCellText(_sBaseDataGrid,    nRow, nColumn, sBase);
                    Grid.SetCellText(_sFinalDataGrid,   nRow, nColumn, sFinal);
                end

            end]]
        end,
        OnTimer = function(nID)

            if (nID ~= _nFileSyncTimerID or _bSyncBlocked or _bSyncBusy) then
                return;
            end

            _bSyncBusy = true;

            local bOK, sErr = xpcall(function()
                local bResetRows            = _bDataChanged         or _bCFGChanged     or _bENVChanged         or _bRowProcChanged;
                local bRedrawCard           = bResetRows            or _bDrawChanged    or _bDrawBackChanged    or _bFontStylesChanged  or CSV.IsActiveRowDirty();
                local bRedrawUtils          = _bFontStylesChanged;
                local bReloadCodeColumns    = _bCodeColumnsChanged--  or _bDataChanged;QUESTION Should data changed trigger this? Currently, I think not

                if (_bInfoChanged) then
                    _bInfoChanged = false;
                    --TODO FINISH , also differentiate between game and cardset info
                end

                if (_bDataChanged) then
                    _bDataChanged = false;
                    MainMenu.SetEnabled("CardSet:>Save", false);

                    --disable Forge draw while the file is reloaded
                    Forge.SetDrawEnabled(false);

                    local bLoadGridOK, sLoadGridErr = xpcall(function()
                        --reload the file
                        _nRowCount, _nColumnCount = CSV.LoadFromFile(FS.CardSet.Data);
                        CSV.UpdateGrids();

                    end, XPCallError);

                    --always reenable Forge draw
                    Forge.SetDrawEnabled(true);

                    if not (bLoadGridOK) then
                        error(sLoadGridErr, 0);
                    end

                end

                if (_bCFGChanged) then
                    _bCFGChanged = false;
                    local tCFGOrErr;

                    local bOK, sErr = xpcall(function()
                        tCFGOrErr = BuildUserTable(_sGameName, _tFileSpecCFG);
                    end, XPCallError);

                    if (type(tCFGOrErr) == "table") then
                        UserEnv.UserUpdateCFG(tCFGOrErr);
                    end

                    if not (bOK) then
                        error(sErr, 0);
                    end

                end

                if (bReloadCodeColumns) then
                    _bCodeColumnsChanged = false;
                    CSV.UpdateCodeColumns(_sCodeColumns);
                end

                if (_bENVChanged) then
                    _bENVChanged = false;
                    local tENVOrErr;

                    local bOK, sErr = xpcall(function()
                        tENVOrErr = BuildUserTable(_sGameName, _tFileSpecENV);
                    end, XPCallError);

                    if (type(tENVOrErr) == "table") then
                        UserEnv.UserUpdateENV(tENVOrErr);
                    end

                    if not (bOK) then
                        error(sErr, 0);
                    end
                end

                --TODO FIX NOTE THIS IS Test, this might not go here in this order..not sure yet
                if (_bRowFiltersChanged) then
                    _bRowFiltersChanged = false;
                    CSV.UpdateRowFilters();
                end

                if (_bRowProcChanged) then
                    _bRowProcChanged = false;
                    local fProcOrErr = BuildFunction("_bRowProcChanged", "RowProc", _sRowProcCode);

                    if (rawtype(fProcOrErr) == "function") then
                        CSV.UpdateRowProc(fProcOrErr);
                    end

                end

                if (_bFontStylesChanged) then
                    _bFontStylesChanged = false;
                    FontStyle.UpdateINI(_sFontStyleINI);
                end

                if (bResetRows) then
                    CSV.MarkAllRowsDirty();
                end

                --CSV.ProcessDirtyRows(); TODO FIX UNCOMMENT AFTER REFACTOR

                if (_bSelectionMade) then

                    --if (bResetRows) then
                        --ProcessRow(_nCurrentRow, true);
                    --end

                    if (_bDrawChanged) then
                        _bDrawChanged = false;

                        local fDraw = BuildFunction("_bDrawChanged", "Draw", _sDrawCode);

                        if (rawtype(fDraw) == "function") then
                            Forge.SetDrawFunction(fDraw);
                        end
                    end

                    if (_bDrawBackChanged) then
                        _bDrawBackChanged = false;

                        local fDrawBack = BuildFunction("_bDrawBackChanged", "DrawBack", _sDrawBackCode);

                        if (rawtype(fDrawBack) == "function") then
                            Forge.SetDrawBackFunction(fDrawBack);
                        end
                    end

                    if (bRedrawCard) then
                        _bDrawChanged       = false;
                        _bDrawBackChanged   = false;
                        TryDrawCard(CSV.GetActiveRow());
                    end

                    if (bRedrawUtils) then
                        Forge.RequestUtilRedraw();
                    end

                end

            end, XPCallError);

            _bSyncBusy = false;

            if not (bOK) then
                error(sErr, 2);
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
            CSV.ProcessRow(_nCurrentRow, bSkipRedraw);
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
                MainMenu.SetEnabled("CardSet:>Save", false);
            end

        end,


        --[[!
            @fqxn CFS.Classes.ProcSys.Methods.SetWindowVisible
            @desc Shows or hides a ProcSys tool window.
            @param number eTool Tool/window identifier (<a href="#CFS.Enums.PANE">Window/Tool Enum</a>).
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
