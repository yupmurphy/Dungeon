# Dungeon Hunters

Indie PC game in **Godot 4.7 + GDScript**. Source of truth for design: `Dungeon Hunters - Game Design Document.docx`
(kept outside the repo). Repo: https://github.com/yupmurphy/Dungeon (remote URL includes the user name,
`https://yupmurphy@github.com/...`, so the stored Windows credential is found and push works non-interactively).

## Game summary
- 2D pixel-art dungeon crawler, top-down camera, **real-time combat** (tactical pause comes later).
- 10 huge procedurally generated floors; cities as hubs; recruitable NPC hunters with personality and hidden stats.
- Races grow stats differently; bosses drop essences that grant abilities (one ability slot per character level).
- **Current work: Floor 1**, in stages (1 map generator, 2 monsters, 3 bosses, 4 progression). Commit after each
  stage and stop so the user can test.

## Working with the user
- The user is a beginner in game dev and works as a QA engineer. Talk to them in **Romanian, without diacritics**.
- Briefly explain what you did and why; finish every task with short **manual test steps**.
- Debug your own work before handing it over: run the automated tests and look at screenshots (see below).
- Code, comments, identifiers and file names are in **English**. **All in-game text is English, ASCII only.**

## Conventions
- **Small, reusable scenes.** One scene = one job (`player`, `enemy`, `prop`, `wall_torch`, `portal`, `hud`).
  Rooms/levels only compose them.
- **Components instead of duplicated code.** Shared behavior lives in `scripts/components/` as child nodes
  (`HealthComponent`, `ExhaustionComponent`, `Hitbox`, `Hurtbox`, `SpriteAnimator`, `DashAttack`, camera shake). Player and enemies share them.
- **Game data is separated from logic** as `Resource` classes (`scripts/resources/`) with instances in `resources/`
  (`.tres`). Adding a monster or changing balance = new/edited `.tres`, no logic rewrite.
  - `Stats` (player): 6 main stats: Strength, Agility, Magic, Intelligence, Perception, Luck (user
    decision). All start at 5 except Magic: 0 and locked until a story event (`magic_unlocked`; debug button).
    Magic: magic damage +4%/pt, mana 20 + 5/pt. Intelligence: passive, no combat effect (later: item appraisal,
    learning spells). General damage bonus = Strength, Agility, Magic, Perception (+1%/pt each). Strength keeps
    health and defense (poison resistance removed until poison exists). Strength also: -1%/pt exhaustion gain. Monsters use Strength, Agility, Intelligence (later: AI behavior),
    Perception. Only main stats are saved. Stats owns every derived formula (health, mana, damage, speeds...)
    as getters, with every number a constant at the top of stats.gd (balanced often). Monsters use the same class.
    Other scripts must call its getters instead of re-implementing the math.
  - `Combat` (scripts/core/combat.gd) resolves every hit the same way for player and monsters: miss roll (target
    Agility, max 80%), crit roll (attacker Perception, x1.5), damage x (1 + bonus) then x 100 / (100 + defense).
    Hitbox carries `attacker` stats, Hurtbox `defender` stats; `Combat.forced_rolls` makes tests deterministic.
    Perception also drives the player's light radius and the map reveal radius (ExplorationMap.reveal_radius,
    set by FloorLevel); monsters are only visible inside the player's sight radius.
  - `MonsterData`: one monster type (stats, XP, behaviors, region, SpriteFrames + tint, ranges, timings, damage).
  - `RegionData`: name, tile tint, map color, monster list, mini-boss. `FloorData`: size, regions, boss.
- **Texts that the user edits** (stat explanations, "Miss") live in `localization/texts.csv` (Godot translation,
  column `en`, English ASCII; use `tr(&"KEY")`). More languages later = more columns.
- **Juice goes through the `GameFeel` autoload** (hit-stop, shake, damage numbers, particles, ghosts). Gameplay code
  says what happened; GameFeel decides how it looks. Effects live on their own CanvasLayer, so darkness doesn't dim them.
