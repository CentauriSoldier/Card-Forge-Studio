-- Reorder stable step IDs here; definitions below do not need to move.
local tStepOrder = {10, 20, 30, 40,};

--[[!
@fqxn CFS.Modules.Tutorial.Topics.DrawingCards
@desc Drawing a complete card: a practical advanced guide with independently ordered steps and screenshot placeholders.
!]]

return {
    title = "Drawing a complete card",
    stepOrder = tStepOrder,
    steps = {
        [10] = {
            title = "Sketch before scripting",
            html = [[
                <p>Decide where the title, artwork, description, and badges belong. Positions are pixels measured from the top-left corner: increasing x moves right, and increasing y moves down. The card set&#x27;s width and height define the canvas. Draw backgrounds first, then artwork, then labels that must remain visible.</p><p>Sketch a layout with generous margins. Forge.GetOutputInfo reports the current dimensions during drawing. Preview zoom does not change the card&#x27;s coordinate system. Leave space for the longest realistic description, not just your nicest sample. A rough sketch saves a surprising amount of coordinate juggling.</p>
            ]],
            images = {
                {file = "DrawingCards-Step10-A.png", caption = "Figure A: Sketch before scripting."},
            },
        },
        [20] = {
            title = "Keep the drawing callback",
            html = [[
                <p>Draw.lua returns a function. Studio calls it during rendering with its object label, drawing helper, and native context. Public Forge commands are available during that pass. The example paints a background and requests fictional artwork; absent artwork uses the application&#x27;s missing-image placeholder.</p><pre>return function(sObject, D, hDC)
    local tSize = Forge.GetOutputInfo();
    Forge.DrawRectangle(0, 0, tSize.Width, tSize.Height, Color.RGB(245, 245, 245));
    Forge.DrawImage(&quot;Images/Example.png&quot;, 20, 50, 120, 120);
end</pre><p>Try it in a disposable set and adjust the dimensions. Drawing calls belong inside the callback, not at file-load time outside a render pass.</p>
            ]],
            images = {
                {file = "DrawingCards-Step20-A.png", caption = "Figure A: Keep the drawing callback."},
            },
        },
        [30] = {
            title = "Add readable text",
            html = [[
                <p>Forge.DrawText takes a named style, a position, and text. Create the style before using its name. Start with fixed text to check placement, then connect it to processed card values using the exposed row access documented in UserEnv. This separates layout problems from data problems.</p><pre>Forge.DrawText(&quot;Title&quot;, 20, 20, &quot;Example Card&quot;);</pre><p>Place this call inside your drawing callback after creating a style named Title. Compare short and long titles. Do not assume text wraps just because it reaches an edge; wrapping and placement require an explicit design. Leave room around labels so the background art does not fight them.</p>
            ]],
            images = {
                {file = "DrawingCards-Step30-A.png", caption = "Figure A: Add readable text."},
            },
        },
        [40] = {
            title = "Review layers and output",
            html = [[
                <p>Later commands can cover earlier ones. If text disappears, check whether a rectangle or image was drawn over it before changing the style. Review several cards with different values and missing artwork. A finished layout should handle the collection, not just the selected card.</p><p>Compare the preview with a PNG export at the intended size. Check edges, text, and images. Keep computed rules in RowProc and visual placement in Draw. With those responsibilities clear, a complete card becomes a series of small understandable decisions instead of one intimidating script.</p>
            ]],
            images = {
                {file = "DrawingCards-Step40-A.png", caption = "Figure A: Review layers and output."},
            },
        },
    },
};
