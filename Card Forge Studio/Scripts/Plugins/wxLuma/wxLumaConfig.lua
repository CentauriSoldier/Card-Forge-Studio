-- Framework configuration. Relative image paths start in the wxLuma folder.
local Config = {
    ImagePath = "Images",
    Skin = "System", -- System or Obsidian; all visual factories share this setting.
    SkinPath = "Skins/Obsidian", -- Optional image provider, organized by object.
};

local _wx = require("wx");
local _oSource = _wx.wxFileName(debug.getinfo(1, "S").source:sub(2));
_oSource:MakeAbsolute();
local _pRoot = _oSource:GetPath(_wx.wxPATH_GET_VOLUME);
_oSource:delete();

local _oImages = _wx.wxFileName.DirName(Config.ImagePath);
_oImages:MakeAbsolute(_pRoot);
Config.ImagePath = _oImages:GetFullPath();
_oImages:delete();
local _oSkin = _wx.wxFileName.DirName(Config.SkinPath);
_oSkin:MakeAbsolute(_pRoot);
Config.SkinPath = _oSkin:GetFullPath();
_oSkin:delete();

return Config;
