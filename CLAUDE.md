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
  (`HealthComponent`, `StaminaComponent`, `Hitbox`, `Hurtbox`, `SpriteAnimator`, camera shake). Player and enemies share them.
- **Game data is separated from logic** as `Resource` classes (`scripts/resources/`) with instances in `resources/`
  (`.tres`). Adding a monster or changing balance = new/edited `.tres`, no logic rewrite.
  - `Stats` (strength, agility, vitality) owns every derived formula (max health, damage, attack speed, ...).
    Other scripts must call its getters instead of re-implementing the math.
  - `MonsterData`: one monster type (stats, XP, behaviors, region, SpriteFrames + tint, ranges, timings, damage).
  - `RegionData`: name, tile tint, map color, monster list, mini-boss. `FloorData`: size, regions, boss.
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
  Verified: with `TILE_SIZE = 32` both test suites still pass. `TileAtlas.TILE_SIZE` is only the art sheet's tile size.
- Resolution: 480 x 270 base, `canvas_items` stretch with **integer** scale (pixel perfect; 1440x810 window = 3x).
- Physics layers are named in `project.godot`: 1 world, 2 player_body, 3 enemy_body, 4 player_hurtbox,
  5 enemy_hurtbox, 6 player_hitbox, 7 enemy_hitbox. A hitbox's mask lists the hurtbox layer it can damage.

## Dungeon floors
- `FloorGenerator` (pure code, seeded) -> `FloorLayout` (grid + halls + regions). 480 x 480 tiles cut into 6 x 6
  sectors, one big hall per sector (sizes in `FloorData`), near the sector center. Start on the map edge, boss arena
  in the farthest sector with exactly one entrance, portal at the far end of the arena; 3 regions grow by random
  flood fill (each contiguous). Corridors: random spanning tree + few extra links. Region "slots": 0 start,
  1..N regions, N+1 boss. `FloorPopulator` (seeded) then plans every monster/prop/torch as `FloorLayout.Spawn`
  data, grouped by 32 x 32 chunk; densities per 100 floor tiles live in `RegionData`.
- **Chunk streaming:** `ChunkManager` paints tiles and creates nodes only for chunks within 2 of the player's chunk,
  clears chunks farther than 3, max 1 chunk load per frame (~3 ms each). Killed monsters (by spawn id) stay dead;
  living monsters left in unloaded chunks go back to data and respawn at their spawn point. Tile variation uses a
  per-cell hash, not a sequential RNG, so load order doesn't matter.
- `FloorLevel` (scenes/floors/floor.tscn, the main scene) creates one tinted TileMapLayer per slot and the portal.
  `ExplorationMap` = fog of war + minimap texture (line-of-sight reveal). `EnemyActivator` pauses monsters farther
  than 30 tiles. Dying enemies leave the "enemy" group so they are never paused mid fade-out.
- Seed: static `FloorLevel.next_seed` survives reloads (R = same layout, F1 = new seed), or `-- --seed=<n>`.
- Debug keys: F1 new seed, F2 reveal map, F3 invincible, F4 show seed + copy to clipboard. M = big map.

## Art
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
`move_up/down/left/right` = WASD, `attack` = left mouse, `dodge` = Space, `restart` = R, `map` = M,
`debug_new_seed` F1, `debug_reveal_map` F2, `debug_invincible` F3, `debug_show_seed` F4.

## Running / checking
Godot is not in PATH. Executable: `D:\Godot\Godot_v4.7.2-stable_win64.exe`. Tools run inside the real game
(`DebugRunner` reads the args after `--`); a plain `--script` run does NOT load autoloads, so scripts using
`GameFeel` fail to compile there.

    <godot> --headless --path . --import                       # re-import, register classes
    <godot> --headless --path . --quit-after 300               # run the game briefly, catch script errors
    <godot> --headless --path . -- --smoke-test                # combat checks (test room), exit code 0 = pass
    <godot> --headless --path . -- --floor-test                # generator (40 seeds) + floor scene + debug keys
    <godot> --path . -- --screenshot=<png> --mode=<mode> [--seed=<n>]   # needs GPU, not headless
            # floor modes: idle, map, overview / test room modes: fight, dodge, room
    <godot> --headless --path . -- --build-room                # regenerate tileset + test room tiles

The user runs the game from the editor's embedded Game tab: if keys do nothing, the Game tab toolbar is
probably in 2D/3D selection mode instead of "Input".
