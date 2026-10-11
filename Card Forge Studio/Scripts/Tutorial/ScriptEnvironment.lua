-- Reorder stable step IDs here; definitions below do not need to move.
local tStepOrder = {10, 20, 30, 40,};

--[[!
@fqxn CFS.Modules.Tutorial.Topics.ScriptEnvironment
@desc Understanding the script environment: a practical advanced guide with independently ordered steps and screenshot placeholders.
!]]

return {
    title = "Understanding the script environment",
    stepOrder = tStepOrder,
    steps = {
        [10] = {
            title = "Follow one card",
            html = [[
                <p>A card travels through three stages: the information you enter, the information Studio prepares, and the picture it draws. Base Data is your editable source. A row processor prepares Final Data. Drawing scripts turn the selected result into artwork. Exporters deliver artwork or data in another format.</p><p>Open both data windows from Window, compare the same row, and inspect its preview. Ask which stage owns a change: a calculated cost belongs in processing; a prettier border belongs in drawing. Changing artwork does not rewrite your CSV. Recognizing these separate jobs makes the whole system less mysterious.</p>
            ]],
            images = {
                {file = "ScriptEnvironment-Step10-A.png", caption = "Figure A: Follow one card."},
            },
        },
        [20] = {
            title = "Game or card set?",
            html = [[
                <p>The game is the shared home for its card sets. Its configuration, environment script, and styles establish things collections can use together. A card set owns its data, dimensions, row processor, and front and back drawing scripts. Shared decisions do not need to be copied into every collection.</p><p>Use Game &gt; Browse and Card Set &gt; Browse to inspect those homes. Work with a small fictional example while learning. Standalone imported sets can carry a bundled source environment: the destination game owns the set, but bundled resources preserve its original dependencies. Do not assume every imported set uses the destination game&#x27;s scripts.</p>
            ]],
            images = {
                {file = "ScriptEnvironment-Step20-A.png", caption = "Figure A: Game or card set?."},
            },
        },
        [30] = {
            title = "Know your workbench",
            html = [[
                <p>The user environment is the collection of names Studio makes available to game scripts. Forge supplies drawing functions, Color creates native colors, and Import loads reusable project code. Configuration is exposed through CFG. These are the tools on your workbench; the entire application is not automatically on that bench.</p><p>In API Docs, inspect UserEnv&#x27;s Functions, Constants, and Namespaces when you need exact commands. Private entries explain internal implementation and cannot be used as game-script commands. Copy an exposed API example rather than calling something simply because it appeared in a search. The workshop has a staff cupboard, too.</p>
            ]],
            images = {
                {file = "ScriptEnvironment-Step30-A.png", caption = "Figure A: Know your workbench."},
            },
        },
        [40] = {
            title = "Change one thing",
            html = [[
                <p>Use the source editor for the script you intend to change, save it, and watch the corresponding data or preview. Studio watches project files and applies changes through its processing loop. A syntax error, an incorrect value, and missing artwork are different problems, even when all three leave an unhappy card.</p><p>In a copied set, change one harmless drawing position and check the result. If it fails, open Window &gt; Log and read the first relevant error before making another change. Keep the last working version available. Later guides explain each stage in detail; today you only need a reliable map of the journey.</p>
            ]],
            images = {
                {file = "ScriptEnvironment-Step40-A.png", caption = "Figure A: Change one thing."},
            },
        },
    },
};
