extends TileMapLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if (Input.is_action_pressed("mb_left")):
		set_cell(local_to_map(get_global_mouse_position()), 0, Vector2i(1,2))