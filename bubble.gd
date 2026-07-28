extends AnimatedSprite2D

@export var float_distance: float = 5.0
@export var float_speed: float = 5.0

var time: float = 0.0
var original_scale: Vector2

func _ready():
	original_scale = scale
	hide_bubble()

func _process(delta):
	if visible:
		time += delta * float_speed
		offset.y = sin(time) * float_distance

func show_bubble():
	time = 0
	visible = true
	modulate.a = 0
	scale = Vector2.ZERO

	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", original_scale, 0.3)

	play("Bubble")

func hide_bubble():
	stop()
	visible = false
	frame = 0
	offset.y = 0
