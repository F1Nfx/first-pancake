extends Node2D


var is_crit: bool = false
var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var damage_number_scene: PackedScene = preload("res://scenes/damage_number.tscn")


func _ready():
	await get_tree().create_timer(5.0).timeout
	queue_free()


func _physics_process(delta):
	global_position += velocity * delta


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		enemy.take_damage(damage)
		_spawn_damage_number(enemy.global_position)
		queue_free()

func _spawn_damage_number(pos: Vector2):
	var dmg_label = damage_number_scene.instantiate()
	dmg_label.text = str(int(damage))
	if is_crit:
		dmg_label.add_theme_font_size_override("font_size", 28)  # крупный шрифт
	else:
		dmg_label.add_theme_font_size_override("font_size", 16)  # обычный
	dmg_label.global_position = pos + Vector2(randf_range(-10, 10), -20)
	get_parent().add_child(dmg_label)
