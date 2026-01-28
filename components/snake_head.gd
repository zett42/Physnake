extends RigidBody2D

# Movement speed and acceleration (when key is hold)
const SNAKE_MIN_SPEED: float = 300
const SNAKE_MAX_SPEED: float = 2000
const SNAKE_MAX_SPEED_AUTO: float = 750  # Lower speed for automatic movement mode
const SNAKE_ACCELERATION: float = 20

const MAX_TIME_BONUS: float = 5
const TIME_BONUS_DURATION: float = 3.0

# Joint length constants
const JOINT_BASE_REST_LENGTH: float = 25.0  # Base rest length from joint scene
const JOINT_HEAD_BONUS: float = 4.0  # Extra length when connecting to head
const JOINT_BIG_SEGMENT_BONUS: float = 6.0  # Extra length for big segments

# Components that will be spawend.
const body_scene  := preload("res://components/snake_body.tscn") as PackedScene
const joint_scene := preload("res://components/snake_joint.tscn") as PackedScene

# Snake controller for trail-following behavior
var controller: SnakeController = null

# Current tail. This starts with self to be able to connect initial tail to head.
var tail: PhysicsBody2D = self

# Current snake speed
var current_speed: float = SNAKE_MIN_SPEED

# Current direction for automatic movement mode (absolute directions)
var current_direction: Vector2 = Vector2.RIGHT

# Boost mechanic for automatic movement
var boost_hold_time: float = 0.0  # Time keys matching direction have been held
const BOOST_DELAY: float = 0.25  # Delay before boost activates (in seconds)

# Time bonus if snake eats food quickly.
var time_bonus: float = MAX_TIME_BONUS

# Food digestion buffer for natural segment spawning
var food_buffer: Array[Dictionary] = []  # Stores {food_size: Food.FoodSize, tail_position: Vector2}
var tail_spawn_distance: float = 0.0  # Accumulated distance traveled by tail

# Death animation
var poisoned_animation: SnakePoisonedAnimation = null

# Force-based wall collision detection
const DEADLY_WALL_IMPACT_THRESHOLD: float = 100.0  # Minimum velocity for deadly wall impact
var last_velocity: Vector2 = Vector2.ZERO  # Track velocity for impact detection
var last_contact_normal: Vector2 = Vector2.ZERO  # Contact normal from last collision


func _ready():
	
	# To process input without _input() method
	set_process_input( true )
	
	# Enable Continuous Collision Detection for fast movement
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	
	# Enable contact monitoring for collision normal detection
	contact_monitor = true
	max_contacts_reported = 4
	
	# Create and initialize the snake controller
	controller = SnakeController.new()
	add_child(controller)
	controller.initialize(self)
	
	# Create and initialize the poisoned animation
	poisoned_animation = SnakePoisonedAnimation.new()
	add_child(poisoned_animation)
	poisoned_animation.initialize(self, controller)

	# Add initial snake tail. As tree is locked in _ready(), it must be called deferred.
	call_deferred( "_spawn_tail", Food.FoodSize.NORMAL )


func _process( delta ):
	
	if poisoned_animation != null and poisoned_animation.is_animating:
		# Play death animation
		poisoned_animation.update_animation(delta)
		return
	
	time_bonus = maxf( 0, time_bonus - MAX_TIME_BONUS / TIME_BONUS_DURATION * delta )
	Global.time_bonus = ceili( time_bonus )
	
	# Check if we should spawn buffered segments based on tail movement
	_check_tail_spawning()


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

	if Global.auto_move:
		# Automatic movement mode (normal/hard difficulty)
		_handle_automatic_movement(state.step)
	else:
		# Manual movement mode (easy difficulty)
		_handle_manual_movement()


func _handle_automatic_movement(delta: float):
	"""Handle automatic forward movement with absolute directional input."""
	
	# Check for direction changes (absolute directions, not relative to snake)
	# Only change direction when a key is newly pressed, but sample all held keys for diagonals
	var direction_changed := false
	var new_direction := Vector2.ZERO
	
	# Detect vertical input
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
		direction_changed = true
	
	# Detect horizontal input  
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
		direction_changed = true
	
	# When a direction key is pressed, sample all currently held keys
	if direction_changed:
		if Input.is_action_pressed("move_up"):
			new_direction.y = -1.0
		elif Input.is_action_pressed("move_down"):
			new_direction.y = 1.0
		
		if Input.is_action_pressed("move_left"):
			new_direction.x = -1.0
		elif Input.is_action_pressed("move_right"):
			new_direction.x = 1.0
		
		# Only change direction if it's not opposite to current direction
		if new_direction != Vector2.ZERO:
			new_direction = new_direction.normalized()
			# Prevent turning 180 degrees (opposite direction)
			if new_direction.dot(current_direction) > -0.9:  # Not opposite (allowing some tolerance)
				current_direction = new_direction
				# Reset boost timer when direction changes
				boost_hold_time = 0.0
	
	# Check if player is holding keys matching the current direction (boost mechanic)
	var held_direction := Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		held_direction.y = -1.0
	elif Input.is_action_pressed("move_down"):
		held_direction.y = 1.0
	
	if Input.is_action_pressed("move_left"):
		held_direction.x = -1.0
	elif Input.is_action_pressed("move_right"):
		held_direction.x = 1.0
	
	# Determine target speed based on whether held keys match current direction
	var target_speed := SNAKE_MAX_SPEED_AUTO
	var keys_match_direction := false
	
	if held_direction != Vector2.ZERO:
		held_direction = held_direction.normalized()
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
	
	# Always move in the current direction
	apply_central_force(current_direction.normalized() * current_speed)


func _handle_manual_movement():
	"""Handle manual movement mode (original behavior for easy mode)."""
	
	var direction := Vector2.ZERO
	
	if Input.is_action_pressed("move_up"):
		direction.y = -1.0
	elif Input.is_action_pressed("move_down"):
		direction.y = 1.0
	
	if Input.is_action_pressed("move_left"):
		direction.x = -1.0
	elif Input.is_action_pressed("move_right"):
		direction.x = 1.0

	if direction.length() > 0:
		apply_central_force(direction.normalized() * current_speed)
		current_speed = minf(current_speed + SNAKE_ACCELERATION, SNAKE_MAX_SPEED)
	else:
		current_speed = SNAKE_MIN_SPEED


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
					poisoned_animation.start_animation(segment_index)
				Global.set_game_over()
				return
	
	if body.is_in_group("food"):
		
		$EatSound.play()
		
		# Buffer the food for later spawning of snake segment
		call_deferred( "_buffer_food", body.food_size, body.food_nutrition )
		
		# remove collided food
		body.queue_free()
		
		# update score
		var food_size_multiplier = 2.0 if body.food_size == Food.FoodSize.BIG else 1.0
		var base_score = int(body.food_nutrition * food_size_multiplier)
		Global.add_score( base_score )
		Global.add_bonus( ceili( time_bonus ) * base_score )
		
		time_bonus = MAX_TIME_BONUS


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

	# Use stored spawn position or fall back to tail position with offset
	if spawn_position != Vector2.ZERO:
		new_tail.position = spawn_position
	else:
		# Fallback for initial segment (backward compatibility)
		var angle := randf_range( 0, TAU )
		var offset := Vector2( cos( angle ), sin( angle ) )
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
