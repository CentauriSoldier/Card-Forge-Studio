# Run Bun! — Prep artwork generation and editing protocol

## 1. References and scope

Read [the shared artwork rules](../../../GEN.md), [the Bun guide](../Bun/GEN.md), and the repository AI RULES.md before related work. Read [the Dog guide](../Dog/GEN.md) if a scene includes a Dog. Current user directions take precedence.

Use approved installed Bun images as direct visual references, including Katie.png and Eddie.png, and appropriate approved action scenes for body proportions. Inspect each reference first. Do not generate from a generic description of a cute steampunk rabbit alone.

This guide records the user's direction. It does not authorize code edits, invented mechanics, or production beyond the user's current request.

## 2. Role and planned count

Prep is the planned fourth action type in the Buns' Survival deck. The user approved working toward 15 Prep cards. Together with 30 Nice, 30 Nasty, and 15 Panic, that would make 90 Survival cards, with Nice : Nasty : Panic : Prep = 2 : 2 : 1 : 1.

Prep depicts Buns making preparations that give their owner an advantage should a Dog Chase, Startle, or otherwise threaten them. The contrast with Panic is advance preparation rather than an immediate reaction. Exact timing, persistence, numerical bonuses, and individual effects have not been specified; do not invent them or turn scene concepts into adopted mechanics.

## 3. Artwork themes

The user requested food stocking, shelters, defenses, and similar preparations. A couple of scenes should concern stocking weapons and checking sidearms. All equipment and weapons must belong to the Victorian steampunk world: brass, copper, wood, leather, and purposeful mechanical components; no modern tactical aesthetic.

Show preparation before trouble rather than active combat. Buns can be carefully stocking a pantry, securing a shelter, arranging supplies, reinforcing a door, testing an alarm, planning an escape route, or checking equipment. A Dog is not required in each scene.

The earlier suggestion of five supply, five shelter/route, and five defense/warning concepts was an organizing proposal, not a finalized roster. Preserve variety rather than rigidly following that split.

Two discussed initial concepts:

- Well Stocked: a Bun carefully fills a concealed weapons cabinet with brass-and-wood steampunk pistols, clockwork carbines, and ammunition.
- Just in Case: a Bun checks a compact brass sidearm at a workbench, with a leather holster and neatly arranged equipment nearby.

The user asked to build a couple of scenes after establishing the frame. Those scenes have not yet been generated or installed as of this guide's creation. Check the live CSV for name collisions before producing named assets.

## 4. Character, world, and geometry

Keep established adorable Bun faces, compact adult bodies, short rabbit legs, and natural paws. No fat/plump redesign, human bodies, chibi exaggeration, or oversized snowshoe feet. Hands and feet have four digits; hands have rounded fingernails rather than claws. Preserve clothing coverage and mix barefoot and booted Buns appropriately.

Vary fur, markings, ears, clothing, occupation, setting, lighting, and viewpoint. Preparations happen in the same richly colored Victorian steampunk world as the rest of Run Bun!, including homes, workshops, city shelters, storage rooms, rooftops, and other plausible locations. Avoid repeating the same workbench scene for every card.

All foreground and distant scenery must remain sharp and readable, without bokeh or motion blur. Standalone scenes have no baked-in card frame, title panel, type label, watermark, or unnecessary lettering.

Mechanical geometry must make sense: cabinet doors and shelter doors pivot on the correct hinge side; latches connect to actual jambs; braces support the structures they reinforce; supplies rest on real shelves; hands grip tools coherently. Verify perspective and attachment points before installation. Decorative gears are not a substitute for a functioning mechanism.

## 5. Approved Prep frame

The user approved the first Prep frame preview on 2026-11-23.

- Installed asset: ../Components/Frame Prep.png, 825 × 1125 PNG.
- Theme: a Bun's emergency supply locker, distinct from Sniff's ornate spy-and-gourmet frame.
- Palette: deep petrol-teal enamel, brushed copper, warm ivory writing panels, and oxblood leather straps.
- Top: carrot-shaped copper latch on a reinforced lid.
- Left of artwork: compact brass-and-wood sidearm rack and rolled map.
- Right at the same vertical height: latched supply tin, bandage roll, and cartridge holder.
- Bottom: reinforced burrow-door emblem beneath a copper shelter roof.
- Border: cabinet panels, hinges, leather buckles, engraved copper corners, and purposeful fasteners. Avoid repeated pawprint decoration and oversized objects covering artwork.
- Preserve the shared layout of name panel, artwork opening, type strip, and rules panel, and the required different side ornaments aligned vertically.

The generated original is archived at ../Components/Backups/Prep Frame Previews/Frame Prep Original 01.png and remains at its generated source location. The installed frame was scaled proportionally onto an 825 × 1125 transparent canvas; center alpha was checked as zero.

Measured transparent opening in this frame: the center column spans approximately Y 209–630; ordinary side edges are around X 75–750, with side decorations intruding locally. These are observations, not yet configured artwork bounds. Measure and confirm the actual frame before choosing the final crop rectangle and scene PNG dimensions. Do not copy Sniff's bounds blindly.

## 6. Integration status and production

No Prep artwork bounds have been added to active Draw.lua, no Prep scene rows have been installed, and Prep scene dimensions are not yet finalized. PREPNAME style integration has not been verified. The frame is installed as an asset; that does not establish that Prep cards can render in Studio.

The current authorization covered the frame and this guide. Obtain file-specific permission before necessary Draw.lua or Styles.ini edits; do not add renderable Prep rows with missing integration.

For authorized scene installation, use Images/Prep/<Name>.png and CSV Type Prep, with one exact matching row per image. Current CSV columns are Name,Type,Description,Flavor,Sex,Tags. Preserve all existing rows and fields. Leave descriptive/flavor fields blank unless supplied or requested. Back up changed files first, retain every generated revision, and verify PNG dimensions and CSV correspondence. Report file checks separately from in-Studio visual review.
