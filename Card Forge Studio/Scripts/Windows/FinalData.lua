local DataGrid = require("Windows.DataGrid");
local FinalData = {};

function FinalData.create(tSession)
    return DataGrid.create(tSession, true);
end

return FinalData;
