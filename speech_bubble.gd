extends PanelContainer
class_name SpeechBubble

## Script นี้ติดที่ scene SpeechBubble.tscn
## Scene tree ที่แนะนำ (ใช้ PanelContainer เพื่อให้ auto-resize ตาม content):
##   SpeechBubble (PanelContainer)  <- ติด script นี้ตรงนี้เลย
##                                     ใส่ลาย nine-patch เป็น Theme Override > Styles > Panel > StyleBoxTexture
##   └─ MarginContainer                <- ตั้ง margin รอบข้อความที่นี่
##       └─ Label                     <- ชื่อ node ต้องตรงกับ Unique Name ด้านล่าง

signal bubble_closed

## ต้องไปตั้งค่าใน Godot ก่อน: คลิกขวา node Label ในฉาก > "Access as Unique Name"
@onready var label: Label = $MarginContainer/Label

## ถ้า > 0 บับเบิ้ลจะปิดอัตโนมัติหลังจากเวลาที่กำหนด (วินาที) ตั้งเป็น 0 = ต้องคลิกปิดเอง
@export var auto_close_time: float = 0.0

var _timer: Timer = null


func _ready() -> void:
	if label == null:
		push_error("SpeechBubble หา Label ไม่เจอ! เช็คว่าตั้ง 'Access as Unique Name' ให้ node Label แล้วหรือยัง")
		return

	if auto_close_time > 0.0:
		_timer = Timer.new()
		_timer.wait_time = auto_close_time
		_timer.one_shot = true
		_timer.timeout.connect(close)
		add_child(_timer)
		_timer.start()


func set_text(text: String) -> void:
	label.text = text
	# PanelContainer เป็น Container จะคำนวณขนาดตาม content (Label ที่ wrap แล้ว) ให้อัตโนมัติ
	# ต้องรอ 1 เฟรมให้ Label คำนวณความสูงจากการ wrap คำเสร็จก่อน แล้วค่อยบังคับให้ container คำนวณขนาดใหม่
	await get_tree().process_frame
	reset_size()
	_play_intro_animation()


func _play_intro_animation() -> void:
	# ตั้ง pivot ไว้ที่กึ่งกลาง "ด้านล่าง" ของกล่อง (ต้องรู้ size จริงก่อน ถึงตั้งตรงนี้ได้)
	# ทำให้ scale.y ขยายจาก 0 ไป 1 แล้วดูเหมือนกล่องงอกขึ้นจากด้านล่างขึ้นบน
	pivot_offset = Vector2(size.x / 2.0, size.y)
	scale = Vector2(1.0, 0.0)
	modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.25)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)


func close() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(1.0, 0.0), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	bubble_closed.emit()
	queue_free()
