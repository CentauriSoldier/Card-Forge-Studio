-- Reorder stable step IDs here; definitions below do not need to move.
local tStepOrder = {10, 20, 30, 40,};

--[[!
@fqxn CFS.Modules.Tutorial.Topics.ReusableCode
@desc Organizing reusable Lua code: a practical advanced guide with independently ordered steps and screenshot placeholders.
!]]

return {
    title = "Organizing reusable Lua code",
    stepOrder = tStepOrder,
    steps = {
        [10] = {
            title = "Notice useful repetition",
            html = [[
                <p>When scripts repeat the same formatting or drawing decision, a reusable module can give that decision one home. Begin with something easy to describe, such as formatting a cost label. Avoid turning every tiny expression into another file. The goal is clarity, not a medal for the most folders.</p><p>List the helper&#x27;s inputs and output before writing it. Keep game-wide helpers with shared resources and card-specific drawing in the set. This makes dependencies visible when sharing a package. A small helper with one responsibility is easier to understand and check than an all-purpose module that secretly does everything.</p>
            ]],
            images = {
                {file = "ReusableCode-Step10-A.png", caption = "Figure A: Notice useful repetition."},
            },
        },
        [20] = {
            title = "Return a helper table",
            html = [[
                <p>A module creates a local table, adds functions, and returns it. Save this example as Scripts/CardLabels.lua inside the project&#x27;s resource root. It validates a cost and produces text without drawing or changing files. Changing its wording once can update every caller.</p><pre>local labels = {};
function labels.Cost(vCost)
    local nCost = tonumber(vCost);
    assert(nCost, &quot;Cost must be a number.&quot;);
    return &quot;Cost: &quot;..tostring(nCost);
end
return labels;</pre><p>Try a valid cost first, then an invalid value in your practice project. The expected result for 3 is Cost: 3; an invalid value should produce the clear error.</p>
            ]],
            images = {
                {file = "ReusableCode-Step20-A.png", caption = "Figure A: Return a helper table."},
            },
        },
        [30] = {
            title = "Import and check",
            html = [[
                <p>Import loads project-relative Lua in the user environment. A successful module can return its helper table. Runtime failure from its chunk can return nil and an error, so check the result. Invalid paths and compilation problems can also report errors.</p><pre>local labels, sError = Import(&quot;Scripts/CardLabels.lua&quot;);
assert(labels, sError);
local sLabel = labels.Cost(&quot;3&quot;);</pre><p>Use this where you need the helper and match the file&#x27;s spelling and location. Keep top-level module work simple. Opening a toolbox should not unexpectedly start a fireworks display. The local sLabel now holds text for your caller to use.</p>
            ]],
            images = {
                {file = "ReusableCode-Step30-A.png", caption = "Figure A: Import and check."},
            },
        },
        [40] = {
            title = "Share dependencies too",
            html = [[
                <p>A script importing a file needs that file when the project moves. Editable game packages include project resources, and standalone sets bundle source dependencies for use in another game. Artwork and data exports are finished outputs, not replacements for the editable environment.</p><p>Inspect imports before sharing and keep helpers within the resource structure. Do not import from personal folders. Check the helper, then its caller, then the completed card. This order makes a failure easier to locate and keeps reusable code approachable for the next person who reads it.</p>
            ]],
            images = {
                {file = "ReusableCode-Step40-A.png", caption = "Figure A: Share dependencies too."},
            },
        },
    },
};