- Static typing in GDScript (`var x: float`, typed function signatures). `snake_case` files/functions, `PascalCase` classes.
- Signals up, calls down: children emit signals, parents/owners connect and decide.
- Exported node references in hand-written `.tscn` need `node_paths=PackedStringArray("prop")` on the node header,
  otherwise they silently stay null.
- Typed resource arrays in `.tres`: `Array[ExtResource("<script id>")]([ExtResource(...), ...])`, with the element
  class script listed as an ext_resource. Write `.tres` files with the Write tool (PowerShell mangles UTF-8).
- **Sizes go through `GameScale`** (scripts/core/game_scale.gd). Distances, speeds, radii and offsets in scripts and
  `.tres` are "reference pixels" (a 16 px tile world) and are converted with `GameScale.world()`; grid math uses
  `GameScale.TILE_SIZE`; sprites are fitted to a `visual_size` with `SpriteAnimator.fit_to()`. Never hardcode 16.
  `TILE_SIZE = 32` (world() doubles every number). `TileAtlas.TILE_SIZE` is only the 16 px art sheet's tile size;
  `FloorTiles.upscale()` enlarges 16 px tile atlases 2x (nearest) until 32 px tilesets replace them.
- Resolution: 640 x 360 base, `canvas_items` stretch with **integer** scale (1280x720 window = 2x, 1920x1080 = 3x).
  UI pages built in fixed coordinates (CharacterSheet) sit on a centered 480 x 270 page.
- Physics layers are named in `project.godot`: 1 world, 2 player_body, 3 enemy_body, 4 player_hurtbox,
  5 enemy_hurtbox, 6 player_hitbox, 7 enemy_hitbox. A hitbox's mask lists the hurtbox layer it can damage.

## Items data pipeline (user rules - never edit hundreds of item files by hand)
1. **One table defines every item:** `data/items/items.csv`, one row per item:
   - columns `id,name,slot,tier,role,set_id,sprite,source,special`;
   - `sprite` = LPC catalog item;
   - `special` = optional exact stat values, for special items only.
   `tools/items/item_generator.gd` (`-- --generate-items`, logic in `ItemPipeline`) writes one `EquipmentData` .tres
   per row into `resources/items/`. **Generated files are never edited by hand.** They carry a "GENERATED - DO NOT
   EDIT" header; to change an item, edit the table and regenerate. `-- --items-test` fails if a generated file
   differs from the table, is missing or is left over. Hair styles are looks, not items (`resources/equipment/`,
   `EquipmentData.LOOK_SLOTS`). New item = new row, never a hand-made .tres. Item ids never change once used
   (saves, drops).
2. **Stat values come from a tier rules table** (values per tier and role): tiers are letters F, D, C, B, A, S
   (`EquipmentData.TIER_NAMES`, `tier` = index). Tables in `data/items/` (explained for the user in its README.md,
   which the user edits alone, keep it current):
   - `stats.csv`: every stat, kind `bonus` (added to the wearer) / `item` (weight, price) / `weapon` (melee, splash,
     attack_range). Adding a stat = a row here + a column only where needed; rows may stop early (= 0).
   - `roles.csv`: role + group (armor / weapon / jewelry) + weapon properties.
   - `slot_rules.csv`: slot + group + scale + drawn.
   - `tier_rules.csv`: role x tier, one column per stat (0 = nothing).
   - `slot_bonuses.csv`: slot x tier, what the slot adds itself (boots speed, helmet sight/light...).
   Item value = tier rule x slot scale + slot bonus, then the item's `special` column (`stat=value;...`, exact) only
   for special items; the generator lists them. Rounded to 0.001, sorted by name, zeros left out. A role must
   match the slot's group; undrawn slots (gloves, amulet, ring) have no sprite.
   Slots: body, pants, boots, helmet, gloves, weapon, amulet, ring (+ hair = look); new slots go at the END of the
   `Slot` enum.
3. **Item bonuses are a flexible list of stat + value pairs**, not fixed fields. `stats.gd` adds the worn
   equipment's bonuses automatically: no per-item code.
4. **Sets are defined once** in their own table, with bonuses at 2, 4 and 6 pieces. Items only reference `set_id`.
5. **A validator checks all data:** unknown stats, unknown set ids, duplicate ids, missing sprites. Run it after
   every table change. The generator refuses a table with errors.
