-- Error reporting never opens or raises a window.
local Errors = {};
local _bReporting = false;

function Errors.report(vError, bRenderer)
    local sError = tostring(vError);
    local pFile = APP_PATH.."/log.log";
    if (bRenderer) then sError = "Renderer: "..sError; end
    if (_bReporting) then
        local hFile = io.open(pFile, "a");
        if (hFile) then hFile:write(sError.."\n"); hFile:close(); end
        return;
    end
    _bReporting = true;
    local bLogged = false;
    if (Log) then bLogged = pcall(Log.Error, sError); end
    if (not bLogged) then
        local hFile = io.open(pFile, "a");
        if (hFile) then hFile:write(sError.."\n"); hFile:close(); end
    end
    _bReporting = false;
end

return Errors;
