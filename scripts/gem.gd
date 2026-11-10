extends Node2D

var pickup_sound: AudioStream = preload("res://assets/sounds/gem_pickup.wav")
@export var experience_value: float = 10.0


func _ready():
	await get_tree().create_timer(10.0).timeout #время жизни гема
	queue_free()


func _process(delta):
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < player.pickup_radius:
			var dir = (player.global_position - global_position).normalized()
			global_position += dir * 900.0 * delta


func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox"):
		var audio = AudioStreamPlayer.new()
		audio.stream = pickup_sound
		audio.bus = "SFX"
		audio.pitch_scale = randf_range(0.95, 1.05)
		audio.finished.connect(audio.queue_free)
		get_parent().add_child(audio)
		audio.play()
		area.get_parent().add_experience(experience_value)
		queue_free()
