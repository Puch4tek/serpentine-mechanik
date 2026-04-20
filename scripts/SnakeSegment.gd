extends Node2D

@onready var sprite = $Sprite2D

func set_head(texture):
	sprite.texture = texture

func set_body(texture):
	sprite.texture = texture

func update_visual(is_corner: bool, rotation_angle: float, texture: Texture2D) -> void:
	sprite.texture = texture
	if is_corner:
		sprite.rotation = rotation_angle + PI / 2.0
	else:
		sprite.rotation = 0.0

