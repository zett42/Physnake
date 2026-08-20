## Default food behavior.
##
## Regular food has no lifetime, no special collection sound, no special stat,
## and uses the base FoodKindBehavior scoring and particle color behavior.

class_name RegularFoodBehavior
extends "res://components/food_kind_behavior.gd"


## Applies the regular food visuals to the owning Food instance.
func setup(owner_food: Node):

	super(owner_food)
	food.modulate = Color(0.235294, 1.0, 0.0, 1.0)
	food.reset_shape_scales()
