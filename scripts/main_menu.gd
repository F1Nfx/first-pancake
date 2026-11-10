extends Node2D

func _ready():
	_connect_ui_sounds(self)

func _connect_ui_sounds(node):
	for child in node.get_children():
		if child is Button:
			child.pressed.connect(UiSound.play_click)
		_connect_ui_sounds(child)

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_settings_button_pressed():
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
