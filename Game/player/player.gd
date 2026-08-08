class_name Player

extends CharacterBody2D

var move_speed: float = 200.0

var last_direction: Vector2 = Vector2.DOWN
var animation_direction: Vector2 = Vector2.DOWN

var can_move := true

var on_stairs: bool = false
var stair_dir: Vector2 = Vector2.ZERO

## เสียงฝีเท้า
##
## ⚠️ walk.ogg เป็นเสียงเดิน "ต่อเนื่อง" ไม่ใช่เสียงก้าวเดียว
## จึงต้องเล่นครั้งเดียวตอนเริ่มเดิน แล้วหยุดตอนหยุด + เปิดวนลูปไว้
## ห้ามสั่ง play() ซ้ำทุกเฟรม เพราะจะได้ยินแค่เศษเสี้ยวแรกของไฟล์วนรัว ๆ
## (เคยพลาดแบบเดียวกันมาแล้วกับเสียงพิมพ์ใน dialogue_system)
##
## ⚠️ ใช้ .ogg ไม่ใช่ .mp3 — mp3 มีความเงียบที่ตัวเข้ารหัสเติมหัวท้ายไฟล์เสมอ
## ต่อให้ตัดเสียงมาเป๊ะแค่ไหน วนลูปแล้วก็จะได้ยินช่องว่างตรงรอยต่อ
##
## ใช้เป็น "ตัวสำรอง" เท่านั้น - ถ้ามี AudioStreamPlayer ในซีนที่ใส่ไฟล์ไว้แล้ว จะใช้ของนั้นก่อน
@export var walk_sound: AudioStream = preload("res://soud_effects/walk.ogg")

## ⚠️ ไม่มี @export ของระดับเสียงโดยตั้งใจ
## ระดับเสียงตั้งที่ `Volume Db` ของ node WalkSoud ใน player.tscn ที่เดียว
## เคยมี walk_sound_volume_db แล้วสับสนมาก เพราะค่าที่ node ทับเสมอ
## ปรับ export แล้วไม่มีอะไรเปลี่ยน - หาสาเหตุไม่เจอเลยว่าทำไม
const FALLBACK_VOLUME_DB := -6.0

## ช่วงที่ใช้จริงในไฟล์เสียง (วินาที) - เล่นถึง end แล้วกระโดดกลับไป start วนไปเรื่อย ๆ
##
## ⚠️ ต้องคุมเองด้วยการ seek เพราะ AudioStream ของ Godot มีแค่ `loop_offset`
## (จุดที่จะกลับไปเมื่อเล่นจนจบไฟล์) แต่ **ไม่มีจุดจบของลูป** ตั้งได้
## ปล่อยให้มันเล่นจนสุดไฟล์จะติดหางเสียงเงียบ ๆ ท้ายไฟล์ แล้วจังหวะก้าวจะเพี้ยนตรงรอยต่อ
##
## ตั้ง end = 0 = ใช้ทั้งไฟล์ ปล่อยให้ลูปของ AudioStream ทำงานเอง
## (ใช้ได้เฉพาะไฟล์ที่ตัดมาพอดีหนึ่งรอบก้าวเป๊ะ ๆ เท่านั้น)
##
## walk.ogg ยาว 8.098 วิ - เสียงก้าวจริงอยู่ช่วง 0.20-7.50 ที่เหลือเป็นหัวท้ายที่ไม่ใช้
@export var walk_sound_start: float = 1.0
@export var walk_sound_end: float = 5.0




@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var _walk_player: AudioStreamPlayer = null
## walk_sound_end หลังตัดให้ไม่เกินความยาวไฟล์จริง
var _loop_end: float = 0.0


func _ready():
	_setup_walk_sound()
	await get_tree().process_frame


## เตรียมตัวเล่นเสียงฝีเท้า
##
## มี AudioStreamPlayer อยู่ในซีนแล้ว -> ใช้ตัวนั้น (ปรับ stream/volume ที่ Inspector ได้)
## ไม่มี -> สร้างจากโค้ดให้เอง (ผู้เล่นถูก instance หลายซีน จะได้ไม่ต้องเพิ่มทีละที่)
##
## ⚠️ ต้องหาของเดิมก่อนเสมอ ถ้าสร้างใหม่ทื่อ ๆ จะได้ตัวเล่น 2 ตัว
## แล้วค่าที่ตั้งไว้ที่ node ในซีนจะไม่มีผลอะไรเลย - หาสาเหตุยากมาก
func _setup_walk_sound() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			_walk_player = child
			break

	if _walk_player == null:
		if walk_sound == null:
			return
		_walk_player = AudioStreamPlayer.new()
		_walk_player.volume_db = FALLBACK_VOLUME_DB
		add_child(_walk_player)

	## node ในซีนใส่ไฟล์เสียงไว้แล้วก็ใช้ของมัน ไม่เขียนทับ
	if _walk_player.stream == null:
		_walk_player.stream = walk_sound

	## loop อยู่ที่ตัวทรัพยากร ไม่ใช่ที่ตัวเล่น - ไม่เปิดจะเงียบไปเองหลังเล่นจบไฟล์
	if _walk_player.stream and "loop" in _walk_player.stream:
		_walk_player.stream.loop = true
	## กันเหนียว: ถ้าหลุดไปจนสุดไฟล์จริง ๆ ให้วนกลับที่ start ไม่ใช่ 0
	## (ปกติ _update_walk_sound จะ seek ก่อนถึงตรงนั้นอยู่แล้ว)
	if _walk_player.stream and "loop_offset" in _walk_player.stream:
		_walk_player.stream.loop_offset = walk_sound_start

	_resolve_loop_range()


