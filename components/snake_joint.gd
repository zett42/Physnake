class_name SnakeJoint
extends DampedSpringJoint2D

@onready var line := $Line as Line2D

var show_detail_line := true:
	set(value):
		if show_detail_line == value:
			return

		show_detail_line = value
		if is_node_ready():
			line.visible = show_detail_line


func _ready():

	line.visible = show_detail_line


func _process( _delta ):

	if not show_detail_line:
		return
	
	var node1 := get_node( node_a ) as Node2D
	var node2 := get_node( node_b ) as Node2D

	if is_instance_valid( node1 ) and is_instance_valid( node2 ):
		line.set_point_position( 0, node1.global_position )
		line.set_point_position( 1, node2.global_position )
