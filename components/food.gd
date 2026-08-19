class_name Food
extends RigidBody2D

enum FoodSize {
	NORMAL,
	BIG,
}

enum FoodType {
	REGULAR,
	GOLDEN,
}

const MAX_NUTRITION: int = 3
const RING_SEGMENTS_PER_RADIUS := 3.0
const MIN_RING_SEGMENTS := 12
const MAX_COLLECTION_EFFECT_POINTS := 36.0
const LOW_VALUE_PARTICLE_COLOR := Color(0.235294, 1.0, 0.0, 1.0)
const HIGH_VALUE_PARTICLE_COLOR := Color(0.45, 1.0, 0.87, 1.0)
const REGULAR_COLOR := Color(0.235294, 1.0, 0.0, 1.0)
const GOLDEN_COLOR := Color(1.0, 0.78, 0.08, 1.0)
const GOLDEN_PULSE_COLOR := Color(1.0, 0.95, 0.32, 1.0)
const GOLDEN_LIFETIME_SECONDS := 6.0
const GOLDEN_SCORE_MULTIPLIER := 3
const GOLDEN_LENGTH_BONUS_SEGMENTS := 5
const GOLDEN_PULSE_SPEED := 5.0
const GOLDEN_PULSE_SCALE := 1.08
const TIMEOUT_RING_RADIUS_PADDING := 4.0
const TIMEOUT_RING_WIDTH := 2.5

@export var food_size: FoodSize = FoodSize.NORMAL
@export var food_nutrition: int = 1
@export var food_type: FoodType = FoodType.REGULAR

var show_detail_rings := true:
	set(value):
		if show_detail_rings == value:
			return

		show_detail_rings = value
		_update_tail_count_ring_visibility()

var _tail_count_rings: Array[Node2D] = []
var _pulse_time := 0.0
var _normal_shape_scale := Vector2.ONE
var _big_shape_scale := Vector2.ONE
var _lifetime_timer: Timer = null
var _timeout_indicator: VisibleCircleShape2D = null


func _ready():
	_normal_shape_scale = $Shape_normal.scale
	_big_shape_scale = $Shape_big.scale
	
	match food_size:
		FoodSize.NORMAL:
			$Shape_normal.visible = true
			$Shape_big.visible = false
			$CollisionShape_normal.set_deferred("disabled", false )
			$CollisionShape_big.set_deferred("disabled", true )
			_setup_tail_count_rings($Shape_normal, 10.0)
		FoodSize.BIG:
			$Shape_normal.visible = false
			$Shape_big.visible = true
			$CollisionShape_normal.set_deferred("disabled", true )
			$CollisionShape_big.set_deferred("disabled", false )
			_setup_tail_count_rings($Shape_big, 15.0)

	_apply_food_type_visuals()
	set_process(food_type == FoodType.GOLDEN)

	if is_timed():
		_setup_timeout_indicator()
		_start_lifetime_timer()


func _process(delta: float):

	if food_type != FoodType.GOLDEN:
		return

	_pulse_time += delta * GOLDEN_PULSE_SPEED
	_apply_food_type_visuals()
	_update_timeout_indicator()


func _setup_tail_count_rings(parent_node: Node2D, base_radius: float):
	"""Create concentric ring shapes to indicate tail count."""
	
	var rings_to_draw := food_nutrition - 1
	if rings_to_draw <= 0:
		return
	
	# Calculate ring spacing
	var ring_spacing := base_radius / (rings_to_draw + 1)
	var ring_width := 2.0
	
	for i in range(rings_to_draw):
		var ring_radius := base_radius - ring_spacing * (i + 1)
		var ring := VisibleCircleShape2D.new()
		ring.radius = ring_radius
		ring.num_circle_segments = maxi(MIN_RING_SEGMENTS, roundi(ring_radius * RING_SEGMENTS_PER_RADIUS))
		ring.border_width = ring_width
		ring.enable_fill = false
		ring.border_color = Color(0, 0, 0, 0.5)  # Semi-transparent black
		parent_node.add_child(ring)
		_tail_count_rings.append(ring)
		# Must call update after adding to tree to generate the polygons
		ring.update_polygon_nodes()

	_update_tail_count_ring_visibility()


func _update_tail_count_ring_visibility():

	for ring in _tail_count_rings:
		if is_instance_valid(ring):
			ring.visible = show_detail_rings


func get_score_multiplier(snake_length: int = 0) -> int:

	match food_type:
		FoodType.GOLDEN:
			return GOLDEN_SCORE_MULTIPLIER + floori(float(snake_length) / GOLDEN_LENGTH_BONUS_SEGMENTS)
		_:
			return 1


