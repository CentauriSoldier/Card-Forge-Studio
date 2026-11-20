# Run Bun! — Bun artwork generation and editing protocol

This is the working guide for artwork in this Bun folder. It records the user's approved direction and corrections. Follow current user instructions first, then the repository's AI RULES.md. Do not treat this guide as permission to change application code.

## 1. Purpose and emotional character

These are adorable, happy, capable bunnies living in a Victorian steampunk world. Players should care about them and not want the dogs to eat them. Their charm is essential, not an optional embellishment.

The game's overall contrast is cute sweetness against nasty, sometimes gory danger: the user's shorthand is “Diablo meets Candy Crush.” Ordinary Bun artwork belongs on the appealing, sympathetic side. Do not add gore to a Bun scene without a specific request.

Buns are clever, sophisticated, kind, industrious, and sometimes mischievous. Humor should come from the activity or situation, not from making the bunny ugly.

## 2. Authoritative visual references

Inspect actual installed artwork before generating or editing. Use approved images directly as visual references; a text description of steampunk is not sufficient.

- Katie.png and Eddie.png were used together for the approved family style.
- Aisling.png is another established reference.
- The installed Orla.png is the approved correction, not either of the rejected Orla versions in Resize.
- Installed Ivo.png and Tamsin.png were expressly approved after their action and family-style corrections.

Match reference head-to-body proportions, torso and limb lengths, eye size relative to the face, muzzle structure, cheek shape, paws, fur rendering, and overall finish. Maintain the family resemblance: the buns should plausibly look related.

Do not substitute:
- Chibi, super-deformed, tiny-bodied, giant-headed characters.
- Long, thin, adult-human bodies with rabbit heads.
- Realistic hares, foxlike faces, or a different illustration style.
- Excessively broad, puffy cheeks or exaggerated facial redesigns.

“Make it cute” does not mean “make it chibi.” Follow the approved images instead of exaggerating proportions.

## 3. Individuality within the family

Vary fur colors and markings, ear colors or tips, natural eye colors, small facial details, and forehead tufts. Keep the underlying anatomy and family design consistent.

Tufts should vary naturally: a small part, short curl, gentle wave, uneven forelock, or flatter fur. Do not repeat the same swept white tuft on every bunny or turn every tuft into elaborate human hair.

Clothes, goggles, tools, and accessories should suit each occupation. Goggles can differ while remaining Victorian steampunk.

Most eye colors should be natural. Astrith's purple eyes were specifically requested because he is a wizard; that is not a general instruction for exotic eye colors.

For an existing bunny the user already likes, do not change its coloring, face, outfit, goggles, pose, or other features unless requested. General variety guidance does not override a narrow edit.

## 4. World, rendering, and scenery

Everything belongs to Victorian-era steampunk: clothing silhouettes, furnishings, architecture, tools, brass/copper apparatus, leather, carved wood, wrought iron, gas lamps, and practical mechanical details.

Use the established polished, richly colored, detailed illustrated finish. Preserve attractive color and lighting in edits.

All scenery must be readable and in focus. Avoid deliberate background blur, bokeh, shallow depth of field, or motion blur. Show action through posture and the scene rather than blurring it.

Build a meaningful setting around the occupation. Mechanical details should make visual sense; do not scatter arbitrary gears to stand in for design.

Artwork is a standalone scene. Do not bake in a card border, name panel, type bar, description panel, watermark, or unnecessary text. The separate frame supplies the card layout.

## 5. Bunnies in action and composition

Bunnies are doing their activities, not posing for a photograph.

Their gaze should follow their work, another character, or the action. Hands must actually use the tools. A chimney sweep should scrub the chimney, a painter should paint, and a musician should play.

Use a mixture of close views and medium/three-quarter compositions. The bunny must remain prominent and emotionally readable. Wider views are appropriate when needed to explain the action; do not make the character a tiny decoration in a large environment.

