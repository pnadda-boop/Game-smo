extends Area2D
class_name NPC

## Script นี้ติดที่ node Area2D ซึ่งเป็นลูกของสไปรท์ (AnimatedSprite2D) ของ NPC
## Scene tree จริงของโปรเจกต์นี้:
##   NPC_AlignX (AnimatedSprite2D)  <- ตัวภาพจริงที่มองเห็น (parent)
##   └─ Area2D                      <- ติด script นี้ตรงนี้ (ลูก, ไม่มีภาพ แค่ไว้จับ input)
##       └─ CollisionShape2D
##
## เพราะ Area2D เป็นแค่ "hitbox" ที่ไม่มีภาพ สคริปต์นี้เลยต้องขยับ parent (สไปรท์) แทน
## ไม่ใช่ขยับ self ตรงๆ ไม่งั้นจะเห็นแค่ hitbox เลื่อน แต่ภาพไม่ขยับตาม
##
## ก่อนใช้ script นี้ ต้องติดตั้งเป็น Autoload ก่อน 2 ตัว:
##   1. npc_database.gd  ชื่อ "NPCDatabase"
##   2. seat_manager.gd   ชื่อ "SeatManager"
## และต้องมี CanvasLayer ชื่อกลุ่ม "ui_layer" สำหรับโชว์บับเบิ้ล (ดูจาก setup ก่อนหน้า)

## ใส่ id ของ NPC ตัวนี้ให้ตรงกับ key ใน NPCDatabase.NPC_DATA เช่น "NPC1", "NPC2"
@export var npc_id: String = ""

## ลาก SpeechBubble.tscn มาใส่ตรงนี้
@export var bubble_scene: PackedScene

## ตำแหน่งบับเบิ้ลเทียบกับตัวละคร (world units ก่อนแปลงเป็น screen position)
@export var bubble_offset: Vector2 = Vector2(0, -90)

## ระยะที่ต้องลากเมาส์เกินถึงจะนับเป็น "ลาก" (ถ้าขยับน้อยกว่านี้ = "คลิก" โชว์บับเบิ้ลแทน)
@export var drag_threshold: float = 16.0

## ระยะสูงสุดที่ยอมให้ "ปล่อย" แล้วนับว่าตกลงบนที่นั่งนั้น (ปรับตามขนาดที่นั่งจริง)
@export var seat_snap_distance: float = 40.0

var _current_bubble: Control = null

## NPC ตัวที่บับเบิลกำลังเปิดอยู่ — **ทั้งฉากมีได้ทีละตัว**
##
## เป็น `static` เพราะ "ตอนนี้ใครเปิดบับเบิลอยู่" เป็นสถานะของ**ทั้งกระดาน** ไม่ใช่ของ NPC ตัวใดตัวหนึ่ง
## เก็บที่ตัวเองแล้วแต่ละตัวจะรู้แค่ของตัวเอง ต้องไล่ถามทุกตัวทุกครั้งที่คลิก
## (กฎเดียวกับที่ `SeatManager._hovered_seat` เก็บช่องที่กำลังเล็งไว้ที่ตัวกลาง)
##
## ⚠️ **ค่านี้อยู่ข้ามฉาก** — เปลี่ยนฉากแล้ว NPC ตัวเก่าถูกลบแต่ตัวแปรยังชี้อยู่
## ทุกที่ที่อ่านต้องผ่าน `is_instance_valid()` ก่อนเสมอ
static var _bubble_owner: NPC = null

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _press_position: Vector2 = Vector2.ZERO
var _origin_position: Vector2 = Vector2.ZERO

## node ที่เป็นภาพจริงของตัวละคร (parent ที่เป็น AnimatedSprite2D)
## ต้องขยับ node นี้แทน self ตอนลาก เพราะ Area2D (ตัวนี้) เป็นแค่ hitbox ที่ซ้อนอยู่ข้างใน ไม่มีภาพให้เห็น
@onready var visual_root: AnimatedSprite2D = get_parent() as AnimatedSprite2D

