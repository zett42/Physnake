extends RigidBody2D

# Movement speed and acceleration (when key is hold)
const SNAKE_MIN_SPEED: float = 300
const SNAKE_MAX_SPEED: float = 2000
const SNAKE_MAX_SPEED_AUTO: float = 750  # Lower speed for automatic movement mode
const SNAKE_ACCELERATION: float = 20

# Force threshold for deadly wall collision
const DEADLY_WALL_IMPACT_THRESHOLD: float = 115.0  # Minimum velocity for deadly wall impact. This is carefully tuned to allow diagonal collisions without death.

# Time bonus constants
const MAX_TIME_BONUS: float = 5
const TIME_BONUS_DURATION: float = 3.0
const MAX_FOOD_AWARD_POINTS := 36.0
const EAT_SOUND_MIN_VOLUME_DB := -5.0
const EAT_SOUND_MAX_VOLUME_DB := 5.0

# Joint length constants
const JOINT_BASE_REST_LENGTH: float = 25.0  # Base rest length from joint scene
const JOINT_HEAD_BONUS: float = 4.0  # Extra length when connecting to head
const JOINT_BIG_SEGMENT_BONUS: float = 6.0  # Extra length for big segments

# Components that will be spawned.
const body_scene  := preload("res://components/snake_body.tscn") as PackedScene
const joint_scene := preload("res://components/snake_joint.tscn") as PackedScene

# Snake controller for trail-following behavior
var controller: SnakeController = null

# Current tail. This starts with self to be able to connect initial tail to head.
var tail: PhysicsBody2D = self

# Current snake speed
var current_speed: float = SNAKE_MIN_SPEED

## Initial movement direction of the snake (used in automatic movement).
@export var start_direction: Vector2 = Vector2.RIGHT

# Current direction for automatic movement
@onready var current_direction: Vector2 = start_direction.normalized() if start_direction != Vector2.ZERO else Vector2.RIGHT
var last_effective_direction: Vector2 = Vector2.ZERO

# Boost mechanic for automatic movement
var boost_hold_time: float = 0.0  # Time keys matching direction have been held
const BOOST_DELAY: float = 0.25  # Delay before boost activates (in seconds)

# Time bonus if snake eats food quickly.
var time_bonus: float = 0.0

# Food digestion buffer for natural segment spawning
var food_buffer: Array[Dictionary] = []  # Stores {food_size: Food.FoodSize, tail_position: Vector2}
var tail_spawn_distance: float = 0.0  # Accumulated distance traveled by tail

# Death animation
var poisoned_animation: SnakePoisonedAnimation = null

# Force-based wall collision detection
var last_velocity: Vector2 = Vector2.ZERO  # Track velocity for impact detection
var last_contact_normal: Vector2 = Vector2.ZERO  # Contact normal from last collision

# Wall proximity detection to prevent slowdown exploit
const WALL_PROXIMITY_DISTANCE: float = 50.0  # Distance to check for nearby walls
const WALL_COLLISION_LAYER: int = 1  # Walls are on layer 1
const WALL_SLIDING_DISTANCE_BUFFER: float = 2.0  # Extra distance beyond head radius for sliding activation
const WALL_SLIDING_VELOCITY_THRESHOLD: float = 150.0  # Max velocity toward wall to trigger parallel sliding
const MIN_PARALLEL_COMPONENT_LENGTH_SQ: float = 0.001  # Minimum parallel component magnitude squared
const INPUT_DIRECTION_THRESHOLD: float = 0.05  # Minimum input to detect directional intent
const MIN_EFFECTIVE_DIRECTION_SPEED: float = 10.0  # Minimum speed used to derive FPV direction from velocity
const EIGHT_WAY_AXIS_DOMINANCE: float = 2.41421356237  # tan(67.5 degrees), for nearest 45-degree snap
const MIN_VISUAL_DIRECTION_LENGTH_SQUARED := 1.0
var wall_raycast_up: RayCast2D
var wall_raycast_down: RayCast2D
var wall_raycast_left: RayCast2D
var wall_raycast_right: RayCast2D

# Head collision radius (retrieved from collision shape)
var head_radius: float = 15.0

