--[[!
@fqxn CFS.Classes.Filters.*All
@desc A built-in filter that includes every row in the active card set. This filter is compatible with all card sets and always returns `true` from its `RowHandler`.
--!]]
return {
    Name        = "*All",
    Description = "Includes all cards in the set.",
    RowHandler  = function(tRow)
        return true;
    end,
    SupportedCardSets = nil,
};
