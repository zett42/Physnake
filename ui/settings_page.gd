extends ColorRect


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$FullscreenCheckButton.button_pressed = Global.is_fullscreen_enabled()
	$FpvControlsCheckButton.button_pressed = Global.is_fpv_controls_enabled()
	$DetailLevelOptionButton.select(_get_detail_level_item_index(Global.get_detail_level()))


func _on_fullscreen_check_button_toggled(toggled_on: bool):
	Global.set_fullscreen(toggled_on)


func _on_fpv_controls_check_button_toggled(toggled_on: bool):
	Global.set_fpv_controls(toggled_on)


func _on_detail_level_option_button_item_selected(index: int):
	Global.set_detail_level($DetailLevelOptionButton.get_item_id(index) as SettingsManager.DetailLevel)


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://ui/start.tscn")


func _get_detail_level_item_index(detail_level: SettingsManager.DetailLevel) -> int:
	for index in $DetailLevelOptionButton.item_count:
		if $DetailLevelOptionButton.get_item_id(index) == detail_level:
			return index

	return 0
