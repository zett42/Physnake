extends Window


func _ready():
	# Load and display the LICENSE file
	var license_path = "res://LICENSE"
	if FileAccess.file_exists(license_path):
		var file = FileAccess.open(license_path, FileAccess.READ)
		if file:
			var license_text = file.get_as_text()
			file.close()
			$Panel/ScrollContainer/LicenseText.text = license_text
	else:
		$Panel/ScrollContainer/LicenseText.text = "LICENSE file not found."


func _on_github_button_pressed():
	OS.shell_open("https://github.com/zett42/Physnake")


func _on_close_button_pressed():
	hide()


func show_about():
	popup_centered()
