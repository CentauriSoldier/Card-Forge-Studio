--[[!
@fqxn CFS.Classes.Log
@desc
<section aria-label="Log overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Log</h2><p style="font-size:1.15rem;margin:0">Logging records Studio activity and preserves useful context when something goes wrong.</p></div>
<h3>How it fits into your work</h3><p>Messages are retained in memory and written to disk. The log window presents readable cards with individual and whole-log copying.</p>
<h3>Follow the handoffs</h3><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,260px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">A record you can return to</h3><p style="margin:0">The log keeps records for inspection and provides them to the Log window. Instead of relying on a message that disappears, you can review what was reported and copy a record or the visible log when investigating a problem.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">Reporting is different from recovery</h3><p style="margin:0">The Errors service can route a failure into logging, and the window presents that information. Recording a failure does not undo an edit or retry a save. The operation that failed still decides whether to stop, preserve a draft, or offer another attempt.</p></article>
</div>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Log">Log</a></h3><p style="margin:0">The log window displays recorded messages as readable cards.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Errors">Errors</a></h3><p style="margin:0">Error reporting gives services a shared way to record failures without opening modal windows.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys">Processing System</a></h3><p style="margin:0">ProcSys keeps project files, card values, and the preview working together as you edit.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">The service records messages and the window displays them. Copying a message does not alter the disk log.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
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
@fqxn CFS.Classes.Log.Private.Functions.DateTime
@desc Formats the current local date and time for log records.
@vis private
!]]
local function DateTime()
    return os.date("%Y-%m-%d @ %H:%M:%S");
end

--[[!
@fqxn CFS.Classes.Log.Private.Functions.Notify
@desc Notifies subscribers that the in-memory log entries changed.
@vis private
!]]
local function Notify()
    for _, fListener in ipairs(_tListeners) do
        fListener();
    end
end

--[[!
@fqxn CFS.Classes.Log.Private.Functions.LogIt
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
        @fqxn CFS.Classes.Log.Private.Functions.Log
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