## ระยะห่างระหว่างจุด hitbox (self) กับตำแหน่งจริงของภาพ (visual_root) เก็บไว้ตอนเริ่มเกม
## เผื่อ Area2D ถูกวางเยื้องจาก parent ไว้เพื่อ align hitbox กับภาพ (จะได้ไม่เสียตำแหน่งเดิม)
var _local_offset_from_parent: Vector2 = Vector2.ZERO

## ที่นั่งปัจจุบันที่ NPC ตัวนี้นั่งอยู่ (null = ยังไม่ได้นั่ง / อยู่แถวรอ)
var current_seat: Node = null

## ช่องยืนปัจจุบัน (โหนด `Stand` ในซีน) — null = ไม่ได้ยืนอยู่ช่องไหน
##
## ⚠️ **ช่องยืนไม่ได้ผูกกับ NPC ตัวใดตัวหนึ่ง** ใครมาถึงก่อนได้ก่อน
## จึงต้องจำว่า "ตอนนี้เรายืนช่องไหน" ไว้ที่ตัว NPC เอง เพื่อคืนช่องตอนย้ายไปที่อื่น
var current_stand: StandZone.StandSlot = null

# 🆕 เช็คว่ากดเมาส์ค้างครั้งนี้ เคลียร์อนิเมชันนั่งไปแล้วหรือยัง (กันเรียกซ้ำระหว่างลากอยู่)
var _mood_cleared_this_press: bool = false


func _ready() -> void:
	input_event.connect(_on_input_event)
	_local_offset_from_parent = global_position - visual_root.global_position
	_origin_position = global_position

	## จองช่องยืนที่ตัวเองยืนอยู่ตั้งแต่เปิดฉาก
	##
	## ⚠️ ต้อง deferred — `StandZone._ready()` อาจยังไม่ทำงานตอนนี้
	## (ลำดับ _ready ขึ้นกับลำดับโหนดในซีน ซึ่งคนจัดซีนสลับได้ตลอด ห้ามพึ่งพา)
	_claim_initial_stand.call_deferred()


## จองช่องยืนเริ่มต้น — ไม่เจอโซน/ไม่เจอช่องก็ไม่เป็นไร แค่ไม่มีช่องให้คืน
func _claim_initial_stand() -> void:
	var zone: StandZone = _get_stand_zone()
	if zone == null:
		return
	current_stand = zone.claim_initial_slot(self, _origin_position)


func _get_stand_zone() -> StandZone:
	return get_tree().get_first_node_in_group(StandZone.GROUP) as StandZone


## ย้ายตัวละครไปยังตำแหน่งโลกที่กำหนด (ขยับ visual_root ตัวจริงที่มองเห็น ไม่ใช่แค่ Area2D)
## เรียกจากที่ไหนก็ได้ในสคริปต์นี้ และจาก seat.gd ตอนวาง NPC ลงที่นั่ง
func set_world_position(target_pos: Vector2) -> void:
	visual_root.global_position = target_pos - _local_offset_from_parent


## เปลี่ยนอนิเมชันตามผลเช็คเงื่อนไขที่นั่ง เรียกจาก SeatManager หลังเช็คทุกครั้ง
## is_correct = true -> นั่งถูกเงื่อนไข (sit_happy), false -> นั่งผิดเงื่อนไข (sit_angry)
func set_seated_mood(is_correct: bool) -> void:
	if visual_root == null:
		return
	var anim_name := "sit_happy" if is_correct else "sit_angry"
	if visual_root.sprite_frames and visual_root.sprite_frames.has_animation(anim_name):
		visual_root.play(anim_name)
	else:
		push_warning("ไม่พบอนิเมชัน '%s' ใน SpriteFrames ของ '%s'" % [anim_name, name])


## กลับไปอนิเมชันปกติ (ตอนถูกหยิบขึ้นมาลาก ยังไม่ได้นั่งที่ไหน)
## ถ้าไม่มีอนิเมชันชื่อ "idle" ในตัวละครของคุณ เปลี่ยนชื่อในนี้ให้ตรงกับที่มีจริง
func clear_seated_mood() -> void:
	if visual_root == null:
		return
	if visual_root.sprite_frames and visual_root.sprite_frames.has_animation("idle"):
		visual_root.play("idle")


