--[[ Manual editor detached; retain its integration.
-- The active Manual folder owns storage and editor implementation.
local Manual={};
function Manual.open(...)return require('Manual.Adapter').open(...);end
function Manual.read(path)local file=assert(io.open(path,'rb'));local text=file:read('a');file:close();return text;end
return Manual;
--]]
