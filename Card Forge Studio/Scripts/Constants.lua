--[[!
@fqxn CFS.Constants
@desc Application constants and read-only filename specifications used by Studio services.
!]]

--[[!
@fqxn CFS.Constants.DEV_MODE
@pulsarlua boolean DEV_MODE
@desc Enables development-only startup behavior. Documentation generation also requires BUILD_DOX.
!]]
constant("DEV_MODE", true);
--[[!
@fqxn CFS.Constants.BUILD_DOX
@pulsarlua boolean BUILD_DOX
@desc Requests startup HTML and Pulsar documentation generation when DEV_MODE is also enabled.
!]]
constant("BUILD_DOX", true);

-- Protected globals supplied by the launcher before any application script runs:
-- APP_PATH: Absolute folder containing Card Forge Studio.exe, resolved by the launcher.
-- Other such constants are set in the launcher.
-- These values are created in the launcher's Lua state, not assigned in this file.

local pRoot    = assert(APP_PATH, "The launcher must initialize APP_PATH before Constants.");
assert(_AppDataLocal, "The launcher must initialize _AppDataLocal before Constants.");
local pScripts = io.normalizepath(pRoot.."/Scripts");

--[[!
@fqxn CFS.Constants._Scripts
@pulsarlua string _Scripts
@desc Absolute normalized path to the application Scripts folder.
!]]
constant("_Scripts",      pScripts);
--[[!
@fqxn CFS.Constants._Images
@pulsarlua string _Images
@desc Path to bundled application images.
!]]
constant("_Images",       pRoot.."/Images");
--[[!
@fqxn CFS.Constants._Fonts
@pulsarlua string _Fonts
@desc Path to bundled application fonts.
!]]
constant("_Fonts",        pRoot.."/Fonts");
--[[!
@fqxn CFS.Constants._Bin
@pulsarlua string _Bin
@desc Path to bundled runtime binaries.
!]]
constant("_Bin",          pRoot.."/Bin");
--[[!
@fqxn CFS.Constants._ExeFolder
@pulsarlua string _ExeFolder
@desc Application installation folder supplied by the launcher.
!]]
constant("_ExeFolder",    pRoot);
-- Documentation has not been migrated; use the existing archive read-only.
--[[!
@fqxn CFS.Constants._Docs
@pulsarlua string _Docs
@desc Path to retained archived documentation assets, including licenses and templates; distinct from the current Docs output folder.
!]]
constant("_Docs",         pRoot.."/CFS Archive/Docs");

local nTimerID = 99;
--[[!
@fqxn CFS.Modules.Constants.Private.GetNextTimerID
@desc Allocates the next application timer identifier from the file-local counter.
@vis private
!]]
local function GetNextTimerID()
    nTimerID = nTimerID + 1;
    return nTimerID;
end

--[[!
@fqxn CFS.Constants.SANDBOX_TIME_START
@pulsarlua number SANDBOX_TIME_START
@desc Startup Unix time in seconds used as the origin for the user environment Uptime function.
!]]
constant("SANDBOX_TIME_START", os.time());

--csv parameters
--[[!
@fqxn CFS.Constants.BACKUP_MINIMUM_INTERVAL
@pulsarlua number BACKUP_MINIMUM_INTERVAL
@desc Minimum interval in minutes between CSV backups.
!]]
constant("BACKUP_MINIMUM_INTERVAL", 6); --in minutes
--[[!
@fqxn CFS.Constants.BACKUP_MAX_FILE_COUNT
@pulsarlua number BACKUP_MAX_FILE_COUNT
@desc Maximum number of CSV backup files retained after saving.
!]]
constant("BACKUP_MAX_FILE_COUNT", 10);
--[[!
@fqxn CFS.Constants.CSV_DELIMITER
@pulsarlua string CSV_DELIMITER
@desc Delimiter used when parsing and encoding card-set CSV data.
!]]
constant("CSV_DELIMITER", ',');

