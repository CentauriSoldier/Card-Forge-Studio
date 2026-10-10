--[[!
@fqxn CFS.Windows.WindowState
@desc Shared native window geometry and visibility persistence outside game folders.
!]]

-- Shared native window geometry, stored outside the application and game folders.
local wx = require("wx");
local WindowState = {};
local _tConfigs  = {};
local _tPolicies = {};
local _tWindows = {};
local _bRaising = false;

--[[!
@fqxn CFS.Windows.WindowState.getRaiseTogether
@pulsarlua function WindowState.getRaiseTogether
@desc Reads the preference controlling whether native windows are raised together.
!]]
function WindowState.getRaiseTogether()
    return INIFile.GetValue(FS.AppCFG, "Settings", "RaiseAllWindows") == "1";
end

--[[!
@fqxn CFS.Windows.WindowState.setRaiseTogether
@pulsarlua function WindowState.setRaiseTogether
@desc Persists the Boolean preference for raising native windows together.
@param any bEnabled Enabled.
!]]
function WindowState.setRaiseTogether(bEnabled)
    assert(type(bEnabled) == "boolean", "Window raising requires a Boolean value.");
    INIFile.SetValue(FS.AppCFG, "Settings", "RaiseAllWindows", bEnabled and "1" or "0");
end

--[[!
@fqxn CFS.Windows.WindowState.raiseOthers
@pulsarlua function WindowState.raiseOthers
@desc Raises shown, non-minimized registered frames and suppresses recursive activation.
@param any dWindow Window.
!]]
function WindowState.raiseOthers(dWindow)
    if (_bRaising or not WindowState.getRaiseTogether()) then return false; end
    _bRaising = true;
    for _, dOther in pairs(_tWindows) do
        if (dOther:GetId() ~= dWindow:GetId() and dOther:IsShown() and not dOther:IsIconized()) then dOther:Raise(); end
    end
    dWindow:Raise();
    return true;
end

--[[!
@fqxn CFS.Windows.WindowState.register
@pulsarlua function WindowState.register
@desc Registers position, size, and visibility persistence policies for a named window.
@param any sName Name.
@param any tOptions Options table.
!]]
function WindowState.register(sName, tOptions)
    assert(type(tOptions.savePosition) == "boolean" and type(tOptions.saveSize) == "boolean" and type(tOptions.saveVisible) == "boolean", "Window state requires three Boolean options.");
    _tPolicies[sName] = tOptions;
end

--[[!
@fqxn CFS.Windows.WindowState.isOpen
@pulsarlua function WindowState.isOpen
@desc Reads saved visibility; returns nil when visibility is not stored or no value exists.
@param any sName Name.
@param any pFile File path.
!]]
function WindowState.isOpen(sName, pFile)
    if (_tPolicies[sName] and not _tPolicies[sName].saveVisible) then return nil; end
    pFile = pFile or assert(_AppDataLocal, "Application data path is unavailable.").."/WindowState.cfg";
    local tConfig = _tConfigs[pFile];
    local oConfig = tConfig and tConfig.config or wx.wxFileConfig("", "", pFile, "", wx.wxCONFIG_USE_LOCAL_FILE);
    local bFound, sValue = oConfig:Read("/Windows/"..sName.."/Visible", "");
    if (not tConfig) then oConfig:delete(); end
    if (not bFound) then return nil; end
    return sValue == "1";
end

