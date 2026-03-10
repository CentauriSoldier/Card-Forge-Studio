local _pLog         = FS.AppDir.."\\Log.log";
local _pAppCFG      = FS.AppCFG;
local _sINISection  = "LogWindow"; --TODO move to constants
local _sSpacer      = "\r\n\r\n";

local function DateTime()
    return System.GetDate(DATE_FMT_ISO)..' @ '..System.GetTime(TIME_FMT_MIL);
end

local function LogIt(vMessage, vLevel, bSkipWrite)
    local sMessage  = rawtype(vMessage) == "string" and tostring(vMessage)  or "";
    local sLevel    = rawtype(vLevel)   == "string" and vLevel              or "NOTE";

    if not (sMessage:isempty()) then
        sMessage = "["..sLevel..' > '..DateTime().."]\r\n"..sMessage;
    end

    sMessage = sMessage:gsub("\t", "\r\n"):gsub("stack traceback:", "\r\nstack traceback:\r\n").._sSpacer;

    if not (bSkipWrite) then
        TextFile.WriteFromString(_pLog, sMessage, true);
    end

    Debug.Print(sMessage);
end

return class("Log",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        ClearFile = function()
            TextFile.WriteFromString(_pLog, "");
        end,
        ClearWindow = function()
            Debug.Clear();
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
            --get and save the Debug's dimensions and visibility
            local tPos = Window.GetPos(HWND_DEBUG);
            local tSize = Window.GetSize(HWND_DEBUG);
            INIFile.SetValue(_pAppCFG, _sINISection, "Width",   tostring(tSize.Width));
            INIFile.SetValue(_pAppCFG, _sINISection, "Height",  tostring(tSize.Height));
            INIFile.SetValue(_pAppCFG, _sINISection, "X",       tostring(tPos.X));
            INIFile.SetValue(_pAppCFG, _sINISection, "Y",       tostring(tPos.Y));
            INIFile.SetValue(_pAppCFG, _sINISection, "Visible", tostring(WindowWizard.IsVisible(HWND_DEBUG)));
        end,
        OnStartup = function()
            --restore the Debug window to previous state
            local nX        = INIFile.GetValueNumber(_pAppCFG, _sINISection, "X");
            local nY        = INIFile.GetValueNumber(_pAppCFG, _sINISection, "Y");
            local nWidth    = INIFile.GetValueNumber(_pAppCFG, _sINISection, "Width", 300);--TODO MAGIC NUMBERS use defaults?
            local nHeight   = INIFile.GetValueNumber(_pAppCFG, _sINISection, "Height", 300);--TODO MAGIC NUMBERS use defaults?
            local bLogVisible  = INIFile.GetValueBoolean(_pAppCFG, _sINISection, "Visible");

            Window.SetRect(HWND_DEBUG, nX, nY, nWidth, nHeight);
            Window.SetText(HWND_DEBUG,  "CFS Debug"); --TODO move to constants
            Debug.ShowWindow(bLogVisible);
        end,
        Show = function()
            Debug.ShowWindow(true);
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
