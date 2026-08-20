class_name DropZoneHint
extends Area2D
## ==============================================
## เส้นบอกจุดวางของ — กระพริบตอนผู้เล่นเข้ามาในห้อง
## ==============================================
## แนบที่โหนด `RoomBox` (Area2D) ใน `level_2_1.tscn` ซึ่งมี `Line2D` เป็นลูก
##
## **สองวงซ้อนกัน คนละหน้าที่:**
##
## | เขต | ขนาด | ความหมาย |
## |---|---|---|
## | `RoomBox` (ตัวนี้) | ทั้งมุมห้อง | "ของต้องไปวางแถวนี้" → เส้นกระพริบ |
## | `Box/InteractArea` | รัศมี 50 | "ยืนตรงนี้กด E ได้เลย" → เส้นดับ |
##
## 🚨 **เส้นดับตอนเข้าเขตกด E ไม่ใช่ตอนวางเสร็จ** — เส้นมีหน้าที่เดียวคือ "พาไปให้ถึง"
## ถึงแล้วยังกระพริบอยู่ก็กลายเป็นเสียงรบกวนทับกล่องที่กำลังจะวาง
## และตัวบอกว่ากดได้คือระบบเป้าหมายของผู้เล่นซึ่งทำงานของมันอยู่แล้ว

## เส้นที่จะกระพริบ — ปล่อยเป็นค่าเริ่มต้นถ้าชื่อโหนดเป็น `Line2D` ตามซีน
@export var line_path: NodePath = ^"Line2D"

## จุดวางกล่อง — ต้องรู้จักเพื่อดับเส้นตอนผู้เล่นเข้าเขตกด E และตอนวางเสร็จ
##
## ⚠️ ชี้ที่โหนด ไม่ใช่ค้นจากกลุ่ม — ห้องเดียวอาจมีจุดวางหลายจุดในอนาคต
## แล้วเส้นแต่ละเส้นต้องรู้ว่าตัวเองคู่กับจุดไหน
@export var drop_point_path: NodePath = ^"../Box"

@export_group("การกระพริบ")
## เวลาต่อหนึ่งรอบ (จางลงแล้วสว่างกลับ) — ยิ่งมากยิ่งช้า
@export var blink_duration: float = 1.0

## ความจางที่สุดตอนกระพริบ (0 = หายสนิท)
##
## ⚠️ ไม่ตั้งเป็น 0 โดยตั้งใจ — จางจนหายสนิทจะอ่านเป็น "เส้นดับไปแล้ว" ได้ในจังหวะที่มืดพอดี
## เหลือติดไว้นิดหน่อยจึงยังบอกว่า "จุดนี้ยังรออยู่"
@export var blink_min_alpha: float = 0.15
@export_group("")

var _line: Line2D = null
var _drop_point: Node = null
var _tween: Tween = null

## ผู้เล่นอยู่ในเขตห้องไหม
var _in_zone: bool = false

## ผู้เล่นเข้าไปถึงระยะกด E ของจุดวางแล้วไหม
var _at_drop_point: bool = false


func _ready() -> void:
	_line = get_node_or_null(line_path) as Line2D
	if _line == null:
		push_error("drop_zone_hint.gd: `%s` หา Line2D ที่ `%s` ไม่เจอ — ไม่มีเส้นให้กระพริบ" \
			% [name, line_path])

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_connect_drop_point()
	_refresh()


func _connect_drop_point() -> void:
	_drop_point = get_node_or_null(drop_point_path)
	if _drop_point == null:
		## ⚠️ warning ไม่ใช่ error — เส้นยังกระพริบได้ตามปกติ แค่จะไม่ดับตอนเข้าใกล้กล่อง
		## (ฟีเจอร์เสียบางส่วน ต่างจากไม่มีเส้นเลยซึ่งเป็นการพังทั้งอัน)
		push_warning("drop_zone_hint.gd: `%s` หาจุดวางที่ `%s` ไม่เจอ — เส้นจะไม่ดับตอนเข้าใกล้" \
			% [name, drop_point_path])
		return

	if _drop_point.has_signal("player_range_changed"):
		_drop_point.player_range_changed.connect(_on_drop_point_range_changed)
	if _drop_point.has_signal("placed"):
		_drop_point.placed.connect(_on_placed)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_in_zone = true
	_refresh()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_in_zone = false
	_refresh()


func _on_drop_point_range_changed(inside: bool) -> void:
	_at_drop_point = inside
	_refresh()


