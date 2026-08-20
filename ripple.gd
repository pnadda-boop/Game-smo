extends Control
## ==============================================
## วงกลมกระเพื่อมตอนคลิก
## ==============================================
## โหนดรากของ `ui_ripple.tscn` · ตัวรูปร่างอยู่ที่ลูกชื่อ `Circle` (`circle.gd`)
##
## 🚨 **จบแล้ว `hide()` ไม่ใช่ `queue_free()`** — ตัวนี้ถูกใช้ซ้ำ
## `click_effect.gd` เก็บไว้เป็นสระ (pool) แล้วหยิบใบที่ซ่อนอยู่มาเล่นใหม่
## ฉากปลุกน้ำฟ้าต้องกดรัว 20-30 ที การสร้าง/ทิ้งโหนดทุกคลิกคือการจ่ายฟรี
##
## ⚠️ **ห้ามใส่ `queue_free()` กลับเข้ามา** — ใบที่ถูกลบไปแล้วยังค้างอยู่ในสระของ
## `click_effect.gd` แล้วคลิกถัดไปจะไปเรียก `play()` ใส่โหนดที่ตายแล้ว

@onready var circle: Control = $Circle

## รัศมีสูงสุดตอนวงบานออกจนสุด
@export var max_radius: float = 60.0
## ใช้เวลากี่วินาทีตั้งแต่เริ่มจนจาง
@export var duration: float = 0.6
## ความเข้มตอนเริ่ม (1.0 = ทึบเต็ม)
@export var start_alpha: float = 0.8

## tween ที่กำลังเล่นอยู่ — เก็บไว้ฆ่าก่อนเริ่มรอบใหม่
var _tween: Tween = null


func _ready() -> void:
	## เอฟเฟกต์ต้องไม่กินคลิก
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	## เกิดมาต้องซ่อนไว้ก่อน — อยู่ในสระรอถูกเรียกใช้ ไม่ใช่โผล่ค้างมุมจอ
	hide()

	if circle == null:
		push_error("ripple.gd: ไม่พบโหนดลูกชื่อ `Circle` — เอฟเฟกต์คลิกจะไม่มีอะไรให้เห็น")
		return

	## ⚠️ เตือน **ครั้งเดียวตอนเปิดเกม** ไม่ใช่พ่น error ทุกคลิก
	## ลืมแนบ `circle.gd` แล้วปล่อยให้ `circle.radius = 0.0` วิ่งไปชน Panel เปล่า ๆ
	## จะได้ error สองบรรทัดต่อการคลิกหนึ่งครั้ง ท่วมคอนโซลจนกลบ error จริงที่ควรเห็น
	if not "radius" in circle:
		push_error("ripple.gd: โหนด `Circle` ยังไม่ได้แนบ `circle.gd` — เอฟเฟกต์คลิกถูกปิดไว้")
		circle = null


## เล่นเอฟเฟกต์ที่ตำแหน่งนี้ (พิกัดบนจอ)
func play(at_position: Vector2) -> void:
	if circle == null:
		return

	## 🚨 ฆ่า tween เก่าก่อนเสมอ — คลิกรัวจนวงเก่ายังไม่จบแล้วถูกหยิบมาใช้ซ้ำ
	## จะมี tween สองตัวแย่งกันเขียนค่า `radius` กับ `modulate:a` ในเฟรมเดียวกัน
	## ผลคือวงกระตุกและบางใบค้างไม่ยอมจางหาย
	if _tween and _tween.is_valid():
		_tween.kill()

	global_position = at_position - size / 2.0
	circle.radius = 0.0
	modulate.a = start_alpha
	show()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(circle, "radius", max_radius, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	## `chain()` ปิดท้ายชุดคู่ขนาน — callback จึงยิงหลังทั้งสองเส้นจบจริง ๆ
	_tween.chain().tween_callback(hide)
