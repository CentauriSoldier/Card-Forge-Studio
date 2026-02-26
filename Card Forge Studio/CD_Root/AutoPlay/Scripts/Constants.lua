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

constant("PROCSYS_FILE_SYNC_TIMER_ID",        101);
constant("PROCSYS_FILE_SYNC_TIMER_INTERVAL",  1500);
constant("PROCSYS_TO_TABLE", 1);
constant("PROCSYS_TO_NUMBER", 2);

local function BuildFilerTable(sName, sExt)
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
        __newindex = function(t, k, v) error("Attempt to write to read-only Filer constant.", 2) end
    };

    setmetatable(tDecoy, tMeta);

    return tDecoy;
end

--filenames/extensions
constant("FILER_CARDSET_DATA",      BuildFilerTable("Data",     "csv"));
constant("FILER_CARDSET_DRAW",      BuildFilerTable("Draw",     "lua"));
constant("FILER_CARDSET_INFO",      BuildFilerTable("Info",     "ini"));
constant("FILER_CARDSET_CELLPROC",  BuildFilerTable("CellProc", "lua"));
