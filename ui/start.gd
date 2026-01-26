extends ColorRect


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


func _on_about_button_pressed():
	$About.show_about()
