extends ColorRect

func _ready():

	$Score.text = "total score: %d" % Global.get_total_score()
	$Bonus.text = "bonus score: %d" % Global.get_total_bonus()
	$SnakeLength.text = "snake length: %d" % (Global.get_total_score() - Global.get_total_bonus() + 1)
	$Difficulty.text = "difficulty: " + ("HARD" if Global.difficulty == Global.Difficulty.HARD else "normal")

	# Check and update high score
	var score = Global.get_total_score()
	var length = Global.get_total_score() - Global.get_total_bonus() + 1
	HighScore.check_and_update_highscore(Global.difficulty, score, length)
	

func _on_button_pressed():

	# Remove the current game scene.
	get_tree().current_scene.free()

	# Attach the game screen to the root node, making it visible.
	get_tree().change_scene_to_file("res://ui/start.tscn" )

	# Remove the game over screen
	queue_free()