func is_timed() -> bool:

	return food_type == FoodType.GOLDEN


func get_lifetime_seconds() -> float:

	match food_type:
		FoodType.GOLDEN:
			return GOLDEN_LIFETIME_SECONDS
		_:
			return 0.0


func _apply_food_type_visuals():

	match food_type:
		FoodType.GOLDEN:
			var pulse := (sin(_pulse_time) + 1.0) * 0.5
			modulate = GOLDEN_COLOR.lerp(GOLDEN_PULSE_COLOR, pulse)

			var pulse_scale := lerpf(1.0, GOLDEN_PULSE_SCALE, pulse)
			$Shape_normal.scale = _normal_shape_scale * pulse_scale
			$Shape_big.scale = _big_shape_scale * pulse_scale
		_:
			modulate = REGULAR_COLOR
			$Shape_normal.scale = _normal_shape_scale
			$Shape_big.scale = _big_shape_scale


func _start_lifetime_timer():

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = get_lifetime_seconds()
	timer.timeout.connect(_on_lifetime_timeout)
	add_child(timer)
	timer.start()
	_lifetime_timer = timer


func _setup_timeout_indicator():

	var parent_shape := $Shape_big if food_size == FoodSize.BIG else $Shape_normal
	var base_radius := 15.0 if food_size == FoodSize.BIG else 10.0

	_timeout_indicator = VisibleCircleShape2D.new()
	_timeout_indicator.radius = base_radius + TIMEOUT_RING_RADIUS_PADDING
	_timeout_indicator.num_circle_segments = maxi(MIN_RING_SEGMENTS, roundi(_timeout_indicator.radius * RING_SEGMENTS_PER_RADIUS))
	_timeout_indicator.start_angle = -90.0
	_timeout_indicator.central_angle = 360.0
	_timeout_indicator.border_width = TIMEOUT_RING_WIDTH
	_timeout_indicator.enable_fill = false
	_timeout_indicator.border_color = Color(1.0, 1.0, 1.0, 0.78)
	parent_shape.add_child(_timeout_indicator)
	_timeout_indicator.update_polygon_nodes()


func _update_timeout_indicator():

	if _timeout_indicator == null or _lifetime_timer == null:
		return

	var lifetime := get_lifetime_seconds()
	if lifetime <= 0.0:
		return

	var remaining_ratio := clampf(_lifetime_timer.time_left / lifetime, 0.0, 1.0)
	_timeout_indicator.central_angle = 360.0 * remaining_ratio
	_timeout_indicator.border_color = Color(1.0, 1.0, 1.0, lerpf(0.2, 0.78, remaining_ratio))
	_timeout_indicator.update_polygon_nodes()


func _on_lifetime_timeout():

	queue_free()


func play_collection_effect(awarded_points: int):
	"""Play particle effect when food is collected. Should be called before queue_free()."""

	# Scale particle effect based on food size and nutrition
	var size_multiplier = 1.5 if food_size == FoodSize.BIG else 1.0
	var nutrition_multiplier = 1.0 + (food_nutrition - 1) * 0.3  # +30% per extra nutrition
	var total_multiplier = size_multiplier * nutrition_multiplier
	var award_intensity := clampf(float(awarded_points) / MAX_COLLECTION_EFFECT_POINTS, 0.0, 1.0)

	var particles := $CollectionParticles
	particles.amount = int(60 * total_multiplier * lerpf(1.0, 2.4, award_intensity))
	particles.scale = Vector2.ONE * (0.8 + (total_multiplier - 1.0) * 0.4 + award_intensity * 0.35)
	particles.modulate = _get_collection_particle_color(award_intensity)

	if particles.process_material is ParticleProcessMaterial:
		var mat := (particles.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		mat.initial_velocity_min = lerpf(60.0, 100.0, award_intensity)
		mat.initial_velocity_max = lerpf(150.0, 300.0, award_intensity)
		particles.process_material = mat

	# Detach particles from food and reparent to scene root so they persist after food is freed
	remove_child(particles)
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position
	particles.emitting = true

	# Auto-cleanup after particles finish
	particles.finished.connect(func(): particles.queue_free())


func _get_collection_particle_color(award_intensity: float) -> Color:

	if food_type == FoodType.GOLDEN:
		return GOLDEN_COLOR.lerp(GOLDEN_PULSE_COLOR, award_intensity)

	return LOW_VALUE_PARTICLE_COLOR.lerp(HIGH_VALUE_PARTICLE_COLOR, award_intensity)
