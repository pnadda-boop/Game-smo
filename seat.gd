extends Area2D
class_name Seat

## ติด script นี้ที่ node ที่นั่งแต่ละช่อง (กล่องสีฟ้าในตาราง)
## ต้องมี CollisionShape2D เป็นลูก ครอบพื้นที่กล่องไว้ (ไม่ต้องรับ input คลิกก็ได้ แค่ใช้ตรวจระยะ)

## แถวที่ (เช่น 1 = แถวหน้าสุด, 2 = แถวกลาง, 3 = แถวหลังสุด)
## ต้องตั้งเลขนี้ให้ตรงกับตำแหน่งจริงในตารางของทุกที่นั่ง
@export var row: int = 1

## คอลัมน์ที่ (1, 2, 3, 4, 5, 6 ตามตำแหน่งซ้ายไปขวา)
@export var column: int = 1

## จุดมาร์กตำแหน่งที่แน่นอนที่ให้ NPC ไปยืน (ลาก Marker2D ที่เป็นลูกของ Seat นี้มาใส่)
## ถ้าไม่ใส่ จะใช้ตำแหน่ง origin ของ Seat เอง (global_position) แทน
@export var mark: Marker2D

## NPC ที่นั่งอยู่ตอนนี้ (เก็บ reference ไปยัง node NPC), null = ที่นั่งว่าง
var current_npc: Node = null

## ==============================================
## หน้าตาของช่อง — เส้นขอบ vs สี่เหลี่ยมสี
## ==============================================
## **เส้นขอบ (Line2D) โชว์ตลอด** — เป็นผังของกระดาน บอกว่ามีช่องอยู่ตรงไหนบ้าง
## ผังต้องอ่านได้ทั้งกระดานเสมอ ไม่ใช่หายเป็นหย่อม ๆ ตามที่คนไปนั่ง
## → **สคริปต์นี้ไม่แตะ `visible` ของเส้นขอบเลย** ตั้งไว้ยังไงในซีนก็เป็นแบบนั้น
##
## **สี่เหลี่ยมสี (ColorRect) โชว์เฉพาะตอนมีของลอยเหนือ** = "กำลังเลือกตำแหน่งนี้อยู่"
##
## 🚨 **สีคือตัวชี้ตำแหน่งที่กำลังเล็ง ไม่ใช่พื้นของช่อง**
## ติดค้างไว้ตอนมีคนนั่งจะกลายเป็นสัญญาณสองความหมายในภาพเดียวกัน
## ผู้เล่นแยกไม่ออกว่าสีที่เห็นแปลว่า "เล็งอยู่" หรือ "มีคนแล้ว"
##
## ⚠️ หาโหนดด้วย `find_child` ไม่ผูก path — ตอนนี้อยู่ใต้ `CollisionShape2D`
## ซึ่งเป็นที่แปลก (เป็นลูกของรูปทรงชนกัน) ถ้าวันหลังย้ายขึ้นมาไว้ใต้ Seat ตรง ๆ จะได้ไม่พัง
@onready var _fill: CanvasItem = find_child("ColorRect", true, false) as CanvasItem


func _ready() -> void:
	add_to_group("seats")
	SeatManager.register_seat(self)
	refresh_visual()


## อัปเดตหน้าตาของช่อง — เรียกทุกครั้งที่สถานะเปลี่ยน (เล็ง / มีคนมานั่ง / ลุกออก)
##
## ตอนนี้มีแต่สี่เหลี่ยมสีที่เปลี่ยนตามสถานะ แต่ยังเรียกจากตอนคนนั่ง/ลุกด้วย
## เพราะกฎหน้าตาของช่องนี้เปลี่ยนมาแล้วหลายรอบ — เก็บทางเข้าไว้จุดเดียวจะได้แก้ที่นี่ที่เดียว
func refresh_visual() -> void:
	if _fill:
		_fill.visible = SeatManager.is_hovered(self)


func is_empty() -> bool:
	return current_npc == null


## คืนตำแหน่งจริงที่ NPC ควรไปยืน (จุด mark ถ้ามี ไม่งั้น fallback เป็น origin ของ seat)
func get_placement_position() -> Vector2:
	return mark.global_position if mark else global_position


## ให้ NPC ตัวนี้มานั่งที่ช่องนี้
func place_npc(npc: Node) -> void:
	current_npc = npc
	refresh_visual()
	npc.set_world_position(get_placement_position())
	# 🆕 นั่งลงเป็น sit_happy ทันทีก่อนเลย (ยังไม่รอผลเช็คเงื่อนไข)
	# ถ้าเช็คแล้วผิด SeatManager.check_all() ที่เรียกต่อจากนี้จะเปลี่ยนเป็น sit_angry ให้เองทีหลัง
	npc.set_seated_mood(true)


## เอา NPC ออกจากที่นั่ง (ตอนลากออกไปที่อื่น)
func remove_npc() -> void:
	current_npc = null
	refresh_visual()


## แสดงผลลัพธ์ถูก/ผิดด้วยสี (เขียว = ถูก, แดง = ผิด, ปกติ = ยังไม่เช็ค/ว่าง)
##
## ย้อม `modulate` ของทั้งช่อง ซึ่งลูกทุกตัวรับไปด้วย —
## **เส้นขอบที่โชว์ตลอดจึงกลายเป็นตัวรับสีเขียว/แดงไปในตัว** (ไม่ต้องเพิ่มโหนดอะไรอีก)
## เป็นเหตุผลหนึ่งที่เส้นขอบไม่ควรหายตอนมีคนนั่ง — ถ้าหาย ไฮไลต์ถูก/ผิดจะไม่เหลืออะไรให้ย้อม
func set_highlight(is_correct: bool) -> void:
	if current_npc == null:
		modulate = Color.WHITE
		return
	modulate = Color(0.6, 1.0, 0.6) if is_correct else Color(1.0, 0.6, 0.6)


func clear_highlight() -> void:
	modulate = Color.WHITE
