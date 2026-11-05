local _ControlDiscProgress = require("wxLuma.Core.ControlDiscProgress");
local RadialProgress = {};

--[[!
@fqxn wxLuma.UI.RadialProgress.create
@desc Creates a concentric progress disc. Outward grows from center to rim;
    inward fills from rim to center. Both are empty at Min and full at Max.
    Value maps linearly to radial distance, not filled circular area: at 50%,
    outward reaches half-radius and inward leaves a half-radius track hole.
@param wxWindow oParent Native parent, which owns the control.
@param table tOptions Skin, Min, Max, Value; optional Direction (outward/inward,
    default outward), Text (%v/current, %m/max), Colour ({R,G,B}), Appearance
    (skin/colour), Artwork (Radial Progress), Enabled, OnChange and shared containment
    options. Explicit Colour defaults to colour mode; otherwise skin.
@ret table oComponent Independent RadialProgress proxy with standard progress API
    and get/setDirection. Setters are silent unless notified.
!]]
function RadialProgress.create(oParent, tOptions)
    return _ControlDiscProgress.create(oParent, tOptions, "RadialProgress");
end

return RadialProgress;
