extends Node

const food_scene = preload("res://components/food.tscn")

# Propability that big food is spawned (0..1)
const BIG_FOOD_PROPABILITY: float = 0.1


@export var food_count: int = 5


@onready var _shape_cast_normal := $ShapeCast_normal as ShapeCast2D
@onready var _shape_cast_big    := $ShapeCast_big as ShapeCast2D


func _process( _delta ):

	# spawn food if needed
	
	var food_nodes = get_tree().get_nodes_in_group("food")
	var food_diff = food_count - food_nodes.size()
	
	if food_diff > 0:
		for i in food_diff:
			_spawn_food()


func _spawn_food():
	
	var food_size = Food.FoodSize.NORMAL if randf() > BIG_FOOD_PROPABILITY else Food.FoodSize.BIG

	# Try to find an unoccluded location for spawning food.
	
	var shape_cast = _shape_cast_normal if food_size == Food.FoodSize.NORMAL else _shape_cast_big
	# For immediate shape cast we are supposed to set target_position to 0,0
	shape_cast.target_position = Vector2.ZERO

	# Don't try too often to prevent lags. If not successful this time, then maybe next frame.
	for i in 100:
		shape_cast.position = Vector2( randf_range( 0, 1152 ), randf_range( 0, 648 ) )
		shape_cast.force_shapecast_update()

		if not shape_cast.is_colliding():

			var food = food_scene.instantiate()
			food.position = shape_cast.position
			food.food_size = food_size
		
			get_parent().add_child( food )	
			break
