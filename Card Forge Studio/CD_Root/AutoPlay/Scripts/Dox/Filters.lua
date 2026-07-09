--[[!
    @fqxn CFS.Classes.Filters
    @desc Represents a reusable card filter. Filters determine whether a row should be included in an operation by evaluating it through a `RowHandler` function.
    Filters may be used by any system that requires card selection logic, such as exporting, searching, reporting, validation, or batch operations.
    Filters may optionally restrict themselves to specific card sets through a `SupportedCardSets` index.
    @ex
    return {
        Name = "Rare Cards",
        Description = "Includes only rare cards.",
        RowHandler = function(tRow)
            return tRow.Rarity == "Rare";
        end,
        SupportedCardSets = {
            "550e8400-e29b-41d4-a716-446655440000",
            "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
        },
    };
    @ex
    Name        = "*All",
    Description = "Includes all cards in the set.",
    RowHandler  = function(tRow)
        return true;
    end,
    SupportedCardSets = nil,
--!]]
