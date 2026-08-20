class_name Food
extends RigidBody2D

## Emitted when this food's behavior requests a named score stat update.
signal food_score_stat_requested(label: String, value: int)


enum FoodSize {
	NORMAL,
	BIG,
}

const MAX_NUTRITION: int = 3
const RING_SEGMENTS_PER_RADIUS := 3.0
const MIN_RING_SEGMENTS := 12
const MAX_COLLECTION_EFFECT_POINTS := 36.0
const LOW_VALUE_PARTICLE_COLOR := Color(0.235294, 1.0, 0.0, 1.0)
const HIGH_VALUE_PARTICLE_COLOR := Color(0.45, 1.0, 0.87, 1.0)
const REGULAR_COLOR := Color(0.235294, 1.0, 0.0, 1.0)

const DEFAULT_FOOD_KIND := preload("res://components/regular_food_definition.tres")

@export var food_size: FoodSize = FoodSize.NORMAL
@export var food_nutrition: int = 1
@export var food_kind: Resource = null

var show_detail_rings := true:
	set(value):
		if show_detail_rings == value:
			return

		show_detail_rings = value
		_update_tail_count_ring_visibility()

var _tail_count_rings: Array[Node2D] = []
var _normal_shape_scale := Vector2.ONE
var _big_shape_scale := Vector2.ONE
var _kind_behavior: Node = null


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

	_setup_kind_behavior()


func _process(delta: float):

	if _kind_behavior != null:
		_kind_behavior.process_kind(delta)


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


## Returns this food kind's score multiplier.
##
## Food keeps size and nutrition separate; this value only represents the
## behavior-specific multiplier applied by the current food kind.
func get_score_multiplier(snake_length: int = 0) -> int:

	if _kind_behavior == null:
		return 1

	return _kind_behavior.get_score_multiplier(snake_length)


## Runs kind-specific logic after this Food is added to the scene.
func on_spawned(spawner: Node):

	if _kind_behavior != null:
		_kind_behavior.on_spawned(spawner)


## Attempts to play this food kind's collection sound.
##
## Returns true when a kind-specific sound was played. Callers should play their
## default collection sound when this returns false.
func play_collection_sound(collector: Node, awarded_points: int) -> bool:

	if _kind_behavior == null:
		return false

	return _kind_behavior.play_collection_sound(collector, awarded_points)


## Applies this food kind's collection stat side effects.
func apply_collection_stats(awarded_points: int):

	if _kind_behavior != null:
		_kind_behavior.apply_collection_stats(awarded_points)


## Restores both authored shape scales.
##
## Food kind behaviors call this when they need to clear temporary visual scale
## changes without knowing which size is currently active.
func reset_shape_scales():

	$Shape_normal.scale = _normal_shape_scale
	$Shape_big.scale = _big_shape_scale


## Applies a temporary scale multiplier to both authored shape variants.
##
## Both shapes are updated so size changes remain correct if Food setup toggles
## which shape is visible.
func apply_shape_pulse_scale(pulse_scale: float):

	$Shape_normal.scale = _normal_shape_scale * pulse_scale
	$Shape_big.scale = _big_shape_scale * pulse_scale


## Returns the visible shape node for the current food size.
##
## Food kind behaviors use this to attach size-aware visual children.
func get_active_shape_node() -> Node2D:

	return $Shape_big if food_size == FoodSize.BIG else $Shape_normal


## Returns the authored radius for the current food size.
##
## Food kind behaviors use this to place size-aware visual elements.
func get_active_base_radius() -> float:

	return 15.0 if food_size == FoodSize.BIG else 10.0


## Creates and initializes the behavior component selected by food_kind.
##
## Regular food is used as a defensive fallback when no definition is assigned.
func _setup_kind_behavior():

	if food_kind == null:
		food_kind = DEFAULT_FOOD_KIND

	_kind_behavior = food_kind.call("create_behavior") as Node
	add_child(_kind_behavior)
	if _kind_behavior.has_signal("food_score_stat_requested"):
		_kind_behavior.food_score_stat_requested.connect(_on_food_score_stat_requested)
	_kind_behavior.setup(self)


func _on_food_score_stat_requested(label: String, value: int):

	food_score_stat_requested.emit(label, value)


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
	if _kind_behavior != null:
		particles.modulate = _kind_behavior.get_collection_particle_color(award_intensity)
	else:
		particles.modulate = LOW_VALUE_PARTICLE_COLOR.lerp(HIGH_VALUE_PARTICLE_COLOR, award_intensity)

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
