-- Ported from the archived Log class. The service owns disk and memory;
-- Windows.Log only displays the entries published here.
-- TODO Add explicit log sessions and window controls to browse, delete, and
-- export sessions. Display only the current session by default.
local _pLog         = assert(APP_PATH).."/log.log";
local _tEntries     = {};
local _tListeners   = {};
local _sSpacer      = "\r\n\r\n";

local function DateTime()
    return os.date("%Y-%m-%d @ %H:%M:%S");
end

local function Notify()
    for _, fListener in ipairs(_tListeners) do
        fListener();
    end
end

local function LogIt(vMessage, vLevel, bSkipWrite)
    local sMessage  = rawtype(vMessage) == "string" and tostring(vMessage) or "";
    local sLevel    = rawtype(vLevel) == "string" and vLevel or "NOTE";
    local sTime     = DateTime();
    local sDisplay  = sMessage:gsub("\t", "\r\n"):gsub("stack traceback:", "\r\nstack traceback:\r\n");
    local sRecord   = (sMessage ~= "" and "["..sLevel.." > "..sTime.."]\r\n" or "")..sDisplay.._sSpacer;

    -- Keep the current file/memory synchronization: Debug is persisted too.
    -- The archived Debug method requested display-only messages with bSkipWrite.
    local hFile = assert(io.open(_pLog, "a"), "Cannot open application log.");
    assert(hFile:write(sRecord));
    assert(hFile:close(), "Cannot close application log.");

    _tEntries[#_tEntries + 1] = {
        level       = sLevel,
        timestamp   = sTime,
        message     = sDisplay,
    };
    Notify();
end

return class("Log",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        ClearFile = function()
            local hFile = assert(io.open(_pLog, "w"));
            assert(hFile:close(), "Cannot close cleared log file.");
        end,
        ClearWindow = function()
            _tEntries = {};
            Notify();
        end,
        Debug = function(sMessage)
            LogIt(sMessage, "DEBUG", true);
        end,
        Error = function(sMessage)
            LogIt(sMessage, "ERROR");
        end,
        Note = function(sMessage)
            LogIt(sMessage, "NOTE");
        end,
        OnShutdown = function()
            -- TODO Restore archived log-window geometry/visibility persistence using WX.
        end,
        OnStartup = function()
            -- TODO Restore archived log-window geometry/visibility from application configuration.
        end,
        Show = function()
            require("Windows.Log").Show();
        end,
        GetEntries = function()
            return _tEntries;
        end,
        GetEntryCount = function()
            return #_tEntries;
        end,
        subscribe = function(fListener)
            assert(rawtype(fListener) == "function", "Log.subscribe requires a function.");
            _tListeners[#_tListeners + 1] = fListener;
        end,
        ClearLog = function()
            Log.ClearFile();
            Log.ClearWindow();
        end,
        Warning = function(sMessage)
            LogIt(sMessage, "WARNING");
        end,
    },
    {--PRIVATE
        Log = function(this, cdat) end,
    },
    {--PROTECTED

    },
    {--PUBLIC

    },
    BaseLog,   --extending class
    false, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