--image parameters
--[[!
@fqxn CFS.Constants.HOR
@pulsarlua number HOR
@desc Retained horizontal-orientation identifier; value 0.
!]]
constant("HOR", 0); --TODO QUESTION DO I NEED THESE ANYMORE?
--[[!
@fqxn CFS.Constants.VER
@pulsarlua number VER
@desc Retained vertical-orientation identifier; value 1.
!]]
constant("VER", 1);
--[[!
@fqxn CFS.Constants.BIT_DEPTH_32
@pulsarlua number BIT_DEPTH_32
@desc Retained 32-bit image-depth value used by the archived renderer.
!]]
constant("BIT_DEPTH_32", 32);



--[[!
@fqxn CFS.Constants.FOLDER_WIKI
@pulsarlua string FOLDER_WIKI
@desc Name of the game Wiki folder.
!]]
constant("FOLDER_WIKI", "Wiki");
--[[!
@fqxn CFS.Constants.FOLDER_CARD_SETS
@pulsarlua string FOLDER_CARD_SETS
@desc Name of the game CardSets folder, available before game preparation.
!]]
constant("FOLDER_CARD_SETS", "CardSets"); --this must be here since it needs to be accessed before the game is prepped

--constant("TIMER_HTML_PROCESS_INTERVAL", 3200);
--constant("TIMER_HTML_PROCESS_ID",       GetNextTimerID());

local hLicense = assert(io.open(_Docs.."/Licenses/licenses.txt", "rb"));
local sLicense = assert(hLicense:read("a"));
assert(hLicense:close());

--[[!
@fqxn CFS.Constants.LICENSE
@pulsarlua string LICENSE
@desc Bundled license text loaded from the archived documentation Licenses folder.
!]]
constant("LICENSE", sLicense);

--[[!
@fqxn CFS.Constants.FORGE_CANVAS_NAME
@pulsarlua string FORGE_CANVAS_NAME
@desc Retained canvas control name used by the archived renderer.
!]]
constant("FORGE_CANVAS_NAME",               "cvs card");
--[[!
@fqxn CFS.Constants.FORGE_REDRAW_TIMER_ID
@pulsarlua number FORGE_REDRAW_TIMER_ID
@desc Allocated identifier for the retained Forge redraw timer.
!]]
constant("FORGE_REDRAW_TIMER_ID",           GetNextTimerID());
--[[!
@fqxn CFS.Constants.FORGE_REDRAW_TIMER_INTERVAL
@pulsarlua number FORGE_REDRAW_TIMER_INTERVAL
@desc Interval in milliseconds for the active main-window rendering timer.
!]]
constant("FORGE_REDRAW_TIMER_INTERVAL",     10);
--[[!
@fqxn CFS.Constants.FORGE_REDRAW_SIZING_INTERVAL
@pulsarlua number FORGE_REDRAW_SIZING_INTERVAL
@desc Retained resize-redraw delay in milliseconds for the archived renderer.
!]]
constant("FORGE_REDRAW_SIZING_INTERVAL",    300);
--[[!
@fqxn CFS.Constants.FORGE_STATUS_NAME
@pulsarlua string FORGE_STATUS_NAME
@desc Retained renderer status control name.
!]]
constant("FORGE_STATUS_NAME",               "par status");
--[[!
@fqxn CFS.Constants.FORGE_STATUS_MOUSE_NAME
@pulsarlua string FORGE_STATUS_MOUSE_NAME
@desc Retained mouse-coordinate status control name.
!]]
constant("FORGE_STATUS_MOUSE_NAME",         "par status mouse");
--[[!
@fqxn CFS.Constants.FORGE_STATUS_MOUSE_NEG_NAME
@pulsarlua string FORGE_STATUS_MOUSE_NEG_NAME
@desc Retained negative mouse-coordinate status control name.
!]]
constant("FORGE_STATUS_MOUSE_NEG_NAME",     "par status mouse neg");

