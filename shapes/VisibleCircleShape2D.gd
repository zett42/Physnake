## Tool to create visible circle/donut/arc polygon procedurally, 
## which Godot 4 is still lacking.
@tool
class_name VisibleCircleShape2D
extends Node2D


## Outer radius, including any border.
@export var radius := 50.0:
	set( value ):
		if radius != value and value >= 0:
			radius = value
			_editor_update_polygon()
			
## Border width.
@export var border_width := 0.0:
	set( value ):
		if border_width != value and value >= 0:
			border_width = value
			_editor_update_polygon()

## Start angle of an sarc.
@export var start_angle := 0.0:
	set( value ):
		if start_angle != value:
			start_angle = value
			_editor_update_polygon()

## Angle that defines length of an arc.
@export var central_angle := 360.0:
	set( value ):
		if central_angle != value and value >= 0 and value <= 360:
			central_angle = value
			_editor_update_polygon()

## Number of segments subdividing the full circle (independent of arc).
@export var num_circle_segments := 64:
	set( value ):
		if num_circle_segments != value and value >= 3:
			num_circle_segments = value
			_editor_update_polygon()

## Fill inner circle. If false, only border will be drawn.
@export var enable_fill := true:
	set( value ):
		if enable_fill != value:
			enable_fill = value
			_editor_update_polygon()

## Circle color.
@export var color := Color.WHITE:
	set( value ):
		if color != value:
			color = value
			if is_inside_tree():
				call_deferred("_update_polygon_color")

## Border color.
@export var border_color := Color.WHITE:
	set( value ):
		if border_color != value:
			border_color = value
			if is_inside_tree():
				call_deferred("_update_polygon_color")

## Cached polygon data, to be persisted in the scene file, instead of
## having to run the expensive generating code every time.
@export var border_polygon: PackedVector2Array = []

## Cached polygon data, to be persisted in the scene file, instead of
## having to run the expensive generating code every time.
@export var fill_polygon: PackedVector2Array = []


# Actual polygon nodes for drawing.
var _border_polygon_node: Polygon2D = null
var _fill_polygon_node: Polygon2D = null


func _ready():

	call_deferred("_create_polygon_nodes")
	call_deferred("_editor_update_polygon")
	call_deferred("_update_polygon_color")


func _create_polygon_nodes():
	
	_border_polygon_node = Polygon2D.new()
	_border_polygon_node.polygon = border_polygon
	_border_polygon_node.color = color
	_border_polygon_node.antialiased = true
	
	add_child( _border_polygon_node, false, Node.INTERNAL_MODE_FRONT )
	
	_fill_polygon_node = Polygon2D.new()
	_fill_polygon_node.polygon = fill_polygon
	_fill_polygon_node.color = color
	_fill_polygon_node.antialiased = true
	
	add_child( _fill_polygon_node, false, Node.INTERNAL_MODE_FRONT )


# Update the polygon only when called while in editor.
func _editor_update_polygon():

	if is_inside_tree() and Engine.is_editor_hint():
		update_polygon()
		

# Update the polygon(s) immediately.
func update_polygon():

	if border_width > 0:
		border_polygon = VisibleCircleShape2D.calculate_circle_polygon( 
				radius - border_width, radius, start_angle, central_angle, num_circle_segments )
		_border_polygon_node.polygon = border_polygon
		_border_polygon_node.visible = true
	else:
		border_polygon.clear()
		_border_polygon_node.polygon.clear()
		_border_polygon_node.visible = false

	if enable_fill:
		fill_polygon = VisibleCircleShape2D.calculate_circle_polygon( 
				0, radius - border_width, start_angle, central_angle, num_circle_segments )
		_fill_polygon_node.polygon = fill_polygon
		_fill_polygon_node.visible = true
	else:
		fill_polygon.clear()
		_fill_polygon_node.polygon.clear()
		_fill_polygon_node.visible = false


static func calculate_circle_polygon( \
		p_radius_inner: float, p_radius: float, 
		p_start_angle: float, p_central_angle: float,
		p_num_circle_segments: int,
		offset: Vector2 = Vector2.ZERO,
		only_arc_line: bool = false ) -> PackedVector2Array:

	var array := PackedVector2Array()

	var angle_step := TAU / p_num_circle_segments

	var start_angle_rad   = deg_to_rad( p_start_angle )
	var central_angle_rad = deg_to_rad( p_central_angle )

	var start_angle_snapped   := snappedf( start_angle_rad, angle_step )
	var central_angle_snapped := snappedf( central_angle_rad, angle_step )

	var end_angle_snapped := start_angle_snapped + central_angle_snapped

	var num_arc_segments := roundi( central_angle_snapped / TAU * p_num_circle_segments )

	# Create outer points counter-clockwise
	
	for i in num_arc_segments:
		array.append( polar_to_cartesian( p_radius, end_angle_snapped - i * angle_step ) + offset )

	# If this is only part of another polygon (e. g. round rect), then we can return "incomplete" shape.
	if only_arc_line:
		return array

	# Create additional points if we are drawing cake piece or ring.
	if not is_equal_approx( central_angle_snapped, TAU ) or p_radius_inner > 0:
		array.append( polar_to_cartesian( p_radius, start_angle_snapped ) )

		if p_radius_inner > 0:
			# Create inner points clockwise
			for i in num_arc_segments + 1:
				array.append( polar_to_cartesian( p_radius_inner, start_angle_snapped + i * angle_step ) + offset )
		else:
			# Create center point of cake piece
			array.append( offset )

	return array
	

static func polar_to_cartesian( p_radius: float, p_phi: float ) -> Vector2:
	
	return Vector2( p_radius * cos( p_phi ), p_radius * sin( p_phi ) )


func _update_polygon_color():
	
	_border_polygon_node.color = border_color
	_fill_polygon_node.color = color