@onready var time_bonus_indicator := $TimeBonusIndicator as SnakeTimeBonusIndicator


func _ready():
	
	# To process input without _input() method
	set_process_input( true )
	
	# Enable Continuous Collision Detection for fast movement
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	
	# Enable contact monitoring for collision normal detection
	contact_monitor = true
	max_contacts_reported = 4
	
	# Get head radius from collision shape
	var collision_shape := $CollisionShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		head_radius = (collision_shape.shape as CircleShape2D).radius
	
	# Create and initialize the snake controller
	controller = SnakeController.new()
	add_child(controller)
	controller.initialize(self)
	
	# Create and initialize the poisoned animation
	poisoned_animation = SnakePoisonedAnimation.new()
	add_child(poisoned_animation)
	poisoned_animation.initialize(self, controller)
	
	# Setup wall proximity detection raycasts
	_setup_wall_proximity_raycasts()

	# Add initial snake tail. As tree is locked in _ready(), it must be called deferred.
	call_deferred( "_spawn_tail", Food.FoodSize.NORMAL )


func _process( delta ):
	
	if poisoned_animation != null and poisoned_animation.is_animating:
		# Play death animation
		poisoned_animation.update_animation(delta)
		return
	
	time_bonus = maxf( 0, time_bonus - MAX_TIME_BONUS / TIME_BONUS_DURATION * delta )
	Global.time_bonus = ceili( time_bonus )
	time_bonus_indicator.set_bonus_segments(controller.segments, time_bonus)
	
	# Check if we should spawn buffered segments based on tail movement
	_check_tail_spawning()
	_update_visual_direction()


func _update_visual_direction():

	var direction := linear_velocity
	if direction.length_squared() < MIN_VISUAL_DIRECTION_LENGTH_SQUARED:
		direction = current_direction

	if direction.length_squared() >= MIN_VISUAL_DIRECTION_LENGTH_SQUARED:
		$VisibleShape.rotation = direction.angle()


func _integrate_forces( state: PhysicsDirectBodyState2D ):

	if Global.is_game_over():
		# Store velocity even during game over for proper animation
		last_velocity = linear_velocity
		return
	
	# Track velocity for force-based collision detection
	last_velocity = linear_velocity
	
	# Get contact normal from physics state for accurate collision detection
	last_contact_normal = Vector2.ZERO
	var contact_count := state.get_contact_count()
	if contact_count > 0:
		# Use the first contact's normal (or could iterate to find strongest)
		last_contact_normal = state.get_contact_local_normal(0)

	_handle_automatic_movement(state.step)


func _handle_automatic_movement(delta: float):
	"""Handle automatic forward movement."""
	
	# Only change direction when a key is newly pressed, but sample all held keys for diagonals
	var direction_changed := false
	
	# Detect vertical input
	if Input.is_action_just_pressed("move_up"):
		direction_changed = true
	elif not Global.is_fpv_controls_enabled() and Input.is_action_just_pressed("move_down"):
		direction_changed = true
	
	# Detect horizontal input  
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
		direction_changed = true
	
	# When a direction key is pressed, sample all currently held keys
	if direction_changed:
		var new_direction := _get_input_direction()
		
		# Only change direction if it's not opposite to current direction
		if new_direction != Vector2.ZERO:
			# Prevent turning 180 degrees (opposite direction)
			if new_direction.dot(current_direction) > -0.9:  # Not opposite (allowing some tolerance)
				# Adjust direction if near wall to prevent slowdown exploit
				new_direction = _adjust_direction_for_wall_proximity(new_direction)
				current_direction = new_direction
				# Reset boost timer when direction changes
				boost_hold_time = 0.0
	
	# Check if player is holding keys matching the current direction (boost mechanic)
	var held_direction := _get_input_direction()
	
	# Determine target speed based on whether held keys match current direction
	var target_speed := SNAKE_MAX_SPEED_AUTO
	var keys_match_direction := false
	
	if held_direction != Vector2.ZERO:
		# If held direction closely matches current direction, track boost timer
		if held_direction.dot(current_direction) > 0.9:
			keys_match_direction = true
			boost_hold_time += delta
			
			# Enable boost only after delay
			if boost_hold_time >= BOOST_DELAY:
				target_speed = SNAKE_MAX_SPEED
	
	# Reset boost timer if keys don't match direction
	if not keys_match_direction:
		boost_hold_time = 0.0
	
	# Accelerate or decelerate towards target speed
	if current_speed < target_speed:
		current_speed = minf(current_speed + SNAKE_ACCELERATION, target_speed)
	elif current_speed > target_speed:
		current_speed = maxf(current_speed - SNAKE_ACCELERATION, target_speed)
	
	# Check if we should adjust direction for wall sliding (continuous check)
	var final_direction := _adjust_direction_for_wall_sliding(current_direction)
	if final_direction != Vector2.ZERO:
		last_effective_direction = _snap_to_8_way_direction(final_direction)
	
	# Always move in the final direction
	apply_central_force(final_direction.normalized() * current_speed)


