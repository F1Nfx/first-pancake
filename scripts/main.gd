extends Node2D


var level_up_sound: AudioStream = preload("res://assets/sounds/level_up.wav")
var card_select_sound: AudioStream = preload("res://assets/sounds/card_select.wav")
var selected_upgrade_index: int = 0
var heart_full = preload("res://assets/sprites/player/heart_full.png")
var heart_half = preload("res://assets/sprites/player/heart_half.png")
var heart_empty = preload("res://assets/sprites/player/heart_empty.png")
var is_paused: bool = false
var current_upgrades: Array = []
var pending_level_ups: int = 0
var spawning: bool = false
var enemies_killed: int = 0
var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
var wave_number: int = 0
var wave_cleared: bool = false
var world_size: Vector2 = Vector2(2000, 2000)
var upgrade_pool: Array = [
	{"name": "+ Speed", "type": "speed", "value": 30, "desc": "Move faster", "icon": preload("res://assets/sprites/icons/speed.png")},
	{"name": "- Cooldown", "type": "cooldown", "value": 0.85, "desc": "Attack faster", "icon": preload("res://assets/sprites/icons/cooldown.png")},
	{"name": "+ Damage", "type": "damage", "value": 0.25, "desc": "More damage", "icon": preload("res://assets/sprites/icons/damage.png")},
	# потом доделаем и вернем {"name": "+ Max HP", "type": "max_hp", "value": 20, "desc": "More health", "icon": preload("res://assets/sprites/icons/max_hp.png")},
	{"name": "+ HP Heal", "type": "heal", "value": 30, "desc": "Heal now", "icon": preload("res://assets/sprites/icons/heal.png")},
	{"name": "+ Projectile", "type": "extra_bullets", "value": 1, "desc": "Extra shot", "icon": preload("res://assets/sprites/icons/projectile.png")},
	{"name": "Lifesteal", "type": "lifesteal", "value": 2, "desc": "HP on kill", "icon": preload("res://assets/sprites/icons/lifesteal.png")},
	{"name": "+ Pickup Radius", "type": "pickup_radius", "value": 40, "desc": "Collect farther", "icon": preload("res://assets/sprites/icons/pickup_radius.png")},
	{"name": "+ Crit Chance", "type": "crit_chance", "value": 0.125, "desc": "Crit chance", "icon": preload("res://assets/sprites/icons/crit_chance.png")},
	{"name": "Regeneration", "type": "regen", "value": 2, "desc": "Regen HP", "icon": preload("res://assets/sprites/icons/regen.png")},
]

@onready var icon_buttons: Array = [
	$CanvasLayer/LevelUpPanel/LeftPage/IconButton1,
	$CanvasLayer/LevelUpPanel/LeftPage/IconButton2,
	$CanvasLayer/LevelUpPanel/LeftPage/IconButton3
]

@onready var selected_icon: TextureRect = $CanvasLayer/LevelUpPanel/RightPage/SelectedIcon
@onready var buff_name: Label = $CanvasLayer/LevelUpPanel/RightPage/BuffName
@onready var buff_desc: Label = $CanvasLayer/LevelUpPanel/RightPage/BuffDesc
@onready var stats_panel: Panel = $CanvasLayer/StatsPanel
@onready var stats_text_label: Label = $CanvasLayer/StatsPanel/StatsTextLabel
@onready var stats_label: Label = $CanvasLayer/GameOverPanel/StatsLabel
@onready var wave_label: Label = $HUD/WaveLabel
@onready var xp_bar: ProgressBar = $HUD/XPBar

func _connect_ui_sounds(node):
	for child in node.get_children():
		if child is Button:
			child.pressed.connect(UiSound.play_click)
		_connect_ui_sounds(child)


func _update_hearts():
	var max_hearts = ceil($Player.max_hp / 20.0)
	var hp_per_heart = 20.0

	for child in $HUD/HeartsContainer/HeartsRow.get_children():
		child.queue_free()
	
	for i in max_hearts:
		var heart = TextureRect.new()
		heart.custom_minimum_size = Vector2(38, 38)
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		$HUD/HeartsContainer/HeartsRow.add_child(heart)
		
		var heart_hp = $Player.hp - (i * hp_per_heart)
		if heart_hp >= hp_per_heart:
			heart.texture = heart_full
		elif heart_hp > 0:
			heart.texture = heart_half
		else:
			heart.texture = heart_empty