--[[!
@fqxn CFS.Constants.PROCSYS_LIVE_FILE_REPO_TIMER_INTERVAL
@pulsarlua number PROCSYS_LIVE_FILE_REPO_TIMER_INTERVAL
@desc Polling interval in milliseconds for active game and card-set file watches.
!]]
constant("PROCSYS_LIVE_FILE_REPO_TIMER_INTERVAL",   250);
--[[!
@fqxn CFS.Constants.PROCSYS_SYNC_TIMER_ID
@pulsarlua number PROCSYS_SYNC_TIMER_ID
@desc Allocated identifier for the retained processing synchronization timer.
!]]
constant("PROCSYS_SYNC_TIMER_ID",                   GetNextTimerID());
--[[!
@fqxn CFS.Constants.PROCSYS_SYNC_TIMER_INTERVAL
@pulsarlua number PROCSYS_SYNC_TIMER_INTERVAL
@desc Configured processing synchronization interval in milliseconds.
!]]
constant("PROCSYS_SYNC_TIMER_INTERVAL",             10);
--[[!
@fqxn CFS.Constants.PROCSYS_TO_TABLE
@pulsarlua number PROCSYS_TO_TABLE
@desc Reserved table-coercion selector exposed to row-processing scripts as _TABLE.
!]]
constant("PROCSYS_TO_TABLE",                        1);
--[[!
@fqxn CFS.Constants.PROCSYS_TO_NUMBER
@pulsarlua number PROCSYS_TO_NUMBER
@desc Numeric-coercion selector exposed to row-processing scripts as _NUMBER.
!]]
constant("PROCSYS_TO_NUMBER",                       2);
--[[!
@fqxn CFS.Constants.PROCSYS_GRID_BASE
@pulsarlua string PROCSYS_GRID_BASE
@desc Retained base-data grid identifier.
!]]
constant("PROCSYS_GRID_BASE",                       "grd Base data");
--[[!
@fqxn CFS.Constants.PROCSYS_GRID_FINAL
@pulsarlua string PROCSYS_GRID_FINAL
@desc Retained final-data grid identifier.
!]]
constant("PROCSYS_GRID_FINAL",                      "grd Final data");



--[[!
@fqxn CFS.Constants.DATA_TYPE_BASE
@pulsarlua string DATA_TYPE_BASE
@desc Retained label identifying base CSV data.
!]]
constant("DATA_TYPE_BASE",                          "CSV Base");
--[[!
@fqxn CFS.Constants.DATA_TYPE_FINAL
@pulsarlua string DATA_TYPE_FINAL
@desc Retained label identifying final CSV data.
!]]
constant("DATA_TYPE_FINAL",                         "CSV Final");




--[[!
@fqxn CFS.Constants.DOX_EXPORT_FILENAME
@pulsarlua string DOX_EXPORT_FILENAME
@desc Base filename used for a loaded game documentation HTML file.
!]]
constant("DOX_EXPORT_FILENAME",     "API Documentation");


--[[!
@fqxn CFS.Modules.Constants.Private.BuildFileSpecTable
@desc Builds a read-only file specification with basename, extension aliases, and complete filename.
@vis private
@param any sName Name.
@param any sExt Ext.
!]]
local function BuildFileSpecTable(sName, sExt)
    local tActual   = {
        Name        = sName,
        Filename    = sName,
        Ext         = sExt,
        Extension   = sExt,
        Full        = sName..'.'..sExt,
    };
    local tDecoy    = {};
    local tMeta     = {
        __index = tActual,
        __newindex = function(t, k, v) error("Attempt to write to read-only FileSpec table.", 2) end,
        __type = "FileSpec",
    };

    setmetatable(tDecoy, tMeta);

    return tDecoy;
end