func _get_input_direction() -> Vector2:

	if Global.is_fpv_controls_enabled():
		return _get_fpv_input_direction()
	
	return _get_absolute_input_direction()


func _get_absolute_input_direction() -> Vector2:

	var direction := Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		direction.y = -1.0
	elif Input.is_action_pressed("move_down"):
		direction.y = 1.0
	
	if Input.is_action_pressed("move_left"):
		direction.x = -1.0
	elif Input.is_action_pressed("move_right"):
		direction.x = 1.0

	return direction.normalized() if direction != Vector2.ZERO else Vector2.ZERO


func _get_fpv_input_direction() -> Vector2:

	var direction := Vector2.ZERO
	var forward := _get_fpv_forward_direction()
	var left := forward.rotated(-PI / 2.0)
	var right := forward.rotated(PI / 2.0)

	if Input.is_action_pressed("move_up"):
		direction += forward

	if Input.is_action_pressed("move_left"):
		direction += left
	elif Input.is_action_pressed("move_right"):
		direction += right

	if direction == Vector2.ZERO:
		return Vector2.ZERO

	return _snap_to_8_way_direction(direction)


func _get_fpv_forward_direction() -> Vector2:

	if linear_velocity.length() >= MIN_EFFECTIVE_DIRECTION_SPEED:
		return _snap_to_8_way_direction(linear_velocity)
	
	if last_effective_direction != Vector2.ZERO:
		return last_effective_direction
	
	return _snap_to_8_way_direction(current_direction)


func _snap_to_8_way_direction(direction: Vector2) -> Vector2:

	if direction == Vector2.ZERO:
		return Vector2.ZERO
	
	var normalized_direction := direction.normalized()
	var abs_x := absf(normalized_direction.x)
	var abs_y := absf(normalized_direction.y)
	var sign_x := -1.0 if normalized_direction.x < 0.0 else 1.0
	var sign_y := -1.0 if normalized_direction.y < 0.0 else 1.0
	
	if abs_x > abs_y * EIGHT_WAY_AXIS_DOMINANCE:
		return Vector2(sign_x, 0.0)
	
	if abs_y > abs_x * EIGHT_WAY_AXIS_DOMINANCE:
		return Vector2(0.0, sign_y)
	
	return Vector2(sign_x, sign_y).normalized()


