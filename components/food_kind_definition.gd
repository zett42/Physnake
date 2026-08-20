class_name FoodKindDefinition
extends Resource


## Relative spawn chance used by FoodSpawner.
@export var spawn_weight: float = 1.0

## Runtime Node script instantiated for each Food instance using this definition.
@export var behavior_script: Script = null

## Creates the per-food runtime behavior node for this kind.
func create_behavior() -> Node:

	if behavior_script == null:
		return preload("res://components/food_kind_behavior.gd").new()

	var behavior: Node = behavior_script.new()
	if behavior != null and behavior.has_method("setup"):
		return behavior

	push_error("Food kind behavior script must extend FoodKindBehavior.")
	return preload("res://components/food_kind_behavior.gd").new()
