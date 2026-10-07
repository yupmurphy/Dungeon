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
  (`HealthComponent`, `ExhaustionComponent`, `Hitbox`, `Hurtbox`, `SpriteAnimator`, camera shake). Player and enemies share them.
- **Game data is separated from logic** as `Resource` classes (`scripts/resources/`) with instances in `resources/`
  (`.tres`). Adding a monster or changing balance = new/edited `.tres`, no logic rewrite.
  - `Stats` (player): 7 main stats: Strength, Agility, Vitality, Magic, Intelligence, Perception, Luck (user
    decision). All start at 5 except Magic: 0 and locked until a story event (`magic_unlocked`; debug button).
    Magic: magic damage +4%/pt, mana 20 + 5/pt. Intelligence: passive, no combat effect (later: item appraisal,
    learning spells). General damage bonus = Strength, Agility, Magic, Perception (+1%/pt each). Strength keeps
    health and defense (poison resistance removed until poison exists). Vitality: -1%/pt exhaustion gain. Monsters use Strength, Agility, Intelligence (later: AI behavior),
    Perception. Only main stats are saved. Stats owns every derived formula (health, mana, damage, speeds...)
    as getters, with every number a constant at the top of stats.gd (balanced often). Monsters use the same class.
    Other scripts must call its getters instead of re-implementing the math.
  - `Combat` (scripts/core/combat.gd) resolves every hit the same way for player and monsters: miss roll (target
    Agility, max 80%), crit roll (attacker Perception, x1.5), damage x (1 + bonus) then x 100 / (100 + defense).
    Hitbox carries `attacker` stats, Hurtbox `defender` stats; `Combat.forced_rolls` makes tests deterministic.
    Perception also drives the player's light radius and the map reveal radius (ExplorationMap.reveal_radius,
    set by FloorLevel); monsters are only visible inside the player's sight radius.
  - `MonsterData`: one monster type (stats, XP, behaviors, region, SpriteFrames + tint, ranges, timings, damage).
    Optional species `base_health` / `base_defense` are stored here (-1 keeps the legacy defaults). Each Enemy
    calls `runtime_copy()`: independent Stats receive these runtime-only bases, then the same Strength
    contributions apply through Stats getters. Stats still saves only its main stats; player formulas are unchanged.
    `attack_damage` is base damage BEFORE Combat bonuses/crit/target defense (user decision).
    `EnemyChaseBehavior` and `EnemyMeleeBehavior` are child components: detection/chase and a direction-locked
    windup -> attack -> recovery cycle, with signals to Enemy. Empty `behaviors` preserves legacy chase/melee.
    Goblin: `goblin.tres`, 35 HP / base damage 12 / defense 0 / reward data 1; LPC paper doll with `head_goblin`.
    Feature-based spawns use `spawn_feature`, group size/spread/radius in MonsterData. Goblins form seeded
    groups of 2-4 in connected `goblin_camp` territory, respecting used/protected cells and the safe start.
    Bats/spiders remain in Galleries during the staged migration. Bestiary/first-kill XP/level cap/F5 come later.
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

## Dungeon floors
- **"Ecological" floor generator, being rebuilt in stages** (1 structure DONE, 2 Goblin Galleries caves with
  themed halls, 3 swamp = the model zone, 4 forest + desert, 5 spawners/territories/day-night + F7).
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
- **Terrain / ecology (stage 2 of the rebuild).** Every cell has a `Terrain.Type` (scripts/floors/terrain.gd: walkable,
  speed factor, blocks sight, map color, art tile). Each region has a `biome` and a `ZoneBuilder`
  (scripts/floors/zones/): `GalleriesBuilder` (cave chambers + winding tunnels, camp / mine / chieftain halls; mine has no luminous floor crystals),
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
  "Canopies" TileMapLayer inside World, so characters walk behind/in front of trees correctly. Galleries use original procedural `CaveArt` (source 3 rock, source 4 floor): complete eight-neighbor masks,
  opaque full-cell rock, directional top/side shading, a tall front face with a single lit brow, and stronger front contact shadows. Geometry,
  sight and collisions do not depend on this art. `FloorLayout` stores visual-only masonry marks on existing
  rock; only the built back wall of the chieftain hall is reinforced with Kenney masonry. Other zones and the
  test room retain their existing art; nature tiles go on an untinted "Nature" layer. A minority of ordinary
  cave chambers have a larger radius (tunable constants in GalleriesBuilder). `Prop` shows either a
  Kenney tile (`tile_index`) or a NatureArt prop (`art`, multi-tile footprint, optional light).
- `-- --terrain-map=<folder> --seeds=<first>:<n>` saves terrain pictures (headless) to eyeball generation.
- Generator rules are checked on 10 seeds by `--floor-test` (zones contiguous, hub sealed except gates, single
  arena entrance, everything reachable, zones blend, determinism, variety, speed).
