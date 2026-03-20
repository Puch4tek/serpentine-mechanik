extends Node2D

@onready var sprite = $Sprite2D

func set_head(texture):
	sprite.texture = texture

func set_body(texture):
	sprite.texture = texture
