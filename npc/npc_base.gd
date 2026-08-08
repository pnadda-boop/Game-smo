class_name NPCBase
extends CharacterBody2D

## ซีนแม่ของ NPC ทุกตัว
##
## NPC หนึ่งตัว = ซีนสืบทอด (inherited scene) ของ `npc_base.tscn` + ไฟล์ `NPCData` ของตัวเอง
## แก้ระบบตรงนี้ทีเดียวกระทบทุกตัว แต่ยังปรับ collision รายตัวได้ที่ซีนลูก
##
## 🚨 **ชื่อโหนดลูกห้ามเปลี่ยน** — ผูกไว้กับ `$` path ในบล็อก @onready ข้างล่าง
## เปลี่ยนชื่อใน editor แล้วจะพังทุกตัวพร้อมกัน ไม่ใช่แค่ตัวที่แก้

## ส่งตอนผู้เล่นกด interact ใส่ NPC ตัวนี้
## ให้ฝั่งเนื้อเรื่อง/เควสต์ดักได้โดยไม่ต้องสืบทอดสคริปต์
signal interacted(npc: NPCBase)

## ข้อมูลประจำตัว — ตั้งที่ซีนลูกให้ชี้ไฟล์ `.tres` ของตัวเอง
@export var data: NPCData = null

## ผู้เล่นอยู่ในระยะคุยไหม — ฝั่งที่รับอินพุตอ่านค่านี้ไปตัดสิน
var player_in_range: bool = false

## ⚠️ ผูก node ครั้งเดียวตอน @onready ไม่เรียก `get_node()` / `$` ซ้ำระหว่างเล่น
## การหา node ด้วย path เป็นการไล่ชื่อลูกทีละชั้น ทำทุกเฟรมคือจ่ายฟรี
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_area: Area2D = $InteractArea
@onready var indicator: AnimatedSprite2D = $Indicator


func _ready() -> void:
	add_to_group("npc")

	## ซ่อนไว้ก่อนเสมอ ค่อยโผล่ตอนผู้เล่นเข้าระยะ
	indicator.visible = false

	## ต่อสัญญาณจากโค้ด ไม่ต่อจาก editor
	##
	## ⚠️ ซีนลูกสืบทอด "การเชื่อมต่อ" มาด้วย ถ้าต่อไว้ที่ editor ของซีนแม่
	## แล้วเผลอต่อซ้ำที่ซีนลูก จะเข้าเมธอดสองรอบต่อการชนหนึ่งครั้ง
	## ต่อจากโค้ดที่เดียวแบบนี้ไม่มีทางซ้ำ (เจอปัญหาต่อซ้ำมาแล้วใน Start.gd)
	interact_area.body_entered.connect(_on_interact_area_body_entered)
	interact_area.body_exited.connect(_on_interact_area_body_exited)

	if data == null:
		## ไม่ crash — ปล่อยให้ NPC ยืนเป็นก้อน collision เฉย ๆ
		## เห็น warning แล้วรู้ว่าลืมใส่ data ตัวไหน ดีกว่าเกมดับทั้งฉาก
		push_warning("npc_base.gd: `%s` ยังไม่ได้ใส่ data (NPCData) — ตัวนี้จะคุยไม่ได้" % name)
		return

	_apply_data()


## ยกค่าจาก NPCData ไปใส่โหนดจริง
func _apply_data() -> void:
	## ⚠️ เขียนทับเฉพาะตอนมีของจริง
	## ยัด null ทับจะลบชุดอนิเมชันที่ตั้งไว้ในซีนลูกทิ้ง แล้ว NPC จะหายไปทั้งตัว
	## (เว้นช่อง frames ใน .tres ว่างไว้ = "ใช้ของที่ตั้งในซีน" ไม่ใช่ "ไม่มีรูป")
	if data.frames != null:
		sprite.sprite_frames = data.frames

	sprite.position = data.sprite_offset
	indicator.position = data.indicator_offset


## เข้าระยะคุย
func _on_interact_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = true
	## NPC ฉากหลังไม่ต้องขึ้นบับเบิลหลอกให้กด
	indicator.visible = can_interact()


## ออกนอกระยะคุย
func _on_interact_area_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = false
	indicator.visible = false


## คุยกับ NPC ตัวนี้ได้ไหม (มีข้อมูล + ไม่ได้ปิดไว้)
func can_interact() -> bool:
	return data != null and data.can_interact


## ทางเข้าเดียวของการกดคุย — ฝั่งผู้เล่น/อินพุตเรียกตัวนี้
func interact() -> void:
	if not can_interact():
		return

	interacted.emit(self)
	_on_interact()


## ให้ซีนลูก override — NPC ตัวไหนมีพฤติกรรมพิเศษเขียนทับตรงนี้
##
## ⚠️ ยังไม่ต่อเข้า DialogueBox ตามที่ตกลงไว้ ตอนนี้แค่ print ดูว่า id มาถูกตัวไหม
## ของจริงจะเป็น: หา node กลุ่ม `dialogue_ui` แล้วเรียก `start_dialogue(lines, self)`
## เหมือนที่ `NPC.gd` เดิมทำ
func _on_interact() -> void:
	print("[NPC] %s -> dialogue_id = %s" % [data.display_name, data.dialogue_id])
