--[[!
@fqxn CFS.RowFilters.Built-in.*All
@desc A built-in filter that includes every row in the active card set. This filter is compatible with all card sets and always returns `true` from its `RowSelector` function.
--!]]
return {
    Name        = "*All",
    Description = "Includes all cards in the Card Set.",
    RowSelector = function(tRow)
        return true;
    end,
};
