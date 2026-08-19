extends Node2D

func _ready():

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Global.reset_game_state()
	$ScorePanel/FpsDisplay.visible = Global.is_show_fps_enabled()

	get_tree().paused = false

	var child_scene: PackedScene = null
	if Global.difficulty == Global.Difficulty.HARD:
		child_scene = load("res://interior/hard_mode.tscn")
	elif Global.difficulty == Global.Difficulty.EASY:
		child_scene = load("res://interior/easy_mode.tscn")
	else:
		child_scene = load("res://interior/normal_mode.tscn") 

	add_child( child_scene.instantiate() )
