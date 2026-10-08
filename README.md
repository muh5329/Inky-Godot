# INKWAVE — Godot edition

A native Godot 4 conversion of [Jayden Davis's INKWAVE](https://github.com/jaydendavisnc/inkwave), based on upstream commit `98ea29694ab3eebaaeaa995c2b525ac883a48de5`.

**Status: playable native port, not verified one-to-one feature or visual parity.** The original stage geometry, props, character meshes, weapon catalogue, and tuning tables are included. Gameplay, rendering, UI, audio, and networking run in GDScript/Godot; no browser, Electron, JavaScript runtime, or network download is needed to play. See [PORTING.md](docs/PORTING.md) for the differences that still need work.

## Play

- Open `project.godot` in **Godot 4.7**, then press **F6** on `scenes/main.tscn` or **F5** to run the project.
- Or open the locally built **`builds/INKWAVE.app`** on this Mac. The app bundles its own Godot runtime and game pack.
- Start with **Play**, choose the stage, mode, difficulty, and match length, then select **Let's make waves**.
- **Loadout** offers all 12 main weapons, 15 subs, and 19 specials. **Locker** saves skin, outfit, tentacle style, headgear, eye color, and player name.

Controls: WASD move; mouse aim; left click fire; Shift swim/refill/climb; Space jump/pistol roll; right click or E sub; F special; Tab/M tactical map; 1–4 while viewing the map jump to an ally; 0 jump home; click a beacon to jump to it; Esc pause. Controller movement, aiming, triggers, face buttons, and menus are mapped as well.

Seven stages support offline play. Cargo Terminal preserves the original humans-only restriction and needs at least two Godot clients. All eight stages have their imported geometry and collision. Turf War, rotating Zone Control, and cooperative HULLBREAKER battles are selectable. Profiles/settings/XP are saved to Godot's `user://profile.json` (on macOS, `~/Library/Application Support/Godot/app_userdata/INKWAVE/profile.json`).

## Multiplayer

Host a room from **Multiplayer**, share your computer's address and UDP port (default **27840**), and have other **Godot editions** join before starting. Empty slots fill with bots except on Cargo Terminal. Hosting across the internet needs reachable UDP routing/port forwarding.

This uses native ENet with host-authoritative combat. **It does not connect to the browser game's Cloudflare relay, five-character room codes, or browser clients.** There is no public matchmaking service.

## Verify

Set `GODOT` to your executable if it differs from the local macOS installation:

```sh
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . --editor --import
"$GODOT" --headless --path . --script tests/gameplay_test.gd -- --smoke --seconds=0
python3 tools/test_port.py
"$GODOT" --headless --path . --script tests/assets_test.gd
```

Run a deterministic-speed bot match:

```sh
"$GODOT" --headless --fixed-fps 60 --path . -- --smoke --map=halyard --mode=zones --seconds=60
```

Run the real rendered game and capture its viewport:

```sh
"$GODOT" --path . -- --autostart --autoplay --capture=/tmp/inkwave.png --capture-at=8 --quit-after-capture
```

## Source and rebuilding

- `scripts/`: native game, actors, combat, stage/paint, zones, boss, UI, and synthesized sound.
- `shaders/`: native surface ink, water, clothing, and eyes.
- `data/`: serialized original stage collision/faces/navigation samples and content catalogue.
- `assets/models/`: exported original glTF models and baked animation clips. Godot generates some texture files when importing embedded images.
- `source_reference/`: the complete pinned original repository, ignored by Godot and the new repository.
- `tools/export_source.mjs`: repeatable offline asset/data conversion; handles instancing, canvas atlases, animation tracks, and Godot material metadata.

The reference source is needed only to regenerate assets:

```sh
./tools/rebuild_assets.sh
python3 tools/package_macos.py
```

The asset exporter needs Node plus its two locked dependencies. Rebuilding the original font files is optional and uses `tools/convert_fonts.py` with Python `fonttools` and `brotli`. The macOS packager exports a PCK and bundles the locally installed Godot executable, using ad-hoc signing for local use; it does not produce a notarized distribution.

## Credits

Original INKWAVE code and procedural art: **Jayden Davis**, MIT, 2026. Original license is retained in `LICENSE`. Rubik and Titan One are converted from the original bundled fonts; their SIL Open Font Licenses are in `assets/fonts/`. Godot is MIT-licensed; the built app includes its license information. INKWAVE is an independent game and is not affiliated with Nintendo.
# Inky-Godot
