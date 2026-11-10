extends Node2D


@export var speed: float = 350.0
@export var world_size: Vector2 = Vector2(2000, 2000)
@export var max_hp: float = 100.0
@export var attack_cooldown: float = 0.5
@export var invincible_duration: float = 1.5


var hurt_sound: AudioStream = preload("res://assets/sounds/hurt.wav")
var base_scale: float = 1.5
var shoot_sound: AudioStream = preload("res://assets/sounds/shoot.wav")
var audio_player: AudioStreamPlayer
var extra_bullets: int = 0
var bullet_spread: float = 0.0
var lifesteal: float = 0.0
var regen_per_second: float = 0.0
var regen_accumulator: float = 0.0
var pickup_radius: float = 30.0  # базовый радиус
var crit_chance: float = 0.0
var crit_multiplier: float = 2.0
var hp: float
var experience: float = 0.0
var experience_to_next: float = 50.0
var level: int = 1
var attack_timer: float = 0.0
var is_invincible: bool = false
var invincible_timer: float = 0.0
var damage_multiplier: float = 1.0
var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
var bounce_time: float = 0.0


signal died
signal level_up


func _ready():
	add_to_group("player")
	hp = max_hp
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	audio_player.stream = shoot_sound
	add_child(audio_player)
	audio_player.volume_db = -10.0
	_start_idle_animation()

func _start_idle_animation():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 1.0)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 1.0)


func _physics_process(delta):
	var input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	global_position += input * speed * delta
	global_position.x = clamp(global_position.x, 0, world_size.x)
	global_position.y = clamp(global_position.y, 0, world_size.y)
	
	var sprite = $AnimatedSprite2D
	if input == Vector2.ZERO:
		sprite.play("idle")
	else:
		sprite.play("walk")
		if input.x < 0:
			sprite.flip_h = false
		elif input.x > 0:
			sprite.flip_h = true
	
	if input != Vector2.ZERO:
		bounce_time += delta * 10
		scale = Vector2(base_scale, base_scale * (1.0 + sin(bounce_time) * 0.05))
	else:
		bounce_time = 0.0
		scale = Vector2(base_scale, base_scale)


func heal(amount: float):
	hp = min(hp + amount, max_hp)
	get_parent()._update_hearts()


func _process(delta):
	if is_invincible:
		invincible_timer -= delta
		if invincible_timer <= 0:
			is_invincible = false
		modulate.a = 0.5 if int(invincible_timer * 10) % 2 == 0 else 1.0
	else:
		modulate.a = 1.0

	if regen_per_second > 0:
		regen_accumulator += delta
		if regen_accumulator >= 1.0:
			regen_accumulator -= 1.0
			heal(regen_per_second)

	attack_timer -= delta
	if attack_timer <= 0:
		var target = _get_nearest_enemy()
		if target:
			_shoot(target.global_position)
			attack_timer = attack_cooldown


func _get_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null
	var nearest = enemies[0]
	var min_dist = global_position.distance_squared_to(nearest.global_position)
	for e in enemies:
		var d = global_position.distance_squared_to(e.global_position)
		if d < min_dist:
			min_dist = d
			nearest = e
	return nearest


func _shoot(target_pos: Vector2):
	var bullet_count = 1 + extra_bullets
	var angle_step = 0.15
	var base_angle = (target_pos - global_position).angle()
	var start_angle = base_angle - (angle_step * (bullet_count - 1) / 2)
	
	for i in bullet_count:
		var bullet = bullet_scene.instantiate()
		get_parent().add_child(bullet)
		bullet.global_position = global_position
		var angle = start_angle + angle_step * i
		var direction = Vector2(cos(angle), sin(angle))
		bullet.velocity = direction * 500.0
		bullet.damage *= damage_multiplier
		
		var is_crit = randf() < crit_chance
		if is_crit:
			bullet.damage *= crit_multiplier
			bullet.is_crit = true
		
	if audio_player:
		audio_player.play()


func add_experience(value: float):
	experience += value
	while experience >= experience_to_next:
		experience -= experience_to_next
		level += 1
		experience_to_next *= 1.3
		emit_signal("level_up")
	get_parent()._update_xp_bar()


func take_damage(amount: float):
	if is_invincible:
		return
	hp -= amount
	print("HP: ", hp)
	is_invincible = true
	invincible_timer = invincible_duration
	
	# Звук урона
	var audio = AudioStreamPlayer.new()
	audio.stream = hurt_sound
	audio.pitch_scale = randf_range(0.95, 1.05)
	audio.bus = "SFX"
	audio.finished.connect(audio.queue_free)
	get_parent().add_child(audio)
	audio.play()
	
	get_parent()._update_hearts()
	get_parent().shake_screen(8.0, 0.15)
	if hp <= 0:
		emit_signal("died")
		queue_free()


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		take_damage(area.get_parent().damage)
