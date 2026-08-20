extends CanvasLayer

@onready var color_rect = $ColorRect
@onready var arrow: TextureRect = $ColorRect/arrow
@onready var menus = {
	"1floor": $ColorRect/floor1,
	"2floor": $ColorRect/floor2,
	"3floor": $ColorRect/floor3
}
@onready var player = get_tree().get_first_node_in_group("player")

# กำหนดว่าแต่ละชั้น เมื่อกด select index ไหน จะไป scene ไหน
# select 0 = ตัวเลือกบน (ลูกศรเริ่มต้น), select 1 = ตัวเลือกล่าง
# ต้องแก้ path ให้ตรงกับไฟล์ scene จริงในโปรเจกต์

## ชั้น 2 ชี้ `AllLevel2` ไม่ใช่ `level_2.tscn` โดยตรง
##
## `AllLevel2` เป็นซีนห่อที่มี `Level2` เป็นลูก — เอาไว้เอาของที่เพิ่มทีหลัง
## (เควสต์กล่อง `level_2_1.tscn` · NPC) มาต่อเป็นพี่น้องกัน โดยไม่ต้องแก้ในซีนแมพ
## ที่ยาวสองพันกว่าบรรทัด · `spawn` ยังใช้ชื่อเดิมได้ เพราะ `level_base.gd`
## หา spawn point ด้วย `find_child()` ในกิ่งของ `Level2` เอง ซ้อนอีกชั้นไม่กระทบ
##
## 🚨 **ย้าย/เปลี่ยนชื่อไฟล์นี้เมื่อไหร่ ต้องกลับมาแก้บรรทัดล่างนี้ด้วยมือ**
## Godot อัปเดตให้เฉพาะการอ้างอิงในซีนกับ `@export` เท่านั้น **string ใน `.gd` มันไม่ตามให้**
## (กับดักเดิมที่เคยเจอตอนเปลี่ยนชื่อ `canvas_layer.tscn` → `DialogueBox.tscn`)
## แยกเป็น const เพราะมี 2 ที่ที่ชี้ชั้น 2 — แก้ที่เดียวไม่มีทางตกหล่นข้างใดข้างหนึ่ง
const LEVEL_2_SCENE := "res://all_level_2.tscn"

var floor_targets := {
	"1floor": [
		{"scene": "res://level_3.tscn", "spawn": "from_1floor_direct"},
		{"scene": LEVEL_2_SCENE, "spawn": "from_1floor"}
	],
	"2floor": [
		{"scene": "res://level_3.tscn", "spawn": "from_2floor_up"},
		{"scene": "res://level1.tscn", "spawn": "from_2floor_down"}
	],
	"3floor": [
		{"scene": LEVEL_2_SCENE, "spawn": "from_3floor"},
		{"scene": "res://level1.tscn", "spawn": "from_3floor_direct"}
	]
}

var current_menu: Control = null
var current_floor_name: String = ""
var select := 0
var is_menu_open := false
var can_select := false
var arrow_start_pos: Vector2

func _ready():
	arrow_start_pos = arrow.position
	color_rect.hide()
	for menu in menus.values():
		menu.hide()

# -------------------------
# เปิดเมนู (เรียกจาก stair.gd ตอนกด E ครั้งแรก)
# -------------------------
func open_menu(floor_name: String):
	if is_menu_open:
		return
	if !menus.has(floor_name):
		push_error("ไม่มีเมนู " + floor_name)
		return

	for menu in menus.values():
		menu.hide()

	current_menu = menus[floor_name]
	current_floor_name = floor_name
	current_menu.show()
	color_rect.show()
	is_menu_open = true
	can_select = false

	if is_instance_valid(player):
		player.can_move = false

	select = 0
	update_arrow()

	# กันไม่ให้ E ตัวที่เปิดเมนูถูกอ่านซ้ำเป็นตัวยืนยันในเฟรมเดียวกัน
	await get_tree().process_frame
	can_select = true

# -------------------------
# ปิดเมนู (ไม่เปลี่ยน scene)
# -------------------------
func hide_menu():
	if !is_menu_open:
		return
	if current_menu:
		current_menu.hide()
	color_rect.hide()
	current_menu = null
	current_floor_name = ""
	is_menu_open = false
	can_select = false

	if is_instance_valid(player):
		player.can_move = true

# -------------------------
# Input
# -------------------------
func _process(_delta):
	if !is_menu_open:
		return

	if Input.is_action_just_pressed("up"):
		select -= 1
		if select < 0:
			select = 0
		update_arrow()

	elif Input.is_action_just_pressed("down"):
		var max_index = floor_targets[current_floor_name].size() - 1
		select += 1
		if select > max_index:
			select = max_index
		update_arrow()

	elif can_select and Input.is_action_just_pressed("interact"):
		confirm_select()

	elif Input.is_action_just_pressed("cancel"):
		hide_menu()

# -------------------------
# ยืนยันตัวเลือก -> เปลี่ยน scene
# -------------------------
func confirm_select():
	var targets = floor_targets.get(current_floor_name, [])
	if select < targets.size():
		var target = targets[select]
		var target_scene = target["scene"]        # <-- ดึงเฉพาะ string path ออกมา
		var target_spawn = target["spawn"]        # <-- ดึงชื่อ spawn point ออกมา
		print("ยืนยันไปที่: ", target_scene, " spawn: ", target_spawn)
		GameState.next_spawn_point = target_spawn
		hide_menu()
		get_tree().change_scene_to_file(target_scene)   # <-- ตอนนี้เป็น String แล้ว ใช้ได้
	else:
		push_error("ไม่มี target scene สำหรับ select นี้ (floor: %s, select: %d)" % [current_floor_name, select])

# -------------------------
# ลูกศร
# -------------------------
func update_arrow():
	arrow.position = arrow_start_pos + Vector2(0, select * 95)


func _on_area_2d_body_entered(body: Node2D) -> void:
	pass # Replace with function body.


func _on_area_2d_body_exited(body: Node2D) -> void:
	pass # Replace with function body.
