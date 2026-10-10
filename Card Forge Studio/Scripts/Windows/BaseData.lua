--[[!
@fqxn CFS.Windows.BaseData
@desc Editable source-data window over the shared data session.
!]]

local DataGrid = require("Windows.DataGrid");
local BaseData = {};

--[[!
@fqxn CFS.Windows.BaseData.create
@pulsarlua function BaseData.create
@desc Creates the editable base-data grid for a shared data session.
@param any tSession Shared data session.
!]]
function BaseData.create(tSession)
    return DataGrid.create(tSession, false);
end

return BaseData;
