extends Node2D

# base class สำหรับทุก level - จัดการเรื่อง spawn point ให้อัตโนมัติ
@onready var base_player = get_tree().get_first_node_in_group("player")

func _ready():
	_apply_spawn_point()
	_on_level_ready()  # hook ให้ level ลูกทำงานเพิ่มเติมของตัวเอง

func _apply_spawn_point():
	if GameState.next_spawn_point != "":
		var spawn_node = find_child(GameState.next_spawn_point, true, false)
		if spawn_node and is_instance_valid(base_player):
			base_player.global_position = spawn_node.global_position
			print("ย้าย player ไปที่: ", GameState.next_spawn_point)
		else:
			push_error("ไม่เจอ spawn point ชื่อ: " + GameState.next_spawn_point)
		GameState.next_spawn_point = ""

# ให้ level ลูก override ฟังก์ชันนี้แทนการเขียน _ready() ตรงๆ
func _on_level_ready():
	pass
