extends Node

## ย้ายผู้เล่นไปยืนที่ spawn point ตามที่ฉากก่อนหน้าฝากไว้ใน `GameState.next_spawn_point`
##
## ⚠️ **มีระบบ spawn สองชุดในโปรเจกต์นี้** — ตัวนี้กับ `level_base.gd`
## ตัวไหนทำงานก่อนก็ล้าง `GameState.next_spawn_point` ทิ้ง อีกตัวจึงไม่ทำอะไรซ้ำ
## (โหนดลูก `_ready()` ก่อนโหนดแม่ → `SpawManager` ได้คิวก่อน `level_base` เสมอ)
## ยังไม่ได้ยุบเป็นระบบเดียวเพราะต้องแก้ซีนทั้ง 5 ฉากที่มีโหนดนี้อยู่
##
## 🚨 **NodePath ทั้งสองช่องปล่อยว่างได้แล้ว** (แก้ 2026-08-20)
## `level_2.tscn` ไม่ได้กรอกไว้ → เดิม `push_error` 2 บรรทัด**ทุกครั้งที่เข้าฉาก**
## แล้วปล่อยให้ `level_base.gd` รับช่วงต่อ · ตำแหน่งถูกต้องอยู่แล้ว แต่ error ประจำแบบนี้
## คือสิ่งที่ทำให้ error จริงกลืนหายไปในกองข้อความ

## ปล่อยว่าง = หาโหนดที่อยู่ในกลุ่ม `"player"` เอง
@export var player_path: NodePath

## ปล่อยว่าง = ค้นหา spawn point จากโหนดรากของซีน
@export var spawn_root: NodePath


func _ready() -> void:
	if GameState.next_spawn_point == "":
		return

	var player: Node = _resolve_player()
	if player == null:
		push_error("SpawManager: ไม่พบผู้เล่น (player_path = `%s` และไม่มีโหนดในกลุ่ม `player`)" \
			% str(player_path))
		return

	var spawn: Node2D = _resolve_spawn(GameState.next_spawn_point)
	if spawn == null:
		push_error("SpawManager: ไม่พบ spawn point ชื่อ `%s`" % GameState.next_spawn_point)
		return

	player.global_position = spawn.global_position
	GameState.next_spawn_point = ""


## หาผู้เล่น — ใช้ NodePath ที่กรอกไว้ก่อน ไม่มีค่อยหาจากกลุ่ม
##
## ⚠️ กลุ่ม `"player"` เป็นทางสำรองที่เชื่อถือได้กว่า NodePath ด้วยซ้ำ
## เพราะไม่พังตอนจัดกลุ่มโหนดใหม่ — แต่ยังเคารพช่องที่กรอกไว้ก่อน
## เผื่อฉากไหนมีผู้เล่นมากกว่าหนึ่งตัว (ยังไม่มี แต่ไม่ปิดทาง)
func _resolve_player() -> Node:
	var node: Node = get_node_or_null(player_path)
	if node != null:
		return node
	return get_tree().get_first_node_in_group("player")


## หา spawn point ตามชื่อ
##
## ⚠️ ค้นจาก `owner` (โหนดรากของซีน) ไม่ใช่จากตัวเอง — มาร์เกอร์อาจอยู่คนละกิ่ง
## และ `find_child()` ไล่ลูกหลานทั้งหมด จึงรอดจากการห่อโหนดเพิ่ม
## (`level_2.tscn` ถูกห่อไว้ใต้ `WorldObjects` มาแล้วรอบหนึ่ง — ดู DEVLOG 2026-08-20)
func _resolve_spawn(spawn_name: String) -> Node2D:
	var root: Node = get_node_or_null(spawn_root)
	if root != null:
		var direct: Node = root.get_node_or_null(NodePath(spawn_name))
		if direct is Node2D:
			return direct

	var scene_root: Node = owner if owner != null else get_tree().current_scene
	if scene_root == null:
		return null

	var found: Node = scene_root.find_child(spawn_name, true, false)
	return found as Node2D