func _on_body_entered( body: Node ):
	
	if Global.is_game_over():
		return
	
	# Check for collision with deadly walls - force-based detection
	if body.is_in_group("deadly_wall"):
		# Use the contact normal from physics state to calculate perpendicular impact.
		# This way a slight touch will not be deadly.
		# The normal points from the wall into this body.
		var wall_normal: Vector2 = last_contact_normal	
		var perpendicular_velocity: float = last_velocity.dot(wall_normal)
		var impact_speed: float = abs(perpendicular_velocity)
		
		if impact_speed >= DEADLY_WALL_IMPACT_THRESHOLD:
			$OuchSound.play()
			if poisoned_animation != null:
				time_bonus_indicator.clear_highlights()
				# Start animation from head (collision_index = -1)
				poisoned_animation.start_animation(-1)
			Global.set_game_over()
		# Otherwise, let physics bounce handle it naturally (gentle touch)
		return
	
	# Check for collision with snake's own body (excluding first 2 segments)
	if body is SnakeBody:
		# Get all registered segments from the controller
		if controller != null and controller.segments.size() > 2:
			var segment_index := controller.segments.find(body)
			# Die if colliding with segment beyond the first 2
			if segment_index >= 2:
				$OuchSound.play()
				if poisoned_animation != null:
					time_bonus_indicator.clear_highlights()
					poisoned_animation.start_animation(segment_index)
				Global.set_game_over()
				return
	
	if body.is_in_group("food"):

		# Calculate score before triggering the effect so particles can reflect the awarded value.
		var food_size_multiplier = 2.0 if body.food_size == Food.FoodSize.BIG else 1.0
		var snake_length := controller.get_segment_count() if controller != null else 0
		var base_score = int(body.food_nutrition * food_size_multiplier * body.get_score_multiplier(snake_length))
		var bonus_score = ceili( time_bonus ) * base_score
		var awarded_points = base_score + bonus_score

		_play_eat_sound( awarded_points )

		# Trigger food's collection effect before removing it
		body.play_collection_effect( awarded_points )

		# Buffer the food for later spawning of snake segment
		call_deferred( "_buffer_food", body.food_size, body.food_nutrition )
		
		# remove collided food
		body.queue_free()
		
		# update score
		Global.add_score( base_score )
		Global.add_bonus( bonus_score )
		
		time_bonus = MAX_TIME_BONUS
		time_bonus_indicator.set_bonus_segments(controller.segments, time_bonus)


func _play_eat_sound(awarded_points: int):

	var award_intensity := clampf(float(awarded_points) / MAX_FOOD_AWARD_POINTS, 0.0, 1.0)
	$EatSound.volume_db = lerpf(EAT_SOUND_MIN_VOLUME_DB, EAT_SOUND_MAX_VOLUME_DB, award_intensity)
	$EatSound.play()


func _buffer_food( food_size: Food.FoodSize, food_nutrition: int = 1 ):
	"""Buffer eaten food for later spawning."""
	
	# Add multiple entries to buffer based on food_nutrition
	for i in food_nutrition:
		# Record current tail position where the segment should eventually spawn
		food_buffer.append({
			"food_size": food_size,
			"tail_position": tail.global_position
		})
	
	# Reset tail spawn distance tracker when eating first food
	if food_buffer.size() == food_nutrition:
		tail_spawn_distance = 0.0


func _check_tail_spawning():
	"""Check if tail has moved enough distance to spawn buffered segments."""
	
	if food_buffer.is_empty():
		return
	
	# Track how far the tail has moved
	if tail is SnakeBody:
		var tail_body := tail as SnakeBody
		if tail_body.has_meta("last_position"):
			var last_pos: Vector2 = tail_body.get_meta("last_position")
			tail_spawn_distance += tail.global_position.distance_to(last_pos)
		tail_body.set_meta("last_position", tail.global_position)
	else:
		# Initialize tracking for first segment
		if tail is SnakeBody:
			(tail as SnakeBody).set_meta("last_position", tail.global_position)
	
	# Calculate required distance based on next food in buffer
	var next_food := food_buffer[0]
	var required_distance := _calculate_joint_length(next_food["food_size"])
	
	# Spawn segment when tail has moved far enough
	if tail_spawn_distance >= required_distance:
		_spawn_tail(next_food["food_size"], next_food["tail_position"])
		food_buffer.pop_front()
		tail_spawn_distance = 0.0  # Reset for next segment


func _calculate_joint_length( food_size: Food.FoodSize ) -> float:
	"""Calculate the joint length for a given food size."""
	
	var joint_len := JOINT_BASE_REST_LENGTH
	
	if tail == self:
		joint_len += JOINT_HEAD_BONUS
	elif (tail as SnakeBody).body_size == SnakeBody.BodySize.BIG:
		joint_len += JOINT_BIG_SEGMENT_BONUS
	
	if food_size == Food.FoodSize.BIG:
		joint_len += JOINT_BIG_SEGMENT_BONUS
	
	return joint_len
	

