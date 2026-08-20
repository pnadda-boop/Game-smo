extends Control
## ==============================================
## วงกลมเส้นขอบที่วาดเอง — ตัวรูปร่างของเอฟเฟกต์คลิก
## ==============================================
## แนบที่โหนด `Circle` ใน `ui_ripple.tscn`
##
## ตัวคุมอยู่ที่ `ripple.gd` (โหนดแม่) ตัวนี้มีหน้าที่เดียวคือ "วาดวงกลมรัศมีเท่านี้"
##
## ⚠️ วาดเองด้วย `_draw()` ไม่ได้ใช้ Panel + StyleBox แบบเดิม เพราะ:
## - เส้นขอบบางคงที่ ไม่ถูกยืดตามตอนวงขยาย (ของเดิมใช้ `scale` เส้นขอบจะหนาขึ้นตามด้วย)
## - คุมรัศมีเป็นตัวเลขตรง ๆ ได้ tween ง่ายกว่าการ tween `scale`

@export var color: Color = Color(1, 1, 1, 1)
@export var stroke_width: float = 3.0

## จำนวนด้านของวงกลม — มากไปเปลืองเปล่า ๆ น้อยไปเห็นเป็นเหลี่ยม
@export var segments: int = 64

## รัศมีปัจจุบัน — `ripple.gd` tween ค่านี้
##
## ⚠️ ต้องมี setter ที่เรียก `queue_redraw()` ไม่งั้น tween เปลี่ยนตัวเลขแล้วภาพไม่ขยับ
## (`_draw()` ทำงานเฉพาะตอนถูกสั่งวาดใหม่ ไม่ได้วาดทุกเฟรมเหมือน `_process`)
var radius: float = 0.0:
	set(value):
		radius = value
		queue_redraw()


func _ready() -> void:
	## เอฟเฟกต์ต้องไม่กินคลิก — มันลอยอยู่ตรงจุดที่ผู้เล่นเพิ่งกดพอดี
	## (โหนดในซีนตั้งไว้แล้ว แต่ย้ำจากโค้ดกันพลาดตอนสร้างโหนดใหม่)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	## โหนดนี้เคยเป็น `Panel` ที่มีสไตล์วงกลมทึบ — ถ้ายังไม่ได้เปลี่ยนชนิดโหนดในซีน
	## สไตล์เดิมจะทึบบังวงกลมที่วาดเอง ล้างทิ้งให้เหลือแต่เส้นที่ `_draw()` วาด
	##
	## ⚠️ เทียบด้วย `get_class()` ไม่ใช่ `self is Panel` — สคริปต์ประกาศ `extends Control`
	## ตัวตรวจชนิดตอนคอมไพล์จึงฟันธงว่า "เป็น Panel ไม่ได้" แล้ว **ขึ้น Parse Error ทั้งไฟล์**
	## (ทั้งที่ตอนรันจริงโหนดเป็น Panel ได้ เพราะ Panel สืบทอดจาก Control)
	if get_class() == "Panel":
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())


func _draw() -> void:
	if radius <= 0.0:
		return
	draw_arc(size / 2.0, radius, 0.0, TAU, segments, color, stroke_width, true)
