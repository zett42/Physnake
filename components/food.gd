class_name Food
extends RigidBody2D

enum FoodSize {
	NORMAL,
	BIG,
}

@export var food_size: FoodSize = FoodSize.NORMAL


func _ready():
	
	match food_size:
		FoodSize.NORMAL:
			$Mesh_normal.visible = true
			$Mesh_big.visible = false
			$CollisionShape_normal.set_deferred("disabled", false )
			$CollisionShape_big.set_deferred("disabled", true )
		FoodSize.BIG:
			$Mesh_normal.visible = false
			$Mesh_big.visible = true
			$CollisionShape_normal.set_deferred("disabled", true )
			$CollisionShape_big.set_deferred("disabled", false )
