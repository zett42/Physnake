## Tool to create visible circle/donut/arc polygon procedurally, 
## which Godot 4 is still lacking.
@tool
class_name VisibleCircleShape2D
extends Node2D


const OUTER_BORDER_NODE_NAME = "OuterBorder"
const INNER_BORDER_NODE_NAME = "InnerBorder"
const FILL_NODE_NAME = "Fill"


## When set to false, protects the polygons from changes through properties.
@export var update_polygons := true:
	set( value ):
		if update_polygons != value:
			update_polygons = value
			if is_inside_tree() and Engine.is_editor_hint() and update_polygons:
				update_polygon_nodes()
				
## Outer radius, including any border.
@export var radius := 50.0:
	set( value ):
		if radius != value and value >= 0:
			radius = value
			if is_inside_tree() and Engine.is_editor_hint() and update_polygons:
				update_polygon_nodes()
				
## Inner radius for ring shape, including any border.
@export var inner_radius := 0.0:
	set( value ):
		if inner_radius != value and value >= 0:
			inner_radius = value
			if is_inside_tree() and Engine.is_editor_hint() and update_polygons:
				update_polygon_nodes()
			
## Outer border width.
@export var border_width := 0.0:
	set( value ):
		if border_width != value and value >= 0:
			border_width = value
			if is_inside_tree() and Engine.is_editor_hint() and update_polygons:
				update_polygon_nodes()
				
## Inner border width.
@export var inner_border_width := 0.0:
	set( value ):
		if inner_border_width != value and value >= 0:
			inner_border_width = value
			if is_inside_tree() and Engine.is_editor_hint() and update_polygons:
				update_polygon_nodes()

## Start angle of an sarc.
@export var start_angle := 0.0:
	set( value ):
		if start_angle != value:
			start_angle = value
			if is_inside_tree() and Engine.is_editor_hint() and update_polygons:
				update_polygon_nodes()

## Angle that defines length of an arc.
@export var central_angle := 360.0:
	set( value ):
		if central_angle != value and value >= 0 and value <= 360:
			central_angle = value
			if is_inside_tree() and Engine.is_editor_hint() and update_polygons:
				update_polygon_nodes()

## Number of segments subdividing the full circle (independent of arc).
@export var num_circle_segments := 64:
	set( value ):
		if num_circle_segments != value and value >= 3:
			num_circle_segments = value
			if is_inside_tree() and Engine.is_editor_hint() and update_polygons:
				update_polygon_nodes()

## Fill inner circle. If false, only border will be drawn.
@export var enable_fill := true:
	set( value ):
		if enable_fill != value:
			enable_fill = value
			if is_inside_tree() and Engine.is_editor_hint() and update_polygons:
				update_fill_polygon_node()

## Circle color.
@export var color := Color.WHITE:
	set( value ):
		if color != value:
			color = value
			if is_inside_tree():
				call_deferred("_update_polygon_color")

## Outer border color.
@export var border_color := Color.WHITE:
	set( value ):
		if border_color != value:
			border_color = value
			if is_inside_tree():
				call_deferred("_update_polygon_color")
				
## Inner border color.
@export var inner_border_color := Color.WHITE:
	set( value ):
		if inner_border_color != value:
			inner_border_color = value
			if is_inside_tree():
				call_deferred("_update_polygon_color")


# Child nodes for drawing border and fill.
@onready var _border_polygon_node       := get_node_or_null( OUTER_BORDER_NODE_NAME ) as Polygon2D
@onready var _inner_border_polygon_node := get_node_or_null( INNER_BORDER_NODE_NAME ) as Polygon2D
@onready var _fill_polygon_node         := get_node_or_null( FILL_NODE_NAME ) as Polygon2D


# Called when the node has entered the scene tree for the first time.
func _ready():

	if Engine.is_editor_hint():
		
		# Reduce clutter in the scene dock by showing this node in the collapsed state.
		set_display_folded( true )
		
		# Make children not selectable by default to prevent accidentally moving them
		# (they can be ungrouped by clicking the "group selected nodes" button in the editor).  
		set_meta( "_edit_group_", true )
		
		if update_polygons:
			call_deferred("update_polygon_nodes")


## Force update of the border and fill polygons. 
## For efficiency, changes to properties in-game don't update the polygons automatically,
## so this needs to be called after you have changed properties that affect the polygon shape.
func update_polygon_nodes():

	update_outer_border_polygon_node()
	update_inner_border_polygon_node()
	update_fill_polygon_node()


