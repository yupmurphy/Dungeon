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
- Code, comments, identifiers and file names are in **English**. In-game text shown to the player is Romanian.

## Conventions
- **Small, reusable scenes.** One scene = one job (`player`, `enemy`, `wall`, `hud`, `stat_bar`). Rooms/levels only compose them.
- **Components instead of duplicated code.** Shared behavior lives in `scripts/components/` as child nodes
  (`HealthComponent`, `StaminaComponent`, `Hitbox`, `Hurtbox`). Player and enemies use the same ones.
- **Game data is separated from logic** as `Resource` classes (`scripts/resources/`) with instances in `resources/`
  (`.tres`). Adding a monster or changing balance = new/edited `.tres`, no logic rewrite.
  - `Stats` (strength, agility, vitality) owns every derived formula (max health, damage, attack speed, ...).
    Other scripts must call its getters instead of re-implementing the math.
  - `EnemyData` describes one monster type (stats, colors, ranges, timings, damage).
- **Placeholder graphics:** only `ColorRect` / `Polygon2D` shapes, so sprites can replace them later without touching logic.
- Static typing in GDScript (`var x: float`, typed function signatures). `snake_case` files/functions, `PascalCase` classes.
- Signals up, calls down: children emit signals, parents/owners connect and decide.
- Physics layers are named in `project.godot`: 1 world, 2 player_body, 3 enemy_body, 4 player_hurtbox,
  5 enemy_hurtbox, 6 player_hitbox, 7 enemy_hitbox. A hitbox's mask lists the hurtbox layer it can damage.

## Layout
- `scenes/` reusable scenes (`player/`, `enemies/`, `levels/`, `ui/`)
- `scripts/` GDScript (`components/`, `resources/`, `player/`, `enemies/`, `levels/`, `ui/`)
- `resources/` `.tres` data files (`stats/`, `enemies/`)
- `assets/` future art, audio, fonts

## Input map
`move_up/down/left/right` = WASD, `attack` = left mouse, `dodge` = Space, `restart` = R.

## Running / checking
Godot is not in PATH on the user's machine. Headless script check (replace the path):

    <godot.exe> --headless --path . --import
    <godot.exe> --headless --path . --quit-after 120