Maintain coherent anatomy:
- Exactly the required limbs, with believable joints and grips.
- Consistent short rounded fingernails on both hands; do not mix fingernails and claws.
- Properly supported feet, objects, and furniture.
- Plausible hand contact with tools and materials.

Maintain coherent perspective:
- Related edges converge consistently.
- Tools, shafts, handles, supports, wheels, drawers, and housings line up.
- Held objects do not float or pass through hands.
- Subject, activity, and setting share the same viewpoint.
- Direction of movement agrees with the surroundings.

Lucy example: preserve her approved bowling pose and camera angle. From this viewpoint only the foul line and a short beginning of the lane are visible at her planted foot in the foreground; the rest of the lane, released ball, and pins are outside the image. Show the approach/waiting area, other bowlers, and ball returns behind her. Do not force lanes or pins into a viewpoint from which they would not be visible. Reconstruct the environment around the actual camera position rather than merely aligning objects in screen space.

## 6. Dimensions and card integration

The full card/frame is 825 × 1125. That is NOT the aspect ratio of Bun artwork.

Current Bun opening:
- At the base card size: approximately X 44, Y 184, width 737, height 493.
- Artwork aspect ratio: 737:493, approximately 1.495:1, landscape.
- Installed artwork size: 1474 × 986 PNG, exactly twice the opening dimensions.

Request the landscape ratio during generation. If generated dimensions differ slightly, scale uniformly and trim only the small excess required to reach 1474 × 986. Never independently stretch width and height.

If the source is square, extend the scenery left and right. Do not squeeze the character or sacrifice substantial top/bottom content to force the image into the window. Inspect the extension for hard seams, repeated strips, inconsistent perspective, or mismatched lighting.

Do not paste a square original over a generated expansion without checking the joins: that caused a visible vertical seam in Percy. A continuous expanded scene was accepted instead.

Keep important details away from the rounded corners and decorative frame overlaps. Preserve useful headroom and action space where possible.

Current Alpha Draw.lua selects art and frame by Type, draws art with Forge.DrawImageCropped, then draws the frame over it. Its bounds table is inside the drawing function and uses _nCardWidth and _nCardHeight. Do not change Forge or drawing code to compensate for an artwork problem without explicit file-specific permission.

## 7. Names, files, and CSV

Use uncommon names for most new buns. Familiar names and fully fabricated names should each be occasional. This concerns name distribution, not a gameplay rarity field.

The image filename must match the CSV Name exactly, including spelling and case:
- Images/Bun/Name.png
- CSV Type: Bun

Use PNG. A JPEG named in the CSV will not load through the current .png path construction.

Keep one working image per character in this folder. Do not leave “Name Original.png,” “Name Expanded.png,” or alternate working copies beside it.

For each new installed image, immediately add exactly one matching row to the card set's Data.csv, so it can be inspected in Alpha without waiting for the batch to finish.

Current CSV fields are Name,Type,Description,Flavor. Preserve existing rows and text. Leave Description and Flavor blank unless supplied or requested; concept sentences are not automatically flavor text.

When copying supplied flavor text, omit decorative enclosing quotation marks. CSV-required structural quoting is still necessary for commas or multiline content. Preserve internal text and line breaks. Sneikhums's existing flavor must remain intact.

## 8. Backups and rejected versions

Before overwriting any artwork, copy the current file into Resize and verify the copy.

- Initial original: Resize/Name.png, using the original name.
- If that backup already exists, preserve it and put the next version in a clearly named subfolder, still named Name.png.
- Examples: Resize/Before Alley Fix/Lucy.png or Resize/Unused Revision 1/Elowen.png.

Preserve ALL generated revisions, including rejected or uninstalled versions. Store them under Resize in separate descriptive or numbered subfolders. Do not overwrite an earlier backup to save a later revision.

Verify backup content, preferably with a hash comparison. Preserve the generated source output too unless the user explicitly asks for deletion.

Back up Data.csv before the first batch addition, preserving an earlier backup if present. Never replace live CSV content with an older copy.

## 9. Editing discipline

Inspect the current image first. State the requested changes and invariants clearly in the edit prompt.

