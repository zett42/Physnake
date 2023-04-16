class_name SnakeBody
extends RigidBody2D

enum BodySize {
	NORMAL,
	BIG,
}

@export var body_size: BodySize = BodySize.NORMAL:
	set( value ):
		if body_size != value:
			body_size = value
			if is_inside_tree():
				# As the method updates physics properties, it must be called deferred.
				call_deferred("_update_body_size")

func _ready():

	# Physics steps haven't run for this object yet, so call_deferred() is not required.
	_update_body_size()


func _update_body_size():

	match body_size:
		BodySize.NORMAL:
			$Mesh_normal.visible = true
			$Mesh_big.visible = false
			$CollisionShape_normal.disabled = false
			$CollisionShape_big.disabled = true
			mass = 0.01
		BodySize.BIG:
			$Mesh_normal.visible = false
			$Mesh_big.visible = true
			$CollisionShape_normal.disabled = true
			$CollisionShape_big.disabled = false
			mass = 0.025
