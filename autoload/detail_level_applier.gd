## Applies the configured game detail level to reusable polygon shape nodes.
##
## This node is owned by the application layer, so the reusable shape scripts can
## stay independent of Global and settings persistence.
##
## API contract for compatible nodes:
## - Expose a property named "polygon_detail_scale".
## - Treat 1.0 as authored/full polygon detail.
## - Treat values below 1.0 as reduced polygon detail.
## - Regenerate visible geometry when the property changes.
## - Keep the setting visual-only; collision or gameplay behavior must not change.

class_name DetailLevelApplier
extends Node


## Detail scale that preserves each shape's authored polygon density.
const HIGH_DETAIL_SCALE := 1.0
## Detail scale that uses roughly half of each shape's authored polygon density.
const MEDIUM_DETAIL_SCALE := 0.5
## Detail scale that uses roughly one quarter of each shape's authored polygon density.
const LOW_DETAIL_SCALE := 0.25


var _global: Node = null
var _current_scale := HIGH_DETAIL_SCALE


## Initializes the applier with the Global autoload node.
##
## Connects to setting changes and SceneTree node additions, then applies the
## current detail scale to all shape nodes that are already in the tree.
func initialize(global_node: Node):

	_global = global_node
	_current_scale = _get_scale_for_detail_level(_global.get_detail_level())

	if not _global.detail_level_changed.is_connected(_on_detail_level_changed):
		_global.detail_level_changed.connect(_on_detail_level_changed)

	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)

	_apply_to_tree(get_tree().root)


func _on_detail_level_changed(level):

	_current_scale = _get_scale_for_detail_level(level)
	_apply_to_tree(get_tree().root)


func _on_node_added(node: Node):

	# Deferred traversal catches child shapes created during the added node's _ready().
	call_deferred("_apply_to_tree", node)


## Applies the current polygon detail scale to nodes in a subtree that expose the
## shared polygon_detail_scale property.
func _apply_to_tree(root_node: Node):

	_apply_to_node(root_node)

	for child in root_node.get_children():
		_apply_to_tree(child)


## Applies the current polygon detail scale to a single compatible node.
func _apply_to_node(node: Node):

	if not is_instance_valid(node):
		return

	if _has_polygon_detail_scale(node):
		node.set("polygon_detail_scale", _current_scale)


## Returns true when a node exposes the shared polygon detail API.
func _has_polygon_detail_scale(node: Node) -> bool:

	for property in node.get_property_list():
		if property["name"] == "polygon_detail_scale":
			return true

	return false


## Converts SettingsManager.DetailLevel enum values to shape polygon detail scale.
func _get_scale_for_detail_level(level) -> float:

	match level:
		0:
			return LOW_DETAIL_SCALE
		1:
			return MEDIUM_DETAIL_SCALE
		_:
			return HIGH_DETAIL_SCALE
