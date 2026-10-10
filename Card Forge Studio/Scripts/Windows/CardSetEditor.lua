--[[!
@fqxn CFS.Windows.CardSetEditor
@desc Source editor for card-set scripts, code-column definitions, and Notes.
!]]

-- Card-set source window; its fixed file tabs share editor preferences.
local wx = require("wx");
local Common = require("Windows.Editors.Common");
local CardSetEditor = {};
--[[!
@fqxn CFS.Windows.CardSetEditor.create
@pulsarlua function CardSetEditor.create
@desc Creates the card-set source editor and appends a configured Notes tab, creating a missing notes file without overwriting.
@param any dParent Parent window.
@param any tFiles Source-file records.
@param any sTitle Display title.
@param any tOptions Options table.
!]]
function CardSetEditor.create(dParent, tFiles, sTitle, tOptions)
    if (tOptions and tOptions.notesFile) then
        local pNotes = tOptions.notesFile;
        if (not wx.wxFileExists(pNotes)) then
            local oFile = wx.wxFile(); local bCreated = oFile:Create(pNotes, false);
            if (bCreated) then oFile:Close(); end; oFile:delete();
            assert(bCreated, "Could not create card-set notes. Existing files are never overwritten.");
        end
        tFiles[#tFiles + 1] = {name = "Notes.txt", path = pNotes, kind = "text"};
    end
    return Common.create(dParent, tFiles, sTitle or "Card Set Source Editor", tOptions);
end
return CardSetEditor;
