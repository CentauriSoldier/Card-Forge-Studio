-- Reorder stable step IDs here; definitions below do not need to move.
local tStepOrder = {10, 20, 30, 40, 50,};

--[[!
@fqxn CFS.Modules.Tutorial.Topics.SharingProjects
@desc Sharing editable games and card sets: a practical advanced guide with independently ordered steps and screenshot placeholders.
!]]

return {
    title = "Sharing editable games and card sets",
    stepOrder = tStepOrder,
    steps = {
        [10] = {
            title = "Choose an editable package",
            html = [[
                <p>Game packages use .cfsg and standalone card-set packages use .cfscs. They are ZIP-based packages with a manifest, rather than a renamed collection of pictures. Use the Game or Card Set menu&#x27;s Export action for editable sharing. The data-window ZIP exporter serves a different purpose.</p><p>Save source data and scripts first. Whole-game packages carry the game structure; standalone sets bring assets and source dependencies for importing into another game. Use fictional examples for public tutorials and inspect resources for private material before sharing. A package should carry your project, not unrelated pieces of your computer.</p>
            ]],
            images = {
                {file = "SharingProjects-Step10-A.png", caption = "Figure A: Choose an editable package."},
            },
        },
        [20] = {
            title = "Import without switching",
            html = [[
                <p>Import installs and reports; it does not automatically load the incoming game or card set. You can load it when ready. A standalone set belongs to its destination game, while bundled resources preserve its source environment without replacing that game&#x27;s setup.</p><p>Use the appropriate Import menu action and read its prompts. Matching an active game or set ID blocks import: close the relevant project first. Close Card Set keeps the game active; Close Game clears both. Closing does not delete files. Load the imported project yourself when you want to review it.</p>
            ]],
            images = {
                {file = "SharingProjects-Step20-A.png", caption = "Figure A: Import without switching."},
            },
        },
        [30] = {
            title = "Check compatibility",
            html = [[
                <p>Import and export share a package-format version separate from the game&#x27;s own version. The package records it, and the importer checks its supported-version handlers. Unsupported packages are rejected before installation instead of being interpreted optimistically.</p><p>Keep the manifest intact. If compatibility is rejected, retain the package and use an importer that explicitly supports its format. Editing the version number does not change the contents or make them compatible. A new passport sticker does not teach a suitcase a new language.</p>
            ]],
            images = {
                {file = "SharingProjects-Step30-A.png", caption = "Figure A: Check compatibility."},
            },
        },
        [40] = {
            title = "Understand repairs",
            html = [[
                <p>Import validates in staging and fills missing required, repairable files from FS&#x27;s shared defaults, logging repairs. A default script restores structure, not original custom behavior. Missing artwork and original data cannot be recreated. Isolated invalid cards or child sets can sometimes be skipped and reported; not every damaged package is repairable.</p><p>Read the summary and Log. Imported Lua syntax is checked without running the scripts, so structural success does not prove custom behavior works later. Keep the original package until you review the installed project and any warnings. Repair messages are information to act on, not decoration.</p>
            ]],
            images = {
                {file = "SharingProjects-Step40-A.png", caption = "Figure A: Understand repairs."},
            },
        },
        [50] = {
            title = "Handle matching IDs",
            html = [[
                <p>Matching inactive IDs require overwrite confirmation. Installation uses staging and backup/recovery handling rather than leaving a half-installed replacement after failure. This protection does not make an unwanted replacement desirable. Compare the intended target before agreeing; an active matching ID remains blocked.</p><p>Practice with a saved sample: export, close it, import deliberately, and then load it yourself. Review cards, scripts, and resources. Try a standalone set in a separate example destination game. Keep your own backup of valuable work. Convenient sharing should not make ownership or replacement mysterious.</p>
            ]],
            images = {
                {file = "SharingProjects-Step50-A.png", caption = "Figure A: Handle matching IDs."},
            },
        },
    },
};