## ตัดช่วงลูปให้อยู่ในไฟล์จริง แล้วบอกให้รู้ถ้าตั้งเกิน
##
## ตั้งเลยความยาวไฟล์แล้วจะ "ไม่พัง" แต่ seek จะไม่เคยทำงาน
## เสียงจะไปวนที่ปลายไฟล์แทนแบบเงียบ ๆ - ต้องเตือนไม่งั้นหาสาเหตุไม่เจอ
func _resolve_loop_range() -> void:
	_loop_end = walk_sound_end
	if _walk_player == null or _walk_player.stream == null:
		return

	var length := _walk_player.stream.get_length()
	if length <= 0.0:
		return

	if walk_sound_start >= length:
		push_warning("player.gd: Walk Sound Start = %.2f วิ เกินความยาวไฟล์ (%.2f วิ) — เริ่มที่ 0 แทน" \
			% [walk_sound_start, length])
		walk_sound_start = 0.0

	## 0 = ไม่ตัดช่วง ใช้ทั้งไฟล์ (ลูปของ AudioStream เนียนกว่าการ seek เอง)
	if walk_sound_end <= 0.0:
		_loop_end = 0.0
		return

	if walk_sound_end > length:
		push_warning("player.gd: Walk Sound End = %.2f วิ แต่ไฟล์ยาวแค่ %.2f วิ — ใช้ทั้งไฟล์แทน" \
			% [walk_sound_end, length])
		_loop_end = 0.0


## เปิด/ปิดเสียงเดินตามสถานะจริง + วนเฉพาะช่วง start..end
## เช็ค playing ก่อนเสมอ ไม่งั้นสั่ง play() ซ้ำทุกเฟรมแล้วเสียงจะกระตุกอยู่ที่จุดเริ่มไฟล์
func _update_walk_sound(moving: bool) -> void:
	if _walk_player == null:
		return

	if not moving:
		if _walk_player.playing:
			_walk_player.stop()
		return

	if not _walk_player.playing:
		_walk_player.play(walk_sound_start)
		return

	if _loop_end <= walk_sound_start:
		return

	var pos := _walk_player.get_playback_position()
	if pos < _loop_end:
		return

	## ถึงปลายช่วงแล้ว -> ตีกลับไปต้นช่วง
	## ใช้ seek() แทน play() ใหม่ เพราะ play() จะรีเซ็ตทั้ง playback เสียงจะสะดุดได้ยิน
	##
	## ⚠️ ต้องบวก "ส่วนที่เลยมา" กลับเข้าไปด้วย
	## เราเช็คได้แค่เฟรมละครั้ง (60fps = คลาดได้ถึง 17ms) ถ้า seek กลับไปที่ start ตรง ๆ
	## รอบลูปจะยาวกว่าที่ตั้งไว้นิดหน่อยแบบสุ่มทุกรอบ -> จังหวะก้าวเพี้ยนสะสม
	## บวกส่วนเกินกลับไปแล้วคาบของลูปจะเท่ากับ (end - start) เป๊ะ ไม่ว่าเฟรมเรตเท่าไหร่
	var overshoot := pos - _loop_end
	var span := _loop_end - walk_sound_start
	## เฟรมกระตุกหนักจนเลยไปเกินหนึ่งรอบ - วนกลับให้อยู่ในช่วง
	if overshoot >= span:
		overshoot = fmod(overshoot, span)
	_walk_player.seek(walk_sound_start + overshoot)


func _process(delta):
	if !can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		play_animation("idle", animation_direction)
		## ต้องหยุดเสียงตรงนี้ด้วย ไม่งั้นถ้าโดนล็อกตอนกำลังเดินอยู่
		## (เช่นเริ่มบทสนทนา หรืออินโทรตอนมาถึงลานจอดรถ) เสียงจะดังค้างไปเรื่อย ๆ
		_update_walk_sound(false)
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
	## อ่านค่าหลัง move_and_slide เพราะมันปรับ velocity ตามการชนแล้ว
	## เสียงจึงตรงกับอนิเมชันเสมอ - เดินชนกำแพงอยู่กับที่ก็ไม่มีเสียงฝีเท้า
	_update_walk_sound(velocity != Vector2.ZERO)


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
