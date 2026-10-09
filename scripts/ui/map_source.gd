class_name MapSource
extends Node2D
## Anything the minimap and the big map (M) can show: a picture with one pixel per tile, a legend and a few
## status lines. Dungeon floors use ExplorationMap (fog of war); the town uses TownMap (all known).
## The HUD finds it through the "map_source" group.

## One pixel per tile, tile (0, 0) at the world origin.
var map_texture: ImageTexture
## [{name, color}] shown next to the big map.
var legend: Array[Dictionary] = []
## Optional: drawn under map_texture on the big map, same size (e.g. the outline of the whole floor, faint).
var outline_texture: ImageTexture


func _enter_tree() -> void:
	add_to_group(&"map_source")


## Map size in tiles.
func map_size() -> Vector2i:
	return Vector2i.ZERO if map_texture == null else Vector2i(map_texture.get_size())


## Extra lines under the legend (e.g. "Explored: 12%").
func status_lines() -> PackedStringArray:
	return PackedStringArray()


## Places always marked on the big map, explored or not: [{cell: Vector2i, color: Color, label: String}].
func markers() -> Array[Dictionary]:
	return []
