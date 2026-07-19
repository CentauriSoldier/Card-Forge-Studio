return {
    ["My Row Filter"] = {
        Description = "What my RowFilter does.",
        RowSelector = function(tRow)
            -- Return true to include this row.
            return true;
        end,
        Blacklist = nil,
        Whitelist = nil,
    },
};
