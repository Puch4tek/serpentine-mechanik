extends Node

const WIDTH: int = 13
const HEIGHT: int = 11

const TOP: int = 1
const RIGHT: int = 2
const BOTTOM: int = 4
const LEFT: int = 8

var grid: Array[Variant] = []
var level: LevelData

@onready var tilemap: TileMapLayer = get_node("../Maze")

class Cell:
	var top: bool = false
	var right: bool = false
	var bottom: bool = false
	var left: bool = false

func load_level(path: String) -> void:
	level = load(path)
	if level == null:
		push_error("Failed to load level: " + path)
		return

func build_grid():
	grid.clear()
	for y in range(level.height):
		var row: Array[Variant] = []
		for x in range(level.width):
			var mask: int = level.get_cell_mask(x, y)
			var cell = Cell.new()
			cell.top = (mask & TOP) != 0
			cell.right = (mask & RIGHT) != 0
			cell.bottom = (mask & BOTTOM) != 0
			cell.left = (mask & LEFT) != 0

			row.append(cell)
		grid.append(row)

func render_tilemap():
	tilemap.clear()
	for y in range(level.height):
		for x in range(level.width):
			var cell: Cell = grid[y][x]
			var tile_id: int = 0
			if cell.top:
				tile_id |= TOP
			if cell.right:
				tile_id |= RIGHT
			if cell.bottom:
				tile_id |= BOTTOM
			if cell.left:
				tile_id |= LEFT
			tilemap.set_cell(Vector2i(x,y), 0, Vector2i(tile_id, 0))

func center_maze():
	var maze_width: float = level.width * 64
	var maze_height: float = level.height * 64
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	var offset_x: float = (viewport_size.x - maze_width) / 2.0
	var offset_y: float = (viewport_size.y - maze_height) / 2.0
	tilemap.position = Vector2(offset_x, offset_y)

func _ready() -> void:
	load_level("res://resources/level1.tres")
	if level == null:
		push_error("Failed to load level, cannot proceed")
		return
	build_grid()
	render_tilemap()
	center_maze()
	get_viewport().size_changed.connect(center_maze)
	print(level.width)
	print(level.height)
	print(level.cells_2d.size())

# Dodaj na końcu klasy, przed _process

func can_move(cell: Vector2i, dir: Vector2i) -> bool:
	if not is_inside_grid(cell):
		return false

	var next: Vector2i = cell + dir
	if not is_inside_grid(next):
		return false

	var current_cell: Cell = grid[cell.y][cell.x]

	if dir == Vector2i.RIGHT:
		return not current_cell.right
	if dir == Vector2i.LEFT:
		return not current_cell.left
	if dir == Vector2i(0, -1):
		return not current_cell.top
	if dir == Vector2i(0, 1):
		return not current_cell.bottom

	return false

func get_maze_offset() -> Vector2:
	return tilemap.position

func get_snake_spawn() -> Vector2i:
	return level.snake_spawn

func get_enemy_spawn_data(body_length: int = 3) -> Array[Dictionary]:
	var spawn_data: Array[Dictionary] = []
	for i in range(level.enemy_spawns.size()):
		var spawn: Vector2i = level.enemy_spawns[i]
		if not is_inside_grid(spawn):
			continue

		var initial_direction: Vector2i = Vector2i.RIGHT
		if i < level.enemy_spawn_directions.size() and level.enemy_spawn_directions[i] != Vector2i.ZERO:
			initial_direction = level.enemy_spawn_directions[i]

		spawn_data.append({
			"spawn": spawn,
			"initial_direction": initial_direction,
		})

	return spawn_data

func get_enemy_spawns(body_length: int = 3) -> Array[Vector2i]:
	var valid_spawns: Array[Vector2i] = []
	for data in get_enemy_spawn_data(body_length):
		valid_spawns.append(data["spawn"])
	return valid_spawns

func get_enemy_body_cells(spawn: Vector2i, body_length: int, initial_direction: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var safe_direction: Vector2i = initial_direction
	if safe_direction == Vector2i.ZERO:
		safe_direction = Vector2i.RIGHT

	for i in range(max(1, body_length)):
		cells.append(spawn - safe_direction * i)

	return cells

func is_inside_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < level.width and cell.y >= 0 and cell.y < level.height

func _process(delta: float) -> void:
	pass
