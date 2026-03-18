extends CanvasLayer

@onready var anim: AnimationPlayer = $AnimationPlayer

func fade_to_scene(path):

	anim.play("fade_out")
	await anim.animation_finished

	get_tree().change_scene_to_file(path)

	anim.play("fade_in")
	

