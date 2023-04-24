extends Node


@export var time_bonus: int = 0:
	get:
		return time_bonus
	set( value ):
		if time_bonus != value:
			time_bonus = value
			var time_bonus_node = get_node("/root/Room/ScorePanel/Panel/TimeBonus")
			if time_bonus_node:
				time_bonus_node.text = "Time Bonus: %d" % time_bonus


enum Difficulty {
	NORMAL,
	HARD
}

@export var difficulty = Difficulty.NORMAL


var total_score: int = 0
var total_bonus: int = 0

var _is_game_over: bool = false



func reset_game_state():

	_is_game_over = false
	total_score = 0
	total_bonus = 0
	

func get_total_score():

	return total_score


func get_total_bonus():

	return total_bonus
	
	
func is_game_over() -> bool:
	
	return _is_game_over
	

func add_score():

	total_score += 1

	update_score_display()
	

func add_bonus( value: int ):

	total_bonus += value
	total_score += value

	update_score_display()


func update_score_display():

	var score_node = get_node("/root/Room/ScorePanel/Panel/Score")
	if score_node:
		score_node.text = "Score: %d" % total_score


func set_game_over():
	
	_is_game_over = true
	
	$GameOverTimer.start()


func _on_game_over_timer_timeout():
	
	get_tree().paused = true

	get_tree().root.add_child( preload("res://ui/game_over.tscn").instantiate() )

