extends Node

const CONFIG_PATH = "user://settings.cfg"

var click_sound: AudioStream = preload("res://assets/sounds/ui_click.wav")


func _ready():
	load_and_apply_settings()


func load_and_apply_settings():
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	var music_value = config.get_value("audio", "music", 80)
	var sound_value = config.get_value("audio", "sound", 80)
	
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_value / 100.0))
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sound_value / 100.0))


func play_click():
	var audio = AudioStreamPlayer.new()
	audio.stream = click_sound
	audio.bus = "SFX"
	audio.pitch_scale = randf_range(0.95, 1.05)
	audio.finished.connect(audio.queue_free)
	add_child(audio)
	audio.play()
