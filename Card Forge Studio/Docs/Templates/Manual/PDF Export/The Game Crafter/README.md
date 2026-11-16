# The Game Crafter PDF profiles

Profiles.json supplies the Manual editor preset dropdown. Source Templates contains the unmodified official artwork; it is reference material, never a page background in the exported manual.

Source: https://www.thegamecrafter.com/make/products
Official downloads: https://s3.amazonaws.com/www.thegamecrafter.com/templates/
Booklet instructions: https://help.thegamecrafter.com/article/80-booklets
Book instructions: https://help.thegamecrafter.com/article/602-books
Spine instructions: https://help.thegamecrafter.com/article/468-setting-up-a-spine
Checked: 2026-11-15. Eleven book products, seventeen selectable page-count profiles.

All dimensions in values are inches. Width and height are trimmed page dimensions; bleed is added to every edge. Margins are measured inward from the trim edge, not from the full-bleed canvas. Inside and outside margins mirror for odd/even pages. Booklet 40-page safe guides narrow both sides. Coil and perfect-bound raster guides use conservatively rounded safe margins. Supplier upload pixel dimensions are retained separately; physical exterior dimensions are not substituted for page trim dimensions. Digest perfect-bound pages have a 0.1875-inch bleed; most other listed pages have 0.125-inch bleed.

## Adding a preset

Add a uniquely identified object to profiles with name, source, templates, minPages, maxPages, pageMultiple and values. Copy an existing object as a structural example. Required values: units (in), width, height, bleed, marginTop, marginBottom, marginInside, marginOutside and dpi. Numbers must be finite; width, height and dpi must be positive; bleed/margins must be nonnegative. Store original reference files in a product-named Source Templates subfolder and list paths relative to this folder. Restart the editor after editing presets. Preset selection copies defaults into the game-owned Config/export-settings.json; later field edits do not change this catalog.

Book page counts include covers. Perfect-bound cover/spine production is separate and spine width depends on page count; no fixed spine size is inferred. The exporter uses these settings for full-bleed PDF pages. Supplier cover/spine generation, raster page images and PDF trim/bleed box postprocessing are separate work; a generated PDF is not automatically a production-approved supplier submission.
