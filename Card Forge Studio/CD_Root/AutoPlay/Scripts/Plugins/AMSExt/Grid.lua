local class         = class;
local math          = math;
    local clamp     = math.clamp;
local rawtype       = rawtype;
local string        = string;
local toboolean     = toboolean;
local tonumber      = tonumber;
local tostring      = tostring;
local type          = type;
    local clamp         = math.clamp;
    local floor         = math.floor;
    local isnumber      = type.isnumber;
    local isstring      = type.isstring;
    local istable       = type.istable;

local function GridEmpty(sInput) return sInput; end

function Grid.GetColumnIDByName(sGrid, sName, bCaseSensitiveRaw)
    local nRet              = nil;
    local bCaseSensitive    = type(bCaseSensitiveRaw) == "boolean" and bCaseSensitiveRaw or false;
    local fCase             = bCaseSensitive and string.lower or GridEmpty;

    for x = 1, Grid.GetColumnCount(sGrid) do
        local nColumn = x - 1;

        if (fCase(Grid.GetCellText(sGrid, 0, nColumn)) == fCase(sName)) then
            nRet = nColumn;
            break;
        end

    end

    return nRet;
end

--TODO check this!!!!
function Grid.GetRow(sGrid, nRow)
    local tRet      = {};
    local nColumns  = Grid.GetColumnCount(sGrid);

    local tByColumnID       = {};
    local tByColumnName     = {};
    local tColumns          = {};
    local tColumnIDsByName  = {};

    if nColumns > 0 then

        for nColumn = 0, Grid.GetColumnCount(sGrid) - 1 do
            local sCellText             = Grid.GetCellText(sGrid, nRow, nColumn);
            local sColumn               = Grid.GetCellText(sGrid, 0, nColumn);
            tByColumnID[nColumn]        = sCellText;
            tByColumnName[sColumn]      = sCellText;
            tColumns[nColumn]           = sColumn;
            tColumnIDsByName[sColumn]   = nColumn;
        end

    end

    local nEntries = #tByColumnID;

    local tRetMeta = {
        --returns the name or index of a column given the index or name
        __call = function(t, v)
            local zV = rawtype(v);

            if (zV == "number") then
                return tColumns[v] or nil;
            elseif (zV == "string") then
                return tColumnIDsByName[v];
            end
        end,
        __index = function(t, k)
            local sRet;
            local zK = type(k);

            if (zK == "number") then
                sRet = tByColumnID[k] or nil;
            elseif (zK == "string") then
                sRet = tByColumnName[k] or nil;
            end

            return sRet;
        end,
        __newindex = function() error("Cannot write to read-only row table for grid \""..sGrid.."\" at row index "..nRow..".") end,
        __pairs = function(t)
            local nIndex = 0;
            local nMax   = #tByColumnID;

            return function()
                nIndex = nIndex + 1;

                if (nIndex <= nMax) then
                    return nIndex, tColumns[nIndex], tByColumnID[nIndex];
                end
            end
        end,
        __len = function()
            return nEntries;
        end,
    };
    setmetatable(tRet, tRetMeta);

    return tRet;
end

function Grid.TryNumber(sGrid, nRow, nColumn)
    return tonumber(Grid.GetCellText(sGrid, nRow, nColumn)) or 0;
end
