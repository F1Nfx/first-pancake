extends Node2D


@export var speed: float = 150.0
@export var hp: float = 30.0
@export var damage: float = 33.0
@export var enemy_type: String = "slime"  # slime, ghost, eye


var is_elite: bool = false
var is_boss: bool = false
var is_devourer: bool = false
var audio_player: AudioStreamPlayer
var enemy_scale: float = 1.0
var hp_scale: float = 1.0
var player_ref: Node2D
var gem_scene: PackedScene = preload("res://scenes/gem.tscn")
# пока не нужен var hit_sound: AudioStream = preload("res://assets/sounds/hit.wav")
var death_sound: AudioStream = preload("res://assets/sounds/enemy_death.wav")


func _ready():
	add_to_group("enemies")
	hp *= hp_scale
	var sprite = get_node("AnimatedSprite2D")
	
	var type_scale_modifier = 1.0
	if enemy_type == "ghost":
		type_scale_modifier = 0.7
	
	var target_scale = Vector2(enemy_scale, enemy_scale) * type_scale_modifier
	
	if is_devourer:
		hp *= 6.0
		speed *= 1.8
		target_scale *= 0.8
		sprite.play("devourer_walk")
	elif is_boss:
		hp *= 10.0
		speed *= 1.8
		target_scale *= 1.2
		sprite.play("beholder_walk")
	elif is_elite:
		hp *= 5.0
		speed *= 1.4
		target_scale *= 1.2
		sprite.play(enemy_type + "_walk")
	else:
		sprite.play(enemy_type + "_walk")
	
	scale = target_scale * 0.1
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.3)
	
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_ref = players[0]
	
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)



func _physics_process(delta):
	if player_ref:
		var dir = (player_ref.global_position - global_position).normalized()
		global_position += dir * speed * delta
		
		if dir.x < 0:
			$AnimatedSprite2D.flip_h = true
		elif dir.x > 0:
			$AnimatedSprite2D.flip_h = false
		
		_separate_from_enemies()


func _separate_from_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for other in enemies:
		if other != self:
			var dist = global_position.distance_to(other.global_position)
			var min_dist = (scale.x * 30) + (other.scale.x * 30)
			if dist < min_dist and dist > 0:
				var push_dir = (global_position - other.global_position).normalized()
				global_position += push_dir * (min_dist - dist) * 0.5
		

func take_damage(amount: float):
	hp -= amount
	
	var sprite = get_node("AnimatedSprite2D")
	sprite.self_modulate = Color(2, 0.3, 0.3, 1)
	await get_tree().create_timer(0.1).timeout
	sprite.self_modulate = Color(1, 1, 1, 1)
	
	if hp <= 0:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.lifesteal > 0:
			player.heal(player.lifesteal)
	
		var death_audio = AudioStreamPlayer.new()
		death_audio.stream = death_sound
		death_audio.bus = "SFX"
		death_audio.pitch_scale = randf_range(0.95, 1.05)
		death_audio.finished.connect(death_audio.queue_free)
		get_parent().add_child(death_audio)
		death_audio.play()
		
		if is_devourer:
			for j in 7:
				var gem = gem_scene.instantiate()
				gem.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
				get_parent().add_child.call_deferred(gem)
		elif is_boss:
			for j in 12:
				var gem = gem_scene.instantiate()
				gem.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
				get_parent().add_child.call_deferred(gem)
		elif is_elite:
			for j in 3:
				var gem = gem_scene.instantiate()
				gem.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
				get_parent().add_child.call_deferred(gem)
		else:
			if randf() < 0.85:
				var gem = gem_scene.instantiate()
				gem.global_position = global_position
				get_parent().add_child.call_deferred(gem)
		
		get_parent().enemies_killed += 1
		call_deferred("queue_free")
