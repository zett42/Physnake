class_name FpsDisplay
extends Label


@export var update_interval := 0.25

var _elapsed := 0.0


func _ready():

	_update_text()


func _process(delta):

	_elapsed += delta
	if _elapsed < update_interval:
		return

	_elapsed = 0.0
	_update_text()


func _update_text():

	text = "FPS: %d" % Engine.get_frames_per_second()