## รับ **เฉพาะการกดเริ่มลาก** — ต้องกดโดนตัวละครถึงจะหยิบขึ้นมาได้
##
## 🚨 **การปล่อยเมาส์ไม่ได้ดักที่นี่** (ดู `_input` ข้างล่าง)
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start_drag()


## ดักปุ่มปล่อยระดับทั้งจอ ไม่ใช่เฉพาะตอนเมาส์อยู่บนตัวละคร
##
## 🚨 **บั๊ก "ตัวละครติดเมาส์"** — ของเดิมดักปล่อยใน `_on_input_event` ซึ่งเป็นสัญญาณของ
## `Area2D` ที่**ยิงเฉพาะตอนเมาส์อยู่บนกรอบชนของมัน**
## ปล่อยเมาส์ตอนเคอร์เซอร์หลุดออกนอกกรอบ (ลากเร็วจนภาพตามไม่ทัน · จับที่ขอบตัว ·
## สลับหน้าต่างระหว่างลาก) จะไม่มีใครเรียก `_end_drag()` เลย
## → `_dragging` ค้าง true ตลอดกาล ตัวละครตามเมาส์ไปทั้งฉากโดยไม่ต้องกดอะไรอีก
##
## "ปล่อยเมาส์" เป็นเหตุการณ์ระดับทั้งจอ ไม่ใช่ของโหนดใดโหนดหนึ่ง จึงต้องดักที่นี่
## (ตัวที่ไม่ได้ลากอยู่ return ทิ้งตั้งแต่บรรทัดแรก ไม่ได้เสียอะไร)
func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_end_drag()


func _process(_delta: float) -> void:
	if _current_bubble:
		_current_bubble.position = _get_screen_position()

	if _dragging:
		## ตาข่ายรับสุดท้าย — ถ้าอีเวนต์ปุ่มปล่อยหายไปจริง ๆ (สลับหน้าต่างระหว่างลาก
		## แล้วปล่อยเมาส์นอกเกม) ก็ยังหลุดจากโหมดลากได้ ไม่ต้องปิดเกมทิ้ง
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_end_drag()
			return

		set_world_position(get_global_mouse_position() + _drag_offset)
		## บอกช่องที่ลอยอยู่เหนือให้ติดสี = ตัวบอกล่วงหน้าว่า "ปล่อยตรงนี้แล้วจะลงช่องนี้"
		##
		## ⚠️ ใช้ `_find_nearby_seat()` ตัวเดียวกับตอนปล่อยจริง (`_end_drag`)
		## ถ้าใช้เกณฑ์คนละอย่าง ช่องที่ติดสีกับช่องที่ NPC ลงจริงจะเป็นคนละช่องในบางมุม
		## ซึ่งเป็นบั๊กที่ผู้เล่นโทษเกมทันทีว่า "วางไม่ลง" ทั้งที่ไฟบอกว่าลงได้
		SeatManager.set_hovered_seat(_find_nearby_seat())
		# 🆕 เคลียร์อนิเมชันนั่งเฉพาะตอนขยับเกิน threshold จริงๆ (ถือว่าเป็นการ "ลาก" แล้ว)
		# ไม่เคลียร์ตั้งแต่ตอนกดเมาส์ลง เพราะแค่ "คลิก" เฉยๆ (ดูบับเบิ้ล) ไม่ควรเปลี่ยนอนิเมชันนั่ง
		if not _mood_cleared_this_press and get_global_mouse_position().distance_to(_press_position) >= drag_threshold:
			_mood_cleared_this_press = true
			clear_seated_mood()


func _start_drag() -> void:
	_dragging = true
	## ยกตัวละครขึ้น = โชว์ช่องยืนที่วางลงได้ ให้ผู้เล่นเห็นว่ามีที่พักตรงไหนบ้าง
	var zone: StandZone = _get_stand_zone()
	if zone:
		zone.set_dragged_npc(self)
	_press_position = get_global_mouse_position()
	_drag_offset = global_position - _press_position
	# ยกตัวขึ้นมาบนสุดตอนลาก จะได้ไม่โดน NPC ตัวอื่นบัง
	visual_root.z_index = 100
	# 🆕 รีเซ็ตสถานะไว้เช็คใน _process ว่าเคลียร์อนิเมชันไปหรือยัง (เริ่มกดใหม่ทุกครั้งต้องรีเซ็ต)
	_mood_cleared_this_press = false


