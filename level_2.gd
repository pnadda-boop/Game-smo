extends "res://level_base.gd"

@onready var rooms = {
	"meetingroom": $meetingroom,
	"small_room": $small_room,
	"toilet_m": $ToiletM,
	"toilet_w": $ToiletW,
	"footpath": $footpath
}

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
