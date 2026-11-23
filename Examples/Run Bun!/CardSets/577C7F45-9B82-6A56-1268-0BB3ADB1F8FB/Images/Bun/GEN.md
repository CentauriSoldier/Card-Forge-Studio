# Run Bun! — Bun artwork generation and editing protocol

This is the working guide for artwork in this Bun folder. It records the user's approved direction and corrections. Follow current user instructions first, then the repository's AI RULES.md. Do not treat this guide as permission to change application code.

Read [the shared card artwork rules](../../../GEN.md) first. They apply alongside the Bun-specific rules below.

## 1. Purpose and emotional character

These are adorable, happy, capable bunnies living in a Victorian steampunk world. Players should care about them and not want the dogs to eat them. Their charm is essential, not an optional embellishment.

The game's overall contrast is cute sweetness against nasty, sometimes gory danger: the user's shorthand is “Diablo meets Candy Crush.” Ordinary Bun artwork belongs on the appealing, sympathetic side. Do not add gore to a Bun scene without a specific request.

Buns are clever, sophisticated, kind, industrious, and sometimes mischievous. Humor should come from the activity or situation, not from making the bunny ugly.

## 2. Authoritative visual references

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

Each new or redesigned bunny must have an individual fur design and distinctive outfit while retaining the shared family resemblance, as though all the bunnies have common ancestry. Do not repeat the same fur-and-outfit combination across characters.

Tufts should vary naturally: a small part, short curl, gentle wave, uneven forelock, or flatter fur. Do not repeat the same swept white tuft on every bunny or turn every tuft into elaborate human hair.

Clothes, goggles, tools, and accessories should suit each occupation. Goggles can differ while remaining Victorian steampunk.

Most eye colors should be natural. Astrith's purple eyes were specifically requested because he is a wizard; that is not a general instruction for exotic eye colors.

For an existing bunny the user already likes, do not change its coloring, face, outfit, goggles, pose, or other features unless requested. General variety guidance does not override a narrow edit.

## 4. Bunnies in action and composition

Bunnies are doing their activities, not posing for a photograph.

Their gaze should follow their work, another character, or the action. Hands must actually use the tools. A chimney sweep should scrub the chimney, a painter should paint, and a musician should play.

Use a mixture of close views and medium/three-quarter compositions. The bunny must remain prominent and emotionally readable. Wider views are appropriate when needed to explain the action; do not make the character a tiny decoration in a large environment.

Bun-specific anatomy:
- Buns have fingernails, not claws. Use consistent short rounded fingernails on both hands; never pointed claws.
- Each hand has exactly four digits: three fingers and one thumb. Each foot has exactly four digits.

Lucy example: preserve her approved bowling pose and camera angle. From this viewpoint only the foul line and a short beginning of the lane are visible at her planted foot in the foreground; the rest of the lane, released ball, and pins are outside the image. Show the approach/waiting area, other bowlers, and ball returns behind her. Do not force lanes or pins into a viewpoint from which they would not be visible. Reconstruct the environment around the actual camera position rather than merely aligning objects in screen space.

## 5. Dimensions and card integration

The full card/frame is 825 × 1125. That is NOT the aspect ratio of Bun artwork.

Current Bun opening:
- At the base card size: approximately X 44, Y 184, width 737, height 493.
- Artwork aspect ratio: 737:493, approximately 1.495:1, landscape.
- Installed artwork size: 1474 × 986 PNG, exactly twice the opening dimensions.

Redesign old prototypes for this current landscape opening and install them at 1474 × 986, rather than retaining their old dimensions or composition at the expense of the character and activity.

Request the landscape ratio during generation. If generated dimensions differ slightly, scale uniformly and trim only the small excess required to reach 1474 × 986. Never independently stretch width and height.

If the source is square, extend the scenery left and right. Do not squeeze the character or sacrifice substantial top/bottom content to force the image into the window. Inspect the extension for hard seams, repeated strips, inconsistent perspective, or mismatched lighting.

Do not paste a square original over a generated expansion without checking the joins: that caused a visible vertical seam in Percy. A continuous expanded scene was accepted instead.

Current Alpha Draw.lua selects art and frame by Type, draws art with Forge.DrawImageCropped, then draws the frame over it. Its bounds table is inside the drawing function and uses _nCardWidth and _nCardHeight. Do not change Forge or drawing code to compensate for an artwork problem without explicit file-specific permission.

## 6. Names, files, and CSV

Use uncommon names for most new buns. Familiar names and fully fabricated names should each be occasional. This concerns name distribution, not a gameplay rarity field.

The image filename must match the CSV Name exactly, including spelling and case:
- Images/Bun/Name.png
- CSV Type: Bun

## 7. Bun-specific preservation notes

Backup examples under this Bun folder: Resize/Before Alley Fix/Lucy.png or Resize/Unused Revision 1/Elowen.png.

Sneikhums's existing flavor must remain intact.

Elowen lesson: an attempted pipe correction removed a liked spinner and green carrot leaves, causing further unwanted changes. The user chose the original generated version. Installed Elowen.png is that original by explicit request; preserve it rather than “fixing” it again unasked. The unused revisions are backed up.

## 8. Bun production checks

Use the shared production sequence. For Buns, check family resemblance, proportions, hands and fingernails, and the Bun-specific anatomy rules. Save at 1474 × 986 with proportional scaling, install under the exact character name, and add or verify its single Bun row in Data.csv.

## 9. Approved 26-card concept roster

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


Use established Bun designs directly. Preserve their reference body proportions, faces, clothing and clothing coverage when changing poses; do not impose longer torsos, shorter bodies, or another anatomy redesign. No exposed upper legs or skirts riding up. Crowds may include kid Buns but must not all look like children; no daycare-attack scenario. Match the existing adult Buns rather than inventing a new adult template.

Buns must remain visibly Buns throughout the body, including background figures. Match actual approved reference proportions directly, including legs, feet and boots. Do not invent human legs, oversized snowshoe-like feet, or chibi shortening as a correction. Boots are allowed. Use approved action artwork to judge foot size relative to the head and body rather than imposing verbal exaggerations.

Mix barefoot and booted Buns across action scenes. Bare rabbit paws may be larger than booted feet, as in the approved artwork; preserve that established distinction. Include some clearly visible barefoot Buns rather than putting everyone in boots. Match actual reference paws without human feet or exaggerated snowshoe shapes.
