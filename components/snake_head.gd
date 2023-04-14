extends RigidBody2D

# Movement speed and acceleration (when key is hold)
const SNAKE_MIN_SPEED: float = 300
const SNAKE_MAX_SPEED: float = 1800
const SNAKE_ACCELERATION: float = 10

const MAX_TIME_BONUS: float = 5
const TIME_BONUS_DURATION: float = 1

# Components that will be spawend.
const body_scene  := preload("res://components/snake_body.tscn") as PackedScene
const joint_scene := preload("res://components/snake_joint.tscn") as PackedScene

# Current tail. This starts with self to be able to connect initial tail to head.
var tail: PhysicsBody2D = self

# Current snake speed
var current_speed: float = SNAKE_MIN_SPEED

# Time bonus if snake eats food quickly.
var time_bonus: float = MAX_TIME_BONUS


func _ready():
	
	# To process input without _input() method
	set_process_input( true )

	# Add initial snake tail. As tree is locked in _ready(), it must be called deferred.
	call_deferred( "_spawn_tail", Food.FoodSize.NORMAL )


func _process( delta ):
	
	time_bonus = maxf( 0, time_bonus - 1 / TIME_BONUS_DURATION * delta )
	Global.time_bonus = ceili( time_bonus )


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
		
		# Add snake tail. For safety of physics this is called deferred.
		call_deferred( "_spawn_tail", body.food_size )
		
		# remove collided food
		body.queue_free()
		
		# update score
		Global.add_score()
		Global.add_bonus( ceili( time_bonus ) )
		
		time_bonus = MAX_TIME_BONUS
	

func _spawn_tail( food_size: Food.FoodSize ):
	
	var new_tail := body_scene.instantiate() as SnakeBody

	var joint_len := 24
	const joint_len_head_add := 4
	const joint_len_big_add := 6

	if tail == self:
		# Make joint longer to accomodate for head size.
		joint_len += joint_len_head_add
	elif (tail as SnakeBody).body_size == SnakeBody.BodySize.BIG:
		# Make joint longer to accomodate for big size of current tail.
		joint_len += joint_len_big_add
	
	if food_size == Food.FoodSize.NORMAL:
		new_tail.body_size = SnakeBody.BodySize.NORMAL
	else:
		new_tail.body_size = SnakeBody.BodySize.BIG
		# Make joint longer to accomodate for big size of new tail
		joint_len += joint_len_big_add	

	# Adding a small random offset makes the spawning of the new tail more stable
	# (otherwise it sometimes suddenly moved across the whole screen).
	var angle := randf_range( 0, TAU )
	var offset := Vector2( cos( angle ), sin( angle ) )

	new_tail.position = tail.position + offset

	get_tree().current_scene.add_child( new_tail )
	
	_add_joint( tail, new_tail, joint_len )
	
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
