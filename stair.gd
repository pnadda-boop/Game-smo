extends Node2D
@export var floor_name := "1floor"
var player_inside := false

@onready var stair_menu = $"../StairMenu"
@onready var area: Area2D = $Area2D
@onready var prompt_e = $PromptE   # เพิ่มบรรทัดนี้ — ต้องมี node ชื่อ PromptE อยู่ใต้ตัวนี้

func _ready() -> void:
	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)
	if prompt_e:
		prompt_e.visible = false
		prompt_e.set_process(false)

func _process(_delta: float) -> void:
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
