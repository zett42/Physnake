class_name SettingsManager
extends RefCounted


const SETTINGS_FILE = "user://settings.cfg"

var fullscreen: bool = false


func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)

	if err != OK:
		return

	fullscreen = config.get_value("display", "fullscreen", false)


func save_settings():
	var config = ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen)

	var err = config.save(SETTINGS_FILE)
	if err != OK:
		push_error("Failed to save settings: " + str(err))


func set_fullscreen(enabled: bool):
	if fullscreen == enabled:
		return

	fullscreen = enabled
	_apply_fullscreen()
	save_settings()


func apply_startup_settings():
	_apply_fullscreen()


func _apply_fullscreen():
	var mode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
