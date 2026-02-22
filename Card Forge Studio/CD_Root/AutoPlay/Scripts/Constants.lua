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
constant("CANVAS_NAME", "cvs card");
