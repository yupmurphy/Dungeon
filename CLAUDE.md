# Dungeon Hunters

Indie PC game in **Godot 4.7 + GDScript**. Source of truth for design: `Dungeon Hunters - Game Design Document.docx`
(kept outside the repo). Repo: https://github.com/yupmurphy/Dungeon

## Game summary
- 2D pixel-art dungeon crawler, top-down camera, **real-time combat** (tactical pause comes later).
- 10 huge procedurally generated floors; cities as hubs; recruitable NPC hunters with personality and hidden stats.
- Races grow stats differently; bosses drop essences that grant abilities (one ability slot per character level).
- **Current scope: combat prototype only.** Everything else arrives in stages (see roadmap in the GDD).

## Working with the user
- The user is a beginner in game dev and works as a QA engineer. Talk to them in **Romanian**.
- Briefly explain what you did and why; finish every task with short **manual test steps**.
- Debug your own work before handing it over: run the smoke test and look at screenshots (see below).
- Code, comments, identifiers and file names are in **English**. In-game text shown to the player is Romanian.

## Conventions
- **Small, reusable scenes.** One scene = one job (`player`, `enemy`, `prop`, `wall_torch`, `hud`, `stat_bar`).
  Rooms/levels only compose them.
- **Components instead of duplicated code.** Shared behavior lives in `scripts/components/` as child nodes
  (`HealthComponent`, `StaminaComponent`, `Hitbox`, `Hurtbox`, `SpriteAnimator`, camera shake). Player and enemies share them.
- **Game data is separated from logic** as `Resource` classes (`scripts/resources/`) with instances in `resources/`
  (`.tres`). Adding a monster or changing balance = new/edited `.tres`, no logic rewrite.
  - `Stats` (strength, agility, vitality) owns every derived formula (max health, damage, attack speed, ...).
    Other scripts must call its getters instead of re-implementing the math.
  - `EnemyData` describes one monster type (stats, SpriteFrames, colors, ranges, timings, damage).
- **Juice goes through the `GameFeel` autoload** (hit-stop, shake, damage numbers, particles, ghosts). Gameplay code
  says what happened; GameFeel decides how it looks. Effects live on their own CanvasLayer, so darkness doesn't dim them.
- Static typing in GDScript (`var x: float`, typed function signatures). `snake_case` files/functions, `PascalCase` classes.
- Signals up, calls down: children emit signals, parents/owners connect and decide.
- Exported node references in hand-written `.tscn` need `node_paths=PackedStringArray("prop")` on the node header,
  otherwise they silently stay null.
- Physics layers are named in `project.godot`: 1 world, 2 player_body, 3 enemy_body, 4 player_hurtbox,
  5 enemy_hurtbox, 6 player_hitbox, 7 enemy_hitbox. A hitbox's mask lists the hurtbox layer it can damage.

## Art
- Pack: Kenney **Tiny Dungeon** (CC0) in `assets/`. Use `assets/Tilemap/tilemap_packed.png`: 12 x 11 tiles of 16 px,
  no spacing. Tile index = row * 12 + column; `TileAtlas` (scripts/levels/tile_atlas.gd) converts it.
- The pack has **one frame per character** (no animation sheets) and **no skulls or torches**. Characters use
  `AnimatedSprite2D` with `idle` / `run` / `attack` (same frame for now) + procedural motion in `SpriteAnimator`;
  real frames can be dropped into the SpriteFrames later. Torch = tile 29 (fire emblem on brick).
- Useful tiles: player 97, slime 108, bat 120, spider 122, sword 104, barrel 66, tombstone 65, chest 89,
  floor 48 (+49, 53, 42), wall face 40 (+28 grate), wall-top ledges 1-5, 13-17, 25-27 (logic in `tools/room_builder.gd`).
- AtlasTextures need `filter_clip = true` (Sprite2D: `region_filter_clip_enabled`), otherwise neighbor tiles bleed in
  when a sprite is scaled.

## Layout
- `scenes/` reusable scenes (`player/`, `enemies/`, `levels/`, `ui/`, `effects/`)
- `scripts/` GDScript (`autoload/`, `components/`, `resources/`, `player/`, `enemies/`, `levels/`, `ui/`, `effects/`)
- `resources/` data (`stats/`, `enemies/`, `sprites/` SpriteFrames, `tilesets/`, `shaders/`)
- `assets/` art pack
- `tools/` dev tools started through the `DebugRunner` autoload

## Input map
`move_up/down/left/right` = WASD, `attack` = left mouse, `dodge` = Space, `restart` = R.

## Running / checking
Godot is not in PATH. Executable: `D:\Godot\Godot_v4.7.2-stable_win64.exe`. Tools run inside the real game
(`DebugRunner` reads the args after `--`); a plain `--script` run does NOT load autoloads, so scripts using
`GameFeel` fail to compile there.

    <godot> --headless --path . --import                       # re-import, register classes
    <godot> --headless --path . --quit-after 300               # run the game briefly, catch script errors
    <godot> --headless --path . -- --smoke-test                # automated combat checks, exit code 0 = pass
    <godot> --path . -- --screenshot=<png> --mode=idle|fight|dodge|overview   # needs GPU, not headless
    <godot> --headless --path . -- --build-room                # regenerate tileset + room tiles (overwrites tile edits)
