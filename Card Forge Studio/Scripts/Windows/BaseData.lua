local DataGrid = require("Windows.DataGrid");
local BaseData = {};

function BaseData.create(tSession)
    return DataGrid.create(tSession, false);
end

return BaseData;
