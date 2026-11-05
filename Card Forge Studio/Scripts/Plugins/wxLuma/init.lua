--[[!
@fqxn wxLuma
@desc Framework loader. Applications may create native windows or use TopLevelWindow;
    the caller owns the wx event loop. Each load has independent artwork defaults.
!]]
local _wx = require("wx");
local _oSource = _wx.wxFileName(debug.getinfo(1, "S").source:sub(2));
_oSource:MakeAbsolute();
local _pRoot = _oSource:GetPath(_wx.wxPATH_GET_VOLUME);
_oSource:delete();

--[[!
@fqxn wxLuma.load
@param string|nil pConfig Lua configuration file; defaults to included wxLumaConfig.lua.
@ret table wxLuma Controls, Window, TopLevelWindow, Path and the resolved Config.
!]]
local function load(pConfig)
    assert(pConfig == nil or (type(pConfig) == "string" and pConfig ~= ""), "Configuration path must be a nonempty string.");
    local tConfig = assert(loadfile(pConfig or _pRoot.."/wxLumaConfig.lua"))();
    assert(type(tConfig) == "table", "Configuration must return a table.");
    assert(type(tConfig.ImagePath) == "string" and tConfig.ImagePath ~= "", "Configuration ImagePath must be a nonempty string.");

    local Config = {};
    for sKey, vValue in pairs(tConfig) do
        Config[sKey] = vValue;
    end
    local oImages = _wx.wxFileName.DirName(Config.ImagePath);
    oImages:MakeAbsolute(_pRoot);
    Config.ImagePath = oImages:GetFullPath();
    oImages:delete();

    local Controls = {};
    for sKey, vValue in pairs(require("wxLuma.Controls")) do
        Controls[sKey] = vValue;
    end
    local Window = {};
    for sKey, vValue in pairs(require("wxLuma.Containers.Window")) do
        Window[sKey] = vValue;
    end
    local fLoadSkin = Controls.loadSkin;
    local fCreateWindow = Window.create;
    Controls.loadSkin = function(pArtwork)
        return fLoadSkin(pArtwork or Config.ImagePath.."/Controls/");
    end;
    Window.create = function(oParent, tOptions)
        local tWindowOptions = {};
        for sKey, vValue in pairs(tOptions or {}) do
            tWindowOptions[sKey] = vValue;
        end
        tWindowOptions.AssetPath = tWindowOptions.AssetPath or Config.ImagePath.."/Window/";
        return fCreateWindow(oParent, tWindowOptions);
    end;

    local TopLevelWindow = {};
    local fCreateTopLevelWindow = require("wxLuma.Containers.TopLevelWindow").create;
    TopLevelWindow.create = function(oParent, tOptions)
        local tWindowOptions = {};
        for sKey, vValue in pairs(tOptions or {}) do tWindowOptions[sKey] = vValue; end
        tWindowOptions.AssetPath = tWindowOptions.AssetPath or Config.ImagePath.."/Window/";
        tWindowOptions.SkinPath = tWindowOptions.SkinPath or Config.ImagePath.."/Controls/";
        return fCreateTopLevelWindow(oParent, tWindowOptions);
    end;
    local wxLuma = {
        Controls = Controls,
        Window   = Window,
        TopLevelWindow = TopLevelWindow,
        Path     = _pRoot,
        Config   = Config,
        State    = require("wxLuma.State"),
    };

    return wxLuma;
end

return load;
