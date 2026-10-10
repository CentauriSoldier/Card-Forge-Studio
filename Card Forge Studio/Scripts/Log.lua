--[[!
@fqxn CFS.Classes.Log
@desc Static logging service providing disk records, in-memory entries, and native-window notifications.
!]]

-- Ported from the archived Log class. The service owns disk and memory;
-- Windows.Log only displays the entries published here.
-- TODO Add explicit log sessions and window controls to browse, delete, and
-- export sessions. Display only the current session by default.
local _pLog         = assert(APP_PATH).."/log.log";
local _tEntries     = {};
local _tListeners   = {};
local _sSpacer      = "\r\n\r\n";

--[[!
@fqxn CFS.Classes.Log.Private.DateTime
@desc Formats the current local date and time for log records.
@vis private
!]]
local function DateTime()
    return os.date("%Y-%m-%d @ %H:%M:%S");
end

--[[!
@fqxn CFS.Classes.Log.Private.Notify
@desc Notifies subscribers that the in-memory log entries changed.
@vis private
!]]
local function Notify()
    for _, fListener in ipairs(_tListeners) do
        fListener();
    end
end

--[[!
@fqxn CFS.Classes.Log.Private.LogIt
@desc Appends formatted text to the disk log, stores an in-memory entry, and notifies listeners. The skip-write argument is retained but disk writing is unconditional.
@param any vMessage Message.
@param any vLevel Level.
@param any bSkipWrite Skip write.
@vis private
!]]
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
        --[[!
        @fqxn CFS.Classes.Log.Methods.ClearFile
        @pulsarlua function Log.ClearFile
        @desc Truncates the disk log without changing the in-memory entries.
        !]]
        ClearFile = function()
            local hFile = assert(io.open(_pLog, "w"));
            assert(hFile:close(), "Cannot close cleared log file.");
        end,
        --[[!
        @fqxn CFS.Classes.Log.Methods.ClearWindow
        @pulsarlua function Log.ClearWindow
        @desc Clears in-memory entries and notifies listeners without truncating the disk log.
        !]]
        ClearWindow = function()
            _tEntries = {};
            Notify();
        end,
        --[[!
        @fqxn CFS.Classes.Log.Methods.Debug
        @pulsarlua function Log.Debug
        @desc Records a DEBUG entry in both disk and memory; the retained skip-write request is not applied by LogIt.
        @param any sMessage Message.
        !]]
        Debug = function(sMessage)
            LogIt(sMessage, "DEBUG", true);
        end,
        --[[!
        @fqxn CFS.Classes.Log.Methods.Error
        @pulsarlua function Log.Error
        @desc Records an ERROR entry in disk and memory.
        @param any sMessage Message.
        !]]
        Error = function(sMessage)
            LogIt(sMessage, "ERROR");
        end,
        --[[!
        @fqxn CFS.Classes.Log.Methods.Note
        @pulsarlua function Log.Note
        @desc Records a NOTE entry in disk and memory.
        @param any sMessage Message.
        !]]
        Note = function(sMessage)
            LogIt(sMessage, "NOTE");
        end,
        --[[!
        @fqxn CFS.Classes.Log.Methods.OnShutdown
        @pulsarlua function Log.OnShutdown
        @desc Retained shutdown hook; currently performs no operation.
        !]]
        OnShutdown = function()
            -- TODO Restore archived log-window geometry/visibility persistence using WX.
        end,
        --[[!
        @fqxn CFS.Classes.Log.Methods.OnStartup
        @pulsarlua function Log.OnStartup
        @desc Retained startup hook; currently performs no operation.
        !]]
        OnStartup = function()
            -- TODO Restore archived log-window geometry/visibility from application configuration.
        end,
        --[[!
        @fqxn CFS.Classes.Log.Methods.Show
        @pulsarlua function Log.Show
        @desc Shows the native log window.
        !]]
        Show = function()
            require("Windows.Log").Show();
        end,
        --[[!
        @fqxn CFS.Classes.Log.Methods.GetEntries
        @pulsarlua function Log.GetEntries
        @desc Returns the live in-memory log-entry array.
        !]]
        GetEntries = function()
            return _tEntries;
        end,
        --[[!
        @fqxn CFS.Classes.Log.Methods.GetEntryCount
        @pulsarlua function Log.GetEntryCount
        @desc Returns the number of in-memory log entries.
        !]]
        GetEntryCount = function()
            return #_tEntries;
        end,
        --[[!
        @fqxn CFS.Classes.Log.Methods.subscribe
        @pulsarlua function Log.subscribe
        @desc Registers a callback for changes to in-memory entries.
        @param any fListener Listener.
        !]]
        subscribe = function(fListener)
            assert(rawtype(fListener) == "function", "Log.subscribe requires a function.");
            _tListeners[#_tListeners + 1] = fListener;
        end,
        --[[!
        @fqxn CFS.Classes.Log.Methods.ClearLog
        @pulsarlua function Log.ClearLog
        @desc Clears both disk and memory logs.
        !]]
        ClearLog = function()
            Log.ClearFile();
            Log.ClearWindow();
        end,
        --[[!
        @fqxn CFS.Classes.Log.Methods.Warning
        @pulsarlua function Log.Warning
        @desc Records a WARNING entry in disk and memory.
        @param any sMessage Message.
        !]]
        Warning = function(sMessage)
            LogIt(sMessage, "WARNING");
        end,
    },
    {--PRIVATE
        --[[!
        @fqxn CFS.Classes.Log.Private.Log
        @desc Private class constructor; the logging service exposes static operations.
        @vis private
        !]]
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
