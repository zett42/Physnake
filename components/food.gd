class_name Food
extends RigidBody2D

enum FoodSize {
	NORMAL,
	BIG,
}

const MAX_NUTRITION: int = 3
const RING_SEGMENTS_PER_RADIUS := 3.0
const MIN_RING_SEGMENTS := 12

@export var food_size: FoodSize = FoodSize.NORMAL
@export var food_nutrition: int = 1

var show_detail_rings := true:
	set(value):
		if show_detail_rings == value:
			return

		show_detail_rings = value
		_update_tail_count_ring_visibility()

var _tail_count_rings: Array[Node2D] = []


func _ready():
	
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


func play_collection_effect():
	"""Play particle effect when food is collected. Should be called before queue_free()."""

	# Scale particle effect based on food size and nutrition
	var size_multiplier = 1.5 if food_size == FoodSize.BIG else 1.0
	var nutrition_multiplier = 1.0 + (food_nutrition - 1) * 0.3  # +30% per extra nutrition
	var total_multiplier = size_multiplier * nutrition_multiplier

	var particles := $CollectionParticles
	particles.amount = int(60 * total_multiplier)
	particles.scale = Vector2.ONE * (0.8 + (total_multiplier - 1.0) * 0.4)  # Slightly bigger visual size

	# Detach particles from food and reparent to scene root so they persist after food is freed
	remove_child(particles)
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position
	particles.modulate = modulate  # Transfer food color to particles
	particles.emitting = true

	# Auto-cleanup after particles finish
	particles.finished.connect(func(): particles.queue_free())
