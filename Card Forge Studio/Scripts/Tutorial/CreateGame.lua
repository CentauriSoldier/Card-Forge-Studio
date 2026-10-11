-- Reorder stable step IDs here; definitions below do not need to move.
local tStepOrder = {
    10, 20, 30, 40,
};

--[[!
@fqxn CFS.Modules.Tutorial.Topics.CreateGame
@desc Creating a game: a beginner guide for the native tutorial reader. Step order is separate from stable step IDs; screenshot references use topic, step ID, and figure letter.
!]]

return {
    title = "Creating a game",
    stepOrder = tStepOrder,
    steps = {
        [10] = {
            title = "Open New Game",
            html = [[
                <p>A game is the home for your card sets, shared styles, and game materials.</p><p>Open <b>Game &gt; New</b>. If you already have unsaved work open, respond to its save or discard prompts first.</p>
            ]],
            images = {
                {file = "CreateGame-Step10-A.png", caption = "Figure A: Game menu with New selected."},
            },
        },
        [20] = {
            title = "Give it a name",
            html = [[
                <p>In <b>New Game</b>, enter a name such as <b>Example Game</b>, then click <b>OK</b>.</p><p>Card Forge Studio creates the starter folders and files in your configured Games folder. Cancel leaves things unchanged.</p>
            ]],
            images = {
                {file = "CreateGame-Step20-A.png", caption = "Figure A: New Game dialog with an example name."},
            },
        },
        [30] = {
            title = "Check your new game",
            html = [[
                <p>The new game becomes active. Its name appears in the main window title and status bar.</p><p>Choose <b>Game &gt; Browse</b> if you want to see its files. Your game starts without card sets; the next tutorial creates one.</p>
            ]],
            images = {
                {file = "CreateGame-Step30-A.png", caption = "Figure A: Main window after creating Example Game."},
            },
        },
        [40] = {
            title = "Return later",
            html = [[
                <p>Use <b>Game &gt; Close Game</b> when you want to leave it. Unsaved work may prompt you before closing.</p><p>To return, choose <b>Game &gt; Load</b> and select the game. Closing a game does not delete its files.</p>
            ]],
            images = {
                {file = "CreateGame-Step40-A.png", caption = "Figure A: Game menu showing Load and Close Game."},
            },
        },
    },
};
