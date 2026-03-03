constant("APP_NAME", "Card Forge Studio");

constant("SANDBOX_TIME_START", os.time());

--csv parameters
constant("BACKUP_MINIMUM_INTERVAL", 6); --in minutes
constant("BACKUP_MAX_FILE_COUNT", 10);
constant("CSV_DELIMITER", ',');

--image parameters
constant("HOR", 0); --TODO QUESTION DO I NEED THESE ANYMORE?
constant("VER", 1);
constant("BIT_DEPTH_32", 32);
constant("APP_CFG", "Card Forge.cfg");

--constant("TIMER_HTML_PROCESS_INTERVAL", 3200);
--constant("TIMER_HTML_PROCESS_ID",       97);

constant("LICENSE", TextFile.ReadToString(_Docs.."\\Licenses\\licenses.txt"));

constant("FORGE_CANVAS_NAME",               "cvs card");
constant("FORGE_REDRAW_TIMER_ID",           100);
constant("FORGE_REDRAW_TIMER_INTERVAL",     50);
constant("FORGE_REDRAW_SIZING_INTERVAL",    300);
constant("FORGE_STATUS_NAME",               "par status");
constant("FORGE_STATUS_MOUSE_NAME",         "par status mouse");
constant("FORGE_STATUS_MOUSE_NEG_NAME",     "par status mouse neg");

constant("PROCSYS_FILE_SYNC_TIMER_ID",        101);
constant("PROCSYS_FILE_SYNC_TIMER_INTERVAL",  400);
constant("PROCSYS_TO_TABLE",    1);
constant("PROCSYS_TO_NUMBER",   2);

constant("DOX_EXPORT_FILENAME",     "API Documentation");

constant("LOG_OBJECT", "inp log");

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
        __index = function(t, k)
            return tActual[k];
        end,
        __newindex = function(t, k, v) error("Attempt to write to read-only FileSpec table.", 2) end,
        __type = "FileSpec",
    };

    setmetatable(tDecoy, tMeta);

    return tDecoy;
end

--filenames/extensions
constant("FILER_CARDSET_DATA",      BuildFileSpecTable("Data",     "csv"));
constant("FILER_CARDSET_DRAW",      BuildFileSpecTable("Draw",     "lua"));
constant("FILER_CARDSET_INFO",      BuildFileSpecTable("Info",     "ini"));
constant("FILER_CARDSET_CELLPROC",  BuildFileSpecTable("CellProc", "lua"));
