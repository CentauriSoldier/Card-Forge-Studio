-- Reorder stable step IDs here; definitions below do not need to move.
local tStepOrder = {10, 20, 30, 40,};

--[[!
@fqxn CFS.Modules.Tutorial.Topics.ImagesAndPaths
@desc Managing images and project paths: a practical advanced guide with independently ordered steps and screenshot placeholders.
!]]

return {
    title = "Managing images and project paths",
    stepOrder = tStepOrder,
    steps = {
        [10] = {
            title = "Give assets a home",
            html = [[
                <p>Keep artwork in the project rather than referencing a personal desktop or downloads folder. Use descriptive filenames another person can understand. A relative path describes a location from the project&#x27;s resource root, so moving the complete project does not require replacing a machine-specific starting address.</p><p>Use Game &gt; Browse to inspect the project and put fictional artwork in its Images folder. A drawing can refer to Images/Example.png. Do not include account names, personal folder paths, or unrelated private assets in scripts or public examples. A portable project should not require a guided tour of your computer.</p>
            ]],
            images = {
                {file = "ImagesAndPaths-Step10-A.png", caption = "Figure A: Give assets a home."},
            },
        },
        [20] = {
            title = "Understand the virtual file system",
            html = [[
                <p>FS is Studio&#x27;s virtual file system: a read-only map of named project locations over real folders and files. It provides a consistent way to identify the right home for resources. It is not a separate disk or an operating-system security sandbox. Controlled paths and validation support safer file access.</p><p>Think of FS as a labeled map, not a guard who can stop every possible action. Image loading and script imports apply their own checks. Use documented relative paths and keep resources inside the expected structure. The API reference explains detailed path rules when you need them; the practical goal is predictable, portable references.</p>
            ]],
            images = {
                {file = "ImagesAndPaths-Step20-A.png", caption = "Figure A: Understand the virtual file system."},
            },
        },
        [30] = {
            title = "Remember bundled dependencies",
            html = [[
                <p>Standalone card-set packages can carry their source environment and assets. Imported into another game, the destination game owns the set, but resource resolution can use the bundled dependency root. That preserves the source resources without replacing the destination game&#x27;s setup.</p><p>When reviewing an imported set, do not fix a missing picture by blindly putting it in the destination game. Inspect its bundled resources and relative reference first. A complete editable package is different from sending a CSV and hoping the recipient already owns every image. Keep shared and set-specific resources organized so those dependencies are understandable.</p>
            ]],
            images = {
                {file = "ImagesAndPaths-Step30-A.png", caption = "Figure A: Remember bundled dependencies."},
            },
        },
        [40] = {
            title = "Handle missing assets",
            html = [[
                <p>Missing artwork displays Missing.png in preview and export. This exposes the omission; it cannot recreate the intended picture. An existing but unreadable image can still produce an error, and an invalid path is not made valid by the fallback. Check the Log when a resource fails to load.</p><p>Before sharing, inspect representative cards for placeholders. Check spelling, location, and whether the image decodes normally. Avoid absolute paths or references climbing outside the project. The placeholder is a useful warning flag, not an acceptable substitute for the finished dragon. Once corrected, review the actual exported artwork as well as the preview.</p>
            ]],
            images = {
                {file = "ImagesAndPaths-Step40-A.png", caption = "Figure A: Handle missing assets."},
            },
        },
    },
};
