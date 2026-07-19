local tRowFilter = {};



--this must run AFTER the debug window is loaded so code errors (WARNINGS) can be displayed to the user
local function BuildFilter(sName, sDescription, fRowSelector, tBlacklist, tWhitelist)
    --TODO assertions
    --TODO WARNING run filter function in safe env!!!

    local tFilter = {
        Apply       = function(tRows)
            local tRet      = {};
            local nIndex    = 0;
            --TODO assertions

            for _, tRow in ipairs(tRows) do --QUESTION WE USING ipairs here? Double check

                if (fRowSelector(tRow)) then --QUESTION should we preserve original index somewhere for queries?
                    nIndex = nIndex + 1;
                    tRet[nIndex] = tRow;
                end

            end

            return tRet;
        end,
        Name        = sName,
        Description = sDescription,
        --RowSelector = fRowSelector,
        --tBlacklist  = tBlacklist,
        --Whitelist   = tWhitelist,
    };
    local tFilterDecoy  = {};
    local tFilterMeta   = {
        __index = tFilter,
        __newindex = function(t, k, v)
            Log.Warning("Attempt to write to read-only RowFilter, '"..sName.."'.");
        end,
    };

    setmetatable(tFilterDecoy, tFilterMeta);
    return tFilterDecoy;
end



local tRowFilterActual = {};
local tRowFilterDecoy  = {};
local tRowFilterMeta   = {
    __call = BuildFilter,
};

setmetatable(tRowFilterDecoy, tRowFilterMeta);
return tRowFilterDecoy;
