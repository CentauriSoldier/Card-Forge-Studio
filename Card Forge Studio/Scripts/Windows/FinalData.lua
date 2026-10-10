--[[!
@fqxn CFS.Windows.FinalData
@desc Processed final-data window over the shared data session.
!]]

local DataGrid = require("Windows.DataGrid");
local FinalData = {};

--[[!
@fqxn CFS.Windows.FinalData.create
@pulsarlua function FinalData.create
@desc Creates the processed final-data grid for a shared data session.
@param any tSession Shared data session.
!]]
function FinalData.create(tSession)
    return DataGrid.create(tSession, true);
end

return FinalData;
