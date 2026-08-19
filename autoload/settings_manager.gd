class_name SettingsManager
extends RefCounted


const SETTINGS_FILE = "user://settings.cfg"

var fullscreen: bool = false
var maximized: bool = false
var window_position: Vector2i = Vector2i.ZERO
var window_size: Vector2i = Vector2i.ZERO


func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)

	if err != OK:
		return

	fullscreen = config.get_value("display", "fullscreen", false)
	maximized = config.get_value("display", "maximized", false)
	window_position = Vector2i(
		config.get_value("display", "window_x", 0),
		config.get_value("display", "window_y", 0)
	)
	window_size = Vector2i(
		config.get_value("display", "window_width", 0),
		config.get_value("display", "window_height", 0)
	)


func save_settings():
	var config = ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "maximized", maximized)
	config.set_value("display", "window_x", window_position.x)
	config.set_value("display", "window_y", window_position.y)
	config.set_value("display", "window_width", window_size.x)
	config.set_value("display", "window_height", window_size.y)

	var err = config.save(SETTINGS_FILE)
	if err != OK:
		push_error("Failed to save settings: " + str(err))


func set_fullscreen(enabled: bool):
	if fullscreen == enabled:
		return

	fullscreen = enabled
	if fullscreen:
		maximized = false

	_apply_window_mode()
	save_settings()


func apply_startup_settings():
	_apply_window_mode()

	if not fullscreen and not maximized:
		_restore_window_bounds()


func set_window_bounds(position: Vector2i, size: Vector2i, window_mode: DisplayServer.WindowMode):
	if fullscreen or size == Vector2i.ZERO:
		return

	var is_maximized = window_mode == DisplayServer.WINDOW_MODE_MAXIMIZED
	if maximized == is_maximized and window_position == position and window_size == size:
		return

	maximized = is_maximized
	window_position = position
	window_size = size
	save_settings()


func _restore_window_bounds():
	if window_size == Vector2i.ZERO:
		window_size = _get_default_window_size()
		window_position = _get_centered_window_position(window_size)
		_apply_window_bounds(window_position, window_size)
		save_settings()
		return

	var decorated_window_rect = _get_decorated_window_rect(window_position, window_size)
	if not _is_window_rect_visible(decorated_window_rect):
		var adjusted_window_bounds = _get_adjusted_window_bounds(window_position, window_size)
		window_position = adjusted_window_bounds.position
		window_size = adjusted_window_bounds.size
		save_settings()

	_apply_window_bounds(window_position, window_size)


func _is_window_rect_visible(window_rect: Rect2i) -> bool:
	for screen_index in DisplayServer.get_screen_count():
		var screen_rect = DisplayServer.screen_get_usable_rect(screen_index)
		if screen_rect.encloses(window_rect):
			return true

	return false


func _get_default_window_size() -> Vector2i:
	var project_default_size = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width", 1152),
		ProjectSettings.get_setting("display/window/size/viewport_height", 648)
	)
	var screen_rect = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	return project_default_size.min(_get_max_client_size_for_screen(screen_rect))


func _get_centered_window_position(size: Vector2i) -> Vector2i:
	var screen_rect = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var decorated_size = _get_decorated_window_size(size)
	return screen_rect.position + ((screen_rect.size - decorated_size) / 2)


func _get_adjusted_window_bounds(position: Vector2i, size: Vector2i) -> Rect2i:
	var window_rect = _get_decorated_window_rect(position, size)
	var screen_rect = _get_best_screen_rect(window_rect)
	var adjusted_size = _get_adjusted_window_size(size, screen_rect)
	var adjusted_position = _get_adjusted_window_position(position, adjusted_size, screen_rect)

	return Rect2i(adjusted_position, adjusted_size)


func _apply_window_bounds(decorated_position: Vector2i, size: Vector2i):
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(_get_client_position(decorated_position))


func _get_decorated_window_rect(decorated_position: Vector2i, size: Vector2i) -> Rect2i:
	return Rect2i(decorated_position, _get_decorated_window_size(size))


func _get_decorated_window_size(size: Vector2i) -> Vector2i:
	return size + _get_window_decoration_size()


func _get_window_decoration_size() -> Vector2i:
	return (DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()).max(Vector2i.ZERO)


func _get_client_position(decorated_position: Vector2i) -> Vector2i:
	return decorated_position + _get_window_decoration_offset()


func _get_window_decoration_offset() -> Vector2i:
	return DisplayServer.window_get_position() - DisplayServer.window_get_position_with_decorations()


func _get_adjusted_window_size(size: Vector2i, screen_rect: Rect2i) -> Vector2i:
	return size.min(_get_max_client_size_for_screen(screen_rect))


func _get_max_client_size_for_screen(screen_rect: Rect2i) -> Vector2i:
	var max_size = screen_rect.size - _get_window_decoration_size()
	return max_size.max(Vector2i.ONE)


func _get_adjusted_window_position(position: Vector2i, size: Vector2i, screen_rect: Rect2i) -> Vector2i:
	var visible_rect = _get_decorated_window_rect(position, size)
	var adjusted_position = position

	if visible_rect.position.x < screen_rect.position.x:
		adjusted_position.x += screen_rect.position.x - visible_rect.position.x
	elif visible_rect.end.x > screen_rect.end.x:
		adjusted_position.x -= visible_rect.end.x - screen_rect.end.x

	if visible_rect.position.y < screen_rect.position.y:
		adjusted_position.y += screen_rect.position.y - visible_rect.position.y
	elif visible_rect.end.y > screen_rect.end.y:
		adjusted_position.y -= visible_rect.end.y - screen_rect.end.y

	return adjusted_position


func _get_best_screen_rect(window_rect: Rect2i) -> Rect2i:
	var best_screen_rect = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var best_overlap_area = -1

	for screen_index in DisplayServer.get_screen_count():
		var screen_rect = DisplayServer.screen_get_usable_rect(screen_index)
		var overlap_area = _get_overlap_area(window_rect, screen_rect)
		if overlap_area > best_overlap_area:
			best_screen_rect = screen_rect
			best_overlap_area = overlap_area

	return best_screen_rect


func _get_overlap_area(a: Rect2i, b: Rect2i) -> int:
	var overlap_left = maxi(a.position.x, b.position.x)
	var overlap_top = maxi(a.position.y, b.position.y)
	var overlap_right = mini(a.end.x, b.end.x)
	var overlap_bottom = mini(a.end.y, b.end.y)

	if overlap_right <= overlap_left or overlap_bottom <= overlap_top:
		return 0

	return (overlap_right - overlap_left) * (overlap_bottom - overlap_top)


func _apply_window_mode():
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif maximized:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
