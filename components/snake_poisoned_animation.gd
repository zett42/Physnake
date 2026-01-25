class_name SnakePoisonedAnimation
extends Node

## Handles the visual death animation for the snake when it bites itself
## Fades segments and joints to gray, spreading from collision point outward

const GRAY_COLOR: Color = Color(0.5, 0.5, 0.5, 1.0)

@export var animation_duration: float = 1.0

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
	"""Start the poisoned animation from the given collision segment index."""
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
	
	# Fade body segments
	if snake_controller != null:
		for i in range(snake_controller.segments.size()):
			var segment := snake_controller.segments[i]
			if is_instance_valid(segment):
				_fade_segment_to_gray(segment, i, current_spread, collision_segment_index)
	
	# Fade joints (joint i connects segment i-1 to segment i, or head to segment 0)
	for i in range(joints.size()):
		var joint := joints[i]
		if is_instance_valid(joint):
			# Joint connects to segment at index i, so use that segment's index for fade calculation
			_fade_joint_to_gray(joint, i, current_spread, collision_segment_index)


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



func _find_visible_shape(segment: Node2D) -> Node2D:
	"""Find the visible shape node by searching for a visible Node2D child with a Fill child."""
	for child in segment.get_children():
		if child is Node2D and child.visible and child.has_node("Fill"):
			return child
	return null