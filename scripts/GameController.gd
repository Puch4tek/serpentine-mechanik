extends Node

# Czas między krokami węża (w sekundach)
@export var move_interval: float = 0.25
@export var enemy_length: int = 3
@export var enemy_scene: PackedScene = preload("res://scenes/Snake.tscn")
@export var extension_scene: PackedScene = preload("res://scenes/Extension.tscn")
@export var swipe_min_distance: float = 48.0

@onready var grid_controller: Node = get_node("../GridController")
@onready var snake: Node2D = get_node("../Snake")
@onready var game_over_ui: Control = get_node("../CanvasLayer/GameOver")
@onready var game_over_backdrop: Control = get_node_or_null("../CanvasLayer/GameOver/ColorRect")
@onready var score_label: Label = get_node_or_null("../CanvasLayer/Control/ScoreLabel")

var move_timer: float = 0.0
var queued_direction: Vector2i = Vector2i.RIGHT
var is_running: bool = false
var enemy_snakes: Array[Node2D] = []
var extensions: Array[Node2D] = []
var score: int = 0
var active_swipe_index: int = -1
var swipe_start_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Poczekaj jeden frame, żeby GridController zdążył się zainicjować
	await get_tree().process_frame
	start_game()

func start_game() -> void:
	clear_enemy_snakes()
	clear_extensions()
	score = 0

	# Synchronizuj offset labiryntu z wężem
	snake.maze_offset = grid_controller.get_maze_offset()
	snake.tile_size = 64

	# Spawn węża 
	
	snake.spawn_snake(grid_controller.get_snake_spawn(), 3)
	
	queued_direction = pick_player_initial_direction()
	snake.set_direction(queued_direction)
	spawn_enemy_snakes()
	spawn_extension()

	move_timer = 0.0
	is_running = true

	update_score_label()

	if game_over_ui:
		game_over_ui.mouse_filter = Control.MOUSE_FILTER_PASS
		game_over_ui.visible = false
	if game_over_backdrop:
		game_over_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_running:
		return

	move_timer += delta
	if move_timer >= move_interval:
		move_timer -= move_interval
		run_tick()

func run_tick() -> void:
	# Gracz zawsze porusza się jako pierwszy.
	snake.set_direction(queued_direction)

	# Jeśli gracz jest pod ścianą, nie kończ od razu gry.
	# Pozwól mu zmienić kierunek i ruszyć w kolejnym ticku.
	if snake.can_move_forward(grid_controller):
		if not try_move_snake(snake, true):
			trigger_game_over()
			return
		check_extension_pickup()

	for idx in range(enemy_snakes.size() - 1, -1, -1):
		var enemy: Node2D = enemy_snakes[idx]
		if not is_instance_valid(enemy):
			enemy_snakes.remove_at(idx)
			continue

		if not is_enemy_runtime_valid(enemy):
			enemy.queue_free()
			enemy_snakes.remove_at(idx)
			continue

		var enemy_dir := choose_enemy_direction(enemy)
		enemy.set_direction(enemy_dir)

		if not try_move_snake(enemy, false):
			enemy.queue_free()
			enemy_snakes.remove_at(idx)

func spawn_enemy_snakes() -> void:
	var enemy_spawns: Array[Vector2i] = grid_controller.get_enemy_spawns(enemy_length)
	for spawn in enemy_spawns:
		if not is_enemy_spawn_valid(spawn):
			continue

		var enemy: Node2D = enemy_scene.instantiate()
		enemy.head_texture = snake.head_texture
		enemy.body_texture = snake.body_texture
		enemy.segment_scene = snake.segment_scene
		enemy.maze_offset = grid_controller.get_maze_offset()
		enemy.tile_size = snake.tile_size

		get_parent().add_child(enemy)
		enemy.spawn_snake(spawn, enemy_length)
		enemy.set_direction(pick_initial_direction(enemy))
		enemy_snakes.append(enemy)

func clear_enemy_snakes() -> void:
	for enemy in enemy_snakes:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemy_snakes.clear()

func clear_extensions() -> void:
	for ext in extensions:
		if is_instance_valid(ext):
			ext.queue_free()
	extensions.clear()

func pick_player_initial_direction() -> Vector2i:
	var candidates: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i(0, -1), Vector2i(0, 1)]
	for dir in candidates:
		if snake.can_move_forward(grid_controller, dir):
			return dir
	return Vector2i.RIGHT

func is_enemy_spawn_valid(spawn: Vector2i) -> bool:
	if spawn == snake.head_cell:
		return false

	for i in range(enemy_length):
		var body_cell: Vector2i = spawn - Vector2i(i, 0)
		if not grid_controller.is_inside_grid(body_cell):
			return false
		if snake.contains_cell(body_cell):
			return false

	for enemy in enemy_snakes:
		if not is_instance_valid(enemy):
			continue
		if enemy.contains_cell(spawn):
			return false

	return true

func is_enemy_runtime_valid(enemy: Node2D) -> bool:
	if enemy.segment_cells.is_empty():
		return false

	for cell in enemy.segment_cells:
		if not grid_controller.is_inside_grid(cell):
			return false

	return true

func pick_initial_direction(enemy: Node2D) -> Vector2i:
	var candidates: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i(0, -1), Vector2i(0, 1)]
	for dir in candidates:
		if enemy.can_move_forward(grid_controller, dir):
			return dir
	return Vector2i.RIGHT

