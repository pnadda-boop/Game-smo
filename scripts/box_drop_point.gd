class_name BoxDropPoint
extends AnimatedSprite2D
## ==============================================
## จุดวางกล่อง — ปลายทางของกล่องที่วาวาฝากมา
## ==============================================
## แนบที่โหนด `Box` ใน `level_2_1.tscn` (ต้องมี Area2D ลูกชื่อ `InteractArea`)
##
## 🚨 **เป็นเรื่องตรงข้ามกับ `interact_box.gd` — อันนั้น "หยิบขึ้น" อันนี้ "วางลง"**
## จึงเป็นคนละสคริปต์ ไม่ใช่เพิ่มโหมดในไฟล์เดิม: เงื่อนไขกดได้ ท่าเริ่มต้น และสิ่งที่เกิดตอนกด
## ตรงข้ามกันหมด ยัดรวมกันแล้วทุกเมธอดจะต้องมี `if โหมดไหน` คร่อมไว้
##
## ⚠️ **ก่อนวาง กล่องซ่อนอยู่** — ผู้เล่นถือกล่องอยู่ในมือ (ชุดอนิเมชัน `_box` วาดกล่องมาในภาพแล้ว)
## โชว์กล่องที่จุดหมายไปด้วยจะเห็นกล่อง 2 ใบในเฟรมเดียว แล้วผู้เล่นแยกไม่ออกว่าใบไหนคือใบที่ถืออยู่
## ตัวบอกจุดก่อนวางคือ `Line2D` ที่กระพริบ (ดู `scripts/drop_zone_hint.gd`)

## ส่งตอนวางกล่องลงสำเร็จ — ให้เนื้อเรื่อง/เควสต์ดักต่อโดยไม่ต้องแก้ไฟล์นี้
signal placed(point: Node2D)

## ส่งตอนผู้เล่นเข้า/ออกระยะกดได้ — `drop_zone_hint.gd` ใช้ตัดสินว่าจะดับเส้นบอกจุดเมื่อไหร่
signal player_range_changed(inside: bool)

## ความสำคัญตอนผู้เล่นเลือกเป้าหมาย — ของในฉาก = 0 · NPC = 1 (กฎเดียวกับ `interact_box.gd`)
@export var priority: int = 0

## ท่าที่เล่นหลังวางลงแล้ว — ต้องมีชื่อนี้ใน SpriteFrames จริง
##
## ⚠️ ในซีนตั้ง `animation = "nearby"` ไว้ ซึ่งเป็นท่า "ผู้เล่นอยู่ใกล้" ของสคริปต์หยิบของ
## จุดวางไม่ได้ใช้ความหมายนั้น — วางแล้วก็คือกล่องธรรมดาวางอยู่ จึงใช้ `normal`
@export var placed_anim: String = "normal"

## ผู้เล่นที่อยู่ในระยะ (null = ไม่มีใครอยู่)
var _player: Node2D = null

## วางเรียบร้อยแล้วหรือยัง — อ่านค่าเริ่มต้นจาก `GameState` เพื่อให้เดินกลับเข้ามาแล้วกล่องยังอยู่
var _placed: bool = false

var _interact_area: Area2D = null


func _ready() -> void:
	_setup_area()

	_placed = GameState.box_delivered
	if _placed:
		_show_placed()
	else:
		## 🚨 ซ่อนตั้งแต่ต้นฉาก ไม่ใช่รอให้ผู้เล่นเดินเข้ามาแล้วค่อยซ่อน
		## ซีนถูกเสียบเข้ามาตอนผู้เล่นอยู่คนละมุมแมพ ถ้าโชว์ไว้ก่อนจะเห็นกล่องโผล่แล้วหายเอง
		visible = false


