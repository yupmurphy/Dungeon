class_name Terrain
## Ground types of a floor cell. One table says, per type, whether it can be walked on, how much it slows,
## whether it hides what is behind it, how it is drawn and its color on the elements map.

enum Type {
	ROCK,           # solid rock: cave walls, desert rock formations, map edge (drawn with WallTiler)
	CAVE,           # cave / dungeon floor (drawn with the dungeon floor tiles)
	GRASS,          # open grass, forest clearings
	FOREST_FLOOR,   # leaves and moss under the trees
	TREE,           # dense forest tree (blocks)
	WATER_SHALLOW,  # walkable, slows
	WATER_DEEP,     # can't be crossed
	BRIDGE,         # wooden planks over deep water
	MUD,            # swamp ground
	REEDS,          # shallow water with reeds: slows, hides
	SAND,
	DUNE,           # dune crest: darker sand, slows a little
	QUICKSAND,      # slows a lot
	OASIS_GRASS,
	WEB,            # spider webs around nests: slows
}

## [walkable, speed factor, blocks sight, map color]
const INFO: Dictionary = {
	Type.ROCK: [false, 1.0, true, Color(0.35, 0.33, 0.36)],
	Type.CAVE: [true, 1.0, false, Color(0.55, 0.5, 0.45)],
	Type.GRASS: [true, 1.0, false, Color(0.45, 0.72, 0.3)],
	Type.FOREST_FLOOR: [true, 1.0, false, Color(0.3, 0.5, 0.22)],
	Type.TREE: [false, 1.0, true, Color(0.08, 0.3, 0.1)],
	Type.WATER_SHALLOW: [true, 0.55, false, Color(0.25, 0.5, 0.55)],
	Type.WATER_DEEP: [false, 1.0, false, Color(0.12, 0.28, 0.65)],
	Type.BRIDGE: [true, 1.0, false, Color(0.6, 0.42, 0.22)],
	Type.MUD: [true, 0.9, false, Color(0.4, 0.42, 0.28)],
	Type.REEDS: [true, 0.6, true, Color(0.5, 0.6, 0.32)],
	Type.SAND: [true, 1.0, false, Color(0.92, 0.8, 0.5)],
	Type.DUNE: [true, 0.85, false, Color(0.8, 0.66, 0.38)],
	Type.QUICKSAND: [true, 0.35, false, Color(0.62, 0.48, 0.25)],
	Type.OASIS_GRASS: [true, 1.0, false, Color(0.4, 0.75, 0.35)],
	Type.WEB: [true, 0.6, false, Color(0.85, 0.85, 0.9)],
}

## Terrain types that are drawn from the procedural nature atlas (NatureArt), with their first tile
## and number of variants there. ROCK and CAVE use the dungeon tileset instead.
const ART: Dictionary = {
	Type.GRASS: [0, 4],
	Type.FOREST_FLOOR: [4, 4],
	Type.TREE: [8, 4],
	Type.WATER_SHALLOW: [12, 3],
	Type.WATER_DEEP: [15, 3],
	Type.BRIDGE: [18, 2],
	Type.MUD: [20, 4],
	Type.REEDS: [24, 3],
	Type.SAND: [27, 4],
	Type.DUNE: [31, 2],
	Type.QUICKSAND: [33, 2],
	Type.OASIS_GRASS: [35, 2],
	Type.WEB: [37, 2],
}
## Number of tiles in the nature atlas.
const ART_TILES: int = 39


static func walkable(type: int) -> bool:
	return INFO[type][0]


static func speed_factor(type: int) -> float:
	return INFO[type][1]


static func blocks_sight(type: int) -> bool:
	return INFO[type][2]


static func map_color(type: int) -> Color:
	return INFO[type][3]


## Nature atlas tile for a terrain; `roll` in [0, 1) picks the variant (first variant most common).
static func art_tile(type: int, roll: float) -> int:
	var art: Array = ART[type]
	var variants: int = art[1]
	if variants == 1 or roll < 0.55:
		return art[0]
	return art[0] + 1 + int((roll - 0.55) / 0.45 * (variants - 1)) % (variants - 1)
