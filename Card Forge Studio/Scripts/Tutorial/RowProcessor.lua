-- Reorder stable step IDs here; definitions below do not need to move.
local tStepOrder = {10, 20, 30, 40,};

--[[!
@fqxn CFS.Modules.Tutorial.Topics.RowProcessor
@desc Writing a row processor: a practical advanced guide with independently ordered steps and screenshot placeholders.
!]]

return {
    title = "Writing a row processor",
    stepOrder = tStepOrder,
    steps = {
        [10] = {
            title = "Start with pass-through",
            html = [[
                <p>RowProc.lua returns a function that Studio calls for ordinary data cells. Its inputs identify the row, column, header, source row, and original text, with a helper for reading finalized values. The starter returns the original text unchanged. Name passes through separately rather than being sent to this callback.</p><p>Open the card set&#x27;s RowProc.lua in the source editor and keep its callback shape. Read its purpose as: given this cell and its row, what text should appear in Final Data? Begin in a copied, small set. First establish that unchanged source values reach the result; then add one calculation.</p>
            ]],
            images = {
                {file = "RowProcessor-Step10-A.png", caption = "Figure A: Start with pass-through."},
            },
        },
        [20] = {
            title = "Calculate one field",
            html = [[
                <p>Add ordinary columns named Cost and DisplayCost. This example changes only DisplayCost, converts the source cost, rejects invalid input, and returns text. Other cells keep their original value. Returning a number directly does not replace the cell: the processor expects a string result.</p><pre>return function(nRow, nColumn, sHeader, tRow, sText, fGetFinalValue)
    if sHeader == &quot;DisplayCost&quot; then
        local nCost = tonumber(tRow.Cost);
        assert(nCost, &quot;Cost must be a number.&quot;);
        return &quot;Cost: &quot;..tostring(nCost);
    end
    return sText;
end</pre><p>Try costs 2 and 5, then an invalid entry in your practice copy. Check Final Data and the Log. Decide whether rejecting blanks fits your game; if not, provide an explicit default rather than guessing.</p>
            ]],
            images = {
                {file = "RowProcessor-Step20-A.png", caption = "Figure A: Calculate one field."},
            },
        },
        [30] = {
            title = "Respect processing order",
            html = [[
                <p>The source-row view reads original fields. The finalized-value helper reads processed fields, so order matters: a later column can depend on a value prepared earlier. Do not expect a later result to be ready just because its header exists. This is an assembly line, not time travel.</p><p>Prefer source values when you do not need another processed result. When you do, place that dependency first and keep the chain short. Write down which calculated column relies on which other column. The exact helper options are in the API reference; understanding the dependency is more important than memorizing its arguments.</p>
            ]],
            images = {
                {file = "RowProcessor-Step30-A.png", caption = "Figure A: Respect processing order."},
            },
        },
        [40] = {
            title = "Verify the answer",
            html = [[
                <p>A script that loads can still calculate the wrong answer. Review several Final Data rows, including edge cases, before connecting a result to artwork. Use Reprocess Row when reviewing an affected row. Keep game rules in processing and visual placement in drawing so each remains understandable.</p><p>Save the script, check your sample rows, and confirm unaffected columns still pass through. Fix the first processing error before chasing a secondary preview error. Save the source data too when it is ready. You now have a repeatable calculation rather than a collection of manually patched values.</p>
            ]],
            images = {
                {file = "RowProcessor-Step40-A.png", caption = "Figure A: Verify the answer."},
            },
        },
    },
};
