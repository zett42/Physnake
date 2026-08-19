extends ColorRect

var _pause_overlay_mode := false


func use_pause_overlay_mode():
	_pause_overlay_mode = true


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$FullscreenCheckButton.button_pressed = Global.is_fullscreen_enabled()
	$VSyncOptionButton.select(_get_vsync_mode_item_index(Global.get_vsync_mode()))
	$ShowFpsCheckButton.button_pressed = Global.is_show_fps_enabled()
	$FpvControlsCheckButton.button_pressed = Global.is_fpv_controls_enabled()
	$DetailLevelOptionButton.select(_get_detail_level_item_index(Global.get_detail_level()))
	$AntialiasingOptionButton.select(_get_antialiasing_level_item_index(Global.get_antialiasing_level()))


func _on_fullscreen_check_button_toggled(toggled_on: bool):
	Global.set_fullscreen(toggled_on)


func _on_v_sync_option_button_item_selected(index: int):
	Global.set_vsync_mode($VSyncOptionButton.get_item_id(index) as SettingsManager.VSyncMode)


func _on_show_fps_check_button_toggled(toggled_on: bool):
	Global.set_show_fps(toggled_on)


func _on_fpv_controls_check_button_toggled(toggled_on: bool):
	Global.set_fpv_controls(toggled_on)


func _on_detail_level_option_button_item_selected(index: int):
	Global.set_detail_level($DetailLevelOptionButton.get_item_id(index) as SettingsManager.DetailLevel)


func _on_antialiasing_option_button_item_selected(index: int):
	Global.set_antialiasing_level($AntialiasingOptionButton.get_item_id(index) as SettingsManager.AntialiasingLevel)


func _on_back_button_pressed():
	if _pause_overlay_mode:
		queue_free()
		return

	get_tree().change_scene_to_file("res://ui/start.tscn")


func _get_detail_level_item_index(detail_level: SettingsManager.DetailLevel) -> int:
	for index in $DetailLevelOptionButton.item_count:
		if $DetailLevelOptionButton.get_item_id(index) == detail_level:
			return index

	return 0


func _get_vsync_mode_item_index(vsync_mode: SettingsManager.VSyncMode) -> int:
	for index in $VSyncOptionButton.item_count:
		if $VSyncOptionButton.get_item_id(index) == vsync_mode:
			return index

	return 0


func _get_antialiasing_level_item_index(antialiasing_level: SettingsManager.AntialiasingLevel) -> int:
	for index in $AntialiasingOptionButton.item_count:
		if $AntialiasingOptionButton.get_item_id(index) == antialiasing_level:
			return index

	return 0
