extends CanvasLayer

var dialogue_queue: Array = []
var index := 0
var is_talking := false
var tween: Tween
var current_npc = null

@export var dialogue_id: String = "npc1"
@export var typing_speed: float = 0.05

@onready var player = get_tree().get_first_node_in_group("player")
@onready var name_label: Label = $Control/HBoxContainer/Label
@onready var text_label: RichTextLabel = $Control/RichTextLabel
# AnimatedSprite2D
@onready var characters := {
	"น้ำฟ้า": $Control/Namfha,
	"พี่วา": $Control/Wawa
}

const BASE_SCALE := 2.5   # ต้องตรงกับ scale ที่ตัวละครควรแสดงในเกม (จาก Camera zoom 0.667)
const COLOR_ACTIVE := Color.WHITE
const COLOR_IDLE := Color(0.5, 0.5, 0.5, 1.0)
const SCALE_ACTIVE := Vector2(1.05, 1.05) * BASE_SCALE
const SCALE_IDLE := Vector2(0.95, 0.95) * BASE_SCALE

func _ready():
	add_to_group("dialogue_ui")
	visible = false
	text_label.bbcode_enabled = true
	set_process_input(true)
	# ตั้งค่าตัวละครเริ่มต้น
	for sprite: AnimatedSprite2D in characters.values():
		sprite.modulate = COLOR_IDLE
		sprite.scale = SCALE_IDLE
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")

func start_dialogue(lines: Array, npc = null):
	if is_talking:
		return
	if lines.is_empty():
		return
	current_npc = npc
	dialogue_queue = lines
	index = 0
	is_talking = true
	player.can_move = false
	visible = true
	show_line()

func show_line():
	var line = dialogue_queue[index]
	name_label.text = line["name"]
	text_label.text = line["text"]
	text_label.visible_ratio = 0.0
	update_character_focus(line["name"])
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(
		text_label,
		"visible_ratio",
		1.0,
		line["text"].length() * typing_speed
	)

func _input(event):
	if !is_talking:
		return
	if !event.is_action_pressed("interact"):
		return
	if text_label.visible_ratio < 1.0:
		if tween:
			tween.kill()
		text_label.visible_ratio = 1.0
		return
	index += 1
	if index >= dialogue_queue.size():
		end_dialogue()
	else:
		show_line()

func end_dialogue():
	if current_npc:
		current_npc.reset_direction()
		current_npc = null
	is_talking = false
	visible = false
	player.can_move = true
	dialogue_queue.clear()
	index = 0
	# กลับเป็น idle ทุกตัว
	for sprite: AnimatedSprite2D in characters.values():
		sprite.modulate = COLOR_IDLE
		sprite.scale = SCALE_IDLE
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")

func update_character_focus(active_name: String):
	var tw = create_tween().set_parallel(true)
	for name in characters.keys():
		var sprite: AnimatedSprite2D = characters[name]
		if name == active_name:
			tw.tween_property(sprite, "modulate", COLOR_ACTIVE, 0.2)
			tw.tween_property(sprite, "scale", SCALE_ACTIVE, 0.2)
			if sprite.sprite_frames.has_animation("talk"):
				sprite.play("talk")
		else:
			tw.tween_property(sprite, "modulate", COLOR_IDLE, 0.2)
			tw.tween_property(sprite, "scale", SCALE_IDLE, 0.2)
			if sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")
