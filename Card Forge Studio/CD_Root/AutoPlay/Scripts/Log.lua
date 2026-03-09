local function DateTime()
    return System.GetDate(DATE_FMT_ISO)..' @ '..System.GetTime(TIME_FMT_MIL);
end


local _tRect;
local _oLogFont;
local _oLogWindows  = {};
local _pLog         = FS.AppDir.."\\Log.log";
local _pAppCFG      = FS.AppCFG;
local _sINISection  = "LogWindow";
local _sLogObject   = LOG_OBJECT;
local _sFullLog     = "";
local _sSpacer      = "\r\n\r\n";
--local _sEntrySep    = "${datetime}";
--local _tCanvases    = {};
local _sLevel       = "";
local _sMessage     = "";
local _nLastY       = 0;
local _bLogVisible  = true;

local function UpdateMessage(vMessage)
    local sMessage = rawtype(vMessage) == "string" and tostring(vMessage) or "";

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

            if not (_tRect) then
                _tRect        = {
                    X         = tonumber(INIFile.GetValue(_pAppCFG, _sINISection, "X"))           or 0;
                    Y         = tonumber(INIFile.GetValue(_pAppCFG, _sINISection, "Y"))           or 0;
                    Width     = tonumber(INIFile.GetValue(_pAppCFG, _sINISection, "Width"))       or 100;
                    Height    = tonumber(INIFile.GetValue(_pAppCFG, _sINISection, "Height"))      or 100; --TODO MAGIC NUMBERS use defaults?
                };
            end

            if not (_oLogWindows[sPage]) then
                local oLog = WinAMS(OBJECT_INPUT, "Log", _tRect.X, _tRect.Y, _tRect.Width, _tRect.Height, _sLogObject, nil, function()
                    Input.SetText(_sLogObject, _sFullLog);
                end);
                _oLogWindows[sPage] = oLog;

                local fOriginalOnClose = oLog.GetCallback(WinSys.EVENT.OnClose);
                local fOnClose = function(hWnd)
                    _bLogVisible = false;
                    INIFile.SetValue(_pAppCFG, _sINISection, "Visible", "false");
                    return fOriginalOnClose(hWnd);
                end

                oLog.SetCallback(WinSys.EVENT.OnClose, fOnClose);

                local function FireAndSaveWindowInfo(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight, sCallback)
                    --fire the original callback
                    --tWindows[ePane].Callback[sCallback](hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight);

                    --save the window's dimensions
                    INIFile.SetValue(_pAppCFG, _sINISection, "Width", tostring(nWidth));
                    INIFile.SetValue(_pAppCFG, _sINISection, "Height", tostring(nHeight));

                    INIFile.SetValue(_pAppCFG, _sINISection, "X", tostring(nX));
                    INIFile.SetValue(_pAppCFG, _sINISection, "Y", tostring(nY));

                    --update whether the window is maximized
                    INIFile.SetValue(_pAppCFG, _sINISection, "Maximized", tostring(sCallback == "OnMaximize"));

                    oLog.FillWindow();
                end

                local function OnMaximize(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight)
                    FireAndSaveWindowInfo(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight, "OnMaximize");
                end

                local function OnResizeStop(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight)
                    FireAndSaveWindowInfo(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight, "OnResizeStop");
                end

                local function OnRestore(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight)
                    FireAndSaveWindowInfo(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight, "OnRestore");
                end

                --update the callbacks
                --oLog.SetCallback(WinSys.EVENT.OnClose,         OnClose);
                oLog.SetCallback(WinSys.EVENT.OnMaximize,      OnMaximize);
                oLog.SetCallback(WinSys.EVENT.OnResizeStop,    OnResizeStop);
                oLog.SetCallback(WinSys.EVENT.OnRestore,       OnRestore);

            end

            --restore the current log window
            local oLog = _oLogWindows[sPage];
            local hWnd = oLog.GetWndHandle();

            local nX            = tonumber(INIFile.GetValue(_pAppCFG, _sINISection, "X"))           or 0;
            local nY            = tonumber(INIFile.GetValue(_pAppCFG, _sINISection, "Y"))           or 0;
            local nWidth        = tonumber(INIFile.GetValue(_pAppCFG, _sINISection, "Width"))       or 800;
            local nHeight       = tonumber(INIFile.GetValue(_pAppCFG, _sINISection, "Height"))      or 1000; --TODO MAGIC NUMBERS use defaults?
            local bMaximized    = INIFile.GetValueBoolean(  _pAppCFG, _sINISection, "Maximized")    or false;

            Window.SetSize(hWnd, nWidth, nHeight);
            oLog.FillWindow();
            Window.SetPos(hWnd, nX, nY);

            if (bMaximized) then
                Window.Maximize(hWnd);
            end

            if not (INIFile.GetValueBoolean(_pAppCFG, _sINISection, "Visible")) then
                Window.Hide(hWnd);
            end

            --[[
            if (_bLogVisible) then
                Window.Show(_oLogWindows[sPage].GetWndHandle());
            else
                Window.Hide(_oLogWindows[sPage].GetWndHandle());
            end]]

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
            --local sOldText = Input.GetText(_sLogObject);
            UpdateMessage(sMessage);
            TextFile.WriteFromString(_pLog, _sMessage, true);
            _sFullLog = _sMessage.._sSpacer.._sFullLog;
            Input.SetText(_sLogObject, _sFullLog);
        end,
        Note = function(sMessage)
            _sLevel = "NOTE";
            --local sOldText = Input.GetText(_sLogObject);
            UpdateMessage(sMessage);
            _sFullLog = _sMessage.._sSpacer.._sFullLog;
            Input.SetText(_sLogObject, _sFullLog);
        end,
        Show = function()
            local sPage = Application.GetCurrentPage();
            local sPageDialog = (not sPage:isempty()) and sPage or Application.GetCurrentDialog();
            Window.Show(_oLogWindows[sPageDialog].GetWndHandle());
            _bLogVisible = true;
            INIFile.SetValue(_pAppCFG, _sINISection, "Visible", "true");
        end,
        Warning = function(sMessage)
            _sLevel = "WARNING";
            --local sOldText = Input.GetText(_sLogObject);
            UpdateMessage(sMessage);
            _sFullLog = _sMessage.._sSpacer.._sFullLog;
            Input.SetText(_sLogObject, _sFullLog);
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
