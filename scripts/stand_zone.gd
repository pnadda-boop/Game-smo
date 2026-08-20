class_name StandZone
extends Node2D
## ==============================================
## จุดยืนของ NPC ในปริศนาจัดที่นั่ง
## ==============================================
## ที่ที่ลาก NPC กลับมาวางได้เมื่อยังไม่อยากให้นั่ง (หรือเปลี่ยนใจเอาออกจากที่นั่ง)
##
## **แนบสคริปต์นี้ที่โหนด `Stand` ตัวเดียว** ไม่ต้องแนบทีละ `AreaStand`
## ลูกทุกตัวที่มี `Marker2D` อยู่ข้างในถูกนับเป็น "ช่องยืน" หนึ่งช่องอัตโนมัติ
## → เพิ่ม/ลบจุดยืนในซีนได้เลย ไม่ต้องแตะโค้ดและไม่ต้องแนบสคริปต์เพิ่ม
##
## 🚨 **ช่องยืนไม่ได้ผูกกับ NPC ตัวใดตัวหนึ่ง — ใครมาถึงก่อนได้ก่อน**
## มาร์เกอร์ในซีนชื่อ `MarkerNPC1` เหมือนกันหมดทุกช่องเพราะก๊อปกันมา
## **ไม่ได้แปลว่าเป็นของ NPC1** โค้ดจึงไม่อ่านชื่อโหนดมาจับคู่กับ NPC เด็ดขาด
##
## ⚠️ **หนึ่งช่องรับได้คนเดียว** — "ไม่บังคับตำแหน่ง" หมายถึงไม่ได้จองไว้ให้ใคร
## ไม่ได้แปลว่าให้ยืนซ้อนกันได้ (ซ้อนแล้วจะเหลือ NPC ที่มองเห็นแค่ตัวเดียว)

## กลุ่มที่ `click.gd` ใช้หาโซนนี้ — สคริปต์เข้ากลุ่มเองตอน `_ready()` ไม่ต้องตั้งในซีน
const GROUP := "stand_zone"

## ระยะที่ยอมให้ "ปล่อย" แล้วนับว่าลงช่องยืนนั้น (ตั้งให้พอ ๆ กับ seat_snap_distance ของ NPC)
@export var snap_distance: float = 40.0

## ระยะที่ถือว่า NPC ซึ่งยืนอยู่ตั้งแต่เปิดฉาก "เป็นเจ้าของ" ช่องนั้น
##
## ต้องแคบกว่า `snap_distance` — ตอนเปิดฉากเรารู้ตำแหน่งจริงเป๊ะ ๆ อยู่แล้ว
## กว้างไปจะไปคว้าช่องข้าง ๆ ที่ตัวอื่นควรได้ แล้วมีคนหนึ่งไม่มีช่องยืนตั้งแต่ต้นเกม
@export var initial_claim_distance: float = 24.0

var _slots: Array[StandSlot] = []


## ช่องยืนหนึ่งช่อง
##
## ตั้งใจให้มีเมธอดชื่อเดียวกับ `Seat` (`is_empty` / `get_placement_position` /
## `place_npc` / `remove_npc`) → `click.gd` ใช้โค้ดชุดเดียวกันจัดการได้ทั้งที่นั่งและที่ยืน
##
## เป็น RefCounted ไม่ใช่ Node เพราะเป็นแค่ "ข้อมูลว่าช่องนี้ใครยืนอยู่"
## ไม่ต้องอยู่ใน tree ไม่ต้องมี `_process` และไม่ต้องให้ใครไปแนบสคริปต์ที่ Area2D ทีละอัน
class StandSlot extends RefCounted:
	var marker: Marker2D
	## สี่เหลี่ยมสีของช่องนี้ — โผล่เฉพาะตอนมีตัวละครถูกยกขึ้น (null ได้ ถ้าซีนยังไม่ได้ใส่)
	var fill: CanvasItem = null
	var current_npc: Node = null

	func _init(marker_node: Marker2D, fill_node: CanvasItem) -> void:
		marker = marker_node
		fill = fill_node

	## โชว์สี่เหลี่ยมสีไหม
	##
	## `dragged_npc` = ตัวที่กำลังถูกยกอยู่ (null = ไม่มีใครถูกยก)
	func update_fill(dragged_npc: Node) -> void:
		if fill == null:
			return

		## ยกใครขึ้นมาถึงจะโชว์ — และโชว์เฉพาะช่องที่ **วางลงได้จริง**
		## (ว่างอยู่ หรือเป็นช่องของตัวที่กำลังยกเอง ซึ่งวางกลับที่เดิมได้)
		##
		## ⚠️ โชว์ช่องที่คนอื่นยืนอยู่ด้วยจะกลายเป็นคำโกหก — ผู้เล่นเล็งไปปล่อยแล้วเด้งกลับ
		var can_drop_here: bool = current_npc == null or current_npc == dragged_npc
		fill.visible = dragged_npc != null and can_drop_here

	func is_empty() -> bool:
		return current_npc == null

	func get_placement_position() -> Vector2:
		return marker.global_position

	func place_npc(npc: Node) -> void:
		current_npc = npc
		npc.set_world_position(get_placement_position())
		## ยืนอยู่ ไม่ได้นั่ง — คืนท่า idle ไม่งั้นจะยืนค้างท่านั่งกลางห้อง
		npc.clear_seated_mood()

	func remove_npc() -> void:
		current_npc = null


