# Run Bun! — Shared card artwork generation and editing rules

These rules apply to every card type under this CardSets folder. Read the relevant card-type guide as well for its character design, anatomy, artwork dimensions, and specific references. Follow current user instructions first, then the repository's AI RULES.md. This guide does not authorize application code changes.

## 1. References, world, rendering, and scenery

Inspect actual installed artwork before generating or editing. Use approved images directly as visual references; a text description of steampunk is not sufficient.

Everything belongs to Victorian-era steampunk: clothing silhouettes, furnishings, architecture, tools, brass/copper apparatus, leather, carved wood, wrought iron, gas lamps, and practical mechanical details.

Steampunk must be unmistakable in every scene, including the characters, not just the background. Buns wear cute Victorian steampunk outfits with readable, varied hats, goggles, waistcoats, coats, leather straps, and appropriate brass or copper accessories. Preserve their established adorable designs and compact rabbit proportions. Do not omit their clothing and accessories when drawing crowds or action scenes. Use purposeful mechanical furnishings and architecture so the setting and its inhabitants visibly belong to the same steampunk world.

Demonic and evil do not mean every Dog has horns. Include hornless Dogs; when horns are present, vary their shapes and placement instead of repeating one design. Fur must not glow: no luminous coats, glowing fur markings, or light-emitting fur. Glowing eyes may use different colors. Convey evil through canine features, expression, posture, and action. Purposeful steampunk equipment on Dogs is welcome and should remain visibly integrated with their anatomy.

Use the established polished, richly colored, detailed illustrated finish. Preserve attractive color and lighting in edits.

Buns AND Dogs must have individual designs across cards while retaining their respective shared ancestry, facial structure, and established rendering style. Vary fur, markings, silhouette, ears, facial details, outfits, and purposeful accessories. Dogs in particular must not repeatedly reuse one black/brindled, spiky, glowing-marked design: vary powerful canine builds, coat patterns, horn/ridge shapes, ears, muzzles, and demonic traits. Rotate suitable direct visual references and specify a distinct design for each new scene. Preserve the identity of a named recurring character when explicitly requested; otherwise do not silently clone the same Dog throughout a batch. Individuality must not weaken the Buns' cuteness or the Dogs' demonic menace.

When correcting and finishing old sepia prototypes, redesign them in full color. Use distinct natural colors for subjects, clothing, and scenery; do not retain a sepia or overall brown wash.

The background MUST be in focus. Everything in the image, including foreground objects and distant scenery, must be sharp and readable. No blurred elements, background blur, bokeh, shallow depth of field, or motion blur. Show action through posture and the scene rather than blurring it.

Build a meaningful setting around the occupation. Mechanical details should make visual sense; do not scatter arbitrary gears to stand in for design.

Artwork is a standalone scene. Do not bake in a card border, name panel, type bar, description panel, watermark, or unnecessary text. The separate frame supplies the card layout.

When Buns face an attacking Dog, show unmistakable terror rather than mild worry: wide fearful eyes, strained brows, open alarmed mouths, pinned or swept ears, and urgent fleeing poses. Vary expressions naturally while keeping faces adorable and readable; the threat must feel immediate. Preserve their cute steampunk hats, goggles, clothing, and accessories throughout the action.

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

Pay particular attention to doors, hatches, wheels, axles, tracks, paths, and connected structures. The user has identified repeated errors in their perspective and physical logic. Do not install an image merely because its style looks good: inspect whether the depicted action could actually work.

