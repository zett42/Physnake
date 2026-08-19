class_name FpsDisplay
extends Label


@export var update_interval := 0.25

var _elapsed := 0.0


func _ready():

	visible = Global.is_show_fps_enabled()
	if not Global.show_fps_changed.is_connected(_on_show_fps_changed):
		Global.show_fps_changed.connect(_on_show_fps_changed)

	_update_text()


func _exit_tree():

	if Global.show_fps_changed.is_connected(_on_show_fps_changed):
		Global.show_fps_changed.disconnect(_on_show_fps_changed)


func _process(delta):

	_elapsed += delta
	if _elapsed < update_interval:
		return

	_elapsed = 0.0
	_update_text()


func _update_text():

	text = "FPS: %d" % Engine.get_frames_per_second()


func _on_show_fps_changed(enabled: bool):

	visible = enabled
