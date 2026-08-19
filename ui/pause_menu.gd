extends CanvasLayer

const settings_scene := preload("res://ui/settings_page.tscn")

@onready var color_rect = $ColorRect

func _ready():
	# Make sure the pause menu is hidden initially
	color_rect.modulate.a = 0
	hide()

func _input(event):
	# Handle ESC key to toggle pause
	if event.is_action_pressed("ui_cancel"):  # ESC key is mapped to ui_cancel by default
		if Global.is_game_over():
			return
		toggle_pause()

func toggle_pause():
	if visible:
		fade_out_and_resume()
	else:
		pause_game()

func pause_game():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	show()
	# Fade in
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, 0.2)

func fade_out_and_resume():
	# Fade out
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.0, 0.2)
	await tween.finished
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	hide()

func resume_without_fade():
	get_tree().paused = false
	color_rect.modulate.a = 0
	hide()

func _on_continue_button_pressed():
	# Resume with fade effect
	fade_out_and_resume()

func _on_settings_button_pressed():
	var settings_page := settings_scene.instantiate()
	if settings_page.has_method("use_pause_overlay_mode"):
		settings_page.use_pause_overlay_mode()
	add_child(settings_page)

func _on_main_menu_button_pressed():
	resume_without_fade()
	# Return to start screen
	get_tree().change_scene_to_file("res://ui/start.tscn")

func _on_exit_button_pressed():
	resume_without_fade()
	# Quit the game
	get_tree().quit()
