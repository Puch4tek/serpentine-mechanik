extends Control


func start_game():
	Transition.fade_to_scene("res://scenes/Game.tscn")

func _unhandled_input(event):
	if event.is_action_pressed("mb_left"):
		start_game()
		
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mb_left"):
		start_game()