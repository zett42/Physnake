extends ColorRect


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$FullscreenCheckButton.button_pressed = Global.is_fullscreen_enabled()


func _on_fullscreen_check_button_toggled(toggled_on: bool):
	Global.set_fullscreen(toggled_on)


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://ui/start.tscn")
