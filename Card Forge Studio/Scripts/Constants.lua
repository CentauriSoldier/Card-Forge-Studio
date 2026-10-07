-- Protected globals supplied by the launcher before any application script runs:
-- APP_PATH: Absolute folder containing Card Forge Studio.exe, resolved by the launcher.
-- Other such constants are set in the launcher.
-- These values are created in the launcher's Lua state, not assigned in this file.

local pRoot    = assert(APP_PATH, "The launcher must initialize APP_PATH before Constants.");
assert(_AppDataLocal, "The launcher must initialize _AppDataLocal before Constants.");
local pScripts = io.normalizepath(pRoot.."/Scripts");

constant("_Scripts",      pScripts);
constant("_Images",       pRoot.."/Images");
constant("_Bin",          pRoot.."/Bin");
constant("_ExeFolder",    pRoot);
-- Documentation has not been migrated; use the existing archive read-only.
constant("_Docs",         pRoot.."/CFS Archive/Docs");

local nTimerID = 99;
local function GetNextTimerID()
    nTimerID = nTimerID + 1;
    return nTimerID;
end

constant("SANDBOX_TIME_START", os.time());

--csv parameters
constant("BACKUP_MINIMUM_INTERVAL", 6); --in minutes
constant("BACKUP_MAX_FILE_COUNT", 10);
constant("CSV_DELIMITER", ',');

--image parameters
constant("HOR", 0); --TODO QUESTION DO I NEED THESE ANYMORE?
constant("VER", 1);
constant("BIT_DEPTH_32", 32);



constant("FOLDER_CARD_SETS", "CardSets"); --this must be here since it needs to be accessed before the game is prepped

--constant("TIMER_HTML_PROCESS_INTERVAL", 3200);
--constant("TIMER_HTML_PROCESS_ID",       GetNextTimerID());

local hLicense = assert(io.open(_Docs.."/Licenses/licenses.txt", "rb"));
local sLicense = assert(hLicense:read("a"));
assert(hLicense:close());

constant("LICENSE", sLicense);

constant("FORGE_CANVAS_NAME",               "cvs card");
constant("FORGE_REDRAW_TIMER_ID",           GetNextTimerID());
constant("FORGE_REDRAW_TIMER_INTERVAL",     10);
constant("FORGE_REDRAW_SIZING_INTERVAL",    300);
constant("FORGE_STATUS_NAME",               "par status");
constant("FORGE_STATUS_MOUSE_NAME",         "par status mouse");
constant("FORGE_STATUS_MOUSE_NEG_NAME",     "par status mouse neg");

constant("PROCSYS_LIVE_FILE_REPO_TIMER_INTERVAL",   250);
constant("PROCSYS_SYNC_TIMER_ID",                   GetNextTimerID());
constant("PROCSYS_SYNC_TIMER_INTERVAL",             10);
constant("PROCSYS_TO_TABLE",                        1);
constant("PROCSYS_TO_NUMBER",                       2);
constant("PROCSYS_GRID_BASE",                       "grd Base data");
constant("PROCSYS_GRID_FINAL",                      "grd Final data");

constant("FILE_LITEXL", _Bin.."\\lite-xl\\lite-xl.exe");
constant("FILE_BUILT_IN_ROW_FILTERS",               _Scripts.."\\ProcSys\\CSV\\RowFilters.lua");

constant("ROW_FILTER_DEFAULT",                      "*All");

constant("DATA_TYPE_BASE",                          "CSV Base");
constant("DATA_TYPE_FINAL",                         "CSV Final");


--[[!
    @fqxn CFS.Enums.PANE
    @desc Identifiers for common window panes/tools.
    <ul>
        <li><p><strong>MAIN</strong>        – The main app window.</p></li>
        <li><p><strong>DATA_EDIT</strong>   – Base data editor pane.</p></li>
        <li><p><strong>DATA_VIEW</strong>   – Final data viewer pane.</p></li>
    </ul>
!]]
enum("PANE", {"MAIN", "DATA_EDIT", "DATA_VIEW"});


constant("DOX_EXPORT_FILENAME",     "API Documentation");


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
constant("FILESPEC_CARDSET_DATA",           BuildFileSpecTable("Data",          "csv"));
constant("FILESPEC_CARDSET_DRAW",           BuildFileSpecTable("Draw",          "lua"));
constant("FILESPEC_CARDSET_DRAWBACK",       BuildFileSpecTable("DrawBack",      "lua"));
constant("FILESPEC_CARDSET_INFO",           BuildFileSpecTable("Info",          "ini"));
constant("FILESPEC_CARDSET_ROWPROC",        BuildFileSpecTable("RowProc",       "lua"));
constant("FILESPEC_CARDSET_CODECOLUMMS",    BuildFileSpecTable("CodeColumns",   "txt"));
constant("FILESPEC_GAME_CFG",               BuildFileSpecTable("CFG",           "lua"));
constant("FILESPEC_GAME_ENV",               BuildFileSpecTable("ENV",           "lua"));
constant("FILESPEC_ROWFILTERS",             BuildFileSpecTable("RowFilters",    "lua"));