## ต่อสัญญาณจากโค้ด ไม่ต่อจาก editor (ต่อซ้ำ = เข้าเมธอดสองรอบต่อการเดินเข้าหนึ่งครั้ง)
func _setup_area() -> void:
	_interact_area = get_node_or_null("InteractArea") as Area2D
	if _interact_area == null:
		push_error("box_drop_point.gd: `%s` ไม่พบ Area2D ชื่อ `InteractArea` — วางกล่องไม่ได้ทั้งฉาก" % name)
		return

	_interact_area.body_entered.connect(_on_body_entered)
	_interact_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	_player = body

	## ⚠️ ลงทะเบียนแม้ตอนนี้ยังกดไม่ได้ (ไม่ได้ถือกล่องอยู่) — ผู้เล่นกรองด้วย `can_interact()`
	## ตอนกดอีกที · สถานะเปลี่ยนได้ระหว่างที่ยืนอยู่ในระยะ กรองตั้งแต่ตอนลงทะเบียน
	## แล้วรายการจะค้างสถานะเก่าจนกว่าจะเดินออกแล้วเข้าใหม่ (กฎเดียวกับ `interact_box.gd`)
	if body.has_method("add_nearby_target"):
		body.add_nearby_target(self)

	player_range_changed.emit(true)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("remove_nearby_target"):
		body.remove_nearby_target(self)

	_player = null
	player_range_changed.emit(false)


## กดได้เมื่อยังไม่ได้วาง และผู้เล่นถือกล่องอยู่จริง
##
## ⚠️ เช็ค `carrying` ด้วย ไม่ใช่แค่ "ยังไม่ได้วาง" — เดินมาถึงจุดนี้โดยมือเปล่า
## แล้วกด E ได้ = กล่องงอกมาจากอากาศ
func can_interact() -> bool:
	if _placed or _player == null:
		return false
	return "carrying" in _player and _player.carrying


## ผู้เล่นกด E (หรือคลิก) ใส่จุดวาง → วางกล่องลง
func interact() -> void:
	if not can_interact():
		return
	_place()


func _place() -> void:
	_placed = true
	GameState.box_delivered = true

	## มือว่างแล้ว — ทุกท่ากลับไปใช้ชุดปกติเองตั้งแต่เฟรมถัดไป
	## (`player._process()` เล่นอนิเมชันใหม่ทุกเฟรมอยู่แล้ว ไม่ต้องสั่งอะไรเพิ่ม)
	## setter ของ `carrying` เขียนกลับลง `GameState.carrying_box` ให้เอง
	_player.carrying = false

	## หันหน้ามาทางกล่องก่อนก้มวาง — เหมือนตอนหยิบและตอนคุยกับ NPC
	##
	## ⚠️ ต้องอยู่ **หลัง** ตั้ง `carrying = false` — `face_toward()` เล่นท่ายืนทันทีในบรรทัดนั้น
	## สลับลำดับจะได้ท่าถือกล่องหนึ่งเฟรมทั้งที่วางไปแล้ว (กระจกเงาของกับดักใน `interact_box.gd`)
	if _player.has_method("face_toward"):
		_player.face_toward(global_position)

	_show_placed()

	## ถอดออกจากรายการเป้าหมายทันที ไม่ต้องรอเดินออกนอกระยะ
	## (ไม่ถอด = กด E ซ้ำตรงนั้นจะยังเลือกกล่องที่วางไปแล้วแทน NPC ข้าง ๆ)
	if _player.has_method("remove_nearby_target"):
		_player.remove_nearby_target(self)

	if _interact_area:
		_interact_area.monitoring = false

	placed.emit(self)


## โผล่ขึ้นมาที่ **ตำแหน่งที่จัดไว้ในซีน** — ไม่ได้ย้ายตามผู้เล่น
##
## จุดวางถูกจัดวางให้เข้ากับของในห้องตั้งแต่ตอนแก้ซีนแล้ว วางตรงที่ผู้เล่นยืนพอดี
## จะได้กล่องเบี้ยว ๆ ทับเฟอร์นิเจอร์ ต่างกันทุกครั้งที่เล่น
func _show_placed() -> void:
	visible = true
	if sprite_frames and sprite_frames.has_animation(placed_anim):
		play(placed_anim)
	else:
		push_warning("box_drop_point.gd: `%s` ไม่มีอนิเมชันชื่อ `%s` (ที่มี: %s)" \
			% [name, placed_anim, ", ".join(sprite_frames.get_animation_names()) if sprite_frames else "—"])
