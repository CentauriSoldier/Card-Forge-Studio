--[[!
@fqxn CFS.Windows.CardSetEditor
@desc
<section aria-label="CardSetEditor overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">CardSetEditor</h2><p style="font-size:1.15rem;margin:0">Card Set Editor brings the active set's scripts and notes together.</p></div>
<h3>How it fits into your work</h3><p>Use its tabs to edit Draw, DrawBack, RowProc, Code Columns, and Notes.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.CardSet">Card Set</a></h3><p style="margin:0">A card set brings together one collection of cards, its dimensions, and the files that describe how those cards look and behave.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys">Processing System</a></h3><p style="margin:0">ProcSys keeps project files, card values, and the preview working together as you edit.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Editors.Common">Editors.Common</a></h3><p style="margin:0">The shared editor helper supplies consistent drafts and save protections.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.EditorSettings">EditorSettings</a></h3><p style="margin:0">Shared settings keep the code editors consistent across projects.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Saving source files and saving card-table data are different operations, with their own validation.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

-- Card-set source window; its fixed file tabs share editor preferences.
local wx = require("wx");
local Common = require("Windows.Editors.Common");
local CardSetEditor = {};
--[[!
@fqxn CFS.Windows.CardSetEditor.Functions.create
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