func choose_enemy_direction(enemy: Node2D) -> Vector2i:
	var current: Vector2i = enemy.direction
	var candidates: Array[Vector2i] = [
		current,
		turn_left(current),
		turn_right(current),
		-current,
	]

	for dir in candidates:
		if not enemy.can_move_forward(grid_controller, dir):
			continue

		var next_cell: Vector2i = enemy.get_next_head(dir)
		if cell_occupied_by_any_body(next_cell, enemy):
			continue

		return dir

	return current

func turn_left(dir: Vector2i) -> Vector2i:
	return Vector2i(dir.y, -dir.x)

func turn_right(dir: Vector2i) -> Vector2i:
	return Vector2i(-dir.y, dir.x)

func try_move_snake(moving_snake: Node2D, is_player: bool) -> bool:
	if not moving_snake.can_move_forward(grid_controller):
		return false

	var next_head: Vector2i = moving_snake.get_next_head()
	if cell_occupied_by_any_body(next_head, moving_snake):
		if is_player:
			return false
		return false

	moving_snake.move(grid_controller)
	return true

func cell_occupied_by_any_body(cell: Vector2i, moving_snake: Node2D) -> bool:
	if snake_has_body_at_cell(snake, cell, moving_snake == snake):
		return true

	for enemy in enemy_snakes:
		if not is_instance_valid(enemy):
			continue
		if snake_has_body_at_cell(enemy, cell, moving_snake == enemy):
			return true

	return false

func snake_has_body_at_cell(check_snake: Node2D, cell: Vector2i, is_self: bool) -> bool:
	if is_self:
		# Ten projekt pozwala jechać po własnym ciele (w tym zawracanie).
		return false

	var start_index: int = 0
	var end_index: int = check_snake.segment_cells.size()


	return check_snake.contains_cell(cell, start_index, end_index)

func get_free_cells() -> Array[Vector2i]:
	var free: Array[Vector2i] = []
	var level = grid_controller.level
	for y in range(level.height):
		for x in range(level.width):
			var cell := Vector2i(x, y)
			if snake.contains_cell(cell):
				continue
			var blocked := false
			for enemy in enemy_snakes:
				if is_instance_valid(enemy) and enemy.contains_cell(cell):
					blocked = true
					break
			if blocked:
				continue
			for ext in extensions:
				if is_instance_valid(ext) and ext.cell == cell:
					blocked = true
					break
			if not blocked:
				free.append(cell)
	return free

func spawn_extension() -> void:
	if extension_scene == null:
		return
	var free_cells := get_free_cells()
	if free_cells.is_empty():
		return
	var cell: Vector2i = free_cells[randi() % free_cells.size()]
	var ext: Node2D = extension_scene.instantiate()
	get_parent().add_child(ext)
	ext.setup(cell, randi_range(1, 6), grid_controller.get_maze_offset(), snake.tile_size)
	extensions.append(ext)

func check_extension_pickup() -> void:
	for i in range(extensions.size() - 1, -1, -1):
		var ext = extensions[i]
		if not is_instance_valid(ext):
			extensions.remove_at(i)
			continue
		if ext.cell == snake.head_cell:
			score += ext.value
			snake.grow()
			ext.queue_free()
			extensions.remove_at(i)
			update_score_label()
			spawn_extension()

func update_score_label() -> void:
	if score_label:
		score_label.text = "Score: " + str(score)

func trigger_game_over() -> void:
	game_over_ui.visible = true
	is_running = false

func queue_direction(new_direction: Vector2i) -> void:
	if new_direction == Vector2i.ZERO:
		return
	queued_direction = new_direction

func try_apply_swipe(swipe_delta: Vector2) -> bool:
	if swipe_delta.length() < swipe_min_distance:
		return false

	var swipe_direction: Vector2i
	if absf(swipe_delta.x) >= absf(swipe_delta.y):
		swipe_direction = Vector2i.RIGHT if swipe_delta.x > 0.0 else Vector2i.LEFT
	else:
		swipe_direction = Vector2i(0, 1) if swipe_delta.y > 0.0 else Vector2i(0, -1)

	queue_direction(swipe_direction)
	return true

func _input(event: InputEvent) -> void:
	if not is_running:
		return
	
	if event.is_action_pressed("snake_right") or event.is_action_pressed("ui_right"):
		queue_direction(Vector2i.RIGHT)
	elif event.is_action_pressed("snake_left") or event.is_action_pressed("ui_left"):
		queue_direction(Vector2i.LEFT)
	elif event.is_action_pressed("snake_up") or event.is_action_pressed("ui_up"):
		queue_direction(Vector2i(0, -1))
	elif event.is_action_pressed("snake_down") or event.is_action_pressed("ui_down"):
		queue_direction(Vector2i(0, 1))
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			active_swipe_index = touch_event.index
			swipe_start_position = touch_event.position
		elif touch_event.index == active_swipe_index:
			try_apply_swipe(touch_event.position - swipe_start_position)
			active_swipe_index = -1
	elif event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event
		if drag_event.index != active_swipe_index:
			return

		if try_apply_swipe(drag_event.position - swipe_start_position):
			# Jeden kierunek na jeden gest; kolejny dopiero po nowym dotknięciu.
			active_swipe_index = -1

