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

# 🆕 เช็คว่ากดเมาส์ค้างครั้งนี้ เคลียร์อนิเมชันนั่งไปแล้วหรือยัง (กันเรียกซ้ำระหว่างลากอยู่)
var _mood_cleared_this_press: bool = false


func _ready() -> void:
	input_event.connect(_on_input_event)
	_local_offset_from_parent = global_position - visual_root.global_position
	_origin_position = global_position


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


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag()
		elif _dragging:
			_end_drag()


func _process(_delta: float) -> void:
	if _current_bubble:
		_current_bubble.position = _get_screen_position()

	if _dragging:
		set_world_position(get_global_mouse_position() + _drag_offset)
		# 🆕 เคลียร์อนิเมชันนั่งเฉพาะตอนขยับเกิน threshold จริงๆ (ถือว่าเป็นการ "ลาก" แล้ว)
		# ไม่เคลียร์ตั้งแต่ตอนกดเมาส์ลง เพราะแค่ "คลิก" เฉยๆ (ดูบับเบิ้ล) ไม่ควรเปลี่ยนอนิเมชันนั่ง
		if not _mood_cleared_this_press and get_global_mouse_position().distance_to(_press_position) >= drag_threshold:
			_mood_cleared_this_press = true
			clear_seated_mood()


func _start_drag() -> void:
	_dragging = true
	_press_position = get_global_mouse_position()
	_drag_offset = global_position - _press_position
	# ยกตัวขึ้นมาบนสุดตอนลาก จะได้ไม่โดน NPC ตัวอื่นบัง
	visual_root.z_index = 100
	# 🆕 รีเซ็ตสถานะไว้เช็คใน _process ว่าเคลียร์อนิเมชันไปหรือยัง (เริ่มกดใหม่ทุกครั้งต้องรีเซ็ต)
	_mood_cleared_this_press = false


func _end_drag() -> void:
	_dragging = false
	visual_root.z_index = 0

	var moved_distance := get_global_mouse_position().distance_to(_press_position)
	if moved_distance < drag_threshold:
		# ขยับน้อยมาก ถือว่าเป็น "คลิก" ไม่ใช่ "ลาก" -> กลับตำแหน่งเดิมแล้วโชว์บับเบิ้ล
		_return_to_current_position()
		_toggle_bubble()
		return

	var target_seat := _find_nearby_seat()
	if target_seat and target_seat.is_empty():
		if current_seat:
			current_seat.remove_npc()
		current_seat = target_seat
		target_seat.place_npc(self)
		SeatManager.check_all()
	else:
		# วางไม่ได้ (ไม่เจอที่นั่ง หรือที่นั่งมีคนอยู่แล้ว) ให้กลับตำแหน่งเดิม
		_return_to_current_position()


func _return_to_current_position() -> void:
	set_world_position(current_seat.get_placement_position() if current_seat else _origin_position)


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

	_current_bubble = bubble_scene.instantiate()
	ui_layer.add_child(_current_bubble)
	_current_bubble.position = _get_screen_position()

	_current_bubble.set_text(text)
	_current_bubble.bubble_closed.connect(_on_bubble_closed)


func _close_bubble() -> void:
	if _current_bubble:
		_current_bubble.close()


func _on_bubble_closed() -> void:
	_current_bubble = null
