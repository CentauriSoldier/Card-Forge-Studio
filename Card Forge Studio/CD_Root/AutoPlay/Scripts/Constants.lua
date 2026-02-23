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
