extends "res://level_base.gd"

## ==============================================
## เควสต์เอากล่องมาวาง — `Level2_1` ถูก instance ไว้ในซีนนี้แล้ว
## ==============================================
## 🚨 **ไม่มีโค้ดเสียบซีนเควสต์เข้ามาที่นี่โดยตั้งใจ** — โหนด `Level2_1` อยู่ในซีนตลอดเวลา
## เคยเขียน `_spawn_box_quest()` ไว้ตอนแรก แล้วถอดออกเพราะจะได้กล่อง 2 ใบซ้อนกัน
## (ใบในซีน + ใบที่โค้ดสร้าง) · อย่าเพิ่มกลับเข้ามาโดยไม่ลบ instance ในซีนก่อน
##
## เงื่อนไขเนื้อเรื่องอยู่ที่ **"โชว์อะไรไหม" ไม่ใช่ "สร้างโหนดไหม"**
## `drop_zone_hint.gd` เงียบเมื่อ `GameState.carrying_box` เป็นเท็จ (ทั้งก่อนหยิบและหลังวาง)
## `box_drop_point.gd` ซ่อนกล่องจนกว่า `GameState.box_delivered` จะเป็นจริง

## ห้องที่ไฮไลต์ได้ — คีย์คือชื่อที่ `room_enter()` ส่งเข้ามา ค่าคือชื่อโหนดในซีน
##
## 🚨 **หาโหนดด้วย `find_child()` ไม่ใช่ `$path`** (แก้ 2026-08-20)
## เดิมเขียน `$meetingroom` ตรง ๆ พอห่อทุกอย่างไว้ใต้ `WorldObjects` ก็ได้ null ทั้ง 5 ตัว
## แล้ว `create_tween().tween_property(null, ...)` พ่น error รัว ๆ ทุกครั้งที่เดินเข้า/ออกห้อง
## · `--import` จับไม่ได้เพราะเป็น path ตอนรัน ไม่ใช่ตอนคอมไพล์
## · ค้นแบบไล่ลูกหลานจึงรอดจากการจัดกลุ่มโหนดใหม่ ซึ่งเกิดขึ้นบ่อยในซีนแมพที่ยังจัดไม่ลงตัว
const ROOM_NODE_NAMES := {
	"meetingroom": "meetingroom",
	"small_room": "small_room",
	"toilet_m": "ToiletM",
	"toilet_w": "ToiletW",
	"footpath": "footpath",
}

@onready var rooms: Dictionary = _collect_rooms()


## หาโหนดห้องทั้งหมดครั้งเดียวตอนเปิดฉาก
##
## ⚠️ ห้องที่หาไม่เจอจะ **ไม่ถูกใส่ลง dictionary** แล้ว push_error บอกชื่อที่หาย
## ใส่ null ไว้แล้วปล่อยผ่านจะไปตายที่ `tween_property` ซึ่ง backtrace ชี้ไปคนละบรรทัดกับต้นเหตุ
func _collect_rooms() -> Dictionary:
	var found := {}
	for key: String in ROOM_NODE_NAMES:
		var node := find_child(ROOM_NODE_NAMES[key], true, false)
		if node == null:
			push_error("level_2.gd: ไม่พบโหนดห้อง `%s` ในซีน — ห้องนี้จะไม่ถูกไฮไลต์" \
				% ROOM_NODE_NAMES[key])
			continue
		found[key] = node
	return found

func _on_level_ready():
	reset_to_default()

func reset_to_default():
	for name in rooms:
		var target_color := Color(0.3, 0.3, 0.3)

		if name == "footpath":
			target_color = Color.WHITE

		create_tween().tween_property(
			rooms[name],
			"modulate",
			target_color,
			0.5
		)

func highlight_room(active_room: String):
	for name in rooms:
		var target_color := Color(0.3, 0.3, 0.3)

		if name == active_room:
			target_color = Color.WHITE

		create_tween().tween_property(
			rooms[name],
			"modulate",
			target_color,
			0.5
		)

# ==========================
# ฟังก์ชันกลาง
# ==========================

func room_enter(body: Node2D, room_name: String):
	if body is Player:
		print("เข้า :", room_name)
		highlight_room(room_name)

func room_exit(body: Node2D):
	if body is Player:
		print("ออกห้อง")
		reset_to_default()

# ==========================
# Meeting Room
# ==========================

func _on_area_2_dmeetingroom_body_entered(body: Node2D) -> void:
	room_enter(body, "meetingroom")

func _on_area_2_dmeetingroom_body_exited(body: Node2D) -> void:
	room_exit(body)

# ==========================
# Small Room
# ==========================

func _on_area_2_dsmallroom_body_entered(body: Node2D) -> void:
	room_enter(body, "small_room")

func _on_area_2_dsmallroom_body_exited(body: Node2D) -> void:
	room_exit(body)

# Toilet M
# ==========================

func _on_area_2_dtoilet_m_body_entered(body: Node2D) -> void:
	room_enter(body, "toilet_m")

func _on_area_2_dtoilet_m_body_exited(body: Node2D) -> void:
	room_exit(body)

# ==========================
# Toilet W
# ==========================

func _on_area_2_dtoilet_w_body_entered(body: Node2D) -> void:
	room_enter(body, "toilet_w")

func _on_area_2_dtoilet_w_body_exited(body: Node2D) -> void:
	room_exit(body)
