extends RigidBody2D

# Movement speed and acceleration (when key is hold)
const SNAKE_MIN_SPEED: float = 300
const SNAKE_MAX_SPEED: float = 2000
const SNAKE_ACCELERATION: float = 20

const MAX_TIME_BONUS: float = 5
const TIME_BONUS_DURATION: float = 1

# Joint length constants
const JOINT_BASE_REST_LENGTH: float = 25.0  # Base rest length from joint scene
const JOINT_HEAD_BONUS: float = 4.0  # Extra length when connecting to head
const JOINT_BIG_SEGMENT_BONUS: float = 6.0  # Extra length for big segments

# Components that will be spawend.
const body_scene  := preload("res://components/snake_body.tscn") as PackedScene
const joint_scene := preload("res://components/snake_joint.tscn") as PackedScene

# Snake controller for trail-following behavior
var controller = null

# Current tail. This starts with self to be able to connect initial tail to head.
var tail: PhysicsBody2D = self

# Current snake speed
var current_speed: float = SNAKE_MIN_SPEED

# Time bonus if snake eats food quickly.
var time_bonus: float = MAX_TIME_BONUS

# Food digestion buffer for natural segment spawning
var food_buffer: Array[Dictionary] = []  # Stores {food_size: Food.FoodSize, tail_position: Vector2}
var tail_spawn_distance: float = 0.0  # Accumulated distance traveled by tail


func _ready():
	
	# To process input without _input() method
	set_process_input( true )
	
	# Enable Continuous Collision Detection for fast movement
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	
	# Create and initialize the snake controller
	const snake_controller_script := preload("res://components/snake_controller.gd")
	controller = snake_controller_script.new()
	get_tree().current_scene.add_child(controller)
	controller.initialize(self)

	# Add initial snake tail. As tree is locked in _ready(), it must be called deferred.
	call_deferred( "_spawn_tail", Food.FoodSize.NORMAL )


func _process( delta ):
	
	time_bonus = maxf( 0, time_bonus - 1 / TIME_BONUS_DURATION * delta )
	Global.time_bonus = ceili( time_bonus )
	
	# Check if we should spawn buffered segments based on tail movement
	_check_tail_spawning()


func _integrate_forces( _state ):

	if Global.is_game_over():
		return

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
		apply_central_force( direction.normalized() * current_speed )
		current_speed = minf( current_speed + SNAKE_ACCELERATION, SNAKE_MAX_SPEED )
	else:
		current_speed = SNAKE_MIN_SPEED


func _on_body_entered( body: Node ):
	
	if Global.is_game_over():
		return
	
	if body.is_in_group("food"):
		
		$EatSound.play()
		
		# Buffer the food for later spawning of snake segment
		call_deferred( "_buffer_food", body.food_size )
		
		# remove collided food
		body.queue_free()
		
		# update score
		Global.add_score()
		Global.add_bonus( ceili( time_bonus ) )
		
		time_bonus = MAX_TIME_BONUS
	

func _buffer_food( food_size: Food.FoodSize ):
	"""Buffer eaten food for later spawning."""
	
	# Record current tail position where the segment should eventually spawn
	food_buffer.append({
		"food_size": food_size,
		"tail_position": tail.global_position
	})
	
	# Reset tail spawn distance tracker when eating first food
	if food_buffer.size() == 1:
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