--[[!
@fqxn CFS.Windows.WindowState.bind
@pulsarlua function WindowState.bind
@desc Restores window state and binds delayed saves to native events. Returns save and close callbacks for the shared configuration.
@param any dWindow Window.
@param any sName Name.
@param any pFile File path.
!]]
function WindowState.bind(dWindow, sName, pFile)
    local tOptions = assert(_tPolicies[sName], "Register window state options before binding a window.");
    pFile = pFile or assert(_AppDataLocal, "Application data path is unavailable.").."/WindowState.cfg";
    local tConfig = _tConfigs[pFile];
    if (not tConfig) then
        tConfig = {
            config = wx.wxFileConfig("", "", pFile, "", wx.wxCONFIG_USE_LOCAL_FILE),
            users  = 0,
        };
        _tConfigs[pFile] = tConfig;
    end
    tConfig.users = tConfig.users + 1;
    local oConfig = tConfig.config;
    local oTimer  = wx.wxTimer(dWindow, wx.wxNewId());
    local bClosed = false;
    local nWindowID = dWindow:GetId();
    local oRaiseTimer = wx.wxTimer(dWindow, wx.wxNewId());
    if (dWindow:IsKindOf(wx.wxClassInfo.FindClass("wxFrame"))) then
        _tWindows[nWindowID] = dWindow;
        dWindow:Connect(wx.wxEVT_ACTIVATE, function(oEvent)
            if (not bClosed and oEvent:GetActive() and WindowState.raiseOthers(dWindow)) then oRaiseTimer:StartOnce(100); end
            oEvent:Skip();
        end);
    end
    dWindow:Connect(oRaiseTimer:GetId(), wx.wxEVT_TIMER, function() _bRaising = false; end);
    dWindow:Connect(wx.wxEVT_DESTROY, function(oEvent)
        if (oEvent:GetId() == nWindowID) then _tWindows[nWindowID] = nil; end
        oEvent:Skip();
    end);
    local sPrefix = "/Windows/"..sName.."/";

    --[[!
    @fqxn CFS.Windows.WindowState.Private.readNumber
    @desc Reads a numeric value from the current window configuration section.
    @vis private
    @param any sKey Setting or field key.
    !]]
    local function readNumber(sKey)
        local bFound, sValue = oConfig:Read(sPrefix..sKey, "");
        return bFound and tonumber(sValue) or nil;
    end

    --[[!
    @fqxn CFS.Windows.WindowState.Private.save
    @desc Persists permitted geometry and visibility, skipping minimized windows and preserving normal geometry while maximized.
    @vis private
    !]]
    local function save()
        if (bClosed or dWindow:IsIconized()) then return; end
        if (not dWindow:IsMaximized()) then
            local oPosition = dWindow:GetPosition();
            local oSize     = dWindow:GetSize();
            if (tOptions.savePosition) then
                oConfig:Write(sPrefix.."X", tostring(oPosition:GetX()));
                oConfig:Write(sPrefix.."Y", tostring(oPosition:GetY()));
            end
            if (tOptions.saveSize) then
                oConfig:Write(sPrefix.."Width", tostring(oSize:GetWidth()));
                oConfig:Write(sPrefix.."Height", tostring(oSize:GetHeight()));
            end
        end
        if (tOptions.saveVisible) then oConfig:Write(sPrefix.."Visible", dWindow:IsShown() and "1" or "0"); end
        if (tOptions.saveSize) then oConfig:Write(sPrefix.."Maximized", dWindow:IsMaximized() and "1" or "0"); end
        if (not oConfig:Flush()) then
            require("Errors").report("Could not save window position and size to application data.");
        end
    end

    local nX      = readNumber("X");
    local nY      = readNumber("Y");
    local nWidth  = readNumber("Width");
    local nHeight = readNumber("Height");
    if (tOptions.saveSize and nWidth and nHeight and nWidth > 0 and nHeight > 0) then
        dWindow:SetSize(wx.wxSize(nWidth, nHeight));
    end
    if (tOptions.savePosition and nX and nY) then
        if (wx.wxDisplay.GetFromPoint(wx.wxPoint(nX, nY)) ~= wx.wxNOT_FOUND) then
            dWindow:Move(nX, nY);
        else
            dWindow:Centre();
        end
    end
    if (tOptions.saveSize and readNumber("Maximized") == 1) then dWindow:Maximize(true); end

    --[[!
    @fqxn CFS.Windows.WindowState.Private.changed
    @desc Schedules a delayed save for a shown, non-minimized window and propagates the native event.
    @vis private
    @param any oEvent Event.
    !]]
    local function changed(oEvent)
        if (not bClosed and dWindow:IsShown() and not dWindow:IsIconized()) then
            oTimer:StartOnce(300);
        end
        oEvent:Skip();
    end

    dWindow:Connect(wx.wxEVT_SHOW, function(oEvent)
        if (not bClosed and tOptions.saveVisible) then
            oConfig:Write(sPrefix.."Visible", dWindow:IsShown() and "1" or "0");
            oTimer:StartOnce(300);
        end
        oEvent:Skip();
    end);
    dWindow:Connect(wx.wxEVT_MOVE, changed);
    dWindow:Connect(wx.wxEVT_SIZE, changed);
    dWindow:Connect(oTimer:GetId(), wx.wxEVT_TIMER, save);
    dWindow:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        oTimer:Stop();
        save();
        oEvent:Skip();
    end);

    return {
        save = save,
        --[[!
        @fqxn CFS.Windows.WindowState.Private.close
        @desc Stops timers, saves final state, and releases the configuration when its last user closes.
        @vis private
        !]]
        close = function()
            if (bClosed) then return; end
            oTimer:Stop();
            oRaiseTimer:Stop();
            _tWindows[nWindowID] = nil;
            _bRaising = false;
            save();
            bClosed = true;
            tConfig.users = tConfig.users - 1;
            if (tConfig.users == 0) then
                oConfig:delete();
                _tConfigs[pFile] = nil;
            end
        end,
    };
end

return WindowState;