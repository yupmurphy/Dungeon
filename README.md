# Dungeon Hunters

Indie 2D dungeon crawler in Godot 4.7 (GDScript). Design notes for contributors and AI helpers: `CLAUDE.md`.
Art credits: `CREDITS.md` and `assets/CREDITS.csv`.

## Editing the town by hand

The human town is one Godot scene: `scenes/town/town.tscn`. Open it in the editor and press **F6** (Run Current
Scene) to walk around in it. Everything is placed by hand; nothing is generated when the game runs.

Before you start: turn on grid snapping (toolbar magnet icon, then "Configure Snap...": grid step **32 x 32**),
so buildings and objects line up with the 32 px tiles.

### What is where (Scene panel)

| Node | What it holds |
|---|---|
| `Lighting` | Day / night. Tick **Night** in the Inspector to preview the town after dark. |
| `Grass` | Ground: grass everywhere. |
| `Water` | The stream (blocks movement; the bridge cells do not). |
| `Roads` | Dirt streets and the tilled soil of the gardens. |
| `Paving` | Cobblestones of the square. |
| `GroundProps` | Things that are always under characters (the bridge). |
| `SideWalls` | The west and east town walls. |
| `World` | Everything characters can walk behind (y-sorted): `Walls` (north/south wall, towers), `Buildings`, `Props`, `Trees`, the `Player`. |
| `NpcSpots` | Markers where NPCs will stand later. |
| `DungeonExit` | Walking into it (outside the north gate) loads the dungeon. |

Buildings draw their own walls, roof, door, windows, chimney, sign and banners from the LPC pieces, so a building
is a single node you can move and restyle; there is no separate roof layer to keep in sync.

### Add a house

1. In the FileSystem panel open `scenes/town/buildings/` and drag **`house.tscn`** onto the `World/Buildings` node.
2. Move it so its **bottom-left corner** sits on the street's first row: the door always faces down (south) and
   must open onto a street.
3. In the Inspector change the look: `width`, `wall_height` (3 = one floor, 4-5 = two floors), `roof_height`,
   `wall_style`, `roof_color`, `roof_shape` (gable or hip), `door_x` / `door_style`, `window_style`,
   `window_spacing`, `flower_boxes`, `chimney_x`, `shop_sign`, `banner`. The editor redraws it right away.
4. Important buildings (guild, town hall, inn, smithy, alchemist, store, temple) are their own scenes in the same
   folder: edit e.g. `inn.tscn` and every inn instance changes.

The building blocks movement on its ground footprint (`width` x `roof_height` tiles, above its corner); the top
of the roof hangs over the ground behind it, so the player can walk behind houses.

### Move or add an object

- **Move:** click the object in the 2D view (or in the Scene panel) and drag it, or type a new `Position` in the
  Inspector. An object's position is the point where it touches the ground (bottom center).
- **Add:** drag `scenes/town/parts/town_prop.tscn` onto `World/Props` and pick what it is in the Inspector
  (`prop`: barrel, crate, sacks, lantern, bench, cart, tree, flower pots...). `solid` decides if it blocks,
  `on_pole` turns a lantern into a lamp post, `flip_h` mirrors it.
- Fences: `scenes/town/parts/town_fence.tscn` (`length`, `vertical`, `style`, `gap_at` for a gate).
  Wall pieces: `town_wall.tscn`. The Wanted board: `wanted_board.tscn` (posters are `.tres` files in
  `resources/town/wanted/`).
- **Delete:** select it and press Delete.

### Change a road

1. Select the **`Roads`** layer in the Scene panel; the TileMap panel opens at the bottom.
2. Open its **Terrains** tab, pick terrain set 0, then **Dirt** (streets) or **Soil** (gardens).
3. Choose the paint tool (pencil or rectangle) and paint on the map: the edges blend into the grass by
   themselves. To remove a road, use the eraser on the `Roads` layer (grass shows through).
4. Same for the stream (`Water` layer, terrain **Water**) and the square (`Paving` layer, paint the cobblestone tile
   from the Tiles tab).

### Check your changes

    <godot.exe> --headless --path . -- --town-test

It checks that every door opens on a street, buildings do not overlap, the gates are open, the walls and the
stream block, and the night lights work (exit code 0 = all passed).

`tools/town_builder.gd` (`-- --build-town --force`) is the tool that laid out the first version of the town.
**Do not run it again**: it would replace `town.tscn` and throw away every hand edit.
