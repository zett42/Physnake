class_name SnakePoisonedAnimation
extends Node

## Handles the visual death animation for the snake when it bites itself
## Fades segments and joints to gray, spreading from collision point outward

const GRAY_COLOR: Color = Color(0.5, 0.5, 0.5, 1.0)

@export var animation_duration: float = 1.0
@export var shake_amplitude: float = 3.0
@export var shake_frequency: float = 20.0
@export var jitter_frequency_min: float = 0.85
@export var jitter_frequency_max: float = 2.5
@export var jitter_wobble_amplitude: float = 0.4
@export var jitter_wobble_frequency: float = 2.9

# Animation state
var is_animating: bool = false
var collision_segment_index: int = -1
var animation_time: float = 0.0

# References
var snake_head: RigidBody2D = null
var snake_controller: SnakeController = null
var joints: Array[SnakeJoint] = []


func initialize(head: RigidBody2D, controller: SnakeController) -> void:
	"""Initialize the animation with references to snake components."""
	snake_head = head
	snake_controller = controller


func register_joint(joint: SnakeJoint) -> void:
	"""Register a joint to be animated."""
	joints.append(joint)


func start_animation(collision_index: int) -> void:
	"""Start the poisoned animation from the given collision segment index.
	Use collision_index = -1 to start the animation from the head (e.g., for wall collisions)."""
	is_animating = true
	collision_segment_index = collision_index
	animation_time = 0.0


func update_animation(delta: float) -> void:
	"""Update the animation. Should be called every frame when animating."""
	if not is_animating:
		return
	
	animation_time += delta
	
	# Progress from 0 to 1 over the animation duration (clamped to ensure we reach 1.0)
	var progress: float = clamp(animation_time / animation_duration, 0.0, 1.0)
	
	# Calculate maximum spread distance in segments (from collision point to furthest end)
	var total_segments := snake_controller.segments.size() if snake_controller != null else 0
	var distance_to_head := collision_segment_index + 1  # Distance from collision to head (index -1)
	var distance_to_tail := (total_segments - 1) - collision_segment_index  # Distance to last segment
	var max_spread_distance := float(max(distance_to_head, distance_to_tail))
	
	# Current spread distance in segment indices (linearly increases)
	# Add +1 to ensure wave fully passes the furthest segment
	var current_spread := progress * (max_spread_distance + 1.0)
	
	# Fade head (treat as index -1)
	_fade_segment_to_gray(snake_head, -1, current_spread, collision_segment_index)
	_shake_segment(snake_head, -1, current_spread, collision_segment_index)
	
	# Fade body segments
	if snake_controller != null:
		for i in range(snake_controller.segments.size()):
			var segment := snake_controller.segments[i]
			if is_instance_valid(segment):
				_fade_segment_to_gray(segment, i, current_spread, collision_segment_index)
				_shake_segment(segment, i, current_spread, collision_segment_index)
	
	# Fade joints (joint i connects segment i-1 to segment i, or head to segment 0)
	for i in range(joints.size()):
		var joint := joints[i]
		if is_instance_valid(joint):
			# Joint connects to segment at index i, so use that segment's index for fade calculation
			_fade_joint_to_gray(joint, i, current_spread, collision_segment_index)
			_shake_joint(joint, i, current_spread, collision_segment_index)


func _fade_segment_to_gray(segment: Node2D, segment_index: int, current_spread: float, collision_index: int):
	"""Fade a single segment to gray based on its distance from collision point."""
	
	# Calculate distance in segments from collision point
	var distance_from_collision: float = abs(segment_index - collision_index)
	
	# Calculate fade amount based on how far the wave has spread past this segment
	var fade_amount: float
	if current_spread < distance_from_collision:
		# Wave hasn't reached this segment yet
		fade_amount = 0.0
	else:
		# Wave has reached or passed this segment
		# Fade over 1 segment distance for smooth transition
		var overshoot: float = current_spread - distance_from_collision
		fade_amount = clamp(overshoot, 0.0, 1.0)
	
	# Apply the fade if there's any amount to fade
	if fade_amount > 0.0:
		# Get the visual shape node and apply gray color
		if segment is RigidBody2D:
			# Find visible shape by looking for a visible Node2D child that has a "Fill" child
			var visible_shape: Node2D = _find_visible_shape(segment)
			
			if visible_shape != null:
				# Get the fill polygon (contains the main color)
				var fill: Polygon2D = visible_shape.get_node("Fill") if visible_shape.has_node("Fill") else null
				if fill != null:
					# Store original color if not already stored
					if not fill.has_meta("original_color"):
						fill.set_meta("original_color", fill.color)
					
					var original_color: Color = fill.get_meta("original_color")
					# Lerp from original color to gray
					fill.color = original_color.lerp(GRAY_COLOR, fade_amount)
			else:
				_restore_shake_offset(segment)
	else:
		_restore_shake_offset(segment)


