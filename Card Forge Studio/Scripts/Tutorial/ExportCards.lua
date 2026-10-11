-- Reorder stable step IDs here; definitions below do not need to move.
local tStepOrder = {
    10, 20, 30, 40, 50,
};

--[[!
@fqxn CFS.Modules.Tutorial.Topics.ExportCards
@desc Exporting cards: a beginner guide for the native tutorial reader. Step order is separate from stable step IDs; screenshot references use topic, step ID, and figure letter.
!]]

return {
    title = "Exporting cards",
    stepOrder = tStepOrder,
    steps = {
        [10] = {
            title = "Prepare the set",
            html = [[
                <p>Load a card set and save your latest data and source edits. Check the preview and <b>Window &gt; Final Data</b> before exporting.</p><p>Exporting artwork and data produces usable outputs. To transfer the editable project itself, use <b>Game &gt; Export Game...</b> or <b>Card Set &gt; Export Card Set...</b> instead.</p>
            ]],
            images = {
                {file = "ExportCards-Step10-A.png", caption = "Figure A: Final Data with a prepared example set."},
            },
        },
        [20] = {
            title = "Choose an output",
            html = [[
                <p>At the bottom of a data window, select the export format.</p><ul><li><b>PNG</b>: separate card images.</li><li><b>Atlas</b>: image sheets and position data.</li><li><b>CSV, JSON, or Lua</b>: finalized card values.</li><li><b>HTML</b>: an interactive card gallery.</li><li><b>ZIP</b>: a bundle of the chosen artwork, data, and gallery contents.</li></ul>
            ]],
            images = {
                {file = "ExportCards-Step20-A.png", caption = "Figure A: Export format selector in a data window."},
            },
        },
        [30] = {
            title = "Set the options",
            html = [[
                <p>Click <b>Export Options</b> to configure the selected format. Atlas includes a target and version; HTML includes a theme; ZIP lets you choose its contents.</p><p>Confirm your settings before exporting. Export choices are remembered for this card set.</p>
            ]],
            images = {
                {file = "ExportCards-Step30-A.png", caption = "Figure A: Export Options for a selected format."},
            },
        },
        [40] = {
            title = "Choose which cards",
            html = [[
                <p>Click <b>Export All</b> for every card, <b>Export Filtered</b> for the current filtered results, or <b>Export Selected</b> for selected rows.</p><p>Choose the destination folder when prompted. Wait for the job to finish before starting another export; export controls are disabled while it is active.</p>
            ]],
            images = {
                {file = "ExportCards-Step40-A.png", caption = "Figure A: Export All, Export Filtered, and Export Selected controls."},
            },
        },
        [50] = {
            title = "Check the results",
            html = [[
                <p>The status bar reports progress, and the Log records completion or errors. Atlas counts output files, which may differ from the number of cards.</p><p>Open your destination folder to inspect the results. For an HTML gallery, open its <b>index.html</b>. For ZIP, extract the bundle first.</p>
            ]],
            images = {
                {file = "ExportCards-Step50-A.png", caption = "Figure A: An export destination containing example output files."},
            },
        },
    },
};
