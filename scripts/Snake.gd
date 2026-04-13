extends Node2D

@export var head_texture : Texture2D
@export var body_texture : Texture2D
@export var segment_scene : PackedScene
@export var tile_size : int = 64
@export var segment_spacing_px: float = 22.0
@export var head_radius_px: float = 16.0
@export var body_radius_px: float = 13.0
@export var move_speed_px: float = 220.0
@export var turn_snap_tolerance_px: float = 6.0

var segments: Array[Node2D] = []
var segment_cells: Array[Vector2i] = []
var segment_positions: Array[Vector2] = []
var direction: Vector2i = Vector2i.RIGHT
var requested_direction: Vector2i = Vector2i.RIGHT
var head_cell: Vector2i
var head_world: Vector2 = Vector2.ZERO
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
	segment_positions.clear()
	head_cell = start
	head_world = grid_to_world(start)
	requested_direction = direction
	var dir_world := Vector2(direction)
	if dir_world == Vector2.ZERO:
		dir_world = Vector2.RIGHT

	for i in range(length):
		var seg: Node2D = segment_scene.instantiate()
		var pos := head_world - dir_world * (float(i) * segment_spacing_px)
		segment_positions.append(pos)
		seg.position = pos

		add_child(seg)  # ← NAJPIERW dodaj do drzewa (uruchamia _ready → @onready)

		if i == 0:
			seg.set_head(head_texture)  # ← teraz sprite już istnieje
		else:
			seg.set_body(body_texture)

		segments.append(seg)

	sync_cells_from_world()


func grow():
	var tail_position := segment_positions[-1]
	segment_positions.append(tail_position)

	var seg: Node2D = segment_scene.instantiate()
	seg.position = tail_position

	add_child(seg)          # ← NAJPIERW
	seg.set_body(body_texture)  # ← potem

	segments.append(seg)
	sync_cells_from_world()

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
		segment_positions.remove_at(tail_index)
		if tail_index < segment_cells.size():
			segment_cells.remove_at(tail_index)

		removed += 1

	sync_cells_from_world()
	return removed


func move(grid_controller):
	advance(1.0 / 60.0, grid_controller)


func update_positions():
	for i in range(segments.size()):
		segments[i].position = segment_positions[i]

func update_head_visual():

	for i in range(segments.size()):
		if i == 0:
			segments[i].set_head(head_texture)
		else:
			segments[i].set_body(body_texture)

func set_direction(new_dir: Vector2i):
	if new_dir == Vector2i.ZERO:
		return
	requested_direction = new_dir

func get_next_head(for_dir: Vector2i = direction) -> Vector2i:
	return head_cell + for_dir

func get_next_head_world(for_dir: Vector2i = direction) -> Vector2:
	return get_predicted_head_world(1.0 / 60.0, for_dir)

func get_predicted_head_world(delta: float, for_dir: Vector2i = direction) -> Vector2:
	return head_world + Vector2(for_dir) * (move_speed_px * maxf(delta, 0.0))

func can_move_forward(grid_controller, for_dir: Vector2i = direction) -> bool:
	if for_dir != direction:
		return grid_controller.can_move(head_cell, for_dir)

	var effective_dir: Vector2i = get_effective_direction(grid_controller)
	return grid_controller.can_move(head_cell, effective_dir)

func get_effective_direction(grid_controller) -> Vector2i:
	if can_apply_requested_direction(grid_controller):
		return requested_direction
	return direction

func contains_cell(cell: Vector2i, from_index: int = 0, to_index_exclusive: int = -1) -> bool:
	var end_index := to_index_exclusive
	if end_index == -1:
		end_index = segment_cells.size()
	for i in range(from_index, end_index):
		if segment_cells[i] == cell:
			return true
	return false

func collides_with_point(point: Vector2, point_radius: float, from_index: int = 0, to_index_exclusive: int = -1) -> bool:
	var end_index := to_index_exclusive
	if end_index == -1:
		end_index = segment_positions.size()
	for i in range(from_index, end_index):
		var segment_radius := head_radius_px if i == 0 else body_radius_px
		if segment_positions[i].distance_to(point) <= point_radius + segment_radius:
			return true
	return false

func get_head_world() -> Vector2:
	return head_world

