--[[!
@fqxn CFS.Windows.LoadCardSet
@desc Styled card-set-selection dialog using set-root Logo.png or the shared fallback.
!]]

local LoadCardSet = {};


--[[!
@fqxn CFS.Windows.LoadCardSet.Show
@pulsarlua function LoadCardSet.Show
@desc Opens a card-set chooser with square logos and the shared NoLogo fallback. Size is remembered independently of the game chooser.
@param wxWindow dParent Parent window.
@param table tCardSets Card sets in display order.
@return number Zero-based selected index, or -1 after cancellation.
!]]
function LoadCardSet.Show(dParent, tCardSets)
    return require("Windows.Loaders.Common").Show(dParent, tCardSets, {
        description = "Choose a card set to continue creating.",
        heading     = "Your Card Sets",
        --[[!
        @fqxn CFS.Windows.LoadCardSet.Private.root
        @desc Returns the selected card set's root folder for logo lookup.
        @param any oCardSet Card set.
        @vis private
        !]]
        root        = function(oCardSet) return FS.CardSet.GetRoot(oCardSet.GetGameUUID(), oCardSet.GetUUID()); end,
        state       = "LoadCardSet",
        title       = "Load Card Set",
    });
end


return LoadCardSet;