## วางเสร็จ — แค่มาปลุกให้คิดใหม่ ตัวคำตอบอ่านจาก `GameState` ใน `_refresh()` เอง
##
## ⚠️ **จงใจไม่เก็บ "วางแล้ว" ไว้เป็นตัวแปรของตัวเอง**
## เก็บสำเนาไว้ = เส้นจะเชื่อสำเนานั้น ซึ่งอัปเดตได้ก็ต่อเมื่อสัญญาณมาถึงจริง
## `drop_point_path` ชี้ผิดเมื่อไหร่ (เปลี่ยนชื่อโหนด / ย้ายที่) สัญญาณไม่ถึง
## แล้ว**เส้นจะกระพริบต่อทั้งที่วางไปแล้ว** — มี warning เตือนก็จริงแต่บนจอคือฟีเจอร์ทำงานผิด
func _on_placed(_point: Node2D) -> void:
	_refresh()


## ตัดสินจากสถานะทั้งหมดพร้อมกันว่าเส้นควรกระพริบอยู่ไหม
##
## 🚨 **จุดเดียวที่เปิด/ปิดเส้น** — เหตุการณ์ที่กระทบมี 4 อย่าง (เข้าห้อง · ออกห้อง ·
## เข้าใกล้กล่อง · วางเสร็จ) และมาไม่เรียงลำดับ (เข้าเขตกด E ก่อนเข้าเขตห้องก็เป็นไปได้
## ถ้าวงซ้อนกันไม่พอดี) · สั่งเปิด/ปิดกระจายตามแต่ละเหตุการณ์เมื่อไหร่
## จะมีลำดับที่ทำให้เส้นค้างสว่างหรือค้างดับแบบทำซ้ำไม่ได้
func _refresh() -> void:
	if _line == null:
		return

	## 🚨 **เงื่อนไขคือ "ถือกล่องอยู่" ไม่ใช่ "ยังไม่ได้วาง"**
	##
	## ซีนเควสต์ถูก instance ค้างไว้ใน `level_2.tscn` ตลอดเวลา ไม่ได้ถูกสร้างตอนเนื้อเรื่องถึงคิว
	## เส้นจึงต้องเงียบเองในทุกจังหวะที่ผู้เล่นไม่ได้ถืออะไรมา:
	##
	## | สถานะ | `carrying_box` | เส้น |
	## |---|---|---|
	## | ยังไม่คุยกับวาวา | false | เงียบ — ไม่งั้นสปอยล์ว่าตรงนี้จะมีอะไร |
	## | ถือกล่องมาแล้ว | true | กระพริบ |
	## | วางเสร็จแล้ว | false | เงียบ |
	##
	## ใช้เงื่อนไขเดียวครอบทั้งสามกรณีได้เพราะ `carrying_box` เป็นเท็จทั้งก่อนหยิบและหลังวาง
	## (เขียนเป็น `not box_delivered` จะเงียบเฉพาะหลังวาง แล้วจะสปอยล์ตั้งแต่ยังไม่ได้คุยกับวาวา)
	##
	## ⚠️ อ่านจาก `GameState` ตรง ๆ ทุกครั้ง ไม่เก็บสำเนา — เป็นแหล่งความจริงเดียวกับที่
	## `box_drop_point.gd` เขียนลงไป จึงถูกเสมอแม้สัญญาณจากกล่องจะไม่เคยมาถึง (สายขาด)
	var should_blink: bool = _in_zone and not _at_drop_point and GameState.carrying_box
	if should_blink:
		_start_blink()
	else:
		_stop_blink()


func _start_blink() -> void:
	if _tween and _tween.is_valid():
		return   ## กระพริบอยู่แล้ว อย่าเริ่มใหม่ ไม่งั้นจังหวะจะรีเซ็ตทุกครั้งที่มีเหตุการณ์อื่นมา

	_line.visible = true
	_line.modulate.a = 1.0

	## ⚠️ ผูก tween กับตัวเอง (`create_tween()` ของโหนดนี้) ไม่ใช่ tween ลอย ๆ
	## ซีนถูกรื้อทิ้งตอนเปลี่ยนฉาก tween ที่ไม่มีเจ้าของจะยังวิ่งต่อแล้วเขียนใส่โหนดที่ตายแล้ว
	_tween = create_tween().set_loops()
	_tween.tween_property(_line, "modulate:a", blink_min_alpha, blink_duration * 0.5)
	_tween.tween_property(_line, "modulate:a", 1.0, blink_duration * 0.5)


func _stop_blink() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null

	## 🚨 ต้องคืน alpha เป็น 1 ด้วย ไม่ใช่แค่ซ่อน
	## หยุดตอนจางอยู่แล้วซ่อนเฉย ๆ = รอบหน้าที่โชว์จะเริ่มจากค่าที่ค้างไว้
	## (ตอนนี้ `_start_blink()` ตั้งให้อยู่แล้ว แต่เก็บไว้กันคนอื่นมาสั่ง `show()` ตรง ๆ ทีหลัง)
	_line.modulate.a = 1.0
	_line.visible = false