func _fade_joint_to_gray(joint: SnakeJoint, joint_index: int, current_spread: float, collision_index: int):
	"""Fade a joint to gray. Joint at index i connects to segment i."""
	
	# Calculate distance: joint connects to segment at joint_index
	var distance_from_collision: float = abs(joint_index - collision_index)
	
	# Calculate fade amount (same logic as segments)
	var fade_amount: float
	if current_spread < distance_from_collision:
		fade_amount = 0.0
	else:
		var overshoot: float = current_spread - distance_from_collision
		fade_amount = clamp(overshoot, 0.0, 1.0)
	
	if fade_amount > 0.0 and joint.has_node("Line"):
		var line: Line2D = joint.get_node("Line")
		if line != null:
			# Store original color if not already stored
			if not line.has_meta("original_color"):
				line.set_meta("original_color", line.default_color)
			
			var original_color: Color = line.get_meta("original_color")
			# Lerp from original color to gray
			line.default_color = original_color.lerp(GRAY_COLOR, fade_amount)
	else:
		_restore_shake_offset(joint)


func _shake_segment(segment: Node2D, segment_index: int, current_spread: float, collision_index: int) -> void:
	"""Apply shake to a segment based on the same spread used for color fade."""
	var fade_amount: float = _compute_fade_amount(segment_index, current_spread, collision_index)
	if fade_amount <= 0.0:
		_restore_shake_offset(segment)
		return

	var decay: float = 1.0 - clamp(animation_time / animation_duration, 0.0, 1.0)
	var intensity: float = fade_amount * decay
	var jitter_seed: float = float(segment_index + 2) * 19.19
	var phase_jitter: float = _hash1(jitter_seed) * TAU
	var freq_jitter: float = lerp(jitter_frequency_min, jitter_frequency_max, _hash1(jitter_seed + 31.7))
	var wobble: float = sin(animation_time * jitter_wobble_frequency + jitter_seed) * jitter_wobble_amplitude
	var phase: float = (animation_time * shake_frequency * freq_jitter) + phase_jitter + wobble
	var offset := Vector2(sin(phase), cos(phase * 0.9 + phase_jitter * 0.3)) * (shake_amplitude * intensity)
	_apply_shake_offset(segment, offset)


func _shake_joint(joint: SnakeJoint, joint_index: int, current_spread: float, collision_index: int) -> void:
	"""Apply shake to a joint line to match the segment shake timing."""
	if not joint.has_node("Line"):
		return

	var fade_amount: float = _compute_fade_amount(joint_index, current_spread, collision_index)
	if fade_amount <= 0.0:
		_restore_shake_offset(joint)
		return

	var decay: float = 1.0 - clamp(animation_time / animation_duration, 0.0, 1.0)
	var intensity: float = fade_amount * decay
	var jitter_seed: float = float(joint_index + 5) * 17.77
	var phase_jitter: float = _hash1(jitter_seed) * TAU
	var freq_jitter: float = lerp(jitter_frequency_min, jitter_frequency_max, _hash1(jitter_seed + 13.3))
	var wobble: float = sin(animation_time * (jitter_wobble_frequency + 0.2) + jitter_seed) * (jitter_wobble_amplitude * 0.875)
	var phase: float = (animation_time * shake_frequency * freq_jitter) + phase_jitter + wobble
	var offset := Vector2(sin(phase * 1.1), cos(phase + phase_jitter * 0.2)) * (shake_amplitude * 0.6 * intensity)
	_apply_shake_offset(joint, offset)


func _compute_fade_amount(index: int, current_spread: float, collision_index: int) -> float:
	var distance_from_collision: float = abs(index - collision_index)
	if current_spread < distance_from_collision:
		return 0.0
	var overshoot: float = current_spread - distance_from_collision
	return clamp(overshoot, 0.0, 1.0)


func _hash1(value: float) -> float:
	var s: float = sin(value) * 43758.5453
	return s - floor(s)


func _apply_shake_offset(node: Node2D, offset: Vector2) -> void:
	if not node.has_meta("original_position"):
		node.set_meta("original_position", node.position)

	var original_position: Vector2 = node.get_meta("original_position")
	node.position = original_position + offset


func _restore_shake_offset(node: Node2D) -> void:
	if node != null and node.has_meta("original_position"):
		node.position = node.get_meta("original_position")



func _find_visible_shape(segment: Node2D) -> Node2D:
	"""Find the visible shape node by searching for a visible Node2D child with a Fill child."""
	for child in segment.get_children():
		if child is Node2D and child.visible and child.has_node("Fill"):
			return child
	return null
