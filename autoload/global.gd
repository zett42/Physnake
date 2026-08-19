extends Node

signal detail_level_changed(level: SettingsManager.DetailLevel)
signal show_fps_changed(enabled: bool)

@export var time_bonus: int = 0:
	get:
		return time_bonus
	set( value ):
		if time_bonus != value:
			time_bonus = value
			var time_bonus_node = get_node("/root/Room/ScorePanel/TimeBonus")
			if time_bonus_node:
				time_bonus_node.text = "Time Bonus: %d" % time_bonus


enum Difficulty {
	EASY,
	NORMAL,
	HARD
}

@export var difficulty = Difficulty.NORMAL

var total_score: int = 0
var total_bonus: int = 0
var total_golden_score: int = 0
var total_head_distance: float = 0.0
var play_time: float = 0.0

var _is_game_over: bool = false
var _detail_level_applier := DetailLevelApplier.new()
var settings := SettingsManager.new()


func get_difficulty_name(diff: Difficulty) -> String:

	return Difficulty.keys()[diff]


func _ready():
	
	settings.load_settings()
	settings.apply_startup_settings()
	
	add_child(_detail_level_applier)
	_detail_level_applier.initialize(self)


func _exit_tree():
	_save_window_bounds()


func reset_game_state():

	_is_game_over = false
	total_score = 0
	total_bonus = 0
	total_golden_score = 0
	total_head_distance = 0.0
	play_time = 0.0
	update_speed_display()
		

func get_total_score():

	return total_score


func get_total_bonus():

	return total_bonus


func get_total_golden_score():

	return total_golden_score


func get_total_head_distance() -> float:

	return total_head_distance


func get_play_time() -> float:

	return play_time


func get_average_speed() -> float:

	if play_time <= 0.0:
		return 0.0

	return total_head_distance / play_time


func add_head_movement(distance: float, delta: float):

	if _is_game_over:
		return

	total_head_distance += maxf(distance, 0.0)
	play_time += maxf(delta, 0.0)
	update_speed_display()
	
	
func is_game_over() -> bool:
	
	return _is_game_over
	

func add_score( amount: int = 1 ):

	total_score += amount

	update_score_display()
	

func add_bonus( value: int ):

	total_bonus += value
	total_score += value

	update_score_display()


func add_golden_score( value: int ):

	total_golden_score += value


func update_score_display():

	var score_node = get_node("/root/Room/ScorePanel/Score")
	if score_node:
		score_node.text = "Score: %d" % total_score


func update_speed_display():

	var speed_node = get_node_or_null("/root/Room/ScorePanel/AvgSpeed")
	if speed_node:
		speed_node.text = "Avg Speed: %.0f" % get_average_speed()


func set_game_over():
	
	_is_game_over = true
	
	$GameOverTimer.start()


func _on_game_over_timer_timeout():
	
	get_tree().paused = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().root.add_child( preload("res://ui/game_over.tscn").instantiate() )


func is_fullscreen_enabled() -> bool:
	return settings.fullscreen


func set_fullscreen(enabled: bool):
	settings.set_fullscreen(enabled)


func get_vsync_mode() -> SettingsManager.VSyncMode:
	return settings.vsync_mode


func set_vsync_mode(mode: SettingsManager.VSyncMode):
	settings.set_vsync_mode(mode)


func is_show_fps_enabled() -> bool:
	return settings.show_fps


func set_show_fps(enabled: bool):
	var previous_enabled := settings.show_fps
	settings.set_show_fps(enabled)
	if settings.show_fps != previous_enabled:
		show_fps_changed.emit(settings.show_fps)


func is_fpv_controls_enabled() -> bool:
	return settings.fpv_controls


func set_fpv_controls(enabled: bool):
	settings.set_fpv_controls(enabled)


func get_detail_level() -> SettingsManager.DetailLevel:
	return settings.detail_level


func set_detail_level(level: SettingsManager.DetailLevel):
	var previous_level := settings.detail_level
	settings.set_detail_level(level)
	if settings.detail_level != previous_level:
		detail_level_changed.emit(settings.detail_level)


func get_antialiasing_level() -> SettingsManager.AntialiasingLevel:
	return settings.antialiasing_level


func set_antialiasing_level(level: SettingsManager.AntialiasingLevel):
	settings.set_antialiasing_level(level)


func _save_window_bounds():
	settings.set_window_bounds(
		DisplayServer.window_get_position_with_decorations(),
		DisplayServer.window_get_size(),
		DisplayServer.window_get_mode()
	)
