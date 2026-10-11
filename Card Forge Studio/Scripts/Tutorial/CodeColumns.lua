-- Reorder stable step IDs here; definitions below do not need to move.
local tStepOrder = {10, 20, 30, 40,};

--[[!
@fqxn CFS.Modules.Tutorial.Topics.CodeColumns
@desc Using code columns: a practical advanced guide with independently ordered steps and screenshot placeholders.
!]]

return {
    title = "Using code columns",
    stepOrder = tStepOrder,
    steps = {
        [10] = {
            title = "Choose the right tool",
            html = [[
                <p>A row processor applies shared rules across a collection. A code column holds Lua for an individual cell. Use it when a card needs individual behavior, rather than copying the same calculation into every row. Ordinary descriptions and costs usually belong in ordinary columns.</p><p>Start with one experimental column in a copied set. Use Columns to mark it as code, keeping Name and normal values beside it. Give the column a clear purpose. Code cells are powerful, but the table should not become a wall of tiny mystery programs.</p>
            ]],
            images = {
                {file = "CodeColumns-Step10-A.png", caption = "Figure A: Choose the right tool."},
            },
        },
        [20] = {
            title = "Return a function",
            html = [[
                <p>A code cell must return a function, which Studio then calls in the user environment. Use Edit Code for the selected cell rather than hand-editing its encoded CSV representation. This small example demonstrates the required shape.</p><pre>return function()
    return &quot;Hello from this card&quot;;
end</pre><p>Accept the edit and inspect Final Data. A successful code cell displays COMPILED, not the greeting: this is a compilation status, while returned values are handled separately. A bare string instead of a function does not satisfy the contract.</p>
            ]],
            images = {
                {file = "CodeColumns-Step20-A.png", caption = "Figure A: Return a function."},
            },
        },
        [30] = {
            title = "Understand the checks",
            html = [[
                <p>The editor checks whether Lua can read the script. Processing checks whether it returns a function and whether that function runs. Passing the first check does not guarantee the second. Empty code cells stay empty; failing cells display ERROR and write a warning with details to the Log.</p><p>In your disposable sample, try returning a plain string instead of a function, inspect the warning, then restore the working example. This demonstrates valid Lua versus a valid Studio code cell without requiring a lecture in compiler theory. Read the first meaningful message rather than treating every traceback line as another separate problem.</p>
            ]],
            images = {
                {file = "CodeColumns-Step30-A.png", caption = "Figure A: Understand the checks."},
            },
        },
        [40] = {
            title = "Keep behavior manageable",
            html = [[
                <p>Code cells use the exposed script environment. Private application helpers remain private, and drawing functions require a render pass. A code cell is not permission to draw at any moment or reach every application object. Repeated behavior belongs in a reusable helper.</p><p>Document the column&#x27;s purpose and returned values, then save Base Data. Final-data exports preserve visible text, including compilation status, rather than exporting portable executable behavior. To share editable cells, scripts, and assets together, use a game or card-set package. The later sharing guide explains that distinction.</p>
            ]],
            images = {
                {file = "CodeColumns-Step40-A.png", caption = "Figure A: Keep behavior manageable."},
            },
        },
    },
};
