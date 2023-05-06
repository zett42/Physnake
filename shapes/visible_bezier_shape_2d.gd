@tool
class_name VisibleBezierShape2D
extends Path2D


const FILL_NODE_NAME = "Fill"
const OUTLINE_NODE_NAME = "Outline"


## When set to false, protects the polygons from changes through properties.
@export var update_polygons := true:
	set( value ):
		if update_polygons != value:
			update_polygons = value
			if Engine.is_editor_hint() and is_inside_tree() and update_polygons:
				update_child_nodes()
				
## Create fill polygon.
@export var enable_fill := true:
	set( value ):
		if enable_fill != value:
			enable_fill = value
			if Engine.is_editor_hint() and is_inside_tree() and update_polygons:
				update_fill_polygon_node()
				
## Create outline.
@export var enable_outline := true:
	set( value ):
		if enable_outline != value:
			enable_outline = value
			if Engine.is_editor_hint() and is_inside_tree() and update_polygons:
				update_outline_node()
				
## Create outline.
@export var close_outline := true:
	set( value ):
		if close_outline != value:
			close_outline = value
			if Engine.is_editor_hint() and is_inside_tree() and update_polygons:
				update_outline_node()
				
## Outline width.
@export_range(0, 50, 0.5, "or_greater") var outline_width := 1.0:
	set( value ):
		if outline_width != value:
			outline_width = value
			if _outline_node:
				_outline_node.width = outline_width

## Outline z-order (relative).
@export var outline_z_index := 1:
	set( value ):
		if outline_z_index != value:
			outline_z_index = value
			if _outline_node:
				_outline_node.z_index = outline_z_index

## Fill color.
@export var color := Color.WHITE:
	set( value ):
		if color != value:
			color = value
			if _fill_polygon_node:
				_fill_polygon_node.color = color

## Outline color.
@export var outline_color := Color.DARK_GRAY:
	set( value ):
		if outline_color != value:
			outline_color = value
			if _outline_node:
				_outline_node.default_color = outline_color


# Child nodes for drawing fill and outline.
@onready var _fill_polygon_node := get_node_or_null( FILL_NODE_NAME ) as Polygon2D
@onready var _outline_node      := get_node_or_null( OUTLINE_NODE_NAME ) as Line2D


# Called when the node has entered the scene tree for the first time.
func _ready():

	if Engine.is_editor_hint():
		
		# This hides the curve drawn by the Path2D base class, but the handles
		# are still visible.
		self_modulate.a = 0.0
		
		# Reduce clutter in the scene dock by showing this node in the collapsed state.
		set_display_folded( true )
		
		# Make children not selectable by default to prevent accidentally moving them
		# (they can be ungrouped by clicking the "group selected nodes" button in the editor).  
		set_meta( "_edit_group_", true )
		
		if curve:
			curve.changed.connect( _on_curve_changed )
		
		if update_polygons:
			# Needs to be deferred because tree is locked in _ready()
			call_deferred("update_child_nodes")
			

	# Get notified if someone deletes the child nodes manually
	child_exiting_tree.connect( _on_child_exiting_tree )
	

func _on_child_exiting_tree( node: Node ):
	
	if node == _fill_polygon_node:
		_fill_polygon_node = null
	elif node == _outline_node:
		_outline_node = null


func _on_curve_changed():
	
	if update_polygons:
		call_deferred("update_child_nodes")


## Force update of the border and fill polygons. 
## For efficiency, changes to properties in-game don't update the polygons automatically,
## so this needs to be called after you have changed properties that affect the polygon shape.
func update_child_nodes():

	update_fill_polygon_node()
	update_outline_node()


## Force update of the fill polygon. 
## The fill polygon gets removed when enable_fill is false.
func update_fill_polygon_node():
	
	if enable_fill:
		_fill_polygon_node = _ensure_polygon_node( FILL_NODE_NAME, color )

		if curve:
			_fill_polygon_node.polygon = curve.get_baked_points()
		else:
			_fill_polygon_node.polygon.clear()

	elif _fill_polygon_node:
		# The docs include a big warning about using queue_free() in the editor, but it appears
		# to work fine in our case.
		_fill_polygon_node.queue_free()
		_fill_polygon_node = null


func update_outline_node():
	
	if enable_outline:
		_outline_node = _ensure_line_node( OUTLINE_NODE_NAME, outline_color )
		
		if curve:
			_outline_node.width = outline_width
			_outline_node.points = curve.get_baked_points()
			if close_outline:
				_outline_node.add_point( _outline_node.get_point_position( 0 ) )
		else:
			_outline_node.clear_points()
	
	elif _outline_node:
		# The docs include a big warning about using queue_free() in the editor, but it appears
		# to work fine in our case.
		_outline_node.queue_free()
		_outline_node = null


# Create polygon node if not exists.
func _ensure_polygon_node( p_name: String, p_color: Color ) -> Polygon2D:
	
	var node := get_node_or_null( p_name ) as Polygon2D
	if node:
		return node

	node = Polygon2D.new()
	node.name = p_name
	node.color = p_color
	node.antialiased = true

	add_child( node, true, Node.INTERNAL_MODE_FRONT )

	if Engine.is_editor_hint():
		# The line below is required to make the node visible in the Scene tree dock
		# and persist changes made by the tool script to the saved scene file.
		node.owner = get_tree().edited_scene_root

	return node


# Create line node if not exists.
func _ensure_line_node( p_name: String, p_color: Color ) -> Line2D:
	
	var node := get_node_or_null( p_name ) as Line2D
	if node:
		return node

	node = Line2D.new()
	node.name = p_name
	node.default_color = p_color
	node.antialiased = true
	node.z_index = 1   # to draw line over fill polygon, regardless of node ordering

	add_child( node, true, Node.INTERNAL_MODE_FRONT )

	if Engine.is_editor_hint():
		# The line below is required to make the node visible in the Scene tree dock
		# and persist changes made by the tool script to the saved scene file.
		node.owner = get_tree().edited_scene_root

	return node
