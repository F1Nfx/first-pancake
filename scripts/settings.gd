extends Node2D

const CONFIG_PATH = "user://settings.cfg"

@onready var music_slider: HSlider = $CanvasLayer/SettingsPanel/VBoxContainer/MusicSlider
@onready var sound_slider: HSlider = $CanvasLayer/SettingsPanel/VBoxContainer/SoundSlider
@onready var fullscreen_toggle: CheckButton = $CanvasLayer/SettingsPanel/VBoxContainer/FullscreenToggle
@onready var apply_button: Button = $CanvasLayer/SettingsPanel/VBoxContainer/ApplyButton


func _ready():
	_load_settings()


func _load_settings():
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	music_slider.value = config.get_value("audio", "music", 80)
	sound_slider.value = config.get_value("audio", "sound", 80)
	fullscreen_toggle.button_pressed = config.get_value("video", "fullscreen", false)
	# Применяем громкость при загрузке
	_apply_volumes()


func _save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "music", music_slider.value)
	config.set_value("audio", "sound", sound_slider.value)
	config.set_value("video", "fullscreen", fullscreen_toggle.button_pressed)
	config.save(CONFIG_PATH)


func _apply_volumes():
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_slider.value / 100.0))
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sound_slider.value / 100.0))


func _apply_fullscreen(pressed: bool):
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_apply_button_pressed():
	print("Apply pressed! Fullscreen toggle: ", fullscreen_toggle.button_pressed)
	_apply_fullscreen(fullscreen_toggle.button_pressed)
	_apply_volumes()
	_save_settings()
	apply_button.text = "Saved!"
	await get_tree().create_timer(1.0).timeout
	apply_button.text = "Apply"


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
