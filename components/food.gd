class_name Food
extends RigidBody2D

enum FoodSize {
	NORMAL,
	BIG,
}

const MAX_TAIL_COUNT: int = 3

@export var food_size: FoodSize = FoodSize.NORMAL
@export var food_tail_count: int = 1


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
	
	var rings_to_draw := food_tail_count - 1
	if rings_to_draw <= 0:
		return
	
	# Calculate ring spacing
	var ring_spacing := base_radius / (rings_to_draw + 1)
	var ring_width := 2.0
	
	for i in range(rings_to_draw):
		var ring_radius := base_radius - ring_spacing * (i + 1)
		var ring := VisibleCircleShape2D.new()
		ring.radius = ring_radius
		ring.border_width = ring_width
		ring.enable_fill = false
		ring.border_color = Color(0, 0, 0, 0.5)  # Semi-transparent black
		parent_node.add_child(ring)
		# Must call update after adding to tree to generate the polygons
		ring.update_polygon_nodes()