func _end_drag() -> void:
	_dragging = false
	visual_root.z_index = 0
	## ปล่อยเมาส์แล้วต้องดับไฟทั้งที่นั่งและที่ยืนเสมอ — วางลงได้หรือไม่ได้ก็ไม่มีอะไรลอยอยู่แล้ว
	## (ต้องอยู่ก่อน return ทุกทางข้างล่าง ไม่งั้นทางที่ "คลิกเฉย ๆ" จะทิ้งไฟค้างไว้ทั้งกระดาน)
	SeatManager.set_hovered_seat(null)
	var zone: StandZone = _get_stand_zone()
	if zone:
		zone.set_dragged_npc(null)

	var moved_distance := get_global_mouse_position().distance_to(_press_position)
	if moved_distance < drag_threshold:
		# ขยับน้อยมาก ถือว่าเป็น "คลิก" ไม่ใช่ "ลาก" -> กลับตำแหน่งเดิมแล้วโชว์บับเบิ้ล
		_return_to_current_position()
		_toggle_bubble()
		return

	var target_seat := _find_nearby_seat()
	if target_seat and target_seat.is_empty():
		_leave_current_spot()
		current_seat = target_seat
		target_seat.place_npc(self)
		SeatManager.check_all()
		_spend_move()
		return

	## ไม่ได้ลงที่นั่ง -> ลองดูว่าปล่อยตรงช่องยืนไหม
	##
	## ⚠️ เช็คที่นั่งก่อนเสมอ — ที่นั่งเป็นเป้าหมายของปริศนา ส่วนที่ยืนเป็นที่พัก
	## ปล่อยตรงจุดที่คาบเกี่ยวกันจึงควรได้ที่นั่ง ไม่ใช่ที่ยืน
	var target_stand: StandZone.StandSlot = _find_nearby_stand()
	if target_stand and target_stand.is_empty():
		_leave_current_spot()
		current_stand = target_stand
		target_stand.place_npc(self)
		## 🚨 ต้องเช็คใหม่ด้วย ถึงจะเป็นการ "ลุกออก" ไม่ใช่ "มานั่ง"
		## เพื่อนบ้านของที่นั่งที่เพิ่งว่างลงมีเงื่อนไขที่ผลเปลี่ยนตาม (เช่น next_to_boy)
		SeatManager.check_all()
		return

	# วางไม่ได้ (ไม่เจอที่นั่ง/ที่ยืน หรือมีคนอยู่แล้ว) ให้กลับตำแหน่งเดิม
	_return_to_current_position()


## หัก 1 move — เรียกเฉพาะตอน**วางลงที่นั่งสำเร็จ**เท่านั้น
##
## 🚨 อยู่ที่ `_end_drag()` ไม่ใช่ใน `Seat.place_npc()` โดยตั้งใจ
## "move" คือ**การกระทำของผู้เล่น** ไม่ใช่ "การที่ NPC ไปอยู่บนเก้าอี้"
## ถ้าไปนับใน `place_npc()` วันหลังมีระบบจัดที่นั่งอัตโนมัติ (สลับ/รีเซ็ต/เฉลย)
## จะกินโควตาผู้เล่นทั้งที่ผู้เล่นไม่ได้ทำอะไร
##
## ⚠️ ย้ายไปพักที่ช่องยืน **ไม่เสีย move** และวางไม่ลงแล้วเด้งกลับก็ไม่เสีย (ตามที่ตกลงไว้)
func _spend_move() -> void:
	var counter: Node = get_tree().get_first_node_in_group(MoveCounter.GROUP)
	if counter == null:
		return
	counter.spend()


## คืนที่นั่ง/ที่ยืนที่ถืออยู่ ก่อนจะไปลงที่ใหม่
##
## ⚠️ ต้องคืน **ทั้งสองอย่าง** ไม่ใช่เฉพาะอันที่เดาว่าถืออยู่
## ลืมคืนช่องยืนตอนไปนั่ง = ช่องนั้นถูกจองค้างตลอดเกม ไม่มีใครมายืนได้อีก
func _leave_current_spot() -> void:
	if current_seat:
		current_seat.remove_npc()
		current_seat = null
	if current_stand:
		current_stand.remove_npc()
		current_stand = null