- **Chunk streaming:** `ChunkManager` paints tiles and creates nodes only for chunks within 2 of the player's chunk,
  clears chunks farther than 3, max 1 chunk load per frame (~3 ms each). Killed monsters (by spawn id) stay dead;
  living monsters left in unloaded chunks go back to data and respawn at their spawn point. Tile variation uses a
  per-cell hash, not a sequential RNG, so load order doesn't matter. Every cell is drawn (deep rock and plain floor
  take a fast path without autotiling, ~6 ms per chunk).
- **Galleries atmosphere:** warm bracket-mounted `WallTorch` sprites use four cached original `WallArt` flame
  frames and subtle smooth light flicker. The plate stays inside rock; an orientation-aware raised bracket
  projects the body toward the adjacent room cell, with a small cast shadow and the light at the flame.
  The torch has no collider. Spawns use front and lateral rock faces beside walkable floor; rear/north mounts are excluded because the visible wall has no front attachment surface.
  Seeded wall details never change terrain, sight, protected cells or floor reservations. Torch spacing comes
  from FloorData; caps per chunk (2 torches, 4 non-light decorations) and decor spacing/chance are constants
  in FloorPopulator. `WallDecoration` has no collider/light/process; cracks, roots and sparse webs are natural,
  marks/bones appear only near goblin halls/camps. Mine keeps rails/carts; luminous crystals are removed.
- `FloorLevel` (scenes/floors/floor.tscn, the main scene) creates one tinted TileMapLayer per slot and the portal.
  `ExplorationMap` = fog of war + minimap texture (line-of-sight reveal). `EnemyActivator` pauses monsters farther
  than 30 tiles. Dying enemies leave the "enemy" group so they are never paused mid fade-out.
- Seed: static `FloorLevel.next_seed` survives reloads (R = same layout, F1 = new seed), or `-- --seed=<n>`.
- Debug keys: F1 new seed, F2 reveal map, F3 invincible, F4 show seed + copy to clipboard. M = big map.
- Character sheet (C, pauses the game: CharacterSheet in the HUD, process_mode ALWAYS): level + XP bar
  (`Progression` on the player), main stats with debug -, +, +10 buttons, derived values; hover = tooltip built by
  `StatTexts` (words from texts.csv, numbers from Stats). Player listens to `stats.changed` (max health follows).
- Exhaustion replaces stamina (user decision): 0..100, grows with sprint (Shift) and attacks, recovers after a
  pause; above 70 slower movement/attacks, at 100 no sprint and less damage until below 70. No dash/dodge.
- Perception thresholds: 10+ shows monster health bars, 20+ monster names colored by power vs the player
  (`EnemyInfo` on the GameFeel layer, `Combat.power_rating` = max health x one hit; ratios in enemy_info.gd).

## Human town (exterior stage)
- Fixed peaceful hub, independent from FloorGenerator: `scenes/town/town.tscn`. Dungeon remains the main scene.
- Launch `-- --town`, or open the town scene in the editor and use F6. `M` toggles a zoomed-out exterior overview.
- `TownData` (Resource) defines tile positions: modest hall, six stalls, blacksmith, bookshop, tavern, twenty homes and
  four empty central 9x7 parcels. Reserved plots are walkable, have no buildings/props and stay available for expansion.
- `TownBuildingData` gives each exterior a persistent ID, footprint, translation key, art variant and optional
  PackedScene interior. Exterior stage leaves interiors null. `TownBuilding` composes cached facade art,
  footprint collision, a `TownDoor` and an `ExteriorReturn` marker. Do not use separate Godot projects for interiors.
- Town clears `FloorLayout.active`; reused Player/Stats/Equipment/HUD are unchanged. World is y-sorted; doors
  are reachable from the square. E currently only explains that interiors are not available, no scene transition.
- Town now has hand-shaped crooked roads and clustered housing rather than a symmetric grid. The civic
  square/hall sit on a stepped terrace (`TERRACE_SHAPE`): full-cell ledge collisions prevent crossing edges,
  with wide south stairs and an east ramp as the two level connections. `TownLayout.elevation()` grades
  their rise; town records the player's current elevation for later gameplay. This is top-down 2D relief,
  not 3D gravity or free jumping. Both crossings are covered by actual physics sweeps in the smoke test.
- `TownPropData` and reusable `TownDecoration` compose benches, fountain, noticeboard, smith work area,
  tavern barrels, planters, sparse yard fences and trees. Pure walkability and scene collision share the
  same solid footprints. Garden placement avoids door paths, transitions and all four reserved parcels.
- `TownBuildingData.floors` counts ground floor plus upper floors (currently 1 or 2). Hall, tavern,
  house_03 and house_13 have ground + one upper floor. Facade height/texture cache depends on floor count;
  footprints, door cells, return markers and interior availability stay unchanged. Do not stretch roofs.
