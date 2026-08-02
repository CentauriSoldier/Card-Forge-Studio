local nTimerID = 99;
local function GetNextTimerID()
    nTimerID = nTimerID + 1;
    return nTimerID;
end

constant("APP_NAME",            "Card Forge Studio");
constant("APP_MAJOR_VERSION",   "v0.");
constant("APP_BUILD_VERSION",   ".alpha");

constant("SANDBOX_TIME_START", os.time());

--csv parameters
constant("BACKUP_MINIMUM_INTERVAL", 6); --in minutes
constant("BACKUP_MAX_FILE_COUNT", 10);
constant("CSV_DELIMITER", ',');

--image parameters
constant("HOR", 0); --TODO QUESTION DO I NEED THESE ANYMORE?
constant("VER", 1);
constant("BIT_DEPTH_32", 32);

constant("APP_CFG",     "Card Forge Studio.cfg");
constant("APP_GITHUB",  "https://github.com/CentauriSoldier/Card-Forge-Studio");
constant("APP_PATREON", "https://www.patreon.com/CentauriSoldier");
constant("APP_WEBSITE", "https://www.cardforge.studio/");


constant("FOLDER_CARD_SETS", "CardSets"); --this must be here since it needs to be accessed before the game is prepped

--constant("TIMER_HTML_PROCESS_INTERVAL", 3200);
--constant("TIMER_HTML_PROCESS_ID",       GetNextTimerID());

constant("LICENSE", TextFile.ReadToString(_Docs.."\\Licenses\\licenses.txt"));

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
constant("PROCSYS_GRID_BASE",                       "grd base data");
constant("PROCSYS_GRID_FINAL",                      "grd final data");

constant("FILE_LITEXL", _Bin.."\\lite-xl\\lite-xl.exe");

constant("ROW_FILTER_DEFAULT",                      "*All");

constant("CSV_TYPE_BASE",                           "CSV Base");
constant("CSV_TYPE_FINAL",                          "CSV Final");


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
