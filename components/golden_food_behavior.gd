## Golden food behavior.
##
## Golden food pulses visually, expires after a short lifetime, awards a
## snake-length-scaled score multiplier, plays its own spawn/collection sounds,
## and owns its collection stat contribution.

class_name GoldenFoodBehavior
extends "res://components/food_kind_behavior.gd"


const GOLDEN_COLOR := Color(1.0, 0.78, 0.08, 1.0)
const GOLDEN_PULSE_COLOR := Color(1.0, 0.95, 0.32, 1.0)
const LIFETIME_SECONDS := 6.0
const SCORE_MULTIPLIER := 3
const LENGTH_BONUS_SEGMENTS := 5
const PULSE_SPEED := 5.0
const PULSE_SCALE := 1.08
const TIMEOUT_RING_RADIUS_PADDING := 4.0
const TIMEOUT_RING_WIDTH := 2.5
const RING_SEGMENTS_PER_RADIUS := 3.0
const MIN_RING_SEGMENTS := 12
const COLLECTION_SOUND_MIN_VOLUME_DB := -2.0
const COLLECTION_SOUND_MAX_VOLUME_DB := 6.0
const MAX_FOOD_AWARD_POINTS := 36.0
const SCORE_STAT_LABEL := "golden food score"

const SPAWN_SOUND := preload("res://sounds/golden_spawn.wav")
const COLLECTION_SOUND := preload("res://sounds/golden_food.wav")


var _pulse_time := 0.0
var _lifetime_timer: Timer = null
var _timeout_indicator: VisibleCircleShape2D = null


## Applies initial golden visuals, timeout UI, and lifetime timer.
func setup(owner_food: Node):

	super(owner_food)
	_apply_visuals()
	_setup_timeout_indicator()
	_start_lifetime_timer()


## Updates the pulse animation and timeout indicator.
func process_kind(delta: float):

	_pulse_time += delta * PULSE_SPEED
	_apply_visuals()
	_update_timeout_indicator()


## Returns the golden score multiplier, including the current snake-length bonus.
func get_score_multiplier(snake_length: int) -> int:

	return SCORE_MULTIPLIER + floori(float(snake_length) / LENGTH_BONUS_SEGMENTS)


## Returns the golden particle color gradient for collection effects.
func get_collection_particle_color(award_intensity: float) -> Color:

	return GOLDEN_COLOR.lerp(GOLDEN_PULSE_COLOR, award_intensity)


## Plays the golden spawn notification.
func on_spawned(spawner: Node):

	_play_spawn_sound(spawner)


## Plays the golden collection sound.
func play_collection_sound(collector: Node, awarded_points: int) -> bool:

	var award_intensity := clampf(float(awarded_points) / MAX_FOOD_AWARD_POINTS, 0.0, 1.0)
	var volume_db := lerpf(COLLECTION_SOUND_MIN_VOLUME_DB, COLLECTION_SOUND_MAX_VOLUME_DB, award_intensity)
	_play_collection_sound(collector, volume_db)
	return true


## Adds this collection to the golden food score stat.
func apply_collection_stats(awarded_points: int):

	food_score_stat_requested.emit(SCORE_STAT_LABEL, awarded_points)


func _apply_visuals():

	var pulse := (sin(_pulse_time) + 1.0) * 0.5
	food.modulate = GOLDEN_COLOR.lerp(GOLDEN_PULSE_COLOR, pulse)
	food.apply_shape_pulse_scale(lerpf(1.0, PULSE_SCALE, pulse))


func _start_lifetime_timer():

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = LIFETIME_SECONDS
	timer.timeout.connect(_on_lifetime_timeout)
	add_child(timer)
	timer.start()
	_lifetime_timer = timer


func _setup_timeout_indicator():

	_timeout_indicator = VisibleCircleShape2D.new()
	_timeout_indicator.radius = food.get_active_base_radius() + TIMEOUT_RING_RADIUS_PADDING
	_timeout_indicator.num_circle_segments = maxi(
		MIN_RING_SEGMENTS,
		roundi(_timeout_indicator.radius * RING_SEGMENTS_PER_RADIUS)
	)
	_timeout_indicator.start_angle = -90.0
	_timeout_indicator.central_angle = 360.0
	_timeout_indicator.border_width = TIMEOUT_RING_WIDTH
	_timeout_indicator.enable_fill = false
	_timeout_indicator.border_color = Color(1.0, 1.0, 1.0, 0.78)
	food.get_active_shape_node().add_child(_timeout_indicator)
	_timeout_indicator.update_polygon_nodes()


func _update_timeout_indicator():

	if _timeout_indicator == null or _lifetime_timer == null:
		return

	var remaining_ratio := clampf(_lifetime_timer.time_left / LIFETIME_SECONDS, 0.0, 1.0)
	_timeout_indicator.central_angle = 360.0 * remaining_ratio
	_timeout_indicator.border_color = Color(1.0, 1.0, 1.0, lerpf(0.2, 0.78, remaining_ratio))
	_timeout_indicator.update_polygon_nodes()


func _on_lifetime_timeout():

	food.queue_free()


func _play_spawn_sound(parent: Node):

	var sound := AudioStreamPlayer.new()
	sound.stream = SPAWN_SOUND
	sound.volume_db = -2.0
	parent.add_child(sound)
	sound.finished.connect(func(): sound.queue_free())
	sound.play()


func _play_collection_sound(parent: Node, volume_db: float):

	var sound := AudioStreamPlayer2D.new()
	sound.stream = COLLECTION_SOUND
	sound.volume_db = volume_db

	if parent is Node2D:
		sound.global_position = (parent as Node2D).global_position

	parent.add_child(sound)
	sound.finished.connect(func(): sound.queue_free())
	sound.play()
