--[[
return {
    Name        = "*All",
    Description = "Includes all cards in the set.",
    RowSelector = function(tRow)
        return true;
    end,
    Blacklist   = nil,
    Whitelist   = nil,
};
]]

local function BuildFilter(tRowFilterData)
    local sName, zName, sDescription, zDescription, fRowSelector, zRowSelector;
    local zRowFilterData = type(tRowFilterData);

    if (zRowFilterData ~= "table") then
        Log.WARNING("Could not create RowFilter. Expected table at argument 1. Got "..zRowFilterData..'.'); return;
    end

    zName = type(tRowFilterData.Name);

    if (zName ~= "string") then
        Log.WARNING("Could not create RowFilter. Expected 'Name' key with string value. Got "..zName..'.'); return;
    end

    sName = tRowFilterData.Name;

    if sName:isempty() then
        Log.WARNING("Could not create RowFilter. 'Name' must be a non-blank string."); return;
    end

    zDescription = type(tRowFilterData.Description);
    if (zDescription ~= "string") then
        Log.WARNING("Could not create RowFilter, '"..sName.."'. Expected 'Description' key with string value. Got "..zDescription..'.'); return;
    end

    sDescription = tRowFilterData.Description;

    if tRowFilterData.Description:isempty() then
        Log.WARNING("Could not create RowFilter, '"..sName.."'. 'Description' must be a non-blank string."); return;
    end

    zRowSelector = type(tRowFilterData.RowSelector);
    if (zRowSelector ~= "function") then
        Log.WARNING("Could not create RowFilter, '"..sName.."'. Expected 'RowSelector' key with function value. Got "..zRowSelector..'.'); return;
    end

    fRowSelector = tRowFilterData.RowSelector;

    --TODO check whitelist/blacklist when ready to complete that part
    --tBlacklist, tWhitelist

    --TODO WARNING run filter function in safe env!!!


    local tRowFilter = {
        Apply       = function(tRows)
            local tRet          = {};
            local nIndex        = 0;
            local wUser         = UserEnv.Get();
            local wOld          = _ENV;
            local sChuckName    = sName.." RowFilter"


            --try to load the chuck
            local fChunk, sError = load(sInitChunk, sChunkName, "t", wUser);
            if not (fChunk) then
                error("Error running '"..sName.."' file for Game '"..sGame.."'.\r\n"..sError, 2);
            end

            --try to call the chunk
            local bOK, sRetOrError = pcall(fChunk);

            if not (bOK) then
                error("Error running '"..sName.."' file for Game '"..sGame.."'.\r\n"..sRetOrError, 2);
            end




            if (type(tRows) ~= "table") then
                Log.WARNING("Error applying RowFilter, '"..sName.."': expected rows table. Got "..type(tRows)..'.');
            end

            for _, tRow in ipairs(tRows) do --QUESTION WE USING ipairs here? Double check

                fRowSelector(tRow)
                if () then --QUESTION should we preserve original index somewhere for queries?
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
    local tRowFilterDecoy  = {};
    local tRowFilterMeta   = {
        __index = tRowFilter,
        __newindex = function(t, k, v)
            Log.Warning("Attempt to write to read-only RowFilter, '"..sName.."'.");
        end,
        __type = "RowFilter",
    };

    setmetatable(tRowFilterDecoy, tRowFilterMeta);
    tRowFilters[sName] = tRowFilterDecoy;
    return tRowFilterDecoy;
end
--TODO LEFT OFF HERE
return class("RowFilter",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --RowFilterManager = function(cMe, sAuthCode) end, --static constructor (runs after class object creation)
        --Create = BuildFilter, --TODO BUG FIX SECURIOTY ISSUE WITH METAMETHODS INJECTION IN PROVIDED TABLE----BUILD IN SAFE ENV
        CreateFromString = function(sInput)

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
