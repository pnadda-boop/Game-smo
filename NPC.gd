extends CharacterBody2D


@onready var bubble = $AnimatedSprite2D2
@onready var sprite = $AnimatedSprite2D
@onready var player = get_tree().get_first_node_in_group("player")
# ลบบรรทัด @onready var dialogue_ui ออก
@export var dialogue_resource: DialogueData
@export var dialogue_id: String = "npc1"
var initial_animation: String
var initial_flip: bool
var is_player_in_range := false

func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		is_player_in_range = true
		bubble.show_bubble()
		
func _on_area_2d_body_exited(body):
	if body.is_in_group("player"):
		is_player_in_range = false
		bubble.hide_bubble()
		
func _ready():
	initial_animation = sprite.animation
	initial_flip = sprite.flip_h

func reset_direction():
	sprite.play(initial_animation)
	sprite.flip_h = initial_flip

func _input(event):
	if not is_player_in_range:
		return
	if not event.is_action_pressed("interact"):
		return
	
	face_player()
	bubble.hide_bubble()
	
	if dialogue_resource != null:
		var lines = dialogue_resource.dialogues[dialogue_id]
		var dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")  # หาสดตอนใช้งานจริง
		if dialogue_ui:
			dialogue_ui.start_dialogue(lines, self)
		else:
			push_error("ไม่พบ dialogue_ui — เช็คว่า Dialogue_System เข้า group 'dialogue_ui' แล้วหรือยัง")
	
func face_player():
	if player == null:
		return
	var diff = player.global_position - global_position
	if abs(diff.x) > abs(diff.y):
		sprite.play("idle_side")
		sprite.flip_h = diff.x > 0
	else:
		sprite.flip_h = false
		if diff.y < 0:
			sprite.play("idle_up")
		else:
			sprite.play("idle_down")