func _spawn_tail( food_size: Food.FoodSize, spawn_position: Vector2 = Vector2.ZERO ):
	
	var new_tail := body_scene.instantiate() as SnakeBody
	
	# Calculate joint length using the dedicated function
	var joint_len := _calculate_joint_length( food_size )
	
	if food_size == Food.FoodSize.NORMAL:
		new_tail.body_size = SnakeBody.BodySize.NORMAL
	else:
		new_tail.body_size = SnakeBody.BodySize.BIG	

	# Use stored spawn position (when food was eaten) if provided
	if spawn_position != Vector2.ZERO:
		new_tail.position = spawn_position
	else:
		# Place the first segment behind the head based on start_direction
		var offset: Vector2
		if tail == self and start_direction != Vector2.ZERO:
			offset = -start_direction.normalized() * joint_len
		else:
			var angle := randf_range( 0, TAU )
			offset = Vector2( cos( angle ), sin( angle ) )
		new_tail.position = tail.position + offset

	get_tree().current_scene.add_child( new_tail )
	
	_add_joint( tail, new_tail, joint_len )
	
	# Add collision exception between adjacent segments
	tail.add_collision_exception_with( new_tail )
	
	# Register segment with controller for trail-following
	if controller != null:
		controller.register_segment( new_tail, joint_len )
	
	tail = new_tail
	
	
func _add_joint( body1: PhysicsBody2D, body2: PhysicsBody2D, rest_length: float ):

	var joint := joint_scene.instantiate() as SnakeJoint
	
	joint.global_position = body1.global_position
	
	# Calculate angle from parent body to collision body, but subtract 90° because 
	# spring joint is pointed downwards when it is at zero degress (while is should be pointed to the right).
	joint.rotation = body1.global_position.angle_to_point( body2.global_position ) - PI/2
	
	# Length must be the current distance between bodies for the join to connect to
	# the centers of the bodies.
	joint.length = body1.global_position.distance_to( body2.global_position )
	
	# rest_length is the distance the joint tries to keep between the bodies.
	joint.rest_length = rest_length
	
	# It is important to assign the nodes only after the spring has been configured.
	joint.node_a = body1.get_path()
	joint.node_b = body2.get_path()
	
	get_tree().current_scene.add_child( joint )
	
	# Track the joint for death animation
	if poisoned_animation != null:
		poisoned_animation.register_joint(joint)


func _setup_wall_proximity_raycasts():
	"""Setup raycasts for detecting nearby walls in all 4 directions."""
	
	# Create raycasts for each cardinal direction
	# Only detect walls on layer 1 for efficient filtering
	wall_raycast_up = RayCast2D.new()
	wall_raycast_up.target_position = Vector2(0, -WALL_PROXIMITY_DISTANCE)
	wall_raycast_up.collision_mask = WALL_COLLISION_LAYER
	wall_raycast_up.enabled = true
	add_child(wall_raycast_up)
	
	wall_raycast_down = RayCast2D.new()
	wall_raycast_down.target_position = Vector2(0, WALL_PROXIMITY_DISTANCE)
	wall_raycast_down.collision_mask = WALL_COLLISION_LAYER
	wall_raycast_down.enabled = true
	add_child(wall_raycast_down)
	
	wall_raycast_left = RayCast2D.new()
	wall_raycast_left.target_position = Vector2(-WALL_PROXIMITY_DISTANCE, 0)
	wall_raycast_left.collision_mask = WALL_COLLISION_LAYER
	wall_raycast_left.enabled = true
	add_child(wall_raycast_left)
	
	wall_raycast_right = RayCast2D.new()
	wall_raycast_right.target_position = Vector2(WALL_PROXIMITY_DISTANCE, 0)
	wall_raycast_right.collision_mask = WALL_COLLISION_LAYER
	wall_raycast_right.enabled = true
	add_child(wall_raycast_right)


