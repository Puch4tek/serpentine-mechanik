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
			var index = y * level.width + x
			var mask: int = level.cells[index]
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
			tilemap.set_cell(Vector2i(x,y), 0, Vector2i(tile_id, 24))

func center_maze():
	var maze_width: float = level.width * 64
	var maze_height: float = level.height * 64
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	
	var offset_x: float = (screen_size.x - maze_width) / 2
	var offset_y: float = (screen_size.y - maze_height) / 2
	tilemap.position = Vector2(offset_x, offset_y)

func _ready() -> void:
	load_level("res://resources/level1.tres")
	build_grid()
	render_tilemap()
	center_maze()
	print(level.width)
	print(level.height)
	print(level.cells.size())
	pass # Replace with function body.

# Dodaj na końcu klasy, przed _process

func can_move(cell: Vector2i, dir: Vector2i) -> bool:
	# Sprawdź czy cell jest w granicach siatki
	var next: Vector2i = cell + dir
	if next.x < 0 or next.x >= level.width or next.y < 0 or next.y >= level.height:
		return false

	var c: Cell = grid[cell.y][cell.x]

	if dir == Vector2i.RIGHT:
		return not c.right
	if dir == Vector2i.LEFT:
		return not c.left
	if dir == Vector2i(0, -1):   # UP
		return not c.top
	if dir == Vector2i(0, 1):    # DOWN
		return not c.bottom

	return false

func get_maze_offset() -> Vector2:
	return tilemap.position


func _process(delta: float) -> void:
	pass