func _ready():
	var player = $Player
	player.died.connect(_on_player_died)
	_update_hearts()
	_update_xp_bar()
	await get_tree().create_timer(3.0).timeout
	_spawn_next_wave()
	player.level_up.connect(_on_player_level_up)
	_connect_ui_sounds(self)

func shake_screen(amount: float = 10.0, duration: float = 0.2):
	var camera = $Player
	var original_pos = camera.global_position
	var tween = create_tween()
	tween.tween_property(camera, "global_position", original_pos + Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), duration * 0.25)
	tween.tween_property(camera, "global_position", original_pos + Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), duration * 0.25)
	tween.tween_property(camera, "global_position", original_pos, duration * 0.5)



func _get_random_upgrades(count: int = 3) -> Array:
	var pool_copy = upgrade_pool.duplicate()
	pool_copy.shuffle()
	return pool_copy.slice(0, count)


func _on_player_level_up():
	pending_level_ups += 1



func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if is_paused:
			_resume_game()
		else:
			_pause_game()
	
	if not is_paused and wave_number > 0 and not wave_cleared and not spawning and get_tree().get_nodes_in_group("enemies").is_empty():
		wave_cleared = true
		_on_wave_cleared()

	if Input.is_action_just_pressed("ui_focus_next"):
		stats_panel.visible = not stats_panel.visible
		if stats_panel.visible:
			_update_stats_panel()


func _pause_game():
	is_paused = true
	$CanvasLayer/PausePanel.visible = true
	$Player.set_process(false)
	$Player.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_process(false)
		enemy.set_physics_process(false)


func _resume_game():
	is_paused = false
	$CanvasLayer/PausePanel.visible = false
	$Player.set_process(true)
	$Player.set_physics_process(true)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_process(true)
		enemy.set_physics_process(true)


func _update_stats_panel():
	var player = $Player
	stats_text_label.text = "Level: " + str(player.level) + "\nSpeed: " + str(player.speed) + "\nDamage: " + str(player.damage_multiplier) + "\nCrit: " + str(int(player.crit_chance * 100)) + "%" + "\nLifesteal: " + str(player.lifesteal) + "\nRegen: " + str(player.regen_per_second) + "\nPickup: " + str(player.pickup_radius)
	
	
func _on_wave_cleared():
	if pending_level_ups > 0:
		pending_level_ups -= 1
		current_upgrades = _get_random_upgrades()
		_update_upgrade_buttons()
		$CanvasLayer/LevelUpPanel.visible = true
		
		var audio = AudioStreamPlayer.new()
		audio.stream = level_up_sound
		audio.finished.connect(audio.queue_free)
		audio.bus = "SFX"
		add_child(audio)
		audio.play()
	else:
		wave_cleared = false
		_spawn_next_wave()


func _update_upgrade_buttons():
	for i in 3:
		icon_buttons[i].texture_normal = current_upgrades[i]["icon"]
	_show_upgrade_info(0)


func _update_xp_bar():
	var progress = $Player.experience / $Player.experience_to_next
	xp_bar.value = progress * 100


func _on_player_died():
	$CanvasLayer/GameOverPanel.visible = true
	stats_label.text = "Waves survived: " + str(wave_number) + "\nEnemies killed: " + str(enemies_killed)


func _spawn_next_wave():
	wave_number += 1
	var enemy_types = ["slime", "ghost", "eye"]
	var count = 3 + wave_number * 3
	var enemy_size = 1.0 + wave_number * 0.01
	var enemy_hp = 1.0 + wave_number * 0.2
	wave_label.text = "Wave " + str(wave_number)
	print("Wave ", wave_number, " | Enemies: ", count, " | Size: ", enemy_size, " | HP: ", enemy_hp)
	
	for i in count:
		var enemy = enemy_scene.instantiate()
		enemy.enemy_type = enemy_types[randi() % enemy_types.size()]
		enemy.enemy_scale = enemy_size
		enemy.hp_scale = enemy_hp
		enemy.global_position = _random_spawn_pos()
		add_child(enemy)
	
	if wave_number % 3 == 0:
		var elite = enemy_scene.instantiate()
		elite.is_elite = true
		elite.enemy_type = enemy_types[randi() % enemy_types.size()]
		elite.enemy_scale = enemy_size * 1.5
		elite.hp_scale = enemy_hp
		elite.global_position = _random_spawn_pos()
		add_child(elite)
		print("Elite spawned!")
		
	if wave_number % 4 == 0:
		var devourer = enemy_scene.instantiate()
		devourer.is_devourer = true
		devourer.enemy_scale = enemy_size * 1.5
		devourer.hp_scale = enemy_hp
		devourer.global_position = _random_spawn_pos()
		add_child(devourer)
		print("Devourer boss spawned!")
		
	if wave_number % 5 == 0:
		var boss = enemy_scene.instantiate()
		boss.is_boss = true
		boss.enemy_scale = enemy_size * 1.5
		boss.hp_scale = enemy_hp
		boss.global_position = _random_spawn_pos()
		add_child(boss)
		print("Beholder boss spawned!")


