--[[!
@fqxn CFS.Windows.GridStyle
@desc Shared, persistent row and index colors for Base Data and Final Data.
!]]

local FS            = FS;
local INIFile       = INIFile;
local error         = error;
local ipairs        = ipairs;
local pairs         = pairs;
local setmetatable  = setmetatable;
local string        = string;
local wx            = require("wx");

local GridStyle = {};
local tViews    = setmetatable({}, {__mode = "k"});

-- Definitions also supply the Options labels and preserve the existing defaults.
--[[!
@fqxn CFS.Windows.GridStyle.definitions
@pulsarlua table GridStyle.definitions
@desc Ordered color roles, Options labels, and original default colors.
!]]
GridStyle.definitions = {
    {key = "primary", label = "Primary Row Background", default = "#FFFFFF"},
    {key = "secondary", label = "Secondary Row Background", default = "#EAEAEA"},
    {key = "primaryText", label = "Primary Row Text", default = "#000000"},
    {key = "secondaryText", label = "Secondary Row Text", default = "#000000"},
    {key = "index", label = "Index Background", system = wx.wxSYS_COLOUR_BTNFACE},
    {key = "indexText", label = "Index Text", system = wx.wxSYS_COLOUR_BTNTEXT},
};

--[[!
@fqxn CFS.Windows.GridStyle.get
@pulsarlua function GridStyle.get
@desc Reads saved grid colors; absent or invalid values retain the original defaults.
@return table Colors keyed by their grid role.
!]]
function GridStyle.get()
    local tColors = {};

    for _, tDefinition in ipairs(GridStyle.definitions) do
        local sSaved = INIFile.GetValue(FS.AppCFG, "Grids", tDefinition.key);
        local sDefault = tDefinition.default;

        if (tDefinition.system) then
            sDefault = wx.wxSystemSettings.GetColour(tDefinition.system):GetAsString(wx.wxC2S_HTML_SYNTAX);
        end

        tColors[tDefinition.key] = string.match(sSaved or "", "^#%x%x%x%x%x%x$") and sSaved or sDefault;
    end

    return tColors;
end


--[[!
@fqxn CFS.Windows.GridStyle.save
@pulsarlua function GridStyle.save
@desc Saves the six validated colors and immediately refreshes subscribed data windows.
@param table tColors Colors keyed by their grid role.
!]]
function GridStyle.save(tColors)
    -- Validate the complete choice before writing any preference.
    for _, tDefinition in ipairs(GridStyle.definitions) do
        if (not string.match(tColors[tDefinition.key] or "", "^#%x%x%x%x%x%x$")) then
            error("Invalid grid color: "..tDefinition.label);
        end
    end

    for _, tDefinition in ipairs(GridStyle.definitions) do
        INIFile.SetValue(FS.AppCFG, "Grids", tDefinition.key, tColors[tDefinition.key]);
    end

    for fRefresh in pairs(tViews) do
        fRefresh();
    end
end


--[[!
@fqxn CFS.Windows.GridStyle.subscribe
@pulsarlua function GridStyle.subscribe
@desc Registers a refresh callback without keeping a closed data window alive.
@param function fRefresh Data window refresh callback.
!]]
function GridStyle.subscribe(fRefresh)
    tViews[fRefresh] = true;
end

return GridStyle;
