-- Reorder stable step IDs here; definitions below do not need to move.
local tStepOrder = {10, 20, 30, 40,};

--[[!
@fqxn CFS.Modules.Tutorial.Topics.CardData
@desc Designing your card data: a practical advanced guide with independently ordered steps and screenshot placeholders.
!]]

return {
    title = "Designing your card data",
    stepOrder = tStepOrder,
    steps = {
        [10] = {
            title = "Give each column a job",
            html = [[
                <p>Plan a few clear fields before adding dozens: Name, Description, Cost, and Artwork are useful fictional examples. A row represents one card; a column represents one kind of information. Name is required, and headers must not collide when letter case is ignored. Cost and COST are not separate drawers.</p><p>Use Columns to manage the structure and enter a few varied sample cards. Decide which fields people will enter and which processing will calculate. Avoid packing unrelated values into one cell. A short, consistent table is easier to maintain than one that needs its own treasure map.</p>
            ]],
            images = {
                {file = "CardData-Step10-A.png", caption = "Figure A: Give each column a job."},
            },
        },
        [20] = {
            title = "Separate source and results",
            html = [[
                <p>Base Data is what you edit and save. Final Data is the processed view. A calculated result can differ from its source without destroying what you entered. This lets you change a rule once rather than manually correcting every card. For example, processing could derive a display label from a base cost.</p><p>Edit one source cell and compare the same row in both windows. Include a blank optional field in your examples. Finalized values are text: JSON and Lua exports do not guess which strings should become numbers. If a receiving tool requires numbers, account for that when it reads the exported data.</p>
            ]],
            images = {
                {file = "CardData-Step20-A.png", caption = "Figure A: Separate source and results."},
            },
        },
        [30] = {
            title = "Decide what blank means",
            html = [[
                <p>An empty description might be valid. An empty cost might mean zero, unknown, or unfinished. Studio cannot decide your game&#x27;s meaning for you. Establish a rule for each important field and apply it consistently. Numeric-looking CSV cells are still text, so calculations need conversion and a check for invalid input.</p><p>Try a complete row, a blank optional field, and an invalid number. Decide whether to provide a deliberate default or report an error. Do not quietly replace every problem with zero just to make warnings disappear. The next guide shows a small calculation with a message that identifies the actual issue.</p>
            ]],
            images = {
                {file = "CardData-Step30-A.png", caption = "Figure A: Decide what blank means."},
            },
        },
        [40] = {
            title = "Save a trustworthy source",
            html = [[
                <p>Use Save in Base Data after reviewing the changes you want to keep. An exported final-data file is an output, not a replacement for editable source and scripts. Keep those roles clear when organizing backups. Selected, filtered, and all rows are different export scopes.</p><p>Save your sample, compare its source and result, and identify the computed columns. Later, inspect the header and row count of a small CSV export before delivering the full collection. That modest habit prevents the discovery that you beautifully exported only the single card you happened to click.</p>
            ]],
            images = {
                {file = "CardData-Step40-A.png", caption = "Figure A: Save a trustworthy source."},
            },
        },
    },
};
