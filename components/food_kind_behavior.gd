## Base behavior component for one food kind.
##
## Food owns shared physics, size, nutrition, and collection-effect plumbing.
## Food kind behavior owns the parts that vary by kind: visuals over time,
## score modifiers, particle colors, spawn side effects, collection sound, and
## collection stats.
class_name FoodKindBehavior
extends Node


## Emitted when this food kind wants to contribute to a named score stat.
@warning_ignore("unused_signal")
signal food_score_stat_requested(label: String, value: int)


const LOW_VALUE_PARTICLE_COLOR := Color(0.235294, 1.0, 0.0, 1.0)
const HIGH_VALUE_PARTICLE_COLOR := Color(0.45, 1.0, 0.87, 1.0)


var food: Node = null


## Initializes this behavior for a specific Food instance.
##
## Called once by Food after size/collision/nutrition setup is complete, so
## implementations may safely read Food shape helpers and add child nodes.
func setup(owner_food: Node):

	food = owner_food


## Advances kind-specific behavior for the owning Food instance.
##
## Food forwards its _process(delta) here. Implementations that do not need
## per-frame behavior can leave the default no-op implementation.
func process_kind(_delta: float):

	pass


## Returns the multiplier applied to this food's base score.
##
## The snake length is provided for food kinds whose reward scales with current
## game state. Regular food uses the default multiplier of 1.
func get_score_multiplier(_snake_length: int) -> int:

	return 1


## Returns the particle color used by Food.play_collection_effect().
##
## award_intensity is normalized from 0.0 to 1.0 by Food based on awarded points.
func get_collection_particle_color(award_intensity: float) -> Color:

	return LOW_VALUE_PARTICLE_COLOR.lerp(HIGH_VALUE_PARTICLE_COLOR, award_intensity)


## Runs kind-specific logic after the owning Food is added to the scene.
func on_spawned(_spawner: Node):

	pass


## Attempts to play kind-specific collection audio.
##
## Returns true when a kind-specific sound was played. Callers should use their
## default collection sound when this returns false.
func play_collection_sound(_collector: Node, _awarded_points: int) -> bool:

	return false


## Applies kind-specific collection stats.
func apply_collection_stats(_awarded_points: int):

	pass
