-- Reorder stable step IDs here; definitions below do not need to move.
local tStepOrder = {10, 20, 30, 40, 50,};

--[[!
@fqxn CFS.Modules.Tutorial.Topics.TextStyles
@desc Building reusable text styles: a practical advanced guide with independently ordered steps and screenshot placeholders.
!]]

return {
    title = "Building reusable text styles",
    stepOrder = tStepOrder,
    steps = {
        [10] = {
            title = "Build a small style family",
            html = [[
                <p>A text style names a group of visual decisions: font, size, color, and optional effects. Instead of restating those choices in every drawing call, a card asks for a named style. Start with a readable body style and a distinct title style. Decorative effects can wait; legibility has first dibs.</p><p>Open Game &gt; Style Editor. Inspect its fields and preview, then create a style suited to your card dimensions. Review it at the size people will actually read. A title that looks dramatic zoomed in may be a fog bank when the card is small.</p>
            ]],
            images = {
                {file = "TextStyles-Step10-A.png", caption = "Figure A: Build a small style family."},
            },
        },
        [20] = {
            title = "Inherit deliberately",
            html = [[
                <p>Inheritance lets a field borrow its value from another named style. A reference such as &lt;Base&gt; resolves that property; it does not mean every property automatically comes from Base. A title might borrow a family while keeping its own size and color. Referenced styles must exist, and circular chains are rejected.</p><p>Use one base style and one variation first. Change a borrowed value in the base and confirm the variation follows it. Change an independent value in the variation and confirm it stays independent. Avoid long chains until you have a clear reason for them.</p>
            ]],
            images = {
                {file = "TextStyles-Step20-A.png", caption = "Figure A: Inherit deliberately."},
            },
        },
        [30] = {
            title = "Preview and save",
            html = [[
                <p>The editor works with a draft. Editing or importing a style is not the same as saving it to the game&#x27;s styles file. Review its preview and your artwork before committing. Outline, shadow, glow, and highlight can separate text from art, but stacking every effect rarely makes every word easier to read.</p><p>Save when the draft is ready. Correct missing references or loops instead of working around them in drawing scripts. Keep names consistent with the references you use. A predictable style family beats twenty almost-identical styles named FinalTitleReallyFinal.</p>
            ]],
            images = {
                {file = "TextStyles-Step30-A.png", caption = "Figure A: Preview and save."},
            },
        },
        [40] = {
            title = "Choose an export strategy",
            html = [[
                <p>When selected styles depend on styles outside the selection, export offers three approaches. Export without inheritance replaces references with resolved values, preserving the appearance without dependencies. Include the full inheritance chain carries referenced styles recursively. Cancel writes nothing.</p><p>Export one variation as a practice exercise. Compare flattened values with a file containing the chain. A flattened style is independent; a full family retains its relationships. Choose based on what the recipient needs. Neither choice exports card artwork.</p>
            ]],
            images = {
                {file = "TextStyles-Step40-A.png", caption = "Figure A: Choose an export strategy."},
            },
        },
        [50] = {
            title = "Import into the draft",
            html = [[
                <p>Import reads a styles file and validates the proposed combined collection before changing the draft. Matching names require confirmation before replacement. Missing references, invalid values, and circular inheritance reject the import instead of leaving a half-working collection. Successful imports still need Save to persist.</p><p>Import your practice export, read the replacement prompt, and review the result. Accepting replacement uses the incoming definition for the matching style, so keep a copy of important styles before large replacements. The importer brings definitions, not the judgment about whether neon green was a good idea.</p>
            ]],
            images = {
                {file = "TextStyles-Step50-A.png", caption = "Figure A: Import into the draft."},
            },
        },
    },
};
