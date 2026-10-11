-- Reorder stable step IDs here; definitions below do not need to move.
local tStepOrder = {10, 20, 30, 40, 50,};

--[[!
@fqxn CFS.Modules.Tutorial.Topics.ExportFormats
@desc Choosing and configuring exports: a practical advanced guide with independently ordered steps and screenshot placeholders.
!]]

return {
    title = "Choosing and configuring exports",
    stepOrder = tStepOrder,
    steps = {
        [10] = {
            title = "Choose the result you need",
            html = [[
                <p>PNG produces separate artwork. Atlas groups artwork into sheets with position information. CSV, JSON, and Lua deliver finalized data. HTML creates an interactive gallery. ZIP collects selected artwork, data, and that gallery. These seven formats are available; planned targets are not working options.</p><p>Choose a format in either data window, then open Export Options. Ask what the recipient needs: pictures, information, a browsable collection, or a bundle. Editable game and card-set packages are separate menu actions. A finished picture and the project used to create it are both useful, but they are different deliveries.</p>
            ]],
            images = {
                {file = "ExportFormats-Step10-A.png", caption = "Figure A: Choose the result you need."},
            },
        },
        [20] = {
            title = "Review scope and settings",
            html = [[
                <p>Export All, Export Filtered, and Export Selected describe different row scopes. Review the scope before choosing a destination. Format choices and their relevant settings save per card set, making repeated jobs convenient. Saved settings are a starting point, not a substitute for checking what you are about to send.</p><p>Try a small selected-row export, inspect it, then export the full intended scope. Export controls disable during a job and re-enable afterward. Progress appears in the status bar and completion is logged. Long-job cancellation is deferred, so choose the scope carefully before starting a large job.</p>
            ]],
            images = {
                {file = "ExportFormats-Step20-A.png", caption = "Figure A: Review scope and settings."},
            },
        },
        [30] = {
            title = "Match an atlas target",
            html = [[
                <p>Atlas supports Generic format 1 and LÖVE 11.5. Targets and versions are explicit because receiving projects must understand the metadata. Pick the target your project supports. Page dimensions and face settings affect how artwork fits into sheets. Unity, Godot, and Phaser remain planned.</p><p>Inspect sheet images and metadata together. Progress can count output files instead of cards: each sheet may hold several cards, and metadata is another file. A smaller file count alone does not mean cards were dropped. Check the listed entries when confirming coverage rather than comparing two different kinds of count.</p>
            ]],
            images = {
                {file = "ExportFormats-Step30-A.png", caption = "Figure A: Match an atlas target."},
            },
        },
        [40] = {
            title = "Review data and galleries",
            html = [[
                <p>CSV, JSON, and Lua preserve finalized text in original column order without guessing numeric types. HTML includes search, filtering, enlarged viewing, front/back switching, and a selectable theme. Relative artwork and embedded data let the gallery travel with its files.</p><p>Inspect an exported record and open a small gallery to try its controls. Code-column status is visible finalized text, not an exported executable result. Choose a readable theme and check both faces when applicable. Your cards should be the stars; the page should not audition for their job.</p>
            ]],
            images = {
                {file = "ExportFormats-Step40-A.png", caption = "Figure A: Review data and galleries."},
            },
        },
        [50] = {
            title = "Bundle with ZIP",
            html = [[
                <p>ZIP can include selected artwork, CSV, JSON, Lua, and the same HTML gallery according to its content choices. It is useful for sending several outputs together. It is not the editable project package and does not automatically include an atlas.</p><p>Review its content checkboxes, export a small bundle, and inspect the archive. Confirm the gallery&#x27;s linked images are present. For editable sharing, choose the dedicated game or card-set package action instead. A suitcase of finished outputs and a suitcase of editable files solve different problems.</p>
            ]],
            images = {
                {file = "ExportFormats-Step50-A.png", caption = "Figure A: Bundle with ZIP."},
            },
        },
    },
};
