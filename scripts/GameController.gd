extends Node

# Ciągły ruch: gracz ma większą prędkość od AI.
@export var player_speed_px: float = 260.0
@export var enemy_speed_px: float = 150.0
@export var enemy_direction_interval: float = 0.18
@export var enemy_length: int = 3
@export var enemy_scene: PackedScene = preload("res://scenes/Snake.tscn")
@export var extension_scene: PackedScene = preload("res://scenes/Extension.tscn")
@export var swipe_min_distance: float = 48.0

@onready var grid_controller: Node = get_node("../GridController")
@onready var snake: Node2D = get_node("../Snake")
@onready var game_over_ui: Control = get_node("../CanvasLayer/GameOver")
@onready var game_over_backdrop: Control = get_node_or_null("../CanvasLayer/GameOver/ColorRect")
@onready var score_label: Label = get_node_or_null("../CanvasLayer/Control/ScoreLabel")

var enemy_direction_timer: float = 0.0
var queued_direction: Vector2i = Vector2i.RIGHT
var is_running: bool = false
var enemy_snakes: Array[Node2D] = []
var extensions: Array[Node2D] = []
var score: int = 0
var active_swipe_index: int = -1
var swipe_start_position: Vector2 = Vector2.ZERO
const REAR_GRACE_SEGMENTS: int = 2

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
	snake.move_speed_px = player_speed_px

	# Spawn węża 
	
	snake.spawn_snake(grid_controller.get_snake_spawn(), 3)
	
	queued_direction = pick_player_initial_direction()
	snake.set_direction(queued_direction)
	spawn_enemy_snakes()
	spawn_extension()

	enemy_direction_timer = 0.0
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

	run_player_frame(delta)
	if not is_running:
		return

	enemy_direction_timer += delta
	if enemy_direction_timer >= enemy_direction_interval:
		enemy_direction_timer -= enemy_direction_interval
		update_enemy_directions(enemy_direction_interval)

	run_enemy_frame(delta)

func run_player_frame(delta: float) -> void:
	snake.set_direction(queued_direction)
	if not try_advance_snake(snake, delta, true):
		trigger_game_over()
		return
	check_extension_pickup()

func run_enemy_frame(delta: float) -> void:
	for idx in range(enemy_snakes.size() - 1, -1, -1):
		var enemy: Node2D = enemy_snakes[idx]
		if not is_instance_valid(enemy):
			enemy_snakes.remove_at(idx)
			continue

		if not is_enemy_runtime_valid(enemy):
			enemy.queue_free()
			enemy_snakes.remove_at(idx)
			continue

		if not try_advance_snake(enemy, delta, false):
			enemy.queue_free()
			enemy_snakes.remove_at(idx)

func update_enemy_directions(lookahead_delta: float) -> void:
	for enemy in enemy_snakes:
		if not is_instance_valid(enemy):
			continue
		enemy.set_direction(choose_enemy_direction(enemy, lookahead_delta))

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
		enemy.move_speed_px = enemy_speed_px

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
	if enemy.segment_positions.is_empty():
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

func choose_enemy_direction(enemy: Node2D, lookahead_delta: float) -> Vector2i:
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

		var next_head_world: Vector2 = enemy.get_predicted_head_world(lookahead_delta, dir)
		if point_occupied_by_any_body(next_head_world, enemy.body_radius_px, enemy):
			continue

		return dir

	return current

func turn_left(dir: Vector2i) -> Vector2i:
	return Vector2i(dir.y, -dir.x)

func turn_right(dir: Vector2i) -> Vector2i:
	return Vector2i(-dir.y, dir.x)

func try_advance_snake(moving_snake: Node2D, delta: float, is_player: bool) -> bool:
	var effective_dir: Vector2i = moving_snake.get_effective_direction(grid_controller)
	if not grid_controller.can_move(moving_snake.head_cell, effective_dir):
		moving_snake.advance(delta, grid_controller)
		return true

	var next_head_world: Vector2 = moving_snake.get_predicted_head_world(delta, effective_dir)
	try_consume_tail_from_rear(moving_snake, next_head_world, moving_snake.head_radius_px)
	if point_occupied_by_any_body(next_head_world, moving_snake.head_radius_px, moving_snake):
		if is_player:
			return false
		return false

	moving_snake.advance(delta, grid_controller)
	return true

func point_occupied_by_any_body(point: Vector2, point_radius: float, moving_snake: Node2D) -> bool:
	if snake_has_body_at_point(snake, point, point_radius, moving_snake == snake, moving_snake):
		return true

	for enemy in enemy_snakes:
		if not is_instance_valid(enemy):
			continue
		if snake_has_body_at_point(enemy, point, point_radius, moving_snake == enemy, moving_snake):
			return true

	return false

func snake_has_body_at_point(check_snake: Node2D, point: Vector2, point_radius: float, is_self: bool, moving_snake: Node2D) -> bool:
	if is_self:
		# Ten projekt pozwala jechać po własnym ciele (w tym zawracanie).
		return false

	var start_index: int = 0
	var end_index: int = check_snake.segment_positions.size()
	if is_rear_end_contact(moving_snake, check_snake, point, point_radius):
		end_index = max(0, end_index - REAR_GRACE_SEGMENTS)
	return check_snake.collides_with_point(point, point_radius, start_index, end_index)

func try_consume_tail_from_rear(moving_snake: Node2D, point: Vector2, point_radius: float) -> bool:
	var target: Node2D = find_rear_end_target(moving_snake, point, point_radius)
	if target == null:
		return false

	if target.segment_positions.size() <= 1:
		eliminate_snake(target)
	else:
		if target.shrink_tail(1, 1) <= 0:
			return false

	moving_snake.grow()
	if moving_snake == snake:
		score += 1
		update_score_label()
	return true

func eliminate_snake(target: Node2D) -> void:
	if target == snake:
		trigger_game_over()
		return

	var idx := enemy_snakes.find(target)
	if idx != -1:
		enemy_snakes.remove_at(idx)
	if is_instance_valid(target):
		target.queue_free()

func find_rear_end_target(moving_snake: Node2D, point: Vector2, point_radius: float) -> Node2D:
	if is_rear_end_contact(moving_snake, snake, point, point_radius):
		return snake

	for enemy in enemy_snakes:
		if not is_instance_valid(enemy):
			continue
		if is_rear_end_contact(moving_snake, enemy, point, point_radius):
			return enemy

	return null

func is_rear_end_contact(moving_snake: Node2D, target_snake: Node2D, point: Vector2, point_radius: float) -> bool:
	if target_snake == moving_snake:
		return false

	var size: int = target_snake.segment_positions.size()
	if size < 1:
		return false

	var tail_index: int = size - 1
	var tail_pos: Vector2 = target_snake.segment_positions[tail_index]
	var tail_radius: float = target_snake.body_radius_px
	if tail_pos.distance_to(point) > point_radius + tail_radius:
		return false

	var tail_forward: Vector2
	if size >= 2:
		var prev_pos: Vector2 = target_snake.segment_positions[tail_index - 1]
		tail_forward = tail_pos - prev_pos
	else:
		tail_forward = Vector2(target_snake.get_effective_direction(grid_controller))

	if tail_forward.length_squared() <= 0.0001:
		return false
	tail_forward = tail_forward.normalized()

	var move_dir: Vector2 = Vector2(moving_snake.get_effective_direction(grid_controller))
	if move_dir.length_squared() <= 0.0001:
		return false
	move_dir = move_dir.normalized()

	return move_dir.dot(tail_forward) > 0.2

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

