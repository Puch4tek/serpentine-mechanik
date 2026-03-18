extends Node2D

func toggle_pause():
	if get_tree().paused:
		resume_game()
	else:
		pause_game()

func pause_game():
	get_tree().paused = true
	$CanvasLayer/Pause.visible = true
	
func resume_game():
	get_tree().paused = false
	$CanvasLayer/Pause.visible = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_reset_button_pressed() -> void:
	get_tree().reload_current_scene()


func _on_pause_button_pressed() -> void:
	pause_game()
	
