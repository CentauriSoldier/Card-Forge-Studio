-- Reorder stable step IDs here; definitions below do not need to move.
local tStepOrder = {10, 20, 30, 40,};

--[[!
@fqxn CFS.Modules.Tutorial.Topics.CardFaces
@desc Creating fronts and backs: a practical advanced guide with independently ordered steps and screenshot placeholders.
!]]

return {
    title = "Creating fronts and backs",
    stepOrder = tStepOrder,
    steps = {
        [10] = {
            title = "Plan both sides",
            html = [[
                <p>The front presents identity and information. The back might be a shared design for a deck or a different design for every card. Decide which your game needs before adding detail. A shared back should not accidentally reveal which card it belongs to; individual backs may intentionally carry more information.</p><p>Sketch both faces using the same dimensions, orientation, and margins. Decide whether players should recognize the top edge on both sides. Shared colors and helpers can keep the design consistent while each face has its own purpose. A back does not need to be complicated to look intentional.</p>
            ]],
            images = {
                {file = "CardFaces-Step10-A.png", caption = "Figure A: Plan both sides."},
            },
        },
        [20] = {
            title = "Use separate callbacks",
            html = [[
                <p>Draw.lua provides the front callback and DrawBack.lua provides the back callback. Both return functions for Studio to call during rendering. Keep back-specific work in the back script instead of expecting a front-only drawing to become two faces automatically. Drawing commands still belong inside the callback.</p><p>Start the back with a simple background and fixed label, then preview it before adding detail. Use the same pixel coordinates from the top-left corner as the front. Reuse a named style where appropriate. Keep the first version simple enough that a missing feature cannot hide among twenty decorative layers.</p>
            ]],
            images = {
                {file = "CardFaces-Step20-A.png", caption = "Figure A: Use separate callbacks."},
            },
        },
        [30] = {
            title = "Review shared and individual backs",
            html = [[
                <p>A shared back should stay independent of card-specific fields. If backs vary, test several rows and confirm the intended differences. A successful front preview does not establish that every back is right. Review both faces before deciding how to export them.</p><p>Check contrasting cards: short and long front text, different images, and any card with unique back information. Confirm drawing does not rely on absent optional values. Keep a small review set so you can repeat these checks without examining the entire collection after every minor change.</p>
            ]],
            images = {
                {file = "CardFaces-Step30-A.png", caption = "Figure A: Review shared and individual backs."},
            },
        },
        [40] = {
            title = "Match the export faces",
            html = [[
                <p>Artwork exporters expose face choices according to their format. Atlas offers fronts only, fronts and backs, or one shared back. Choose the option that matches the design you reviewed. Data exports carry information rather than a second picture face.</p><p>Select the format and open Export Options before exporting. Inspect the resulting files or gallery, not just the completion message. One shared back is convenient when the backs truly are shared; it cannot preserve different backs while saving space. Let the setting follow your design instead of surprising it.</p>
            ]],
            images = {
                {file = "CardFaces-Step40-A.png", caption = "Figure A: Match the export faces."},
            },
        },
    },
};
