extends Node

# Czas między krokami węża (w sekundach)
@export var move_interval: float = 0.25

@onready var grid_controller: Node = get_node("../GridController")
@onready var snake: Node2D = get_node("../Snake")

var move_timer: float = 0.0
var queued_direction: Vector2i = Vector2i.RIGHT
var is_running: bool = false

func _ready() -> void:
	# Poczekaj jeden frame, żeby GridController zdążył się zainicjować
	await get_tree().process_frame
	start_game()

func start_game() -> void:
	# Synchronizuj offset labiryntu z wężem
	snake.maze_offset = grid_controller.get_maze_offset()
	snake.tile_size = 64

	# Spawn węża na środku labiryntu
	var start_x: int = grid_controller.level.width / 2
	var start_y: int = grid_controller.level.height / 2
	snake.spawn_snake(Vector2i(start_x, start_y), 3)
	
	queued_direction = Vector2i.RIGHT
	snake.set_direction(queued_direction)
	move_timer = 0.0
	is_running = true

func _process(delta: float) -> void:
	if not is_running:
		return

	move_timer += delta
	if move_timer >= move_interval:
		move_timer -= move_interval
		snake.set_direction(queued_direction)
		snake.move(grid_controller)

func _unhandled_input(event: InputEvent) -> void:
	if not is_running:
		return

	var current_dir: Vector2i = snake.direction

	if event.is_action_pressed("ui_right") and current_dir != Vector2i.LEFT:
		queued_direction = Vector2i.RIGHT
	elif event.is_action_pressed("ui_left") and current_dir != Vector2i.RIGHT:
		queued_direction = Vector2i.LEFT
	elif event.is_action_pressed("ui_up") and current_dir != Vector2i(0, 1):
		queued_direction = Vector2i(0, -1)
	elif event.is_action_pressed("ui_down") and current_dir != Vector2i(0, -1):
		queued_direction = Vector2i(0, 1)