func _random_spawn_pos() -> Vector2:
	var margin = 100.0  # отступ от краёв карты
	var x = randf_range(margin, world_size.x - margin)
	var y = randf_range(margin, world_size.y - margin)
	return Vector2(x, y)



func _on_accept_button_pressed():
	_apply_upgrade(current_upgrades[selected_upgrade_index])
	
	# Звук выбора
	var audio = AudioStreamPlayer.new()
	audio.stream = card_select_sound
	audio.bus = "SFX"
	audio.finished.connect(audio.queue_free)
	add_child(audio)
	audio.play()
	
	_close_level_up()

func _show_upgrade_info(index: int):
	selected_upgrade_index = index
	selected_icon.texture = current_upgrades[index]["icon"]
	buff_name.text = current_upgrades[index]["name"]
	buff_desc.text = current_upgrades[index]["desc"]


func _apply_upgrade(upgrade: Dictionary):
	match upgrade["type"]:
		"speed":
			$Player.speed += upgrade["value"]
		"cooldown":
			$Player.attack_cooldown *= upgrade["value"]
		"damage":
			$Player.damage_multiplier += upgrade["value"]
		"max_hp":
			$Player.max_hp += upgrade["value"]
			$Player.hp += upgrade["value"]
		"heal":
			$Player.hp = min($Player.hp + upgrade["value"], $Player.max_hp)
		"extra_bullets":
			$Player.extra_bullets += upgrade["value"]
		"lifesteal":
			$Player.lifesteal += upgrade["value"]
		"pickup_radius":
			$Player.pickup_radius += upgrade["value"]
		"crit_chance":
			$Player.crit_chance += upgrade["value"]
		"regen":
			$Player.regen_per_second += upgrade["value"]
	_update_hearts()


func _on_restart_button_pressed():
	get_tree().reload_current_scene()


func _on_resume_button_pressed():
	is_paused = false
	$CanvasLayer/PausePanel.visible = false
	$Player.set_process(true)
	$Player.set_physics_process(true)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_process(true)
		enemy.set_physics_process(true)


func _on_menu_button_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_quit_button_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _close_level_up():
	$CanvasLayer/LevelUpPanel.visible = false
	if pending_level_ups > 0:
		pending_level_ups -= 1
		current_upgrades = _get_random_upgrades()
		_update_upgrade_buttons()
		$CanvasLayer/LevelUpPanel.visible = true
		return
	spawning = true
	print("Level up closed, spawning next wave in 2 sec...")
	await get_tree().create_timer(2.0).timeout
	spawning = false
	if not is_paused:
		_spawn_next_wave()
	wave_cleared = false


func _on_icon_button_1_pressed() -> void:
	var audio = AudioStreamPlayer.new()
	audio.stream = card_select_sound
	audio.bus = "SFX"  
	audio.pitch_scale = randf_range(1.0, 1.1)
	audio.finished.connect(audio.queue_free)
	add_child(audio)
	audio.play()
	_show_upgrade_info(0)


func _on_icon_button_2_pressed() -> void:
	var audio = AudioStreamPlayer.new()
	audio.stream = card_select_sound
	audio.bus = "SFX"  
	audio.pitch_scale = randf_range(1.0, 1.1)
	audio.finished.connect(audio.queue_free)
	add_child(audio)
	audio.play()
	_show_upgrade_info(1)


func _on_icon_button_3_pressed() -> void:
	var audio = AudioStreamPlayer.new()
	audio.stream = card_select_sound
	audio.bus = "SFX"  
	audio.pitch_scale = randf_range(1.0, 1.1)
	audio.finished.connect(audio.queue_free)
	add_child(audio)
	audio.play()
	_show_upgrade_info(2)
