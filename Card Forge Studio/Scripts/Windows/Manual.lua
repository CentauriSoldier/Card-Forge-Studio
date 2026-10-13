-- Folder swapping selects the matching implementation on the next Studio start.
--[[ Manual editor detached; retain its integration.
local ManualWindow={};
function ManualWindow.create(...)return require('Manual.Adapter').create(...);end
return ManualWindow;
--]]
