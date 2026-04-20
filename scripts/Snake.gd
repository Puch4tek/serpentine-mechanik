extends Node2D

@export var head_texture: Texture2D
@export var body_texture: Texture2D
@export var segment_scene: PackedScene
@export var tile_size: int = 64
@export var move_speed_px: float = 220.0

var segments: Array[Node2D] = []
var segment_cells: Array[Vector2i] = []
var direction: Vector2i = Vector2i.RIGHT
var requested_direction: Vector2i = Vector2i.RIGHT
var head_cell: Vector2i
var maze_offset: Vector2 = Vector2.ZERO
var move_accumulator: float = 0.0

func grid_to_world(cell: Vector2i) -> Vector2:
	return maze_offset + Vector2(
		cell.x * tile_size + tile_size / 2.0,
		cell.y * tile_size + tile_size / 2.0
	)

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = world_pos - maze_offset
	return Vector2i(
		int(floor(local.x / float(tile_size))),
		int(floor(local.y / float(tile_size)))
	)

func spawn_snake(start: Vector2i, length: int = 3, initial_direction: Vector2i = direction) -> void:
	for seg in segments:
		seg.queue_free()
	segments.clear()
	segment_cells.clear()

	if initial_direction == Vector2i.ZERO:
		initial_direction = Vector2i.RIGHT

	direction = initial_direction
	requested_direction = initial_direction
	head_cell = start
	move_accumulator = 0.0

	for i in range(max(1, length)):
		var cell: Vector2i = start - initial_direction * i
		var seg: Node2D = segment_scene.instantiate()
		seg.position = grid_to_world(cell)
		add_child(seg)

		if i == 0:
			seg.set_head(head_texture)
		else:
			seg.set_body(body_texture)

		segments.append(seg)
		segment_cells.append(cell)

func grow() -> void:
	if segment_cells.is_empty():
		return

	var tail_cell: Vector2i = segment_cells[-1]
	var seg: Node2D = segment_scene.instantiate()
	seg.position = grid_to_world(tail_cell)
	add_child(seg)
	seg.set_body(body_texture)

	segments.append(seg)
	segment_cells.append(tail_cell)

func shrink_tail(count: int = 1, min_length: int = 1) -> int:
	var removed: int = 0
	var safe_min: int = max(1, min_length)
	var to_remove: int = max(0, count)

	while removed < to_remove and segments.size() > safe_min:
		var tail_index: int = segments.size() - 1
		var tail_segment: Node2D = segments[tail_index]
		if is_instance_valid(tail_segment):
			tail_segment.queue_free()

		segments.remove_at(tail_index)
		segment_cells.remove_at(tail_index)
		removed += 1

	return removed

func set_direction(new_dir: Vector2i) -> void:
	if new_dir == Vector2i.ZERO:
		return
	requested_direction = new_dir

func can_move_forward(grid_controller, for_dir: Vector2i = direction, ignore_walls: bool = false) -> bool:
	if ignore_walls:
		return grid_controller.is_inside_grid(head_cell + for_dir)
	return grid_controller.can_move(head_cell, for_dir)

func get_effective_direction(grid_controller, ignore_walls: bool = false) -> Vector2i:
	if can_apply_requested_direction(grid_controller, ignore_walls):
		return requested_direction
	return direction

func contains_cell(cell: Vector2i) -> bool:
	return cell in segment_cells

func get_step_duration() -> float:
	return float(tile_size) / maxf(1.0, move_speed_px)

func consume_step_budget(delta: float) -> int:
	if delta <= 0.0:
		return 0
	move_accumulator += delta
	var step_duration: float = get_step_duration()
	var steps: int = int(floor(move_accumulator / step_duration))
	if steps <= 0:
		return 0
	# Limit kroków na jedną klatkę, żeby nie "teleportować" przy spadkach FPS.
	steps = min(steps, 4)
	move_accumulator -= step_duration * float(steps)
	return steps

func advance(grid_controller, ignore_walls: bool = false) -> bool:
	if segment_cells.is_empty():
		return false

	if can_apply_requested_direction(grid_controller, ignore_walls):
		direction = requested_direction

	if not ignore_walls and not grid_controller.can_move(head_cell, direction):
		return false

	var next_head: Vector2i = head_cell + direction

	for i in range(segment_cells.size() - 1, 0, -1):
		segment_cells[i] = segment_cells[i - 1]
	segment_cells[0] = next_head
	head_cell = next_head

	update_positions()
	return true

func can_apply_requested_direction(grid_controller, ignore_walls: bool = false) -> bool:
	if requested_direction == direction:
		return false

	if ignore_walls:
		return grid_controller.is_inside_grid(head_cell + requested_direction)

	return grid_controller.can_move(head_cell, requested_direction)

func get_predicted_head_world(delta: float, for_dir: Vector2i = direction) -> Vector2:
	var next_cell: Vector2i = head_cell + for_dir
	return grid_to_world(next_cell)

func update_positions() -> void:
	for i in range(segments.size()):
		segments[i].position = grid_to_world(segment_cells[i])
		if i == 0:
			segments[i].set_head(head_texture)
		else:
			segments[i].set_body(body_texture)
