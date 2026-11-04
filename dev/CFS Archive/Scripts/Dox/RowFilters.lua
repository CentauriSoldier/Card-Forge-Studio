--[[!
@fqxn CFS.RowFilters
@todo Discuss how the row presents data in regards to type. Is everything strings?
@desc <p>Row Filters allow users to define which rows from a card set should be included in a result set.
They provide a flexible way to create custom views of card data without modifying the underlying
card set.
</p>

<p>
A Row Filter evaluates every row in a card set and determines whether that row should be included.
This allows users to create custom views of card data, such as filtering cards by rarity, class,
type, set, or any other properties available on a card.
</p>

<p>
For example, a Row Filter can be used to display only rare cards, show cards belonging to a
specific class or type, find cards with certain words in their names, and create custom selections based on any
available row data.
</p>

<p>
Because Row Filters are defined separately from the card set itself, they allow users to customize
how card data is viewed and processed without changing the original data source.
</p>

<p>A row filter definition consists of:</p>
<ul>
    <li><b>Name</b> - The table key in the returned table.</li>
    <li><b>Description</b> - A brief description of the filter.</li>
    <li><b>RowSelector</b> - A function that returns <b>true</b> if the row should be included in the result set; otherwise, <b>false</b>.</li>
    <li><b>Blacklist</b> <i>(optional)</i> - A list of card set UUIDs for which the filter will <b>not</b> be available.</li>
    <li><b>Whitelist</b> <i>(optional)</i> - A list of card set UUIDs. The filter will be available <b>only</b> for the sets listed.</li>
</ul>
<p>
The <b>RowSelector</b> function is invoked once for every row in the card set. It may inspect
any of the row's data in order to determine whether the row should be included in the result set.
Returning <b>true</b> includes the row; returning <b><i>any other value</i></b> other value excludes the row.</p>
<p>The <b>Blacklist</b> and <b>Whitelist</b> properties are numerically-indexed tables
containing card set UUIDs. These UUIDs determine which card sets the filter is loaded for.
A <b>Blacklist</b> prevents the filter from being loaded when the active card set matches
one of the listed UUIDs.
<br>A <b>Whitelist</b> causes the filter to only be loaded when the
active card set matches one of the listed UUIDs. If both properties are provided, the
<b>Blacklist</b> takes precedence and the <b>Whitelist</b> is ignored.

Both <b>Blacklist</b> and <b>Whitelist</b> may be <b>nil</b>. When both
properties are <b>nil</b>, the filter is loaded for all card sets in the game.
</p>
@ex
return {
    ["*All"] = {
        Description = "Includes all cards in the set.",

        RowSelector = function(tRow)
            return true;
        end,

        Blacklist = nil,
        Whitelist = nil,
    },

    ["Rare"] = {
        Description = "Includes only rare cards.",

        RowSelector = function(tRow)
            return tRow.Rarity == "Rare";
        end,

        Blacklist = nil,
        Whitelist = {"8dd73cf2-77a9-454f-a496-5c34f783f307"}, --filter will load only for the specified card set
    },
};
--!]]
