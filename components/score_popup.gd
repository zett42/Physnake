class_name ScorePopup
extends Node2D


const LIFETIME_SECONDS := 0.75
const START_FORWARD_OFFSET := 24.0
const START_SIDE_OFFSET := 18.0
const DRIFT_DISTANCE := 72.0
const DRIFT_SIDE_OFFSET := 36.0
const DRIFT_UP_OFFSET := 14.0
const POP_SCALE := Vector2(1.22, 1.22)
const NORMAL_COLOR := Color(0.92, 1.0, 0.78, 1.0)
const HIGH_VALUE_COLOR := Color(1.0, 0.78, 0.08, 1.0)
const HIGH_VALUE_POINTS := 12

@onready var _label := $Label as Label


func show_score(points: int, origin: Vector2, base_direction: Vector2) -> void:

	var direction := base_direction.normalized() if base_direction != Vector2.ZERO else Vector2.RIGHT
	var side_direction := direction.rotated(PI / 2.0)
	var start_offset := direction * START_FORWARD_OFFSET + side_direction * randf_range(-START_SIDE_OFFSET, START_SIDE_OFFSET)
	var drift_offset := (
		direction * DRIFT_DISTANCE
		+ side_direction * randf_range(-DRIFT_SIDE_OFFSET, DRIFT_SIDE_OFFSET)
		+ Vector2.UP * randf_range(0.0, DRIFT_UP_OFFSET)
	)

	global_position = origin + start_offset
	scale = Vector2(0.75, 0.75)

	_label.text = "+%d" % points
	_label.modulate = Color.WHITE
	_set_label_color(HIGH_VALUE_COLOR if points >= HIGH_VALUE_POINTS else NORMAL_COLOR)

	var drift_tween := create_tween()
	drift_tween.set_parallel(true)
	drift_tween.tween_property(self, "global_position", global_position + drift_offset, LIFETIME_SECONDS)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	drift_tween.tween_property(_label, "modulate:a", 0.0, LIFETIME_SECONDS)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)
	drift_tween.chain().tween_callback(queue_free)

	var pop_tween := create_tween()
	pop_tween.tween_property(self, "scale", POP_SCALE, 0.12)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(self, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)


func _set_label_color(color: Color):

	var settings := _label.label_settings.duplicate() as LabelSettings
	settings.font_color = color
	_label.label_settings = settings