## กลับไปที่ที่ตัวเองอยู่ก่อนถูกหยิบขึ้นมา
## ลำดับ: ที่นั่ง -> ช่องยืน -> ตำแหน่งตั้งต้นตอนเปิดฉาก (เผื่อไม่มีโซนที่ยืนในฉากนั้น)
func _return_to_current_position() -> void:
	if current_seat:
		set_world_position(current_seat.get_placement_position())
		_restore_seated_mood()
		return
	if current_stand:
		set_world_position(current_stand.get_placement_position())
		return
	set_world_position(_origin_position)


## คืนท่านั่งหลังเด้งกลับที่นั่งเดิม
##
## 🚨 **บั๊ก "นั่งอยู่แต่เป็นท่ายืน"** — การลากเคลียร์ท่านั่งทิ้งไปแล้ว
## (`clear_seated_mood()` ใน `_process` ตอนขยับเกิน `drag_threshold`)
## พอวางไม่ลง (เล็งพลาด · ช่องปลายทางมีคนอยู่) แล้วเด้งกลับเก้าอี้ตัวเดิม
## ถ้าไม่คืนท่าให้ จะได้ตัวละคร**ยืนตัวตรงอยู่บนเก้าอี้**
##
## ⚠️ เช็ค `_mood_cleared_this_press` ก่อน — แค่ "คลิกดูบับเบิล" ไม่ได้ลากจริง
## ท่านั่งยังอยู่ครบ สั่ง `play()` ซ้ำจะทำให้อนิเมชันกระตุกกลับไปเฟรมแรกโดยไม่จำเป็น
##
## ใช้ `check_seat()` ตัวเดียว ไม่เรียก `check_all()` — วางไม่สำเร็จแปลว่าไม่มีอะไรบนกระดานเปลี่ยน
## คนอื่นจึงไม่ต้องถูกคำนวณใหม่ทั้งกระดาน
func _restore_seated_mood() -> void:
	if not _mood_cleared_this_press:
		return
	set_seated_mood(SeatManager.check_seat(current_seat))


## ช่องยืนที่ใกล้ที่สุดในระยะ (null = ไม่มี หรือฉากนี้ไม่มีโซนที่ยืน)
func _find_nearby_stand() -> StandZone.StandSlot:
	var zone: StandZone = _get_stand_zone()
	if zone == null:
		return null
	return zone.find_nearby_slot(global_position)


func _find_nearby_seat() -> Node:
	var seats := get_tree().get_nodes_in_group("seats")
	var closest: Node = null
	var closest_dist := seat_snap_distance
	for seat in seats:
		var d := global_position.distance_to(seat.get_placement_position())
		if d < closest_dist:
			closest_dist = d
			closest = seat
	return closest


func _get_screen_position() -> Vector2:
	var world_pos: Vector2 = global_position + bubble_offset
	return get_viewport().get_canvas_transform() * world_pos


func _toggle_bubble() -> void:
	if _current_bubble:
		_close_bubble()
		return

	if npc_id.is_empty() or not NPCalignDatabase.has_npc(npc_id):
		push_warning("NPC '%s' ไม่มี npc_id หรือหา id ไม่เจอใน NPCalignDatabase" % name)
		return

	_show_bubble(NPCalignDatabase.get_dialogue(npc_id))


