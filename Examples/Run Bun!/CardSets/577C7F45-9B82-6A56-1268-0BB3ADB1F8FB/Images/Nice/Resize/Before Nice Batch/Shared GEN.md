# Run Bun! — Shared card artwork generation and editing rules

These rules apply to every card type under this CardSets folder. Read the relevant card-type guide as well for its character design, anatomy, artwork dimensions, and specific references. Follow current user instructions first, then the repository's AI RULES.md. This guide does not authorize application code changes.

## 1. References, world, rendering, and scenery

Inspect actual installed artwork before generating or editing. Use approved images directly as visual references; a text description of steampunk is not sufficient.

Everything belongs to Victorian-era steampunk: clothing silhouettes, furnishings, architecture, tools, brass/copper apparatus, leather, carved wood, wrought iron, gas lamps, and practical mechanical details.

Use the established polished, richly colored, detailed illustrated finish. Preserve attractive color and lighting in edits.

When correcting and finishing old sepia prototypes, redesign them in full color. Use distinct natural colors for subjects, clothing, and scenery; do not retain a sepia or overall brown wash.

The background MUST be in focus. Everything in the image, including foreground objects and distant scenery, must be sharp and readable. No blurred elements, background blur, bokeh, shallow depth of field, or motion blur. Show action through posture and the scene rather than blurring it.

Build a meaningful setting around the occupation. Mechanical details should make visual sense; do not scatter arbitrary gears to stand in for design.

Artwork is a standalone scene. Do not bake in a card border, name panel, type bar, description panel, watermark, or unnecessary text. The separate frame supplies the card layout.

## 2. Anatomy, perspective, and framing

Where the depicted subject has limbs or uses tools, maintain coherent anatomy:
- Exactly the required limbs, with believable joints and grips.
- Properly supported feet, objects, and furniture.
- Plausible hand contact with tools and materials.

Maintain coherent perspective:
- Related edges converge consistently.
- Tools, shafts, handles, supports, wheels, drawers, and housings line up.
- Held objects do not float or pass through hands.
- Subject, activity, and setting share the same viewpoint.
- Direction of movement agrees with the surroundings.

Keep important details away from the rounded corners and decorative frame overlaps. Preserve useful headroom and action space where possible.

## 3. Names, files, and CSV

The image filename must match the CSV Name exactly, including spelling and case. Use the correct image folder and CSV Type for the card type.

Use PNG. A JPEG named in the CSV will not load through the current .png path construction.

Keep one working image per card in its image folder. Do not leave “Name Original.png,” “Name Expanded.png,” or alternate working copies beside it.

For each new installed image, immediately add exactly one matching row to the card set's Data.csv, so it can be inspected in Alpha without waiting for the batch to finish.

Current CSV fields are Name,Type,Description,Flavor. Preserve existing rows and text. Leave Description and Flavor blank unless supplied or requested; concept sentences are not automatically flavor text.

When copying supplied flavor text, omit decorative enclosing quotation marks. CSV-required structural quoting is still necessary for commas or multiline content. Preserve internal text and line breaks.

## 4. Backups and rejected versions

Paths in this section are relative to the relevant artwork folder.

Before overwriting any artwork, copy the current file into Resize and verify the copy.

- Initial original: Resize/Name.png, using the original name.
- If that backup already exists, preserve it and put the next version in a clearly named subfolder, still named Name.png.

Preserve ALL generated revisions, including rejected or uninstalled versions. Store them under Resize in separate descriptive or numbered subfolders. Do not overwrite an earlier backup to save a later revision.

Verify backup content, preferably with a hash comparison. Preserve the generated source output too unless the user explicitly asks for deletion.

Back up Data.csv before the first batch addition, preserving an earlier backup if present. Never replace live CSV content with an older copy.

## 5. Editing discipline

Inspect the current image first. State the requested changes and invariants clearly in the edit prompt.

Change only the requested part. If the user approves the pose and camera angle, preserve both and rebuild the environment around them. If only an eye color, hook drip, cheek shape, or background focus needs changing, do not redesign the rest.

Do not promise pixel-for-pixel preservation from a generative edit without actually verifying it. Compare the result with the source, especially the user's favorite details.

If an edit damages approved details, return to the last approved source instead of repeatedly editing an already damaged revision. Retain every version.

## 6. Production and verification sequence

1. Read current user directions, applicable project rules, this guide, and the relevant card-type guide.
2. Inspect the source image and approved style references.
3. Check the intended filename and current CSV row; avoid duplicates.
4. Back up anything to be overwritten and verify the backup.
5. Generate or edit one distinct artwork using the built-in image-generation tool, with direct visual references for the established style.
6. Inspect the result: applicable character design and anatomy, action, perspective, focus, scene logic, and requested invariants.
7. Keep rejected variants in Resize; do not silently discard them.
8. Save the selected PNG at the dimensions specified for its card type, with proportional scaling.
9. Install it under the exact CSV Name.
10. Immediately add or verify its single matching row and correct Type in Data.csv.
11. Check image readability/dimensions and CSV consistency. Verify existing rows were preserved.
12. Report what is actually installed and checked. Distinguish file verification from an in-Studio visual check.

For an authorized batch, keep going through the entire approved list. The user explicitly requested no repeated approval questions during production. Follow later corrections immediately without abandoning unfinished authorized work.

Never claim an image is installed when it is only generated. Do not claim that in-card appearance was checked unless it actually was.
