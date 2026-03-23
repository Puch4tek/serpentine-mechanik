extends Resource
class_name LevelData

@export var width: int = 13
@export var height: int = 11
@export var snake_spawn: Vector2i = Vector2i(6, 5)
@export var enemy_spawns: Array[Vector2i] = [Vector2i(1, 1)]

@export var cells : PackedInt32Array

