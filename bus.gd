extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var max_speed := 280.0

var speed := 0.0
var driving := false

func _ready():
	sprite.play("idle")
	sprite.speed_scale = 1.0

func start_drive():
	if driving:
		return

	driving = true
	sprite.play("drive")

	# เริ่มต้นให้ล้อหมุนช้ามาก
	sprite.speed_scale = 0.05

	var tween = create_tween()

	# ค่อย ๆ ออกจากป้าย
	tween.tween_property(self, "speed", 60.0, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	# แล้วค่อยเร่งเต็มที่
	tween.tween_property(self, "speed", max_speed, 2.5)\
		.set_trans(Tween.TRANS_QUINT)\
		.set_ease(Tween.EASE_IN)

func _physics_process(delta):
	if driving:
		# รถเคลื่อนที่
		position.x += speed * delta

		# ความเร็ว Animation ตามความเร็วรถ
		var t := speed / max_speed
		sprite.speed_scale = clamp(lerp(0.05, 1.0, t), 0.05, 1.0)

		# ลบรถเมื่อวิ่งออกนอกฉาก
		if position.x > 2500:
			queue_free()