Status: rule 1 done (v0.1.15), rule 2 done (v0.1.17, detailed tables; 23 example items); rules 3-5 are being
built in stages.

## Dungeon floors
- **"Ecological" floor generator, being rebuilt in stages** (1 structure DONE, 2 Goblin Galleries caves with
  themed halls, 3 swamp = the model zone, 4 forest + desert, 5 spawners/territories/day-night + F7).
- **Floor 1 simplification (user spec, 3 stages: 1 shape, 2 structure = corner cave start + forest + portal at the
  opposite corner, swamp/desert out of floor 1 but kept in code, 3 checks).** Stage 1 DONE (v0.1.18): `FloorShape`
  (scripts/floors/floor_shape.gd) = organic capsule from one corner to the opposite (random diagonal), bent by slow
  noise, rough edge, wavy border along the map edge (cubed slow noise = a few big bays); width picked so land =
  random `FloorData.shape_coverage` (70-95%; the edge border caps it near 92%). Settings in FloorData "Shape" group.
  Outside = impassable border, never dug: patches of ROCK, `CHASM` (see-through) and `THICKET` (dense forest, full
  collision, some crowns), new Terrain types at the end of the enum. `FloorLayout.land` (mask), `shape_tips`,
  `shape_coverage`; `is_land_index()`. The boss arena is pulled inward until it fits inside the shape.
