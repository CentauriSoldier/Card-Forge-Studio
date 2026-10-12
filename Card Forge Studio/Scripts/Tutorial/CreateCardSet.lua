-- Reorder stable step IDs here; definitions below do not need to move.
local tStepOrder = {
    10, 20, 30, 40,
};

--[[!
@fqxn CFS.Modules.Tutorial.Topics.CreateCardSet
@desc Creating a card set: a beginner guide for the native tutorial reader. Step order is separate from stable step IDs; screenshot references use topic, step ID, and figure letter.
!]]

return {
    title = "Creating a card set",
    stepOrder = tStepOrder,
    steps = {
        [10] = {
            title = "Choose the game",
            html = [[
                <p>Create or load the game that will own this collection of cards.</p><p>Open <b>Card Set &gt; New</b>. A game must be active before you can create a card set.</p>
            ]],
            images = {
                {file = "CreateCardSet-Step10-A.png", caption = "Figure A: Card Set menu with New selected."},
            },
        },
        [20] = {
            title = "Name and size the set",
            html = [[
                <p>Enter a <b>Card Set Name</b>, such as <b>Example Cards</b>, and a positive whole number for both pixel dimensions.</p><p>For a simple practice set, try <b>600</b> pixels wide and <b>900</b> pixels high. These are example dimensions, not a printing requirement.</p><p>Click <b>OK</b> to create and load the set.</p>
            ]],
            images = {
                {file = "CreateCardSet-Step20-A.png", caption = "Figure A: New Card Set dialog with example dimensions."},
            },
        },
        [30] = {
            title = "Add your card data",
            html = [[
                <p>Open <b>Window &gt; Base Data</b>. The new set starts with a <b>Name</b> column.</p><p>Use <b>New</b> to add cards, edit their names, and click <b>Save</b> to keep your data. Use <b>Columns...</b> when you need additional fields.</p><p><b>Final Data</b> shows the processed results; edit the original values in Base Data.</p>
            ]],
            images = {
                {file = "CreateCardSet-Step30-A.png", caption = "Figure A: Base Data with a few example card names."},
            },
        },
        [40] = {
            title = "Find the card scripts",
            html = [[
                <p>Choose <b>Card Set &gt; Edit Source...</b> to inspect the drawing and row-processing scripts. These control how card values become artwork and finalized data.</p><p>Creating a set provides starter files; it does not design your finished cards. Use <b>Card Set &gt; Browse</b> to inspect the set folder, or <b>Close Card Set</b> to leave the set while keeping its game active.
                <br>
                <strong>Card names must match the filename of the primary image file.</strong>
                </p>
            ]],
            images = {
                {file = "CreateCardSet-Step40-A.png", caption = "Figure A: Card Set source editor with the starter scripts."},
            },
        },
    },
};
