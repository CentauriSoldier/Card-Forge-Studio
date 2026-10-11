--[[!
@fqxn CFS.Windows.WindowState
@desc
<section aria-label="WindowState overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">WindowState</h2><p style="font-size:1.15rem;margin:0">WindowState remembers useful native-window choices outside game folders.</p></div>
<h3>How it fits into your work</h3><p>Registered windows restore supported geometry and visibility policies when opened again.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Main">Main</a></h3><p style="margin:0">The main Studio window connects your project, preview, and editing tools.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.LoadGame">LoadGame</a></h3><p style="margin:0">The game chooser presents projects as easy-to-scan logo cards.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.LoadCardSet">LoadCardSet</a></h3><p style="margin:0">The card-set chooser presents the active game's sets as logo cards.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Options">Options</a></h3><p style="margin:0">Options puts application preferences and project information in one place.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Different windows can use different policies; not every dialog restores its screen position.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

-- Shared native window geometry, stored outside the application and game folders.
local wx = require("wx");
local WindowState = {};
local _tConfigs  = {};
local _tPolicies = {};
local _tWindows = {};
local _bRaising = false;

--[[!
@fqxn CFS.Windows.WindowState.Functions.getRaiseTogether
@pulsarlua function WindowState.getRaiseTogether
@desc Reads the preference controlling whether native windows are raised together.
!]]
function WindowState.getRaiseTogether()
    return INIFile.GetValue(FS.AppCFG, "Settings", "RaiseAllWindows") == "1";
end

--[[!
@fqxn CFS.Windows.WindowState.Functions.setRaiseTogether
@pulsarlua function WindowState.setRaiseTogether
@desc Persists the Boolean preference for raising native windows together.
@param any bEnabled Enabled.
!]]
function WindowState.setRaiseTogether(bEnabled)
    assert(type(bEnabled) == "boolean", "Window raising requires a Boolean value.");
    INIFile.SetValue(FS.AppCFG, "Settings", "RaiseAllWindows", bEnabled and "1" or "0");
end

--[[!
@fqxn CFS.Windows.WindowState.Functions.raiseOthers
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
@fqxn CFS.Windows.WindowState.Functions.register
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
@fqxn CFS.Windows.WindowState.Functions.isOpen
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
@fqxn CFS.Windows.WindowState.Functions.bind
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
    @fqxn CFS.Windows.WindowState.Private.Functions.readNumber
    @desc Reads a numeric value from the current window configuration section.
    @vis private
    @param any sKey Setting or field key.
    !]]
    local function readNumber(sKey)
        local bFound, sValue = oConfig:Read(sPrefix..sKey, "");
        return bFound and tonumber(sValue) or nil;
    end

    --[[!
    @fqxn CFS.Windows.WindowState.Private.Functions.save
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
    @fqxn CFS.Windows.WindowState.Private.Functions.changed
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
        @fqxn CFS.Windows.WindowState.Private.Functions.close
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