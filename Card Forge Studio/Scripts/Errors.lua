--[[!
@fqxn CFS.Modules.Errors
@desc Non-modal error reporting with a disk fallback.
!]]

-- Error reporting never opens or raises a window.
local Errors = {};
local _bReporting = false;

--[[!
@fqxn CFS.Modules.Errors.report
@pulsarlua function Errors.report
@desc Reports an error through Log and falls back to the disk log when logging fails or reporting recurses. Never opens a window.
@param any vError Error.
@param any bRenderer Renderer.
!]]
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
