extends Node2D
@export var floor_name := "1floor"
var player_inside := false

## 🚨 **หา StairMenu จากรากของซีน ไม่ใช่ `$"../StairMenu"`** (แก้ 2026-08-20)
##
## `StairMenu` เป็นลูกของโหนดรากเสมอ แต่ `Stair` อยู่ลึกไม่เท่ากันในแต่ละฉาก
## · `level1` · `level_3` — `Stair` เป็นลูกของราก → `../` ชี้ถูกพอดี
## · `level_2` — `Stair` ถูกย้ายไปอยู่ใต้ `WorldObjects` → `../` กลายเป็น `WorldObjects` ซึ่งไม่มี `StairMenu`
##   **ผลคือกด E ที่บันไดแล้วเมนูไม่ขึ้น = ขึ้น/ลงชั้นไม่ได้เลย** (เกิดจริง เจอตอนตรวจ)
##
## ค้นจาก `owner` (โหนดรากของซีน) จึงรอดจากการจัดกลุ่มโหนดใหม่ ไม่ว่าจะย้าย `Stair` ไปลึกแค่ไหน
@onready var stair_menu = _find_stair_menu()
@onready var area: Area2D = $Area2D
@onready var prompt_e = $PromptE   # เพิ่มบรรทัดนี้ — ต้องมี node ชื่อ PromptE อยู่ใต้ตัวนี้


func _find_stair_menu() -> Node:
	## `owner` = โหนดรากของซีนที่ `Stair` ถูกเซฟไว้ · เป็น null เฉพาะตอนตัวเองเป็นราก
	var root: Node = owner if owner != null else get_tree().current_scene
	if root == null:
		return null
	return root.find_child("StairMenu", true, false)


func _ready() -> void:
	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)
	if prompt_e:
		prompt_e.visible = false
		prompt_e.set_process(false)

	## เตือนตั้งแต่เปิดฉาก ไม่ใช่รอให้ผู้เล่นเดินมาถึงบันไดแล้วเงียบ
	if stair_menu == null:
		push_error("stair.gd: ไม่พบโหนด `StairMenu` ในซีนนี้ — กด E ที่บันไดจะไม่มีอะไรเกิดขึ้น")

func _process(_delta: float) -> void:
	if stair_menu == null:
		return
	if player_inside \
	and !stair_menu.is_menu_open \
	and Input.is_action_just_pressed("interact"):
		stair_menu.open_menu(floor_name)

func _on_area_body_entered(body: Node2D) -> void:
	if body is Player:
		player_inside = true
		print("Player เข้า Stair :", floor_name)
		if prompt_e:
			prompt_e.visible = true
			prompt_e.set_process(true)

func _on_area_body_exited(body: Node2D) -> void:
	if body is Player:
		player_inside = false
		print("Player ออก Stair :", floor_name)
		if prompt_e:
			prompt_e.visible = false
			prompt_e.set_process(false)