- Stairs use one cached composite stone flight with distinct treads/risers, staggered joints, side coping
  and paved landings. Side coping occupies blocking cells OUTSIDE the six-tile clear passage; geometry
  and physical sweeps verify both free traversal and blocked borders. `Ground/StairFlight` draws below actors.
- Yard fences merge adjacent legal cells into continuous vertical runs; posts have caps, shaded side faces,
  nails/grain, two thick rails and contact shadows. The same run footprint defines collision. Frontages and
  door paths remain open, with no fences/curbs inside the four expansion parcels.
- `TownArt` has taller facades, two shaded roof planes, eave/foundation shading and projected building
  shadows below world actors. It is original code-generated pixel art, nearest-scaled through GameScale;
  no external town assets.
- `--smoke-test` also verifies counts, IDs, connected walkability/door approaches, all four reserved plots,
  actual scene/collision, HUD and bounded setup time. `--screenshot=... --mode=town|town_overview` needs GPU.
- Later: a transition owner retains the same player/state and caches or background-loads small interior scenes.
  Do not implement merchants, NPC schedules or town/dungeon travel in the exterior stage.

## Art
- **Characters are LPC** (Liberated Pixel Cup, 64 x 64 frames, rows up/left/down/right; hurt = one row, the fall).
  `tools/lpc_import.gd` (`-- --lpc-import=D:/DungeonHunters/lpc-generator`, a clone of the Universal LPC generator
  kept OUTSIDE the project) copies the pieces listed in its ITEMS into `assets/lpc/` (same folder structure) and writes
  `assets/lpc/catalog.json` (item -> slot, layers with z order, sheet per animation per body type), `assets/CREDITS.csv`
  (license row per file) and `CREDITS.md` (authors, sources, and which pieces are free to use and how). Keep credits!
  `LpcCatalog` cuts sheets into SpriteFrames; `LpcCharacter` stacks one AnimatedSprite2D per layer and drives the
  same frame on all of them (idle, walk, slash, thrust; flinch = first frames of the LPC fall, death = the whole
  fall; layers without the animation hide). LPC has 4 directions only: diagonals use the side view.
- **Paper doll:** `EquipmentData` (resources/equipment/<id>.tres, made by the import tool, edits kept): `id` (unique,
  for future stats/drops/saves), display name, slot (hair, torso, legs, feet, helmet, weapon), `lpc_item`. The
  player's `Equipment` node holds body type + one piece per slot and emits `changed`; the player rebuilds its
  LpcCharacter. The weapon's art decides the attack (spear = thrust, others slash). Character sheet (C) has an
  Equipment column: live preview + one debug list per slot.
- Goblins use the existing LPC body/clothes/dagger plus the imported adult goblin head; per-item tint colors only
  their body. Other monsters still use Kenney sprites (no separate LPC monster packs downloaded yet).
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
- `resources/` data (`stats/`, `monsters/`, `regions/`, `floors/`, `sprites/` SpriteFrames, `tilesets/`, `shaders/`)
- `assets/` art pack
- `tools/` dev tools started through the `DebugRunner` autoload

## Input map
`move_up/down/left/right` = WASD, `attack` = left mouse, `sprint` = Shift, `restart` = R, `map` = M, `character_sheet` = C,
`debug_new_seed` F1, `debug_reveal_map` F2, `debug_invincible` F3, `debug_show_seed` F4.

## Running / checking
Godot is not in PATH. Executable: `D:\Godot\Godot_v4.7.2-stable_win64.exe`. Tools run inside the real game
(`DebugRunner` reads the args after `--`); a plain `--script` run does NOT load autoloads, so scripts using
`GameFeel` fail to compile there.

    <godot> --headless --path . --import                       # re-import, register classes
    <godot> --headless --path . --quit-after 300               # run the game briefly, catch script errors
    <godot> --headless --path . -- --smoke-test                # combat checks (test room), exit code 0 = pass
    <godot> --headless --path . -- --stats-test                # stat formulas with known values
    <godot> --headless --path . -- --floor-test                # cave art/collision checks + generator (8 seeds) + floor scene + streaming + debug keys
    <godot> --headless --path . -- --floor-test --seeds=100:25 --generator-only   # generator rules on more seeds
    <godot> --path . -- --screenshot=<png> --mode=<mode> [--seed=<n>]   # needs GPU, not headless
            # floor modes: idle, map, sheet (--hover=stat:2), overview, gate, arena, start, place, cave, atmosphere / test room: fight (--crit, --miss), room, goblin
            # atmosphere: --wall-side=south|north|east|west selects mount orientation
            # any mode: --perception=<n> sets the player's Perception first
    <godot> --headless --path . -- --build-room                # regenerate tileset + test room tiles

The user runs the game from the editor's embedded Game tab: if keys do nothing, the Game tab toolbar is
probably in 2D/3D selection mode instead of "Input".
