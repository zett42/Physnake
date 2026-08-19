class_name SnakeBody
extends RigidBody2D

enum BodySize {
	NORMAL,
	BIG,
}

const MIN_VISUAL_DIRECTION_LENGTH_SQUARED := 1.0

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
	
	# Enable Continuous Collision Detection for fast-moving segments
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY

	# Low detail modes make circular segments visibly faceted, so keep them from spinning.
	lock_rotation = true


func _update_body_size():

	match body_size:
		BodySize.NORMAL:
			$VisibleShape_normal.visible = true
			$VisibleShape_big.visible = false
			$CollisionShape_normal.disabled = false
			$CollisionShape_big.disabled = true
			mass = 0.01
		BodySize.BIG:
			$VisibleShape_normal.visible = false
			$VisibleShape_big.visible = true
			$CollisionShape_normal.disabled = true
			$CollisionShape_big.disabled = false
			mass = 0.025


func set_visual_direction(direction: Vector2):

	if direction.length_squared() < MIN_VISUAL_DIRECTION_LENGTH_SQUARED:
		return

	var visual_rotation := direction.angle()
	$VisibleShape_normal.rotation = visual_rotation
	$VisibleShape_big.rotation = visual_rotation
