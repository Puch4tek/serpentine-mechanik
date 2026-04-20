extends Resource
class_name LevelData

@export var width: int = 13
@export var height: int = 11
@export var snake_spawn: Vector2i = Vector2i(6, 5)
@export var player_spawn_box: Vector2i = Vector2i(-1, -1)
@export var player_spawn_direction: Vector2i = Vector2i.ZERO
@export var player_exit_cell: Vector2i = Vector2i(-1, -1)
@export var enemy_spawns: Array[Vector2i] = [Vector2i(1, 1)]
@export var enemy_spawn_directions: Array[Vector2i] = []
@export var enemy_exit_cells: Array[Vector2i] = []

# Preferowany format: dane kafli jako wiersze (łatwiejsze do edycji).
@export var cells_2d: Array[PackedInt32Array] = []

# Legacy fallback dla starszych poziomów.
@export var cells: PackedInt32Array

func get_cell_mask(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return 0

	if y < cells_2d.size():
		var row: PackedInt32Array = cells_2d[y]
		if x < row.size():
			return row[x]

	var index: int = y * width + x
	if index >= 0 and index < cells.size():
		return cells[index]

	return 0
