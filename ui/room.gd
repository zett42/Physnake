extends Node2D

func _ready():

	Global.reset_game_state()

	get_tree().paused = false

	var child_scene: PackedScene = null
	if Global.difficulty == Global.Difficulty.HARD:
		child_scene = load("res://interior/hard_mode.tscn")
	else:
		child_scene = load("res://interior/normal_mode.tscn") 

	add_child( child_scene.instantiate() )
