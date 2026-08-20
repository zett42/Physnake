extends Node

const food_scene = preload("res://components/food.tscn")
const DEFAULT_FOOD_KIND := preload("res://components/regular_food_definition.tres")

# Propability that big food is spawned (0..1)
const BIG_FOOD_PROPABILITY: float = 0.1


@export var food_count: int = 25
@export var food_kinds: Array[Resource] = []


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
	var food_kind := _pick_food_kind()

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
			food.food_kind = food_kind
			food.food_nutrition = randi_range(1, Food.MAX_NUTRITION)
		
			get_parent().add_child( food )
			food.on_spawned(self)
			break


func _pick_food_kind() -> Resource:

	var available_kinds := _get_food_kinds()
	var total_weight := 0.0
	for food_kind in available_kinds:
		if food_kind != null:
			total_weight += maxf(float(food_kind.get("spawn_weight")), 0.0)

	if total_weight <= 0.0:
		return DEFAULT_FOOD_KIND

	var selected_weight := randf() * total_weight
	for food_kind in available_kinds:
		if food_kind == null:
			continue

		selected_weight -= maxf(float(food_kind.get("spawn_weight")), 0.0)
		if selected_weight <= 0.0:
			return food_kind

	return available_kinds.back()


func _get_food_kinds() -> Array[Resource]:

	if not food_kinds.is_empty():
		return food_kinds

	return [DEFAULT_FOOD_KIND]