- Doors and hatches pivot about their hinge edge. The opposite free edge closes against the latch side of the opening. Handles, bolts, hinges, jambs, and the swing arc must agree; never depict a door closing at its hinge edge or a bolt joining the wrong surfaces.
- Wheels share a coherent chassis, axle positions, and ground plane. Rail wheels sit on the corresponding rails; track gauge, curves, junctions, and vehicle travel direction must align. No wheels, pedals, axles, or rails passing through characters or unrelated parts.
- Paths, bridges, stairs, thresholds, tunnels, and escape openings must connect continuously in perspective and have plausible clearance. A route must actually lead where the scene implies, rather than end at a wall or intersect a structure accidentally.
- Ropes, pulleys, levers, loads, supports, and traps must form a physically coherent mechanism. Check attachment points, tension, gravity, load support, available travel, and the result of activating a control. A lifting net cannot be anchored to the ground; a falling weight must have room to fall.
- Before generation, describe the geometry and cause-and-effect of the crucial action. After generation, trace those connections visually. Correct failures before installation, preserving every revision. Do not rely on decorative detail to conceal a mechanically impossible scene.

Keep important details away from the rounded corners and decorative frame overlaps. Preserve useful headroom and action space where possible.

For all card-frame generation and editing, include at least one pair of different decorative objects on opposite sides of the artwork opening, aligned at the same vertical height. The left-side object must differ from its right-side counterpart; for example, a lever on one side and a pressure gauge on the other. Other paired elements, such as springs, may remain matching and aligned. This rule applies to every card type, not just Panic.

## 3. Names, files, and CSV

The image filename must match the CSV Name exactly, including spelling and case. Use the correct image folder and CSV Type for the card type.

Use PNG. A JPEG named in the CSV will not load through the current .png path construction.

Keep one working image per card in its image folder. Do not leave “Name Original.png,” “Name Expanded.png,” or alternate working copies beside it.

For each new installed image, immediately add exactly one matching row to the card set's Data.csv, so it can be inspected in Alpha without waiting for the batch to finish.

Current CSV fields are Name,Type,Description,Flavor. Preserve existing rows and text. Leave Description and Flavor blank unless supplied or requested; concept sentences are not automatically flavor text.

When copying supplied flavor text, omit decorative enclosing quotation marks. CSV-required structural quoting is still necessary for commas or multiline content. Preserve internal text and line breaks.

## 4. Backups and rejected versions

Paths in this section are relative to the relevant artwork folder.

Before overwriting any artwork, copy the current file into its sibling Backups subfolder and verify the copy. For frames in Components, use Components/Backups. This later user instruction supersedes the earlier Resize backup locations below; retain existing archives where they are.

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


Style continuity is mandatory: use installed approved Bun and Dog images as direct generation inputs, not merely verbal inspiration. Match their facial anatomy, proportions, fur rendering, material detail, color richness, and polished dimensional finish. The rejected library Chase samples are not style references: do not reuse their flattened cartoon faces, character designs, or illustration treatment. A new scene must look like it belongs beside the existing cards.


Use established Bun designs directly. Preserve their reference body proportions, faces, clothing and clothing coverage when changing poses; do not impose longer torsos, shorter bodies, or another anatomy redesign. No exposed upper legs or skirts riding up. Crowds may include kid Buns but must not all look like children; no daycare-attack scenario. Match the existing adult Buns rather than inventing a new adult template.

Buns must remain visibly Buns throughout the body, including background figures. Match actual approved reference proportions directly, including legs, feet and boots. Do not invent human legs, oversized snowshoe-like feet, or chibi shortening as a correction. Boots are allowed. Use approved action artwork to judge foot size relative to the head and body rather than imposing verbal exaggerations.

Mix barefoot and booted Buns across action scenes. Bare rabbit paws may be larger than booted feet, as in the approved artwork; preserve that established distinction. Include some clearly visible barefoot Buns rather than putting everyone in boots. Match actual reference paws without human feet or exaggerated snowshoe shapes.

Bun body shape: No large, plump, or fat Buns. This applies to every card type. Match the approved existing Bun references for body build; preserve their short, stubby legs and big rabbit paws without widening or inflating their bodies. Do not compensate by making them skinny or human-proportioned. The plump bodies in Take My Goggles are rejected and must not be used as anatomy references.
