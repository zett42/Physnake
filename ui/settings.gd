extends ColorRect


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://ui/start.tscn")
