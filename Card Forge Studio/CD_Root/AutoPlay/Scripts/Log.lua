local function DateTime()
    return System.GetDate(DATE_FMT_ISO)..' @ '..System.GetTime(TIME_FMT_MIL);
end

local _oLogFont;
local _oLogWindows  = {};
local _pLog         = FS.AppDir.."\\Log.log";
local _sLogObject   = LOG_OBJECT;
--local _sEntrySep    = "${datetime}";
--local _tCanvases    = {};
local _sLevel       = "";
local _sMessage     = "";
local _nLastY       = 0;
local _bLogVisible  = true;

local function UpdateMessage(vMessage)
    local sMessage = rawtype(vMessage) == "string" and vMessage or "";

    if not (sMessage:isempty()) then
        sMessage = "["..DateTime().." ".._sLevel.."]\r\n"..sMessage;
    end

    _sMessage = sMessage;
end

return class("Log",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
    --    __INIT = function(stapub)
            --_oLogFont = DrawingFont.Load("Courier New", 12); --TODO FINISH get from INI
        --end,

        --Log = function(this, sAuthCode) end, --static constructor (runs after class object creation)
        OnClose = function(sPage)
            Window.Hide(_oLogWindows[sPage].GetWndHandle());
        end,
        OnShow = function(sPage)

            if not (_oLogWindows[sPage]) then
                local oLog = WinAMS(OBJECT_INPUT, "Log", 100, 100, 500, 500, _sLogObject);
                _oLogWindows[sPage] = oLog;

                local fOriginalOnClose = oLog.GetCallback(WinSys.EVENT.OnClose);
                local fOnClose = function(hWnd)
                    _bLogVisible = false;
                    return fOriginalOnClose(hWnd);
                end

                oLog.SetCallback(WinSys.EVENT.OnClose, fOnClose);
                -- If you want to manually force-fit once:
                --_oLogWindows[sPage].FillWindow()
                --Log.Note("This is a test of the log system.");
                --Input.SetEnabled(_sLogObject, true);
            end

            if (_bLogVisible) then
                Window.Show(_oLogWindows[sPage].GetWndHandle());
            else
                Window.Hide(_oLogWindows[sPage].GetWndHandle());
            end

        end,
        ClearFile = function()
            TextFile.WriteFromString(_pLog, "");
        end,
        ClearWindow = function()
            _sMessage = "";
            Input.SetText(_sLogObject, "");
        end,
        Error = function(sMessage)
            --TODO FINISH break the loginto lines...then print them
            _sLevel = "ERROR";
            UpdateMessage(sMessage);
            TextFile.WriteFromString(_pLog, _sMessage, true);
            Input.SetText(_sLogObject, _sMessage);
        end,
        Note = function(sMessage)
            _sLevel = "NOTE";
            UpdateMessage(sMessage);
            Input.SetText(_sLogObject, _sMessage);
        end,
        Show = function()
            local sPage = Application.GetCurrentPage();
            local sPageDialog = (not sPage:isempty()) and sPage or Application.GetCurrentDialog();
            Window.Show(_oLogWindows[sPageDialog].GetWndHandle());
            _bLogVisible = true;
        end,
        Warning = function(sMessage)
            _sLevel = "WARNING";
            UpdateMessage(sMessage);
            Input.SetText(_sLogObject, _sMessage);
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