func _show_bubble(text: String) -> void:
	if bubble_scene == null:
		push_warning("ยังไม่ได้ใส่ bubble_scene ใน NPC '%s'" % name)
		return

	var ui_layer := get_tree().get_first_node_in_group("ui_layer")
	if ui_layer == null:
		push_error("หา CanvasLayer กลุ่ม 'ui_layer' ไม่เจอ! สร้าง CanvasLayer แล้วเพิ่มเข้ากลุ่ม 'ui_layer' ก่อน")
		return

	## ปิดบับเบิลของตัวก่อนหน้า — บนจอมีได้ทีละใบ
	##
	## ⚠️ ต้องอยู่**หลัง**ด่านเช็คข้างบน ไม่ใช่ต้นฟังก์ชัน
	## ปิดใบเก่าทิ้งแล้วใบใหม่ขึ้นไม่ได้ = คลิกแล้วบับเบิลหายไปเฉย ๆ โดยไม่มีอะไรมาแทน
	_close_other_bubble()

	_current_bubble = bubble_scene.instantiate()
	ui_layer.add_child(_current_bubble)
	_current_bubble.position = _get_screen_position()

	_current_bubble.set_text(text)
	_current_bubble.bubble_closed.connect(_on_bubble_closed)
	_bubble_owner = self

	## จดข้อกำหนดลงสมุดด้วย — ส่ง `text` ตัวเดียวกับที่บับเบิลเพิ่งได้ไป
	##
	## ⚠️ อยู่ **หลัง** บับเบิลขึ้นจริงแล้ว ไม่ใช่ต้นฟังก์ชัน
	## ทางที่ return ทิ้งข้างบน (ไม่มี bubble_scene · หา ui_layer ไม่เจอ) ต้องไม่จดลงสมุด
	## ไม่งั้นจะได้สมุดที่มีข้อความโดยไม่มีบับเบิล แล้วปิดไม่ได้เพราะไม่มีอะไรให้คลิกปิด
	var note: NPCNote = _get_note()
	if note:
		note.write(npc_id, text)


func _close_bubble() -> void:
	if _current_bubble:
		_current_bubble.close()


## ปิดบับเบิลของ NPC ตัวอื่นที่เปิดค้างอยู่ (ถ้ามี)
##
## ไม่ต้องรอให้ปิดเสร็จ — `close()` เป็นอนิเมชันย่อหาย 0.15 วิ ปล่อยให้ใบเก่าย่อหาย
## พร้อมกับใบใหม่ที่กำลังงอกขึ้นมาดูลื่นกว่ารอให้หายหมดก่อนแล้วค่อยขึ้นใบใหม่
func _close_other_bubble() -> void:
	if _bubble_owner == null or _bubble_owner == self:
		return
	## 🚨 ตัวแปร static อยู่ข้ามฉาก — ตัวที่ชี้อยู่อาจถูกลบไปพร้อมฉากก่อนหน้าแล้ว
	if not is_instance_valid(_bubble_owner):
		_bubble_owner = null
		return
	_bubble_owner._close_bubble()


func _on_bubble_closed() -> void:
	_current_bubble = null

	## ปล่อยตำแหน่ง "เจ้าของบับเบิล" เฉพาะตอนที่ยังเป็นของเราอยู่
	##
	## 🚨 สัญญาณนี้มาถึง**หลัง**อนิเมชันย่อหายจบ (0.15 วิ) ซึ่งช้ากว่าการที่ตัวใหม่
	## ตั้งตัวเองเป็นเจ้าของไปแล้ว · เซ็ต null ทื่อ ๆ = ลบทะเบียนของตัวที่เพิ่งเปิด
	## แล้วคลิกตัวถัดไปจะไม่มีใครถูกปิด กลายเป็นบับเบิลค้าง 2 ใบเหมือนเดิม
	if _bubble_owner == self:
		_bubble_owner = null

	## ล้างสมุด — `erase()` เช็คเจ้าของให้เอง ตัวที่ไม่ได้เป็นเจ้าของข้อความปัจจุบันเรียกแล้วไม่เกิดอะไร
	##
	## ⚠️ **ยังต้องเช็คเจ้าของอยู่แม้จะเปิดได้ทีละใบแล้ว** — ใบเก่ายิงสัญญาณช้ากว่าใบใหม่
	## 0.15 วิ ล้างทื่อ ๆ = สมุดของตัวที่เพิ่งคลิกดูถูกลบทิ้งหลังโผล่มาแป๊บเดียว
	var note: NPCNote = _get_note()
	if note:
		note.erase(npc_id)


## สมุดจดข้อกำหนดของฉากนี้ — คืน null ได้ ฉากปริศนาที่ไม่มีสมุดก็ยังเล่นได้ตามปกติ
## (บับเบิลเป็นตัวหลัก สมุดเป็นตัวช่วยจำ)
func _get_note() -> NPCNote:
	return get_tree().get_first_node_in_group(NPCNote.GROUP) as NPCNote
