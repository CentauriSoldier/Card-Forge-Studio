-- Reorder stable step IDs here; definitions below do not need to move.
local tStepOrder = {10, 20, 30, 40,};

--[[!
@fqxn CFS.Modules.Tutorial.Topics.Debugging
@desc Debugging processing and drawing: a practical advanced guide with independently ordered steps and screenshot placeholders.
!]]

return {
    title = "Debugging processing and drawing",
    stepOrder = tStepOrder,
    steps = {
        [10] = {
            title = "Find the first useful error",
            html = [[
                <p>Open Window &gt; Log and locate the earliest relevant failure after your change. A later drawing error can follow an earlier processing error. Read the message and script location before reacting to the longest part of the traceback. The first broken domino is usually more interesting than the twentieth.</p><p>Record what changed, which stage failed, and which row was involved. Keep the previous working version available. Avoid several unrelated edits while identifying the cause; otherwise even success becomes difficult to explain. A useful error report includes what you did and what happened, not just that the program was unhappy.</p>
            ]],
            images = {
                {file = "Debugging-Step10-A.png", caption = "Figure A: Find the first useful error."},
            },
        },
        [20] = {
            title = "Separate data from drawing",
            html = [[
                <p>Inspect Base Data and Final Data for the same card. If processing failed or a computed value is wrong, investigate source values and the row processor first. If finalized values are right but the picture is wrong, focus on drawing, style, image paths, or layer order.</p><p>Use a tiny sample with simple values. Check number conversions and blank-field rules. In a copied set, simplify drawing to fixed text and a basic shape. That separates a layout failure from a problem in its incoming information. Restore the working parts gradually rather than rewriting the entire card.</p>
            ]],
            images = {
                {file = "Debugging-Step20-A.png", caption = "Figure A: Separate data from drawing."},
            },
        },
        [30] = {
            title = "Check the kind of value",
            html = [[
                <p>CSV values start as text even when they look numeric. Arithmetic needs deliberate conversion and an invalid-input rule. A missing field differs from an empty string; a misspelled header differs from a zero cost. Code columns also have their returned-function contract and compilation status.</p><p>Compare the actual header with the script and review the failing value. Prefer a message such as Cost must be a number over a calculation that fails far away. Correct the rule or source rather than adding defaults just to hide warnings. A quiet error is still an error wearing slippers.</p>
            ]],
            images = {
                {file = "Debugging-Step30-A.png", caption = "Figure A: Check the kind of value."},
            },
        },
        [40] = {
            title = "Recover in small steps",
            html = [[
                <p>Save the corrected source and confirm processing succeeds. Reprocess the affected row when appropriate, then inspect Final Data and its preview. Check a second previously working row for accidental side effects. If it still fails, return to your working copy and narrow the experiment.</p><p>A successful export checks another stage but does not prove every card looks correct. Inspect representative outputs. Keep a short note about subtle causes and fixes. Future you will appreciate an explanation much more than a comment saying do not touch, magic happens here.</p>
            ]],
            images = {
                {file = "Debugging-Step40-A.png", caption = "Figure A: Recover in small steps."},
            },
        },
    },
};
