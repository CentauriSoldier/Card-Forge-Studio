-- Shared native window geometry, stored outside the application and game folders.
local wx = require("wx");
local WindowState = {};
local _tConfigs  = {};
local _tPolicies = {};

function WindowState.register(sName, tOptions)
    assert(type(tOptions.savePosition) == "boolean" and type(tOptions.saveSize) == "boolean" and type(tOptions.saveVisible) == "boolean", "Window state requires three Boolean options.");
    _tPolicies[sName] = tOptions;
end

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
    local sPrefix = "/Windows/"..sName.."/";

    local function readNumber(sKey)
        local bFound, sValue = oConfig:Read(sPrefix..sKey, "");
        return bFound and tonumber(sValue) or nil;
    end

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
        close = function()
            if (bClosed) then return; end
            oTimer:Stop();
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