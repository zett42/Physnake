extends ColorRect


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	update_highscore_display()


func update_highscore_display():
	# Update each difficulty's high score label
	var difficulties = [
		{
			"enum": Global.Difficulty.EASY,
			"node": $HighScoresContainer/EasyHighScore,
			"name": "EASY"
		},
		{
			"enum": Global.Difficulty.NORMAL,
			"node": $HighScoresContainer/NormalHighScore,
			"name": "NORMAL"
		},
		{
			"enum": Global.Difficulty.HARD,
			"node": $HighScoresContainer/HardHighScore,
			"name": "HARD"
		}
	]

	for diff_data in difficulties:
		var highscore = HighScore.get_highscore(diff_data["enum"])
		if highscore["score"] > 0:
			diff_data["node"].text = "%s: %d (Length: %d)" % [
				diff_data["name"],
				highscore["score"],
				highscore["length"]
			]
		else:
			diff_data["node"].text = "%s: ---" % diff_data["name"]


func _on_easy_button_pressed():
	
	Global.difficulty = Global.Difficulty.EASY
	get_tree().change_scene_to_file("res://ui/room.tscn")


func _on_normal_button_pressed():
	
	Global.difficulty = Global.Difficulty.NORMAL
	get_tree().change_scene_to_file("res://ui/room.tscn")


func _on_hard_button_pressed():
	
	Global.difficulty = Global.Difficulty.HARD
	get_tree().change_scene_to_file("res://ui/room.tscn")


func _on_exit_button_pressed():
	get_tree().quit()


func _on_settings_button_pressed():
	get_tree().change_scene_to_file("res://ui/settings.tscn")


func _on_about_button_pressed():
	$About.show_about()
