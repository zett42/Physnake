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
		FoodSize.BIG:
			$Shape_normal.visible = false
			$Shape_big.visible = true
			$CollisionShape_normal.set_deferred("disabled", true )
			$CollisionShape_big.set_deferred("disabled", false )
