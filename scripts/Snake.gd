extends Node2D

@export var head_texture : Texture2D
@export var body_texture : Texture2D
@export var segment_scene : PackedScene
@export var tile_size : int = 64

var segments: Array = []
var segment_cells: Array = []
var direction: Vector2i = Vector2i.RIGHT
var head_cell: Vector2i
var maze_offset: Vector2 = Vector2.ZERO

func grid_to_world(cell: Vector2i) -> Vector2:
	return maze_offset + Vector2(
		cell.x * tile_size + tile_size / 2,
		cell.y * tile_size + tile_size / 2
	)

func spawn_snake(start: Vector2i, length := 3):
	for seg in segments:
		seg.queue_free()
	segments.clear()
	segment_cells.clear()
	head_cell = start

	for i in range(length):
		var seg: Node = segment_scene.instantiate()
		var cell = start - Vector2i(i, 0)
		segment_cells.append(cell)
		seg.position = grid_to_world(cell)

		add_child(seg)  # ← NAJPIERW dodaj do drzewa (uruchamia _ready → @onready)

		if i == 0:
			seg.set_head(head_texture)  # ← teraz sprite już istnieje
		else:
			seg.set_body(body_texture)

		segments.append(seg)


func grow():
	var tail_cell = segment_cells[-1]
	segment_cells.append(tail_cell)

	var seg: Node = segment_scene.instantiate()
	seg.position = grid_to_world(tail_cell)

	add_child(seg)          # ← NAJPIERW
	seg.set_body(body_texture)  # ← potem

	segments.append(seg)


func move(grid_controller):
	var new_head: Vector2i = head_cell + direction
	
	# check walls
	if not grid_controller.can_move(head_cell, direction):
		return
	
	# Jeśli wąż zawraca, nowa głowa trafi w segment[1] —
	# ale segment[1] za chwilę się przesunie, więc to jest OK wizualnie.
	# Opcjonalnie: zezwól lub zabroń wchodzenia w środkowe segmenty:
	# (zostaw puste jeśli chcesz pełne przejście przez siebie)
	
	segment_cells.insert(0, new_head)
	segment_cells.pop_back()
	head_cell = new_head
	
	update_positions()
	update_head_visual()


func update_positions():

	for i in range(segments.size()):
		segments[i].position = grid_to_world(segment_cells[i])

func update_head_visual():

	for i in range(segments.size()):
		if i == 0:
			segments[i].set_head(head_texture)
		else:
			segments[i].set_body(body_texture)

func set_direction(new_dir: Vector2i):
	direction = new_dir

func get_next_head(for_dir: Vector2i = direction) -> Vector2i:
	return head_cell + for_dir

func can_move_forward(grid_controller, for_dir: Vector2i = direction) -> bool:
	return grid_controller.can_move(head_cell, for_dir)

func contains_cell(cell: Vector2i, from_index: int = 0, to_index_exclusive: int = -1) -> bool:
	var end_index := to_index_exclusive
	if end_index == -1:
		end_index = segment_cells.size()
	for i in range(from_index, end_index):
		if segment_cells[i] == cell:
			return true
	return false

