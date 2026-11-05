local _ControlDiscProgress = require("wxLuma.Core.ControlDiscProgress");
local GlobeProgress = {};

--[[!
@fqxn wxLuma.UI.GlobeProgress.create
@desc Creates a health/mana-style globe with a straight level inside a round
    silhouette. Value maps linearly to level distance, not filled circular area.
    Default fill is bottom-up. Origin and orientation remain mutable at runtime.
@param wxWindow oParent Native parent, which owns the control.
@param table tOptions Skin, Min, Max, Value; optional Origin (bottom/top/left/right),
    Orientation (vertical/horizontal), Text (%v/current, %m/max), Colour ({R,G,B}),
    Appearance (skin/colour), Artwork (Globe Progress), Enabled, OnChange and shared
    containment options. Explicit Colour defaults to colour mode; otherwise skin.
@ret table oComponent Independent GlobeProgress proxy with standard progress API,
    get/setOrigin and get/setOrientation. Setters are silent unless notified.
!]]
function GlobeProgress.create(oParent, tOptions)
    return _ControlDiscProgress.create(oParent, tOptions, "GlobeProgress");
end

return GlobeProgress;