func advance(delta: float, grid_controller) -> void:
	if delta <= 0.0:
		return
	if direction == Vector2i.ZERO:
		return

	apply_requested_direction_if_possible(grid_controller)

	var old_positions: Array[Vector2] = segment_positions.duplicate()
	var remaining: float = move_speed_px * delta
	var dir_vec: Vector2 = Vector2(direction)
	const EPS: float = 0.001

	while remaining > 0.0:
		head_cell = world_to_cell(head_world)

		# Gdy przed nami jest ściana, dojedź płynnie do środka kafla i tam się zatrzymaj.
		if not grid_controller.can_move(head_cell, direction):
			var center: Vector2 = grid_to_world(head_cell)
			var to_center_along: float = distance_to_center_along_direction(center, direction)
			if to_center_along > 0.0:
				var center_travel: float = minf(remaining, to_center_along)
				head_world += dir_vec * center_travel
				snap_to_centerline()
				remaining -= center_travel
				if remaining <= 0.0:
					break

			head_world = center
			snap_to_centerline()
			break

		var dist_to_edge := distance_to_cell_edge(head_world, head_cell, direction)
		var travel: float = minf(remaining, dist_to_edge)
		head_world += dir_vec * travel
		snap_to_centerline()
		remaining -= travel

		if remaining <= 0.0:
			break

		# Styk z granicą komórki: zanim przekroczymy ją, pytamy grid o ścianę.
		if not grid_controller.can_move(head_cell, direction):
			remaining = 0.0
			break

		head_world += dir_vec * EPS
		snap_to_centerline()
		remaining = maxf(0.0, remaining - EPS)
		apply_requested_direction_if_possible(grid_controller)
		dir_vec = Vector2(direction)

	segment_positions[0] = head_world

	# Ciało podąża za poprzednimi pozycjami, zachowując sub-tile spacing.
	for i in range(1, segment_positions.size()):
		var target: Vector2 = old_positions[i - 1]
		var to_target: Vector2 = target - segment_positions[i]
		var dist: float = to_target.length()
		if dist > segment_spacing_px and dist > 0.0001:
			segment_positions[i] += to_target / dist * (dist - segment_spacing_px)

	head_cell = world_to_cell(head_world)
	sync_cells_from_world()
	update_positions()
	update_head_visual()

func distance_to_cell_edge(world_pos: Vector2, cell: Vector2i, dir: Vector2i) -> float:
	if dir == Vector2i.RIGHT:
		var edge_x: float = maze_offset.x + (cell.x + 1) * tile_size
		return maxf(0.0, edge_x - world_pos.x)
	if dir == Vector2i.LEFT:
		var edge_x: float = maze_offset.x + cell.x * tile_size
		return maxf(0.0, world_pos.x - edge_x)
	if dir == Vector2i(0, 1):
		var edge_y: float = maze_offset.y + (cell.y + 1) * tile_size
		return maxf(0.0, edge_y - world_pos.y)
	if dir == Vector2i(0, -1):
		var edge_y: float = maze_offset.y + cell.y * tile_size
		return maxf(0.0, world_pos.y - edge_y)
	return 0.0

func distance_to_center_along_direction(center: Vector2, dir: Vector2i) -> float:
	if dir == Vector2i.RIGHT:
		return maxf(0.0, center.x - head_world.x)
	if dir == Vector2i.LEFT:
		return maxf(0.0, head_world.x - center.x)
	if dir == Vector2i(0, 1):
		return maxf(0.0, center.y - head_world.y)
	if dir == Vector2i(0, -1):
		return maxf(0.0, head_world.y - center.y)
	return 0.0

func apply_requested_direction_if_possible(grid_controller) -> void:
	if can_apply_requested_direction(grid_controller):
		direction = requested_direction
		snap_to_centerline()

func can_apply_requested_direction(grid_controller) -> bool:
	if requested_direction == direction:
		return false

	if is_axis_turn(direction, requested_direction):
		if requested_direction.x != 0 and distance_to_nearest_center_y() > turn_snap_tolerance_px:
			return false
		if requested_direction.y != 0 and distance_to_nearest_center_x() > turn_snap_tolerance_px:
			return false

	return grid_controller.can_move(world_to_cell(head_world), requested_direction)

func is_axis_turn(from_dir: Vector2i, to_dir: Vector2i) -> bool:
	return (from_dir.x != 0 and to_dir.y != 0) or (from_dir.y != 0 and to_dir.x != 0)

func snap_to_centerline() -> void:
	var cell := world_to_cell(head_world)
	var center := grid_to_world(cell)
	if direction.x != 0:
		head_world.y = center.y
	elif direction.y != 0:
		head_world.x = center.x

func distance_to_nearest_center_x() -> float:
	var origin_x: float = maze_offset.x + tile_size * 0.5
	var relative_x: float = head_world.x - origin_x
	var center_index: float = roundf(relative_x / float(tile_size))
	var nearest_center_x: float = origin_x + center_index * tile_size
	return absf(head_world.x - nearest_center_x)

func distance_to_nearest_center_y() -> float:
	var origin_y: float = maze_offset.y + tile_size * 0.5
	var relative_y: float = head_world.y - origin_y
	var center_index: float = roundf(relative_y / float(tile_size))
	var nearest_center_y: float = origin_y + center_index * tile_size
	return absf(head_world.y - nearest_center_y)

func sync_cells_from_world() -> void:
	segment_cells.clear()
	for pos in segment_positions:
		segment_cells.append(world_to_cell(pos))

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = world_pos - maze_offset
	return Vector2i(
		int(floor(local.x / float(tile_size))),
		int(floor(local.y / float(tile_size)))
	)