func _adjust_direction_for_wall_proximity(desired_direction: Vector2) -> Vector2:
	"""
	Adjust the desired direction if it would move toward a nearby wall.
	When approaching a wall, creates a diagonal. This is called on input changes.
	"""
	
	# Check if the desired direction would move toward a nearby wall
	var wall_detected := false
	var parallel_component := Vector2.ZERO
	
	# Check vertical walls (top/bottom) - parallel movement is horizontal
	if desired_direction.y < -INPUT_DIRECTION_THRESHOLD and wall_raycast_up.is_colliding():
		wall_detected = true
		parallel_component = Vector2(current_direction.x, 0)
	elif desired_direction.y > INPUT_DIRECTION_THRESHOLD and wall_raycast_down.is_colliding():
		wall_detected = true
		parallel_component = Vector2(current_direction.x, 0)
	
	# Check horizontal walls (left/right) - parallel movement is vertical
	if desired_direction.x < -INPUT_DIRECTION_THRESHOLD and wall_raycast_left.is_colliding():
		wall_detected = true
		parallel_component = Vector2(0, current_direction.y)
	elif desired_direction.x > INPUT_DIRECTION_THRESHOLD and wall_raycast_right.is_colliding():
		wall_detected = true
		parallel_component = Vector2(0, current_direction.y)
	
	# If no wall detected in the desired direction, allow the direction change
	if not wall_detected:
		return desired_direction
	
	# Wall nearby: blend to create diagonal for approach
	# Normalize parallel component, using sensible fallback if zero
	if parallel_component.length_squared() < MIN_PARALLEL_COMPONENT_LENGTH_SQ:
		# If no clear parallel direction, use perpendicular to the wall-directed axis
		if abs(desired_direction.y) > 0.5:  # Vertical wall-directed input
			parallel_component = Vector2(1.0, 0)
		else:  # Horizontal wall-directed input
			parallel_component = Vector2(0, 1.0)
	else:
		parallel_component = parallel_component.normalized()
	
	# Blend desired direction with parallel component to create stable diagonal
	var adjusted_direction = (desired_direction + parallel_component).normalized()
	
	# If the desired direction was diagonal (both x and y components present), 
	# ensure the result is also a proper 45° diagonal
	if abs(desired_direction.x) > 0.1 and abs(desired_direction.y) > 0.1:
		# Make it a proper 45° diagonal by equalizing the components
		var sign_x = sign(adjusted_direction.x) if abs(adjusted_direction.x) > 0.01 else 1.0
		var sign_y = sign(adjusted_direction.y) if abs(adjusted_direction.y) > 0.01 else 1.0
		adjusted_direction = Vector2(sign_x, sign_y).normalized()
	
	return adjusted_direction


func _adjust_direction_for_wall_sliding(movement_direction: Vector2) -> Vector2:
	"""
	Continuously adjust movement direction when sliding along walls.
	This prevents slowdown by switching to pure parallel movement when touching a wall.
	"""
	
	# Check each wall direction
	var checks := [
		{"dir": Vector2.UP, "raycast": wall_raycast_up, "input_check": movement_direction.y < -INPUT_DIRECTION_THRESHOLD, "parallel": Vector2(movement_direction.x, 0)},
		{"dir": Vector2.DOWN, "raycast": wall_raycast_down, "input_check": movement_direction.y > INPUT_DIRECTION_THRESHOLD, "parallel": Vector2(movement_direction.x, 0)},
		{"dir": Vector2.LEFT, "raycast": wall_raycast_left, "input_check": movement_direction.x < -INPUT_DIRECTION_THRESHOLD, "parallel": Vector2(0, movement_direction.y)},
		{"dir": Vector2.RIGHT, "raycast": wall_raycast_right, "input_check": movement_direction.x > INPUT_DIRECTION_THRESHOLD, "parallel": Vector2(0, movement_direction.y)}
	]
	
	for check in checks:
		if check["input_check"] and check["raycast"].is_colliding():
			var collision_point = check["raycast"].get_collision_point()
			var wall_distance = global_position.distance_to(collision_point)
			
			if wall_distance < head_radius + WALL_SLIDING_DISTANCE_BUFFER:
				var parallel_component: Vector2 = check["parallel"]
				if parallel_component.length_squared() > MIN_PARALLEL_COMPONENT_LENGTH_SQ:
					var velocity_toward_wall := last_velocity.dot(check["dir"])
					if velocity_toward_wall < WALL_SLIDING_VELOCITY_THRESHOLD:
						return parallel_component.normalized()
	
	return movement_direction
