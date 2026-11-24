# Run Bun! — Sniff artwork generation and editing protocol

## 1. References and scope

Read [the shared artwork rules](../../../GEN.md), [the Bun guide](../Bun/GEN.md), and [the Dog guide](../Dog/GEN.md), plus the repository AI RULES.md before related work. Current user directions take precedence. Inspect installed approved artwork and supply direct visual references to generation; text descriptions alone are insufficient.

This guide records the user's direction and completed production. It does not authorize application code changes or further edits on its own.

## 2. Gameplay and scene purpose

Sniff belongs to the Dog's Havoc action deck. Sniff reveals face-down Buns; it cannot catch them. Catching requires a Chase. Do not invent additional effects, numbers, or targeting rules from an illustration.

Dogs are scouting the city for the best-tasting, yummiest Buns while Buns go about everyday life. Dogs sneak, observe, sniff, or pretend to perform ordinary work. Buns remain oblivious and accept unconvincing disguises. The humor comes from the contrast between a plainly dangerous predator and unsuspecting Buns, not from making Buns ugly.

Show a readable cover activity and covert attention to the Bun. A hat alone does not establish sneaking. Avoid a Dog openly looming nose-to-nose with its target, attacking, chasing, or catching it. This is not Startle. A cover task may involve serving, cleaning, inspecting, commuting, collecting taxes, or attending an event; vary the activity and composition.

## 3. Dogs, Buns, and variety

- Dogs must remain evil, menacing demonic predators with powerful healthy muscle, recognizable canine heads and bodies, and exactly two eyes. Disguises must not turn them into harmless pets.
- No bulldogs, pug-like flat faces, blobular cheeks or shoulders, poodles, Chihuahuas, or toy-breed designs. No skinny/emaciated Dogs. Use strong normal-length muzzles and necks, compact believable torsos, and distinct shoulder anatomy. Do not stretch bodies to fit a scene.
- Vary Dog build, fur, markings, ears, eyes, horn shapes, and silhouette. Include hornless Dogs. No glowing fur. Do not reuse one wolfish face or black-and-tan design throughout the set.
- Exactly four Dog limbs, including those hidden by clothing or furniture. Raised forepaws replace front legs on the ground; they are not extra limbs. Trace every visible limb to its body before acceptance.
- Preserve established adorable Bun facial and body proportions, short rabbit legs, paws, four-digit hands, clothing coverage, and polished rendering. Mix appropriate barefoot and booted Buns. Avoid human bodies, chibi redesigns, fat Buns, and exaggerated hair.
- Vary Bun designs, occupations, setting, light, camera angle, number of characters, and cover activity. Full-color steampunk city scenes must be sharply focused throughout.

## 4. Disguises

Use varied costumes and ordinary activities rather than repeatedly hiding behind menus or newspapers. The user rejected fake moustaches. Other possibilities include fake Bun paws or feet, cheap-looking goggles, costume jewelry, work uniforms, and inconspicuous props. Do not repeat any single disguise gimmick excessively.

Only Collecting Taxes has costume rabbit ears in this set. Its final ears are tidy faux fur with muted pink interiors and a discreet headband, still recognizable as a costume without ragged patches or conspicuous rough stitching. Parcel Inspection's earlier fake ears were removed; do not restore them.

Rush-Hour Whiff uses mismatched goggles; A Fine Vintage uses gaudy jewelry; Something in the Air uses fake Bun-paw mittens; Table for Two uses rabbit slippers. Do not treat any one of these as a template for every future card.

## 5. Composition and correction lessons

The bakery's Bun, shop, pastries, and composition were approved; repeated corrections concerned its Dog. The final Window Shopping uses a compact seated Dog behind a pastry menu, with lower body hidden by the sill. The earlier oversized shoulder mound, stretched walking Dog, and extra limbs were rejected.

Café Stakeout was accepted after removing the extra ground-level forelegs. The user explicitly wanted that accepted image left alone, while requiring more evil-looking Dogs in later scenes.

Market Research's elongated and openly confronting versions were rejected. Its installed Dog uses an inspection stand and ledger as cover.

Room Service's original head protruded into the room while its body and trolley remained farther back. The installed correction keeps the nose within the corridor opening, clear of the nearer door edge, and trolley behind the threshold. Always check wall planes, hinges, occlusion, wheel support, and head/shoulder alignment. Never accept impossible depth merely because rendering looks attractive.

Preserve approved details during narrow edits, retain every revision, and compare the result with the actual source. Do not claim generative edits preserve every pixel.

## 6. Frame and installation

- Installed frame: ../Components/Frame Sniff.png, 825 × 1125 PNG with transparent artwork opening.
- Approved design: burgundy enamel, ivory panels and ornate gold/brass; nose at top, peeking eye over a menu on the left, spyglass on the right at the same vertical height, modest intrusion, city details, fork and spoon below, steaming baked bun at bottom, only two pawprints.
- The menu must protrude a little; neither menu nor spyglass should dominate the opening. No pressure regulator or horn ornaments.
- Active Draw.lua bounds at 825 × 1125: X 66, Y 204, width 695, height 458.
- Installed scene PNGs: 1390 × 916, twice the artwork bounds. Scale proportionally with only slight necessary cropping; never stretch width and height independently.
- Scene path: Images/Sniff/<Name>.png. CSV Type: Sniff. Exact spelling and case must match Name, including Café Stakeout's accent and Chef's Recommendation's apostrophe.
- Name style: SNIFFNAME in the project Styles.ini. Frame, artwork bounds, and name style are installed. Any future code/style edits require file-specific permission.
- Current CSV fields: Name,Type,Description,Flavor,Sex,Tags. Preserve all fields and existing content. The new Sniff rows were installed with the other fields blank.
- Special Delivery already names another card; this Sniff artwork was renamed Parcel Inspection with the user's approval. Check names against the entire CSV before installation.

## 7. Installed roster

1. Window Shopping
2. Café Stakeout
3. Market Research
4. Laundry Day
5. Room Service
6. Theatre Critic
7. Collecting Taxes
8. Parcel Inspection
9. Good Taste
10. Rush-Hour Whiff
11. A Fine Vintage
12. Something in the Air
13. Sweet Tooth
14. Table for Two
15. Chef's Recommendation

## 8. Preservation and verification

All 15 scene PNGs and their unique matching Sniff rows were installed. All 15 images decoded at 1390 × 916; CSV consistency and diff checks passed. In-Studio visual appearance has not been verified.

Original generated outputs remain under the Codex generated-images directory. Project archives are in Resize/Initial Previews, Resize/Second Three Previews, and Resize/Completion Sources. The completion archive includes earlier revisions; these are not all approved references. Frame revisions are in ../Components/Backups/Sniff Frame Previews 20261123. CSV backups are under the set's Backups directory, including Before Three Sniff Cards, Before Second Three Sniff, Before Sniff Completion, and Before Final Three Sniff folders.

Follow the shared backup and immediate matching-row workflow for authorized additions. Preserve working images and previous revisions; never replace the CSV with an older backup.