- `FloorGenerator` (pure code, seeded) -> `FloorLayout` (rock/floor grid + a zone slot per cell, no empty space).
  900 x 900 tiles (`FloorData.map_size`, the one setting for floor size; ~1.3-2 s to generate, a loading
  screen will hide it later - don't over-optimize). Zones are computed per 4x4 block (islands merged there),
  cells next to the hub ring / arena are fixed cell by cell (`_fix_strip`). The first CLOSED `RegionData` (Goblin Galleries) is the hub: a wobbly disc in the middle with the
  start at its center, sealed by a rock ring. The OPEN regions (Forest, Swamp, Desert) are angular sectors around
  it; order, sizes and rotation change with the seed, borders meander (noise) and are walkable (natural transitions).
  2-3 gates per open zone through the ring, spaced apart (`gates_per_zone`, `gate_spacing`). Boss arena = walled ellipse at the outer edge of a random open zone,
  one entrance facing the middle, portal at the far end. Map edge = rock band. Accessibility: tiny pockets filled,
  others joined to the start by the cheapest dug tunnel (never through the hub ring, arena walls or map edge).
  Slots: 0..N-1 = `FloorData.regions`, N = boss arena. Cells marked "protected" (gates, arena entrance) never get
  props. `FloorPopulator` (seeded) plans every monster/prop/torch as `FloorLayout.Spawn` data, grouped by 32 x 32
  chunk; densities per 100 floor tiles live in `RegionData`; torches only in closed zones.
- **Cave look of the Galleries (v0.1.4, taken from Notion AI's `notion-wip` branch, then given more volume).**
  `CaveArt` (scripts/art/cave_art.gd) draws natural rock and floor procedurally: one wall tile per open-neighbor mask
  x 3 variants (lit rim, top darkening inward, tall south face with ledges and cracks, west-lit side faces), floor
  tiles with contact shadows and rubble; `FloorTiles` sources CAVE_WALL_SOURCE / CAVE_FLOOR_SOURCE, used by
  `ChunkManager` for hub cells (the chieftain hall's back wall is masonry: `FloorLayout.mark_masonry`, Kenney bricks).
  Wall torches and `WallDecoration`s (`WallArt`: cracks, roots, webs; goblin marks and bones near goblin places) hang
  on rock facing the room (down, left or right; `Spawn.wall_direction`), capped per chunk. No glowing crystals (user
  decision). Look at it with `--mode=cave --zoom=1 --dark`.
- **Terrain / ecology (stage 2 of the rebuild).** Every cell has a `Terrain.Type` (scripts/floors/terrain.gd: walkable,
  speed factor, blocks sight, map color, art tile). Each region has a `biome` and a `ZoneBuilder`
  (scripts/floors/zones/): `GalleriesBuilder` (cave chambers + winding tunnels, camp / mine / chieftain halls),
  `ForestBuilder` (river with bridges and fords, dense woods vs clearings, old trees, spider nests with webs),
  `SwampBuilder` (lakes to puddles, deep vs shallow water, reeds, mud islands, dead trees, fog),
  `DesertBuilder` (dunes, big mesas, quicksand patches, oasis with palms, giant bones). Builder phases:
  plan -> paint (per cell; near borders the neighbor zone's builder may paint, so zones blend) -> shape ->
  accessibility (cheapest passage: trees 1 < deep water 2 < rock 3; each zone decides what a passage looks
  like) -> decorate (props; solid props must not cut a path). Notable places are `FloorLayout.features`
  (camp, mine, nests, bridges, oasis, bones... used by the elements map and future spawners).
  `FloorLayout.speed_factor_at()` slows player and monsters (shallow water, reeds, quicksand, webs).
- Art for nature is procedural placeholder pixel art (`NatureArt`: one tile atlas + prop textures), added to
  the floor TileSet as source 1 by `FloorTiles`; deep water collides, a TREE cell only with its trunk. Trees are
  big: a TREE cell is just the trunk spot (max one per 3x3 block); its 48x56 crown is source 2 on the y-sorted
  "Canopies" TileMapLayer inside World, so characters walk behind/in front of trees correctly. Rock and cave floor still use
  the Kenney tiles (tinted per zone); nature tiles go on an untinted "Nature" layer. `Prop` shows either a
  Kenney tile (`tile_index`) or a NatureArt prop (`art`, multi-tile footprint, optional light).
- `-- --terrain-map=<folder> --seeds=<first>:<n>` saves terrain pictures (headless) to eyeball generation.
- Generator rules are checked on 10 seeds by `--floor-test` (zones contiguous, hub sealed except gates, single
  arena entrance, everything reachable, zones blend, determinism, variety, speed).
- **Chunk streaming:** `ChunkManager` paints tiles and creates nodes only for chunks within 2 of the player's chunk,
  clears chunks farther than 3, max 1 chunk load per frame (~3 ms each). Killed monsters (by spawn id) stay dead;
  living monsters left in unloaded chunks go back to data and respawn at their spawn point. Tile variation uses a
  per-cell hash, not a sequential RNG, so load order doesn't matter. Every cell is drawn (deep rock and plain floor
  take a fast path without autotiling, ~6 ms per chunk).
- `FloorLevel` (scenes/floors/floor.tscn, the main scene) creates one tinted TileMapLayer per slot and the portal.
  `ExplorationMap` = fog of war + minimap texture (line-of-sight reveal). `EnemyActivator` pauses monsters farther
  than 30 tiles. Dying enemies leave the "enemy" group so they are never paused mid fade-out.
- Seed: static `FloorLevel.next_seed` survives reloads (R = same layout, F1 = new seed), or `-- --seed=<n>`.
- Debug keys: F1 new seed, F2 reveal map, F3 invincible, F4 show seed + copy to clipboard. M = big map.
- Character sheet (C, pauses the game: CharacterSheet in the HUD, process_mode ALWAYS): level + XP bar
  (`Progression` on the player), main stats with debug -, +, +10 buttons, derived values; hover = tooltip built by
  `StatTexts` (words from texts.csv, numbers from Stats). Player listens to `stats.changed` (max health follows).
- Exhaustion replaces stamina (user decision): 0..100, grows with sprint (Shift) and attacks, recovers after a
  pause; above 70 slower movement/attacks, at 100 no sprint and less damage until below 70.
- Dash (v0.1.9+ rework, user spec in 4 stages: 1 tap, 2 charge, 3 air visuals, 4 goblins). Player (constants at
  the top of player.gd): tap Space (< 0.2 s) = short dash where the character faces (walking direction, else the
  mouse), +8 exhaustion, 0.6 s cooldown; attack during it = a normal attack. Hold Space = charge 0.2 -> 1 s
  (stands still, crouches, ChargeBar above the head, +30 exhaustion/s until full, then no more); release = long dash
  1.5x-3x, no damage; attack while holding = dash attack at once (thrust, hits all on the way, 1.2x-2x damage);
  exhaustion hitting 100 while charging launches the long dash. Agility: x(1 + 0.05/point) dash distance and dash
  attack damage (`Stats.get_dash_power_multiplier`). Player dashes are x0.8 (`DASH_DISTANCE_FACTOR`, user asked -20%).
  `DashAttack` component (scripts/components/dash_attack.gd), the
  same for player and monsters: passes through bodies (not walls), `try_dash(dir, distance_scale, ignore_exhaustion)`,
  `try_strike(damage, knockback, multiplier)` (default +30%), no invulnerability by default (flag),
  optional wind-up lean (monsters warn before dashing). Defaults are constants; monsters override the exports.
  Visuals (user: no color change on the dasher, no blue ghosts): `AirFlow` (scripts/effects/air_flow.gd, on the
  GameFeel layer) = wind streaks + dust; GATHER while charging / during a wind-up, TRAIL while dashing, intensity
  grows with the charge / dash distance. Dash attack = thrust held on frame 4 (`LpcCharacter.play(.., hold_frame)`,
  `release()` when the dash ends); the long dash uses the walk animation (legs capped at 2x).
  Monsters: `MonsterData` "Dash attack" group (`dash_attack_chance`, `_hurt` below `hurt_health_ratio`, `dash_range`,
  wind-up 0.4 s lean, speed/time/cooldown/knockback, `dash_stop_distance`, `dash_flee_range`). No charging: lean,
  short dash that stops `dash_stop_distance` before the target, THEN the strike (+30%, dash knockback). Rolled once
  per attack. Young goblin: 0.28 (1 in 3-4), hurt 0.4 (1 in 2-3); the direction locks at the lean, so stepping aside
  dodges it; a hit during the lean cancels it. Grown Goblin = the heavy one (stands in for the Brute, which does not
  exist): slower dash (200 x 0.28), knockback x1.7. Archer: `dash_flee_range` 40 = dashes away (no lean, no strike,
  picks a direction without a wall), cooldown 3 s.
- Monster awareness and movement (user): an idle monster notices the player only in `detect_range` AND in line of
  sight (`Enemy._sees`: physics ray + `FloorLayout.sight_clear` over blocks_sight cells: rock, trees, reeds); a hit
  also wakes it. Once chasing it follows the player around walls: straight when `_walk_clear` (2 rays a body wide),
  else A* waypoints from `FloorPaths` (AStarGrid2D window of 81x81 cells around the player, rebuilt when the player
  moves 16 cells; none without FloorLayout.active = straight). Melee attacks need a clear line too.
  `CornerSlide.apply(body, wanted, delta)` after move_and_slide (player + monsters): walking head-on into a wall,
  tree or prop slips sideways toward a free edge within 14 ref px; other characters are not slipped around.
- Perception thresholds: 10+ shows monster health bars, 20+ monster names colored by power vs the player
  (`EnemyInfo` on the GameFeel layer, `Combat.power_rating` = max health x one hit; ratios in enemy_info.gd).

## Town (human hub)
- Static, hand-edited scene `scenes/town/town.tscn` (user decision: towns are built by hand, not generated). Guide for
  editing it: `README.md`. `tools/town_builder.gd` (`-- --build-town --force`) laid out the first version ONCE; never
  rerun it (it overwrites hand edits). Run the town with F6 on the scene; N toggles night (`toggle_night`).
- Layers: Grass, Water, Roads (dirt + soil), Paving (cobbles) = `TownTiles` TileSet (`resources/tilesets/town_tileset.tres`,
  LPC terrain sheets, corner terrains so roads can be painted in the editor). y-sorted `World`: Walls, Buildings,
  Props, Trees, Player. Every LPC door faces south, so every building fronts a street (checked by `--town-test`).
- Nodes, all `@tool` (live preview in the editor): `TownBuilding` (walls, roof, door, windows, chimney, sign, banners
  from LPC pieces; footprint = width x roof_height tiles above its bottom-left corner), `TownWall`, `TownFence`,
  `TownProp` (any `TownArt.PROPS` entry: sprite rect, footprint, frames, light), `WantedBoard` (`WantedPoster` .tres).
  Landmarks are scenes in `scenes/town/buildings/`; drag-in parts in `scenes/town/parts/`.
- `TownArt` is the single list of sheet rectangles for town art (`assets/town/`, LPC packs + LPC Base Assets).
  `TownLighting` (CanvasModulate) fades day / night and switches every "town_lights" node (`lit`) and the player torch.
  `TownSmoke` = chimney / forge particles; `town_water.gdshader` = glints on the stream.
- Map: minimap + big map (M) read any `MapSource` (group "map_source"): `ExplorationMap` on floors (fog of war),
  `TownMap` in town (drawn once at start from the scene: ground layers, walls, buildings in roof colors, landmarks
  with their own color + legend, so hand edits show up on the map).

## Art
- **Characters are LPC** (Liberated Pixel Cup, 64 x 64 frames, rows up/left/down/right; hurt = one row, the fall).
  `tools/lpc_import.gd` (`-- --lpc-import=D:/DungeonHunters/lpc-generator`, a clone of the Universal LPC generator
  kept OUTSIDE the project) copies the pieces listed in its ITEMS into `assets/lpc/` (same folder structure) and writes
  `assets/lpc/catalog.json` (item -> slot, layers with z order, sheet per animation per body type), `assets/CREDITS.csv`
  (license row per file) and `CREDITS.md` (authors, sources, and which pieces are free to use and how). Keep credits!
  `LpcCatalog` cuts sheets into SpriteFrames; `LpcCharacter` stacks one AnimatedSprite2D per layer and drives the
  same frame on all of them (idle, walk, slash, thrust; flinch = first frames of the LPC fall, death = the whole
  fall; layers without the animation hide). LPC has 4 directions only: diagonals use the side view.
- **Paper doll:** `EquipmentData` (items: generated in resources/items/ from the items table, see "Items data
  pipeline"; hair looks: resources/equipment/, made by the import tool): `id` (unique, for stats/drops/saves), display name, slot (hair, torso, legs, feet, helmet, weapon), `lpc_item`. The
  player's `Equipment` node holds body type + one piece per slot and emits `changed`; the player rebuilds its
  LpcCharacter. The weapon's art decides the attack (spear = thrust, others slash). Character sheet (C) has an
  Equipment column: live preview + one debug list per slot.
- Monsters: bat, slime, spider still use Kenney sprites. The goblin is a young LPC goblin (child body + child head
  with long ears, green, child clothes) baked once by `tools/goblin_baker.gd` (`-- --bake-goblin=<clone>`) into
  `assets/monsters/goblin/young_goblin.png`; `MonsterData.sprite_sheet` + `MonsterSheet` cut such sheets into
  idle_/run_/attack_<down|left|up|right> + death (real size, no scaling); `SpriteAnimator` then faces 4 ways and the
  swing plays during the wind-up. `MonsterData.max_health` (0 = from Stats), `group_size`, `home_feature` +
  `groups_per_home` (FloorPopulator spawns groups, goblins also around the goblin camp). User decision (v0.1.3):
  Galleries = ONLY young goblins with a knife (`goblin.tres`); Forest = "Goblin Archer" (`goblin_archer.tres`, young
  goblin with a bow, baked too) led by the "Grown Goblin" ([LPC] Goblin adult sheet + its sword, `goblin_grown.tres`, its sheet rows go down, right, up, left = `sheet_direction_rows`,
  `group_leader`). LPC weapons are adult-sized: the baker moves each weapon frame toward the feet (`_fit`); the child
  body has no bow animation, so the archer stands and only its front arm (cut from the adult shoot frames) and the
  bow move. Ranged monsters: `MonsterData.projectile_texture` (+ speed, range, homing turn rate, `keep_distance`,
  `aim_lock_time`): the wind-up draws the bow (no aim line, no red tint: user decision v0.1.5), needs a clear line of fire (ray on the world layer), then a
  `Projectile` (a moving Hitbox, scripts/enemies/projectile.gd) flies; they back away while reloading.
- Pack: Kenney **Tiny Dungeon** (CC0) in `assets/`. Use `assets/Tilemap/tilemap_packed.png`: 12 x 11 tiles of 16 px,
  no spacing. Tile index = row * 12 + column; `TileAtlas` (scripts/levels/tile_atlas.gd) converts it.
- The pack has **one frame per character** (no animation sheets) and **no skulls or torches**. Characters use
  `AnimatedSprite2D` with `idle` / `run` / `attack` (same frame for now) + procedural motion in `SpriteAnimator`;
  real frames can be dropped into the SpriteFrames later. Torch = tile 29 (fire emblem on brick).
- Useful tiles: player 97, slime 108, bat 120, spider 122, sword 104, barrel 66, tombstone 65, chest 89,
  floor 48 (+49, 53, 42), wall face 40 (+28 grate), wall-top ledges 1-5, 13-17, 25-27 (logic in `WallTiler`).
- AtlasTextures need `filter_clip = true` (Sprite2D: `region_filter_clip_enabled`), otherwise neighbor tiles bleed in
  when a sprite is scaled.

## Layout
- `scenes/` reusable scenes (`player/`, `enemies/`, `levels/`, `floors/`, `ui/`, `effects/`)
- `scripts/` GDScript (`autoload/`, `components/`, `resources/`, `player/`, `enemies/`, `levels/`, `floors/`, `ui/`, `effects/`)
- `data/` source tables for generated data (`items/items.csv`; importer "skip")
- `resources/` data (`stats/`, `monsters/`, `items/` (generated), `equipment/` (hair), `regions/`, `floors/`, `sprites/` SpriteFrames, `tilesets/`, `shaders/`)
- `assets/` art pack
- `tools/` dev tools started through the `DebugRunner` autoload

## Input map
`move_up/down/left/right` = WASD, `attack` = left mouse, `sprint` = Shift, `dash` = Space, `restart` = R, `map` = M, `character_sheet` = C,
`debug_new_seed` F1, `debug_reveal_map` F2, `debug_invincible` F3, `debug_show_seed` F4, `toggle_night` = N (town).

## Running / checking
Godot is not in PATH. Executable: `D:\Godot\Godot_v4.7.2-stable_win64.exe`. Tools run inside the real game
(`DebugRunner` reads the args after `--`); a plain `--script` run does NOT load autoloads, so scripts using
`GameFeel` fail to compile there.

    <godot> --headless --path . --import                       # re-import, register classes
    <godot> --headless --path . --quit-after 300               # run the game briefly, catch script errors
    <godot> --headless --path . -- --smoke-test                # combat checks (test room), exit code 0 = pass
    <godot> --headless --path . -- --stats-test                # stat formulas with known values
    <godot> --headless --path . -- --floor-test                # generator (8 seeds) + floor scene + streaming + debug keys
    <godot> --headless --path . -- --floor-test --seeds=100:25 --generator-only   # generator rules on more seeds
    <godot> --path . -- --screenshot=<png> --mode=<mode> [--seed=<n>]   # needs GPU, not headless
            # floor modes: idle, map, sheet (--hover=stat:2), overview, gate, arena, start, place / test room: fight (--crit, --miss), room
            # any mode: --perception=<n> sets the player's Perception first
    <godot> --headless --path . -- --build-room                # regenerate tileset + test room tiles
    <godot> --headless --path . -- --town-test                 # town scene checks (doors, overlaps, gates, walls, night)
    <godot> --headless --path . -- --generate-items            # items table -> resources/items/*.tres (after every table edit)
            # or double-click tools/generate_items.bat; in PowerShell put & before the quoted godot path
    <godot> --headless --path . -- --items-test                # generated items match the table
    <godot> --path . -- --screenshot=<png> --mode=town --at=<x>,<y> --zoom=<z> [--night] [--no-limits]

The user runs the game from the editor's embedded Game tab: if keys do nothing, the Game tab toolbar is
probably in 2D/3D selection mode instead of "Input".
