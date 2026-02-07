extends Node


# High score tracking - stores top score per difficulty
# Keys correspond to Global.Difficulty enum values (0=EASY, 1=NORMAL, 2=HARD)
var high_scores: Dictionary = {
	0: {"score": 0, "length": 0},  # EASY
	1: {"score": 0, "length": 0},  # NORMAL
	2: {"score": 0, "length": 0}   # HARD
}
const HIGHSCORE_FILE = "user://highscores.cfg"


func _ready():
	load_highscores()


func load_highscores():
	var config = ConfigFile.new()
	var err = config.load(HIGHSCORE_FILE)

	if err != OK:
		# First time playing or file doesn't exist - use defaults
		print("High scores file not found, initializing with defaults")
		return

	# Load each difficulty's high score
	for difficulty_value in Global.Difficulty.values():
		var section = Global.Difficulty.keys()[difficulty_value]
		if config.has_section(section):
			high_scores[difficulty_value] = {
				"score": config.get_value(section, "score", 0),
				"length": config.get_value(section, "length", 0)
			}


func save_highscores():
	var config = ConfigFile.new()

	# Save each difficulty's high score
	for difficulty_value in Global.Difficulty.values():
		var section = Global.Difficulty.keys()[difficulty_value]
		config.set_value(section, "score", high_scores[difficulty_value]["score"])
		config.set_value(section, "length", high_scores[difficulty_value]["length"])

	var err = config.save(HIGHSCORE_FILE)
	if err != OK:
		push_error("Failed to save high scores: " + str(err))


func get_highscore(diff: Global.Difficulty) -> Dictionary:
	return high_scores[diff]


func check_and_update_highscore(diff: Global.Difficulty, score: int, length: int) -> bool:
	# Returns true if this is a new high score
	var current_high = high_scores[diff]["score"]

	if score > current_high:
		high_scores[diff]["score"] = score
		high_scores[diff]["length"] = length
		save_highscores()
		return true

	return false