func _ready() -> void:
	add_to_group(GROUP)
	_build_slots()


## ไล่เก็บช่องยืนจากลูกในซีน
##
## หา `Marker2D` แบบไล่ลงไปทุกชั้น ไม่ผูกชื่อและไม่ผูกความลึก —
## ตอนนี้มาร์เกอร์อยู่ใต้ `AreaStand` ตรง ๆ แต่ถ้าวันหลังห่อเพิ่มอีกชั้นก็ยังหาเจอ
func _build_slots() -> void:
	_slots.clear()

	for child: Node in get_children():
		var markers: Array[Node] = child.find_children("*", "Marker2D", true, false)
		if markers.is_empty():
			push_warning("stand_zone.gd: `%s` ไม่มี Marker2D ข้างใน — ไม่ถูกนับเป็นช่องยืน" % child.name)
			continue

		var fills: Array[Node] = child.find_children("*", "ColorRect", true, false)
		if fills.is_empty():
			## ไม่มีก็ยังยืนได้ตามปกติ แค่ไม่มีไฟบอกตอนยกตัวละคร
			push_warning("stand_zone.gd: `%s` ไม่มี ColorRect — ช่องนี้จะไม่ขึ้นสีตอนยกตัวละคร" % child.name)

		_slots.append(StandSlot.new(
			markers[0] as Marker2D,
			fills[0] as CanvasItem if not fills.is_empty() else null,
		))

	if _slots.is_empty():
		push_error("stand_zone.gd: `%s` ไม่มีช่องยืนสักช่อง — ลาก NPC กลับมายืนไม่ได้เลย" % name)

	## เริ่มฉากมาต้องดับหมดก่อน (ในซีนอาจเปิด visible ค้างไว้ตอนจัดหน้าจอ)
	set_dragged_npc(null)


## บอกว่าตอนนี้มีใครถูกยกอยู่ — `click.gd` เรียกตอนเริ่มลากและตอนปล่อย
##
## 🚨 **ต้องเรียกด้วย null ตอนปล่อยเสมอ** ไม่งั้นไฟค้างสว่างทั้งกระดานหลังวางเสร็จ
func set_dragged_npc(npc: Node) -> void:
	for slot: StandSlot in _slots:
		slot.update_fill(npc)


## ช่องยืนที่ใกล้ตำแหน่งนี้ที่สุด (คืน null ถ้าไม่มีช่องไหนอยู่ในระยะ)
##
## ⚠️ คืนช่องที่ใกล้ที่สุด**แม้ช่องนั้นจะมีคนยืนอยู่** — ให้ฝั่งที่เรียกเป็นคนตัดสินใจเอง
## ข้ามช่องที่ไม่ว่างให้ตรงนี้จะกลายเป็น "ปล่อยทับคนอื่นแล้วเด้งไปลงช่องข้าง ๆ" ซึ่งไม่มีใครสั่ง
func find_nearby_slot(world_position: Vector2) -> StandSlot:
	var closest: StandSlot = null
	var closest_distance: float = snap_distance

	for slot: StandSlot in _slots:
		var distance: float = world_position.distance_to(slot.get_placement_position())
		if distance < closest_distance:
			closest_distance = distance
			closest = slot

	return closest


## จองช่องให้ NPC ที่ยืนอยู่ตรงนั้นอยู่แล้วตั้งแต่เปิดฉาก
##
## ⚠️ **จำเป็น** ไม่งั้นช่องเริ่มต้นทุกช่องจะถือว่า "ว่าง" ทั้งที่มีคนยืนอยู่
## แล้วจะลาก NPC ตัวอื่นมาปล่อยทับได้ตั้งแต่วินาทีแรก
func claim_initial_slot(npc: Node, world_position: Vector2) -> StandSlot:
	for slot: StandSlot in _slots:
		if not slot.is_empty():
			continue
		if world_position.distance_to(slot.get_placement_position()) <= initial_claim_distance:
			slot.current_npc = npc
			return slot

	return null
