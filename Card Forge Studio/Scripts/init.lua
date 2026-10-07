-- The launcher creates and protects APP_PATH (and other constants) before loading this script.
local _pRuntime = assert(APP_PATH, "Start Card Forge Studio through its launcher.");

assert(_pRuntime ~= "" and not _pRuntime:find("[\r\n%z]"), "Launcher supplied an invalid application folder.");

_pRuntime = _pRuntime:gsub("\\", "/"):gsub("/+$", "").."/";

local _pScripts = _pRuntime.."Scripts/";
local wx;
local _dMain, _oTestTimer;

package.path = _pScripts.."?.lua;".._pScripts.."?/init.lua;"..package.path;
package.cpath = _pRuntime.."Bin/?.dll;"..package.cpath;

local function initialize()
    wx = require("wx");
    require("Globals");
    local dMain = require("Windows.Main");

    if (arg[1] == "--verify") then
        assert(type(dMain.create) == "function", "Editor module is unavailable.");

        return;
    end

    _dMain = dMain.create();
    OnStartUp(_dMain.frame);

    if (arg[1] == "--smoke") then
        _oTestTimer = wx.wxTimer(_dMain.frame);
        _dMain.frame:Connect(wx.wxEVT_TIMER, function()
            _dMain.frame:Close(true);
        end);
        _oTestTimer:Start(250, true);
    end

    wx.wxGetApp():MainLoop();
end

local _bOK, _sError = xpcall(initialize, debug.traceback);

if (not _bOK) then
    if (Log) then
        Log.Error(_sError);
        dLog.Show();
    end

    local hLog = io.open(_pRuntime.."editor-errors.log", "a");

    if (hLog) then
        hLog:write(_sError.."\n");
        hLog:close();
    end

    if (wx) then
        wx.wxMessageBox(_sError, "Card Forge Studio - Startup Error", wx.wxOK + wx.wxICON_ERROR);
    else
        io.stderr:write(_sError.."\n");
    end
end

os.exit(_bOK and 0 or 1);