Change only the requested part. If the user approves the pose and camera angle, preserve both and rebuild the environment around them. If only an eye color, hook drip, cheek shape, or background focus needs changing, do not redesign the rest.

Do not promise pixel-for-pixel preservation from a generative edit without actually verifying it. Compare the result with the source, especially the user's favorite details.

Elowen lesson: an attempted pipe correction removed a liked spinner and green carrot leaves, causing further unwanted changes. The user chose the original generated version. Installed Elowen.png is that original by explicit request; preserve it rather than “fixing” it again unasked. The unused revisions are backed up.

If an edit damages approved details, return to the last approved source instead of repeatedly editing an already damaged revision. Retain every version.

## 10. Production and verification sequence

1. Read current user directions and applicable project rules.
2. Inspect the source image and approved style references.
3. Check the intended filename and current CSV row; avoid duplicates.
4. Back up anything to be overwritten and verify the backup.
5. Generate or edit one distinct artwork using the built-in image-generation tool, with direct visual references for the established family style.
6. Inspect the result: family resemblance, proportions, action, hands/nails, perspective, focus, scene logic, and requested invariants.
7. Keep rejected variants in Resize; do not silently discard them.
8. Save the selected PNG at 1474 × 986 with proportional scaling.
9. Install it under the exact character name.
10. Immediately add or verify its single Bun row in Data.csv.
11. Check image readability/dimensions and CSV consistency. Verify existing rows were preserved.
12. Report what is actually installed and checked. Distinguish file verification from an in-Studio visual check.

For an authorized batch, keep going through the entire approved list. The user explicitly requested no repeated approval questions during production. Follow later corrections immediately without abandoning unfinished authorized work.

Never claim an image is installed when it is only generated. Do not claim that in-card appearance was checked unless it actually was.

## 11. Approved 26-card concept roster

| Name | Occupation and scene |
| --- | --- |
| Orla | Stand-up comedian performing on a velvet stage, with a scratched empty chair nearby. |
| Ivo | Chimney sweep actively cleaning a chimney above a steampunk town. |
| Tamsin | Beekeeper working honeycomb frames in a flowering orchard. |
| Stellan | Lighthouse keeper polishing the reflector above a stormy sea. |
| Elowen | Glassblower shaping a glowing glass carrot in a colorful workshop. |
| Bram | Organist playing an elaborate pipe organ with mechanical birds. |
| Nerys | Advocate addressing a jury from a book-supported courtroom lectern. |
| Oswin | Balloon pilot navigating among floating market stalls. |
| Saskia | Sculptor carving a heroic marble bunny with extravagant ears. |
| Leif | Ferryman poling passengers through a reed-lined waterway. |
| Anouk | Perfumer testing a scent beside a copper flower distillery. |
| Torin | Miller filling a flour sack beneath the mill chute. |
| Zadie | Roller-skating server carrying desserts through a soda parlor. |
| Emrys | Moth breeder examining a moth in a conservatory. |
| Vesna | Puppeteer operating a wooden dragon that has stolen her sandwich. |
| Oona | Brass-helmeted diver exploring a sunken ballroom. |
| Alaric | Falconer offering food to a tiny unimpressed owl. |
| Isolde | Opera singer sustaining a note near cracking glassware. |
| Runa | Locksmith working an ornate vault lock. |
| Dorian | Portrait painter painting a snail on a velvet cushion. |
| Eira | Ice sculptor carving a swan in a frozen courtyard. |
| Florian | Funeral director guiding a small hearse through an overgrown cemetery. |
| Max | Bicycle courier delivering parcels through a rainy market. |
| Lucy | Bowler following through on a roll in a Victorian steampunk alley. |
| Quibnock | Inventor lifted toward the ceiling by an expanding mechanical umbrella. |
| Wumplett | Food critic scrutinizing a single pea at a grand banquet. |

These concepts establish each character's occupation. Do not rigidly reuse one pose, framing, tuft, or expression across the roster.
