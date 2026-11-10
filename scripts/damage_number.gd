extends Label

var velocity: Vector2 = Vector2(0, -80)

func _ready():
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _process(delta):
	position += velocity * delta
