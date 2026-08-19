class_name SnakeTimeBonusIndicator
extends Node2D


const MAX_BONUS_SEGMENTS := 5
const FIRST_SEGMENT_ALPHA := 0.9
const LAST_SEGMENT_ALPHA := 0.6
const MARKER_COLOR = Color(0.0, 0.7, 0.0)
const MARKER_BORDER_GAP := 3.0
const MARKER_SEGMENTS := 24
const MARKER_NODE_NAME := "TimeBonusMarker"

var _highlighted_segments: Array[SnakeBody] = []


func set_bonus_segments(segments: Array[RigidBody2D], bonus_value: float):

	clear_highlights()

	var clamped_bonus := clampf(bonus_value, 0.0, float(MAX_BONUS_SEGMENTS))
	var full_segments := floori(clamped_bonus)
	var partial_segment_ratio := clamped_bonus - full_segments
	var segments_to_highlight := mini(ceili(clamped_bonus), segments.size())

	for index in range(segments_to_highlight):
		var segment := segments[index] as SnakeBody
		if not is_instance_valid(segment):
			continue

		var segment_ratio := 1.0
		if index == full_segments:
			segment_ratio = partial_segment_ratio

		_apply_segment_highlight(segment, index, segment_ratio)
		_highlighted_segments.append(segment)


func _apply_segment_highlight(segment: SnakeBody, index: int, segment_ratio: float):

	var falloff := 1.0
	if MAX_BONUS_SEGMENTS > 1:
		falloff = 1.0 - (float(index) / float(MAX_BONUS_SEGMENTS - 1))

	var alpha := lerpf(LAST_SEGMENT_ALPHA, FIRST_SEGMENT_ALPHA, falloff) * segment_ratio

	for marker in _get_segment_indicator_markers(segment):
		marker.visible = alpha > 0.0
		marker.color = Color(MARKER_COLOR, alpha)


func clear_highlights():

	for segment in _highlighted_segments:
		if not is_instance_valid(segment):
			continue

		for marker in _get_segment_indicator_markers(segment):
			marker.visible = false

	_highlighted_segments.clear()


func _get_segment_indicator_markers(segment: SnakeBody) -> Array[VisibleCircleShape2D]:

	var result: Array[VisibleCircleShape2D] = []
	_append_indicator_marker(result, segment.get_node_or_null("VisibleShape_normal"))
	_append_indicator_marker(result, segment.get_node_or_null("VisibleShape_big"))
	return result


func _append_indicator_marker(result: Array[VisibleCircleShape2D], visible_shape: Node):

	if not visible_shape:
		return

	var marker := visible_shape.get_node_or_null(MARKER_NODE_NAME) as VisibleCircleShape2D
	if not marker:
		marker = _create_indicator_marker(visible_shape)

	result.append(marker)


func _create_indicator_marker(visible_shape: Node) -> VisibleCircleShape2D:

	var marker := VisibleCircleShape2D.new()
	marker.name = MARKER_NODE_NAME
	marker.radius = maxf(1.0, visible_shape.get("radius") - visible_shape.get("border_width") - MARKER_BORDER_GAP)
	marker.enable_fill = true
	marker.num_circle_segments = MARKER_SEGMENTS
	marker.color = MARKER_COLOR
	marker.visible = false
	visible_shape.add_child(marker)
	marker.update_polygon_nodes()
	return marker
