class_name Player

extends CharacterBody2D

var move_speed: float = 200.0

var last_direction: Vector2 = Vector2.DOWN
var animation_direction: Vector2 = Vector2.DOWN

var can_move := true

var on_stairs: bool = false
var stair_dir: Vector2 = Vector2.ZERO

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	await get_tree().process_frame


func _process(delta):
	if !can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		play_animation("idle", animation_direction)
		return

	# รับค่าทิศทางจากการกดปุ่ม
	var direction: Vector2 = Vector2.ZERO
	direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")

	if direction != Vector2.ZERO:
		direction = direction.normalized()

		if on_stairs:
			# เดินตามแนวบันได
			if direction.dot(stair_dir) < 0:
				velocity = -stair_dir.normalized() * move_speed
				last_direction = -stair_dir.normalized()
			else:
				velocity = stair_dir.normalized() * move_speed
				last_direction = stair_dir.normalized()

			# ไม่เปลี่ยน animation_direction
			# เพื่อให้อนิเมชันคงเดิมตอนเข้าบันได

		else:
			velocity = direction * move_speed
			last_direction = direction
			animation_direction = direction

	else:
		velocity = Vector2.ZERO

	move_and_slide()

	process_animation(animation_direction)


func process_animation(direction) -> void:
	if velocity != Vector2.ZERO:
		play_animation("walk", direction)
	else:
		play_animation("idle", direction)


func play_animation(prefix: String, dir: Vector2) -> void:
	if dir.y < 0:
		animated_sprite_2d.play(prefix + "_up")
		animated_sprite_2d.flip_h = false

	elif dir.y > 0:
		animated_sprite_2d.play(prefix + "_down")
		animated_sprite_2d.flip_h = false

	elif dir.x < 0:
		animated_sprite_2d.play(prefix + "_side")
		animated_sprite_2d.flip_h = false

	elif dir.x > 0:
		animated_sprite_2d.play(prefix + "_side")
		animated_sprite_2d.flip_h = true


func _on_area_2d_body_entered(body: Node2D) -> void:
	pass


func _on_area_2d_body_exited(body: Node2D) -> void:
	pass


func _on_area_2_dsmallroom_body_exited(body: Node2D) -> void:
	pass


func _on_area_2_dmeetingroom_body_entered(body: Node2D) -> void:
	pass


func _on_area_2_dmeetingroom_body_exited(body: Node2D) -> void:
	pass


func _on_stair_area_2d_body_entered(body: Node2D) -> void:
	if body == self:
		on_stairs = true
		stair_dir = Vector2(1, -0.3)


func _on_stair_area_2d_body_exited(body: Node2D) -> void:
	if body == self:
		on_stairs = false
		stair_dir = Vector2.ZERO
