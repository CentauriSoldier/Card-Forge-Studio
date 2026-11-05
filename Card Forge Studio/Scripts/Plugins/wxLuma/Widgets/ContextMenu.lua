local _ControlMenu = require("wxLuma.Core.ControlMenu");
local ContextMenu = {};

--[[!
@fqxn wxLuma.UI.ContextMenu.create
@desc Creates a skinned popup with programmatic/right-click opening, nested pages,
    automatic overflow, Back navigation and asynchronous completed selection.
@param wxWindow|table oParent Lifetime and inherited containment parent.
@param table tOptions Skin, Items (unique Id, Text and/or Image, optional Items,
    Value, Enabled, Shape, Width/Height, ImageWidth/Height and ClipImage), OnSelect.
    Radial options: Direction (CW), StartAngle (0 top), Shape (circle), Spacing (12),
    MinRadius (64), MaxRadius (160), ItemWidth/Height (64). Context defaults use
    Width 240, ItemWidth 232, ItemHeight 40 and Spacing 2. Artwork defaults to Menu.
@ret table oMenu Independent public menu with showAt/showAtObject, attach/detach,
    close/isOpen, back, activateItem, getSelection/getValue, item mutation and events.
!]]
function ContextMenu.create(oParent, tOptions)
    return _ControlMenu.create(oParent, tOptions, "ContextMenu");
end

return ContextMenu;
