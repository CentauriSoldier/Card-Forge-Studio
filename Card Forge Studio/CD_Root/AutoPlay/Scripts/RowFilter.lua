--Builds and returns a table from a string
local function BuildRowFiltersTableFromString(sChunk, sChunkNamePrefix)
    local sPrefix       = type(sChunkNamePrefix) == "string" and sChunkNamePrefix or "Unknown";
    local sChunkName    = sPrefix..' RowFilters';

    --load the chunk
    local fChunk, sError = load(sChunk, sChunkName, "t", UserEnv.Get());
    if not (fChunk) then
        error("Error loading RowFilters chunk ("..sChunkName..").\r\n"..sError, 1);
    end

    --execute the chuck and retrieve the results
    local bOK, fRetOrErr = pcall(fChunk);
    if not (bOK) then
        error("Error loading RowFilters table ("..sChunkName..").\r\n"..fRetOrErr, 1);
    end

    --check the results are a table
    if not (rawtype(fRetOrErr) == "table") then
        error("Error validating RowFilters table ("..sChunkName..").\r\nExpected return type, table. Got "..rawtype(fRetOrErr)..'.', 1);
    end

    return fRetOrErr, sChunkName;
end


local function BuildRowFilterFromTable(tFilterData)
    local sName = tFilterData.Name;
    local fRowSelector = tFilterData.RowSelector;

    local tRowFilter = {
        Apply       = function(tRows)
            local tRet          = {};
            local nIndex        = 0;
            local wUser         = UserEnv.Get();
            local wOld          = _ENV;
            local sChuckName    = sName.." RowFilter"

            for _, tRow in ipairs(tRows) do

                if (fRowSelector(tRow)) then
                    nIndex = nIndex + 1;
                    tRet[nIndex] = tRow;
                end

            end

            return tRet;
        end,
        Name        = sName,
        Description = sDescription,
        --tBlacklist  = tBlacklist,
        --Whitelist   = tWhitelist,
    };

    local tRowFilterDecoy  = {};
    local tRowFilterMeta   = {
        __index = tRowFilter,
        __newindex = function(t, k, v)
            Log.Warning("Attempt to write to read-only RowFilter, '"..sName.."'.");
        end,
        __type = "RowFilter",
    };

    setmetatable(tRowFilterDecoy, tRowFilterMeta);
    return tRowFilterDecoy;
end


--assumes the input is a valid table. Checks the entry table contents.
local function ValidateRowFilterTable(tFilter, sChunkName)
    local sName, zName, sDescription, zDescription, fRowSelector, zRowSelector;
    zName = type(tFilter.Name);

    if (zName ~= "string") then
        Log.Warning("Could not create RowFilter ("..sChunkName..").\r\nExpected 'Name' key with string value. Got "..zName..'.'); return;
    end

    sName = tFilter.Name;

    if sName:isempty() then
        Log.Warning("Could not create RowFilter ("..sChunkName..").\r\n'Name' must be a non-blank string."); return;
    end

    zDescription = type(tFilter.Description);
    if (zDescription ~= "string") then
        Log.Warning("Could not create RowFilter ("..sChunkName.."),\r\n'"..sName.."'. Expected 'Description' key with string value. Got "..zDescription..'.'); return;
    end

    sDescription = tFilter.Description;

    if tFilter.Description:isempty() then
        Log.Warning("Could not create RowFilter ("..sChunkName.."),\r\n'"..sName.."'. 'Description' must be a non-blank string."); return;
    end

    zRowSelector = type(tFilter.RowSelector);
    if (zRowSelector ~= "function") then
        Log.Warning("Could not create RowFilter ("..sChunkName.."),\r\n'"..sName.."'. Expected 'RowSelector' key with function value. Got "..zRowSelector..'.'); return;
    end

    --TODO FINISH check whitelist/blacklist when ready to complete that part
    --tBlacklist, tWhitelist
    return true;
end


return class("RowFilter",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --RowFilter = function(cMe, sAuthCode) end, --static constructor (runs after class object creation)
        BuildAllFromString = function(sInput)
            local tRet = {};

            local tRowFilters, sChunkName = BuildRowFiltersTableFromString(sInput);

            for _, tFilterData in pairs(tRowFilters) do

                if (ValidateRowFilterTable(tFilterData)) then
                    tRet[#tRet + 1] = BuildRowFilterFromTable(tFilterData);
                end

            end

            return tRet;
        end,
    },
    {--PRIVATE
        RowFilter = function(this, cdat) end,
    },
    {--PROTECTED

    },
    {--PUBLIC

    },
    nil,   --extending class
    true,  --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
