# Conversion scope and remaining parity work

This project is a playable native implementation, not a claim that every line of the browser game has been translated or that its balance and appearance are identical. The original repository remains available under `source_reference/` for comparison.

## Carried over directly

- All eight arena layouts, box/ramp orientations, mode-specific pieces, prop placements and collision volumes.
- Procedural prop geometry and canvas sign atlases, converted to glTF. GPU instances are expanded because Godot's importer did not accept the source instancing extension.
- Twelve original weapon-equipped skinned characters; sampled idle/run/fire/victory animations. Eight tentacle styles with four headgear variations. Original wardrobe and eye palettes.
- HULLBREAKER and crablet meshes, plus sampled original boss movement/attack animations.
- Source content definitions, loadout names, descriptions, weapon/sub/special order, settings defaults, progression constants, map metadata, and zone polygons.
- The two original fonts, with their font licenses, and stage selection artwork from the source game.

## Implemented natively

CharacterBody3D movement, ink swimming/refill/climbing, jump, pistol dodge, collision and sea deaths; paintable floor/wall atlas and exposed-surface turf scoring; health, damage protection, recovery, splats and respawns; twelve distinct main weapon paths; deployable/projectile subs and special activation paths; bots with graph navigation; timed matches/results/XP; rotating zone captures, penalties and overtime; a boss with phases and six attack families; tactical map/ally and beacon jumps; menu/loadout/locker/settings/pause/results UI; local persistence; procedural audio; controller bindings; and ENet rooms with replicated input, actors, ink, projectiles and deployables.

## Differences and unfinished fidelity work

- **Networking is a replacement protocol.** No browser cross-play, Cloudflare room codes, source relay compatibility, host migration, emotes, ready-check/team-selection lobby, or source interpolation/lag compensation. Native room teams are assigned automatically. LAN was tested with two clients; internet routing and eight physical clients were not tested.
- **Weapon mechanics are adaptations.** Every catalogue entry has an implementation, but many specialist interactions need comparison with the original: exact charge rings, falloff, piercing, Brolly shield launch geometry, Shaker manual charging, Mitts wall cling, Zipline travel/return behavior, stamp directional blocking, crab armor exposure, and Cheer Orb teammate charging. This is not a balance-identical implementation.
- **Characters use baked animation.** They do not yet reproduce the original runtime IK, facial shader, spring rig, aim layers, gear-specific poses, or dynamic LOD. Outfit palettes/patterns are exposed, but the original clothing cuts/prints and eyebrow shapes are not all reproduced.
- **Rendering is native and approximate.** Props retain original models/textures. Stage surfaces use a smaller procedural material shader; the original generated material library, baked AO, custom lighting/grade, liquid displacement, wall drips, swimming wakes, cinematics, and much of the particle work remain to port. Ink dries visually, but does not use the original fluid shader.
- **Boss logic was rebuilt.** Six attack families and original sampled clips are included. Original detailed weak-point hit shapes, terrain-aware hazards, AI planning, minion animation, and full boss presentation are not equivalent yet. Basic boss state and effects replicate; complete minion/hazard presentation on guest clients still needs work.
- **Menus differ.** The title uses original stage artwork rather than the source's animated lobby. Full wardrobe preview, profile imports from browser saves, every source quality/accessibility setting, and complete Chinese UI are not finished. Original Chinese phrases are preserved in the data catalogue.
- **Audio is newly synthesized.** It is not a conversion of the complete original WebAudio sequencer, spatial effects recipes, optional songs, or boss score.

## Validation and its limits

The native test script verifies ownership replacement and non-farmable turf, wall queries, damage protection, splats/respawns, all weapon ink-use paths, all sub spawn paths, all special activation/refill paths, bounded projectiles, zone capture/rotation, boss damage, and results/progression. These are functional regression checks, not proof of source gameplay parity.

Seven offline maps have automated bot smoke tests. Additional 60-second simulations exercised splats/respawns and boss combat. Rendered screenshots were inspected to catch blank atlases, missing prop material colors, camera capture jumps, and UI contrast. A local host and guest were run as separate processes. Remaining source-parity items above require further implementation and comparative playtesting.

Final local check: Godot 4.7 stable, 67 gameplay assertions passed, 78 exported scenes loaded, seven offline smoke scenarios passed, and two Cargo Terminal clients had matching replicated coverage. The self-contained macOS app was also tested outside the project directory.
