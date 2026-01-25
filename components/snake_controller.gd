class_name SnakeController
extends Node

## Controls snake trail-following behavior using breadcrumb path
## Records head positions and provides target positions for body segments

# Breadcrumb recording
const BREADCRUMB_RECORD_DISTANCE: float = 2.0  # Record every 2 pixels

# Path guidance tuning
@export var path_guidance_kp: float = 50.0     # Position stiffness (gentle guidance)
@export var path_guidance_kd: float = 1.5      # Velocity damping - reduces oscillations
@export var max_guidance_force: float = 200.0  # Force clamp (keep it subtle)
@export var reference_speed: float = 400.0     # Speed for drive factor calculation
@export var min_drive_threshold: float = 0.1   # Minimum speed ratio to activate guidance

# Breadcrumb storage (append-only for performance)
var breadcrumb_positions: PackedVector2Array = PackedVector2Array()
var breadcrumb_lengths: PackedFloat32Array = PackedFloat32Array()  # Cumulative arc length at each point
var total_length: float = 0.0

# Snake segments tracking
var head: RigidBody2D = null
var segments: Array[RigidBody2D] = []

# Last recorded position
var last_recorded_position: Vector2 = Vector2.ZERO


func initialize(snake_head: RigidBody2D) -> void:
	"""Initialize the controller with the snake head."""
	head = snake_head
	last_recorded_position = snake_head.global_position
	
	# Record initial breadcrumb
	breadcrumb_positions.append(snake_head.global_position)
	breadcrumb_lengths.append(0.0)
	total_length = 0.0


func register_segment(segment: RigidBody2D, joint_length: float) -> void:
	"""Register a new body segment with the controller."""
	segments.append(segment)
	segment.set_meta("spawn_time", Time.get_ticks_msec())
	segment.set_meta("joint_length", joint_length)


func _physics_process(_delta: float) -> void:
	if head == null or not is_instance_valid(head):
		return
	
	# Record breadcrumbs as head moves
	_record_breadcrumbs()
	
	# Update segment targets
	_update_segment_targets()
	
	# Clean up old breadcrumbs to avoid unbounded growth
	_cleanup_breadcrumbs()


func _record_breadcrumbs() -> void:
	"""Record head position when it has moved far enough."""
	var current_position := head.global_position
	var distance_moved := current_position.distance_to(last_recorded_position)
	
	if distance_moved >= BREADCRUMB_RECORD_DISTANCE:
		# Append new breadcrumb at the end
		breadcrumb_positions.append(current_position)
		total_length += distance_moved
		breadcrumb_lengths.append(total_length)
		
		last_recorded_position = current_position


func _update_segment_targets() -> void:
	"""Efficiently assign target positions to all segments in one pass."""
	if breadcrumb_positions.size() < 2:
		return
	
	# Calculate drive factor (0 = idle, 1 = moving), that avoids unwanted movement when the head is stopped.
	# Use squared scaling for smoother transition
	var drive_factor := 0.0
	if is_instance_valid(head):
		var speed_ratio := head.linear_velocity.length() / reference_speed
		if speed_ratio > min_drive_threshold:
			drive_factor = clampf(speed_ratio, 0.0, 1.0)
			drive_factor = drive_factor * drive_factor  # Square for smoother ramp
		
	# Accumulate actual distances for precise positioning
	var accumulated_distance := 0.0
	
	for i in range(segments.size()):
		if not is_instance_valid(segments[i]):
			continue
		
		# Get this segment's actual joint length
		var joint_length := segments[i].get_meta("joint_length", 25.0) as float
		accumulated_distance += joint_length
		
		# Calculate target distance behind the head
		var target_length := total_length - accumulated_distance
		
		# Find the target position on the breadcrumb path
		var target_position := _sample_position_at_length(target_length)
		
		# Apply path guidance force (PD controller)
		_apply_guidance_force(segments[i], target_position, drive_factor)
		
		# Store for potential use by segment
		segments[i].set_meta("target_position", target_position)
		segments[i].set_meta("drive_factor", drive_factor)


func _sample_position_at_length(target_length: float) -> Vector2:
	"""Sample a position at a given arc length along the breadcrumb path."""
	
	# Clamp to available range
	if target_length <= 0.0:
		return breadcrumb_positions[0]
	if target_length >= total_length:
		return breadcrumb_positions[breadcrumb_positions.size() - 1]
	
	# Binary search for efficiency (could also be linear since we often search in order)
	var left := 0
	var right := breadcrumb_lengths.size() - 1
	
	while left < right:
		var mid := int((left + right + 1) / 2.0)
		if breadcrumb_lengths[mid] <= target_length:
			left = mid
		else:
			right = mid - 1
	
	var index := left
	
	# Interpolate between points if needed
	if index < breadcrumb_lengths.size() - 1:
		var length_before := breadcrumb_lengths[index]
		var length_after := breadcrumb_lengths[index + 1]
		var segment_length := length_after - length_before
		
		if segment_length > 0.001:
			var t := (target_length - length_before) / segment_length
			return breadcrumb_positions[index].lerp(breadcrumb_positions[index + 1], t)
	
	return breadcrumb_positions[index]


func _apply_guidance_force(segment: RigidBody2D, target_position: Vector2, drive_factor: float) -> void:
	"""Apply PD force to guide segment toward its target."""
	
	# Calculate PD force
	var position_error := target_position - segment.global_position
	var velocity_error := -segment.linear_velocity
	
	var force := path_guidance_kp * position_error + path_guidance_kd * velocity_error
	
	# Scale by drive factor (weaker when idle)
	force *= drive_factor
	
	# Clamp force magnitude for stability
	if force.length() > max_guidance_force:
		force = force.normalized() * max_guidance_force
	
	# Apply the force
	segment.apply_central_force(force)


func _cleanup_breadcrumbs() -> void:
	"""Remove old breadcrumbs that are no longer needed."""
	
	# Calculate required history length based on actual segment lengths
	var max_segment_distance := 0.0
	for segment in segments:
		if is_instance_valid(segment):
			max_segment_distance += segment.get_meta("joint_length", 25.0) as float
	max_segment_distance += 125.0  # Add margin (5 segments worth at base length)
	var min_required_length := total_length - max_segment_distance
	
	# Remove breadcrumbs before the required length
	var remove_count := 0
	for i in range(breadcrumb_lengths.size()):
		if breadcrumb_lengths[i] < min_required_length:
			remove_count = i + 1
		else:
			break
	
	# Keep at least 2 breadcrumbs
	if remove_count > 0 and breadcrumb_positions.size() - remove_count >= 2:
		# Remove from the start (less efficient but happens infrequently)
		var new_positions := PackedVector2Array()
		var new_lengths := PackedFloat32Array()
		
		for i in range(remove_count, breadcrumb_positions.size()):
			new_positions.append(breadcrumb_positions[i])
			new_lengths.append(breadcrumb_lengths[i])
		
		breadcrumb_positions = new_positions
		breadcrumb_lengths = new_lengths


func get_segment_count() -> int:
	"""Get the number of registered segments."""
	return segments.size()


func get_breadcrumb_count() -> int:
	"""Get the number of breadcrumbs stored."""
	return breadcrumb_positions.size()


func get_total_path_length() -> float:
	"""Get the total arc length of the recorded path."""
	return total_length
