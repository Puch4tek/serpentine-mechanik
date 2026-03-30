extends Node2D

var value: int = 1
var cell: Vector2i

func setup(grid_cell: Vector2i, v: int, maze_offset: Vector2, tile_size: int) -> void:
	cell = grid_cell
	value = v
	$Label.text = str(v)
	position = maze_offset + Vector2(
		grid_cell.x * tile_size + tile_size / 2.0,
		grid_cell.y * tile_size + tile_size / 2.0
	)