--filenames/extensions
--[[!
@fqxn CFS.Constants.FILESPEC_CARDSET_DATA
@pulsarlua table FILESPEC_CARDSET_DATA
@desc Card-set CSV data file specification. Its fields are read-only; the exported constant spelling is preserved.
@field string Ext Extension without its leading dot. Value: csv.
@field string Extension Alias of Ext. Value: csv.
@field string Filename Alias of Name. Value: Data.
@field string Full Filename including extension. Value: Data.csv.
@field string Name Filename without extension. Value: Data.
!]]
constant("FILESPEC_CARDSET_DATA",           BuildFileSpecTable("Data",          "csv"));
--[[!
@fqxn CFS.Constants.FILESPEC_CARDSET_DRAW
@pulsarlua table FILESPEC_CARDSET_DRAW
@desc Card front drawing script file specification. Its fields are read-only; the exported constant spelling is preserved.
@field string Ext Extension without its leading dot. Value: lua.
@field string Extension Alias of Ext. Value: lua.
@field string Filename Alias of Name. Value: Draw.
@field string Full Filename including extension. Value: Draw.lua.
@field string Name Filename without extension. Value: Draw.
!]]
constant("FILESPEC_CARDSET_DRAW",           BuildFileSpecTable("Draw",          "lua"));
--[[!
@fqxn CFS.Constants.FILESPEC_CARDSET_DRAWBACK
@pulsarlua table FILESPEC_CARDSET_DRAWBACK
@desc Card back drawing script file specification. Its fields are read-only; the exported constant spelling is preserved.
@field string Ext Extension without its leading dot. Value: lua.
@field string Extension Alias of Ext. Value: lua.
@field string Filename Alias of Name. Value: DrawBack.
@field string Full Filename including extension. Value: DrawBack.lua.
@field string Name Filename without extension. Value: DrawBack.
!]]
constant("FILESPEC_CARDSET_DRAWBACK",       BuildFileSpecTable("DrawBack",      "lua"));
--[[!
@fqxn CFS.Constants.FILESPEC_CARDSET_INFO
@pulsarlua table FILESPEC_CARDSET_INFO
@desc Card-set metadata file specification. Its fields are read-only; the exported constant spelling is preserved.
@field string Ext Extension without its leading dot. Value: ini.
@field string Extension Alias of Ext. Value: ini.
@field string Filename Alias of Name. Value: Info.
@field string Full Filename including extension. Value: Info.ini.
@field string Name Filename without extension. Value: Info.
!]]
constant("FILESPEC_CARDSET_INFO",           BuildFileSpecTable("Info",          "ini"));
--[[!
@fqxn CFS.Constants.FILESPEC_CARDSET_ROWPROC
@pulsarlua table FILESPEC_CARDSET_ROWPROC
@desc Card-set row processor file specification. Its fields are read-only; the exported constant spelling is preserved.
@field string Ext Extension without its leading dot. Value: lua.
@field string Extension Alias of Ext. Value: lua.
@field string Filename Alias of Name. Value: RowProc.
@field string Full Filename including extension. Value: RowProc.lua.
@field string Name Filename without extension. Value: RowProc.
!]]
constant("FILESPEC_CARDSET_ROWPROC",        BuildFileSpecTable("RowProc",       "lua"));
--[[!
@fqxn CFS.Constants.FILESPEC_CARDSET_CODECOLUMMS
@pulsarlua table FILESPEC_CARDSET_CODECOLUMMS
@desc Card-set code-column definitions file specification. Its fields are read-only; the exported constant spelling is preserved.
@field string Ext Extension without its leading dot. Value: txt.
@field string Extension Alias of Ext. Value: txt.
@field string Filename Alias of Name. Value: CodeColumns.
@field string Full Filename including extension. Value: CodeColumns.txt.
@field string Name Filename without extension. Value: CodeColumns.
!]]
constant("FILESPEC_CARDSET_CODECOLUMMS",    BuildFileSpecTable("CodeColumns",   "txt"));
--[[!
@fqxn CFS.Constants.FILESPEC_GAME_CFG
@pulsarlua table FILESPEC_GAME_CFG
@desc Game configuration script file specification. Its fields are read-only; the exported constant spelling is preserved.
@field string Ext Extension without its leading dot. Value: lua.
@field string Extension Alias of Ext. Value: lua.
@field string Filename Alias of Name. Value: CFG.
@field string Full Filename including extension. Value: CFG.lua.
@field string Name Filename without extension. Value: CFG.
!]]
constant("FILESPEC_GAME_CFG",               BuildFileSpecTable("CFG",           "lua"));
--[[!
@fqxn CFS.Constants.FILESPEC_GAME_ENV
@pulsarlua table FILESPEC_GAME_ENV
@desc Game environment script file specification. Its fields are read-only; the exported constant spelling is preserved.
@field string Ext Extension without its leading dot. Value: lua.
@field string Extension Alias of Ext. Value: lua.
@field string Filename Alias of Name. Value: ENV.
@field string Full Filename including extension. Value: ENV.lua.
@field string Name Filename without extension. Value: ENV.
!]]
constant("FILESPEC_GAME_ENV",               BuildFileSpecTable("ENV",           "lua"));
