extends Node2D
## ห้องที่ใช้เลย์เอาต์เดิมทุกบท แต่สลับ "ของตกแต่ง + NPC" ตามบทของเนื้อเรื่อง
##
## แนวคิด: ตัวห้อง (พื้น กำแพง บันได จุดเกิด ผู้เล่น) อยู่ในซีนเดียวตลอด
## ของที่เปลี่ยนตามบทถูกแยกไปเป็นซีนย่อยใน res://decor/ แล้วเสียบเข้ามาตอนรัน
## ทำแบบนี้แก้เลย์เอาต์ทีเดียวได้ผลทุกบท ไม่ต้องก็อปซีนห้องทั้งใบต่อบท
##
## วิธีใช้: แนบสคริปต์นี้ที่โหนดรากของห้อง ต้องมีลูกชื่อ ChapterSlot (Node2D) อยู่ด้วย

## ซีนของตกแต่งเรียงตามบท — index 0 = บท 1, index 1 = บท 2 ไปเรื่อย ๆ
## ใช้ Array ไม่ใช่ Dictionary เพราะลากซีนใส่ใน Inspector ได้ตรง ๆ
## ช่องไหนปล่อยว่าง (null) = บทนั้นห้องโล่ง ไม่มีของตกแต่ง (ไม่ใช่ error)
@export var chapter_decors: Array[PackedScene] = []

## ที่แขวนของตกแต่ง — ล้างทิ้งได้ทั้งกิ่งโดยไม่กระทบผู้เล่น/พื้น/จุดเกิด
@onready var slot: Node2D = $ChapterSlot


func _ready() -> void:
	_apply_chapter(GameState.chapter)
	GameState.chapter_changed.connect(_apply_chapter)


## รื้อของบทเดิมทิ้งแล้วเสียบของบทใหม่เข้า ChapterSlot
func _apply_chapter(chapter: int) -> void:
	var index: int = chapter - 1
	if index < 0 or index >= chapter_decors.size():
		push_warning("room.gd: ไม่มีของตกแต่งของบท %d (chapter_decors มี %d ช่อง) — ห้องคงสภาพเดิม" % [chapter, chapter_decors.size()])
		return

	## 🚨 ล้างเฉพาะลูกของ slot เท่านั้น — player / Tile_set / SpawManager อยู่นอก slot จึงรอดเสมอ
	## remove_child ก่อน queue_free เพราะ queue_free ลบจริงตอนท้ายเฟรม
	## ถ้าไม่ถอดออกจาก tree ก่อน ของบทเก่ากับบทใหม่จะซ้อนกันอยู่ 1 เฟรม แล้วชื่อโหนดยังชนกันด้วย
	for child: Node in slot.get_children():
		slot.remove_child(child)
		child.queue_free()

	var decor_scene: PackedScene = chapter_decors[index]
	if decor_scene == null:
		return   ## บทนี้ตั้งใจให้ห้องโล่ง

	var decor: Node = decor_scene.instantiate()
	slot.add_child(decor)
