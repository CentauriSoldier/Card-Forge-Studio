--[[!
@fqxn CFS.Windows.GridStyle
@desc
<section aria-label="GridStyle overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">GridStyle</h2><p style="font-size:1.15rem;margin:0">GridStyle keeps row stripes, text, and index colors consistent between data windows.</p></div>
<h3>How it fits into your work</h3><p>Try colors in the fixed four-row Options sample. Apply or OK saves choices; canceled choices disappear on reopening.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Options">Options</a></h3><p style="margin:0">Options puts application preferences and project information in one place.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.DataGrid">Data Grid</a></h3><p style="margin:0">The common grid supplies table controls for both data windows.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.BaseData">BaseData</a></h3><p style="margin:0">Base Data is the table of values you actually edit.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.FinalData">FinalData</a></h3><p style="margin:0">Final Data shows the results after card values and scripts have been processed.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">The sample is read-only. Preview changes do not update the real grids until applied.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
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
@fqxn CFS.Windows.GridStyle.Functions.get
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
@fqxn CFS.Windows.GridStyle.Functions.save
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
@fqxn CFS.Windows.GridStyle.Functions.subscribe
@pulsarlua function GridStyle.subscribe
@desc Registers a refresh callback without keeping a closed data window alive.
@param function fRefresh Data window refresh callback.
!]]
function GridStyle.subscribe(fRefresh)
    tViews[fRefresh] = true;
end

return GridStyle;