## Force update of the outer border polygon. 
## The border polygon gets removed when border_width is zero. 
func update_outer_border_polygon_node():
	
	if border_width > 0:
		_border_polygon_node = _ensure_polygon_node( _border_polygon_node, OUTER_BORDER_NODE_NAME, border_color )
			
		_border_polygon_node.polygon = VisibleCircleShape2D.calculate_circle_polygon( 
				radius - border_width, radius, start_angle, central_angle, num_circle_segments )

	elif _border_polygon_node:
		# The docs include a big warning about using queue_free() in the editor, but it appears
		# to work fine in our case.
		_border_polygon_node.queue_free()
		_border_polygon_node = null


## Force update of the inner border polygon. 
## The border polygon gets removed when inner_border_width is zero. 
func update_inner_border_polygon_node():
	
	if inner_border_width > 0:
		_inner_border_polygon_node = _ensure_polygon_node( _inner_border_polygon_node, INNER_BORDER_NODE_NAME, inner_border_color )
			
		_inner_border_polygon_node.polygon = VisibleCircleShape2D.calculate_circle_polygon( 
				inner_radius, inner_radius + inner_border_width, start_angle, central_angle, 
				num_circle_segments )

	elif _inner_border_polygon_node:
		# The docs include a big warning about using queue_free() in the editor, but it appears
		# to work fine in our case.
		_inner_border_polygon_node.queue_free()
		_inner_border_polygon_node = null


## Force update of the fill polygon. 
## The fill polygon gets removed when enable_fill is false.
func update_fill_polygon_node():
	
	if enable_fill:
		_fill_polygon_node = _ensure_polygon_node( _fill_polygon_node, FILL_NODE_NAME, color )

		_fill_polygon_node.polygon = VisibleCircleShape2D.calculate_circle_polygon( 
				inner_radius + inner_border_width, radius - border_width, start_angle, 
				central_angle, num_circle_segments )

	elif _fill_polygon_node:
		# The docs include a big warning about using queue_free() in the editor, but it appears
		# to work fine in our case.
		_fill_polygon_node.queue_free()
		_fill_polygon_node = null


# Create polygon node if not exists.
func _ensure_polygon_node( p_node: Polygon2D, p_name: String, p_color: Color ) -> Polygon2D:
	
	if p_node:
		return p_node

	var node := Polygon2D.new()
	node.name = p_name
	node.color = p_color
	node.antialiased = true

	add_child( node, true, Node.INTERNAL_MODE_FRONT )

	if Engine.is_editor_hint():
		# The line below is required to make the node visible in the Scene tree dock
		# and persist changes made by the tool script to the saved scene file.
		node.owner = get_tree().edited_scene_root

	return node


static func calculate_circle_polygon( \
		p_radius_inner: float, p_radius_outer: float, 
		p_start_angle: float, p_central_angle: float,
		p_num_circle_segments: int,
		offset: Vector2 = Vector2.ZERO,
		only_arc_line: bool = false ) -> PackedVector2Array:

	var result := PackedVector2Array()

	var angle_step := TAU / p_num_circle_segments

	var start_angle_rad   = deg_to_rad( p_start_angle )
	var central_angle_rad = deg_to_rad( p_central_angle )

	var start_angle_snapped   := snappedf( start_angle_rad, angle_step )
	var central_angle_snapped := snappedf( central_angle_rad, angle_step )

	var end_angle_snapped := start_angle_snapped + central_angle_snapped

	var num_arc_segments := roundi( central_angle_snapped / TAU * p_num_circle_segments )

	# Create outer points counter-clockwise
	
	for i in num_arc_segments:
		result.append( polar_to_cartesian( p_radius_outer, end_angle_snapped - i * angle_step ) + offset )

	# If this is only part of another polygon (e. g. round rect), then we can return "incomplete" shape.
	if only_arc_line:
		return result

	# Create additional points if we are drawing cake piece or ring.
	if not is_equal_approx( central_angle_snapped, TAU ) or p_radius_inner > 0:
		result.append( polar_to_cartesian( p_radius_outer, start_angle_snapped ) )

		if p_radius_inner > 0:
			# Create inner points clockwise
			for i in num_arc_segments + 1:
				result.append( polar_to_cartesian( p_radius_inner, start_angle_snapped + i * angle_step ) + offset )
		else:
			# Create center point of cake piece
			result.append( offset )

	return result
	

static func polar_to_cartesian( p_radius: float, p_phi: float ) -> Vector2:
	
	return Vector2( p_radius * cos( p_phi ), p_radius * sin( p_phi ) )


func _update_polygon_color():
	
	if _border_polygon_node:
		_border_polygon_node.color = border_color
	if _inner_border_polygon_node:
		_inner_border_polygon_node.color = inner_border_color
	if _fill_polygon_node:
		_fill_polygon_node.color = color
