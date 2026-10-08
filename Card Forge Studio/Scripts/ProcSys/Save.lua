-- Write all source rows; grid sorting and filtering do not affect storage.
local wx = require("wx");
local Save = {};

local function readFile(pFile)
    local hFile = assert(io.open(pFile, "rb"));
    local sText, sError = hFile:read("a");
    local bClosed, sCloseError = hFile:close();
    assert(sText, sError);
    assert(bClosed, sCloseError);
    return sText;
end

local function backupFiles(pFolder)
    local tFiles  = {};
    local oFolder = wx.wxDir(pFolder);
    local bFound, sName = oFolder:GetFirst("*.csv", wx.wxDIR_FILES);
    while (bFound) do
        if (sName:match("^%d+%-%d+%.csv$")) then tFiles[#tFiles + 1] = sName; end
        bFound, sName = oFolder:GetNext();
    end
    oFolder:delete();
    table.sort(tFiles);
    return tFiles;
end

function Save.write(pFile, pBackup, tHeaders, tRows, sExpected)
    assert(#tHeaders > 0, "Cannot save data without headers.");
    local sOriginal = readFile(pFile);
    assert(sOriginal == sExpected, "The CSV changed outside Card Forge Studio. Reload it before saving; your edits have been retained.");
    local sCSV;

    if (#tRows > 0) then
        sCSV = FTCSV.encode(tRows, CSV_DELIMITER, {fieldsToKeep = tHeaders,});
    else
        local tQuoted = {};
        for nColumn, sHeader in ipairs(tHeaders) do tQuoted[nColumn] = '"'..sHeader:gsub('"', '""')..'"'; end
        sCSV = table.concat(tQuoted, CSV_DELIMITER).."\r\n";
    end
    if (sOriginal:sub(1, 3) == "\239\187\191") then sCSV = "\239\187\191"..sCSV; end
    local tCheck, tCheckHeaders = FTCSV.parse(sCSV, CSV_DELIMITER, {loadFromString = true,});
    assert(#tCheck == #tRows and #tCheckHeaders == #tHeaders, "CSV save validation failed.");
    for nColumn, sHeader in ipairs(tHeaders) do
        assert(tCheckHeaders[nColumn] == sHeader, "CSV header order changed while saving.");
        for nRow, tRow in ipairs(tRows) do assert(tCheck[nRow][sHeader] == tRow[sHeader], "CSV cell changed while saving."); end
    end

    assert(wx.wxDirExists(pBackup) or wx.wxFileName.Mkdir(pBackup, 511, wx.wxPATH_MKDIR_FULL), "Cannot create the CSV backup folder.");
    local tBackups = backupFiles(pBackup);
    local nNow = os.time();
    local nLatest = #tBackups > 0 and tonumber(tBackups[#tBackups]:match("^(%d+)")) or nil;
    if (not nLatest or nNow - nLatest >= BACKUP_MINIMUM_INTERVAL * 60) then
        local nSuffix = 0;
        local pSnapshot;
        repeat
            pSnapshot = pBackup.."/"..string.format("%012d-%04d.csv", nNow, nSuffix);
            nSuffix = nSuffix + 1;
        until not wx.wxFileExists(pSnapshot)
        assert(wx.wxCopyFile(pFile, pSnapshot, false), "Cannot back up the CSV. Save aborted.");
        assert(readFile(pSnapshot) == sOriginal, "CSV backup verification failed. Save aborted.");
    end

    local oStaging = wx.wxFile();
    local pStaging = wx.wxFileName.CreateTempFileName(pFile..".saving-", oStaging);
    if (oStaging:IsOpened()) then oStaging:Close(); end
    local bStagingClosed = not oStaging:IsOpened();
    oStaging:delete();
    assert(bStagingClosed, "Cannot close the temporary CSV file.");
    assert(pStaging ~= "", "Cannot create a temporary CSV file.");
    local bOK, sError = xpcall(function()
        local hFile = assert(io.open(pStaging, "wb"));
        local bWritten, sWriteError = hFile:write(sCSV);
        local bClosed, sCloseError = hFile:close();
        assert(bWritten, sWriteError);
        assert(bClosed, sCloseError);
        assert(readFile(pStaging) == sCSV, "Temporary CSV verification failed.");
        assert(readFile(pFile) == sOriginal, "The CSV changed during saving. Save aborted.");
        assert(wx.wxRenameFile(pStaging, pFile, true), "Cannot replace the CSV. Your edits have been retained.");
    end, debug.traceback);
    if (not bOK) then
        wx.wxRemoveFile(pStaging);
        error(sError, 0);
    end

    -- Prune only our timestamped backups after a successful replacement.
    tBackups = backupFiles(pBackup);
    for nIndex = 1, #tBackups - BACKUP_MAX_FILE_COUNT do
        if (not wx.wxRemoveFile(pBackup.."/"..tBackups[nIndex])) then
            pcall(Log.Warning, "Could not remove an old CSV backup: "..tBackups[nIndex]);
        end
    end
    return sCSV;
end

return Save;