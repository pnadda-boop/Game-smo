extends Node2D
class_name wokeup



## สไปรท์ตัวละครในซีน (ตอนนี้ node ชื่อ "wawa")
## ปล่อยว่างไว้ = หา AnimatedSprite2D ตัวแรกในซีนให้เอง
## ทำแบบนี้เพื่อไม่ให้พังอีกเวลาเปลี่ยนชื่อ node ใน editor
@export var character_sprite: AnimatedSprite2D

@onready var timer: Timer = $Timer

var anim: AnimatedSprite2D = null
var area: Area2D = null

var animations = [
	"idle",
	"halfasleep",
	"wokeup"
]
var stage := 0
var click_count := 0
var clicks_needed := 0

## หน่วงก่อนรีเซ็ตความคืบหน้าการคลิก - หยุดคลิกนานเกินนี้แล้วต้องเริ่มนับใหม่
@export var click_reset_delay: float = 1.0

## จำนวนคลิกที่ต้องกดในแต่ละช่วง สุ่มในช่วงนี้ทุกครั้ง
## เพื่อให้ผู้เล่นไม่รู้ล่วงหน้าว่าเหลืออีกกี่ที ต้องกดย้ำ ๆ ไปเรื่อย ๆ เหมือนปลุกคนจริง
@export var clicks_stage1_min: int = 8   ## idle -> halfasleep
@export var clicks_stage1_max: int = 12
@export var clicks_stage2_min: int = 14  ## halfasleep -> wokeup
@export var clicks_stage2_max: int = 20


# ==============================================
# ลำดับหลังตื่น
# นั่งขึ้น -> คิดในใจ -> เสียงข้อความเข้า 2 ครั้ง -> หยิบโทรศัพท์ -> เปิดแชท
# ==============================================

const DIALOGUE_BOX := preload("res://DialogueBox.tscn")
const CHAT := preload("res://Chat.tscn")

## บทพูดตอนตื่น - ไม่ใส่ชื่อผู้พูดเพราะเป็นความคิดในใจ
@export var wake_line: String = "จะถึงแล้วเหรอเนี่ย..."
## หน่วงหลังนั่งขึ้น ก่อนบทพูดโผล่ (ให้เห็นท่านั่งก่อน ไม่เด้งพร้อมกัน)
@export var wake_line_delay: float = 0.8
## ค้างไว้กี่วินาทีหลังพิมพ์จบ ก่อนเสียงข้อความเข้า
@export var wake_line_hold: float = 1.5

## เสียงข้อความเข้า - เล่นหลังบทพูดจบ ก่อนหยิบโทรศัพท์
@export var notify_sound: AudioStream = preload("res://soud_effects/notification.mp3")
## เล่นกี่ครั้ง - ตรงกับจำนวนข้อความใหม่ใน INCOMING_CHAT ของ phone.gd
@export var notify_count: int = 2
## เว้นจังหวะระหว่างเสียงแต่ละครั้ง
@export var notify_gap: float = 0.55
## หน่วงหลังเสียงครั้งสุดท้าย ก่อนหยิบโทรศัพท์ขึ้นมาดู
@export var notify_to_phone_delay: float = 0.6

## ชื่ออนิเมชันตอนหยิบโทรศัพท์
@export var phone_anim: String = "phone"
## เวลาจางลง/จางขึ้นตอนสลับอนิเมชัน (วินาทีต่อครึ่ง รวมเป็น 2 เท่าของค่านี้)
## สไปรท์สลับเฟรมทันทีเสมอ จะทำให้ไหลลื่นไม่ได้ - ต้องใช้การจางบังจังหวะสลับไว้
@export var anim_fade_time: float = 0.22
## จางลงถึงระดับความทึบไหนก่อนสลับ (0 = หายไปเลย, 0.3 = จางแต่ยังเห็นเงา)
@export var anim_fade_alpha: float = 0.15

## --- เพลงประกอบฉาก ---
## node `BG` (AudioStreamPlayer) ในซีนมีไฟล์เพลงเสียบไว้แล้ว แต่ไม่ได้ติ๊ก autoplay
## จึงไม่เคยดังเลย - สั่งเล่นจากโค้ดแทนการติ๊ก autoplay เพราะได้ทั้งวนลูปและค่อย ๆ ดังขึ้น
@export_group("เพลงประกอบ")
## ชื่อ node เพลง - เปลี่ยนชื่อใน editor แล้วมาแก้ตรงนี้ที่เดียว
@export var bg_music_node: String = "BG"
@export_range(-40.0, 6.0) var bg_music_volume_db: float = -12.0
## ค่อย ๆ ดังขึ้นตอนเปิดฉาก - 0 = ดังเต็มทันที
@export var bg_music_fade_in: float = 2.0
## วนลูปไหม (เพลงฉากควรวนเสมอ ไม่งั้นเงียบไปเฉย ๆ ตอนเพลงจบ)
@export var bg_music_loop: bool = true
@export_group("")

var _dialogue_box: Node = null
var _chat: Node = null
var _notify_player: AudioStreamPlayer = null
var _bg_player: AudioStreamPlayer = null
## กันลำดับนี้ทำงานซ้ำ เผื่ออนิเมชัน wokeup จบหลายรอบ
var _wake_sequence_started := false


func _ready():
	randomize()

	if not _resolve_nodes():
		return

	anim.play(animations[stage])
	roll_next_target()
	timer.one_shot = true
	timer.wait_time = click_reset_delay
	timer.timeout.connect(_on_timer_timeout)
	anim.animation_finished.connect(_on_animation_finished)
	# 🆕 เปลี่ยนจาก _input (รับคลิกทั้งจอ) มาเป็น Area2D (รับคลิกเฉพาะโดนตัวละคร)
	area.input_event.connect(_on_area_input_event)

	_setup_notify_player()
	_start_bg_music()


## เปิดเพลงประกอบฉาก
##
## ⚠️ ไฟล์ AudioStream ตั้ง loop ที่ตัว "ทรัพยากร" ไม่ใช่ที่ตัวเล่น
## ติ๊ก autoplay ใน editor อย่างเดียวจะได้เพลงที่เล่นรอบเดียวแล้วเงียบตลอดฉาก
func _start_bg_music() -> void:
	_bg_player = get_node_or_null(bg_music_node) as AudioStreamPlayer
	if _bg_player == null:
		push_warning("wokeup.gd: ไม่พบ node เพลง '%s' — ฉากนี้จะไม่มีเพลงประกอบ" % bg_music_node)
		return
	if _bg_player.stream == null:
		push_warning("wokeup.gd: node '%s' ยังไม่ได้ใส่ไฟล์เพลง" % bg_music_node)
		return

	if bg_music_loop and "loop" in _bg_player.stream:
		_bg_player.stream.loop = true

	if bg_music_fade_in > 0.0:
		## เริ่มจากเงียบสนิทแล้วไล่ขึ้น - เปิดฉากมาแล้วเพลงตูมใส่เลยจะสะดุด
		## -60 dB คือเงียบจนไม่ได้ยิน ไม่ใช่ 0 (0 dB = ดังเต็ม)
		_bg_player.volume_db = -60.0
		_bg_player.play()
		create_tween().tween_property(_bg_player, "volume_db", bg_music_volume_db, bg_music_fade_in)
	else:
		_bg_player.volume_db = bg_music_volume_db
		_bg_player.play()


## สร้างตัวเล่นเสียงข้อความเข้าจากโค้ด ไม่ต้องเพิ่ม node ในซีน
func _setup_notify_player() -> void:
	_notify_player = AudioStreamPlayer.new()
	_notify_player.stream = notify_sound
	add_child(_notify_player)


## หาสไปรท์ตัวละครและ Area2D ที่ใช้รับคลิก
## คืน false ถ้าหาไม่เจอ (พร้อมบอกว่าขาดอะไร) เพื่อไม่ให้ _ready() ไปพังต่อ
func _resolve_nodes() -> bool:
	anim = character_sprite
	if anim == null:
		for child in get_children():
			if child is AnimatedSprite2D:
				anim = child
				break

	if anim == null:
		push_error("wokeup.gd: ไม่พบ AnimatedSprite2D ในซีน — ลากใส่ช่อง Character Sprite ที่ Inspector")
		return false

	area = anim.get_node_or_null("Area2D")
	if area == null:
		push_error("wokeup.gd: ไม่พบ Area2D ใต้ '%s' — ต้องมีไว้รับคลิกปลุก" % anim.name)
		return false

	return true


# 🆕 แทนที่ _input(event) เดิม - ทำงานเหมือนเดิมทุกอย่าง แค่เปลี่ยนช่องทางรับ event
func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		# ถ้าอยู่ช่วงสุดท้ายแล้ว ไม่ต้องคลิกอีก
		if stage >= animations.size() - 1:
			return
		click_count += 1
		timer.start()
		print("%d / %d" % [click_count, clicks_needed])
		if click_count >= clicks_needed:
			stage += 1
			click_count = 0
			anim.play(animations[stage])
			# ถ้ายังไม่ใช่ wokeup ให้สุ่มจำนวนคลิกใหม่
			if stage < animations.size() - 1:
				roll_next_target()
			else:
				# ตื่นแล้ว ไม่ต้องนับถอยหลังรีเซ็ตอีก
				timer.stop()


func roll_next_target():
	match stage:
		0:
			clicks_needed = randi_range(clicks_stage1_min, clicks_stage1_max)
		1:
			clicks_needed = randi_range(clicks_stage2_min, clicks_stage2_max)


func _on_timer_timeout():
	click_count = 0
	print("รีเซ็ตการคลิก")


func _on_animation_finished():
	if anim.animation == "wokeup":
		anim.play("sit")
		_start_wake_sequence()


# ==============================================
# ลำดับหลังตื่น
# ==============================================

## นั่งขึ้นแล้ว -> หน่วงแป๊บ -> ขึ้นบทพูดคิดในใจ
func _start_wake_sequence() -> void:
	if _wake_sequence_started:
		return
	_wake_sequence_started = true

	await get_tree().create_timer(wake_line_delay).timeout

	var box := _get_dialogue_box()
	if box == null:
		push_error("wokeup.gd: หากล่องคำพูดไม่ได้ — ข้ามบทพูดไปหยิบโทรศัพท์เลย")
		_on_wake_line_finished()
		return

	# CONNECT_ONE_SHOT: ต่อครั้งเดียวแล้วตัดเอง
	# ถ้าไม่ใส่ พอมีบทสนทนาอื่นในซีนนี้จบ จะมาเรียกซ้ำแล้วหยิบโทรศัพท์อีกรอบ
	box.dialogue_finished.connect(_on_wake_line_finished, CONNECT_ONE_SHOT)

	# ไม่ใส่คีย์ "name" -> ป้ายชื่อถูกซ่อน (เป็นความคิดในใจ)
	# show_portraits = false -> ไม่โชว์รูปในกล่อง เพราะเห็นตัวจริงอยู่ในฉากแล้ว
	# "hold" -> พิมพ์จบแล้วค้างไว้ แล้วไปต่อเอง ไม่ต้องให้ผู้เล่นกด E
	box.start_dialogue([{"text": wake_line, "hold": wake_line_hold}], null, false)


## บทพูดจบ -> ได้ยินเสียงข้อความเข้า -> หยิบโทรศัพท์ขึ้นมาดู
func _on_wake_line_finished() -> void:
	await _play_notifications()

	var real_anim := _resolve_anim(phone_anim)
	if real_anim != "":
		await _change_anim_fade(real_anim)
	else:
		push_warning("wokeup.gd: '%s' ไม่มีอนิเมชัน '%s'" % [anim.name, phone_anim])

	_show_chat()


## สลับอนิเมชันแบบค่อย ๆ จาง แทนการตัดทันที
## จางลง -> สลับเฟรม -> จางขึ้น
## ตัวสลับเฟรมยังทันทีเหมือนเดิม แต่การจางบังจังหวะนั้นไว้ ทำให้ตาไม่รู้สึกว่ากระตุก
func _change_anim_fade(target: String) -> void:
	if anim == null:
		return

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(anim, "modulate:a", anim_fade_alpha, anim_fade_time)
	tw.tween_callback(anim.play.bind(target))
	tw.tween_property(anim, "modulate:a", 1.0, anim_fade_time)
	await tw.finished


## หาชื่ออนิเมชันจริงใน SpriteFrames คืน "" ถ้าไม่มีจริง ๆ
##
## รองรับกรณีชื่อมีช่องว่างนำหน้า/ต่อท้ายโดยไม่ตั้งใจ เช่น " phone" แทน "phone"
## ⚠️ ช่องว่างพวกนี้ "มองไม่เห็น" ใน editor — ชื่อสองแบบดูเหมือนกันเป๊ะบนหน้าจอ
## ถ้าไม่มีตัวช่วยนี้ อนิเมชันจะไม่เล่นแบบเงียบ ๆ แล้วหาสาเหตุไม่ได้เลย
func _resolve_anim(wanted: String) -> String:
	if anim == null or anim.sprite_frames == null:
		return ""

	if anim.sprite_frames.has_animation(wanted):
		return wanted

	var target := wanted.strip_edges()
	for anim_name in anim.sprite_frames.get_animation_names():
		if String(anim_name).strip_edges() == target:
			push_warning("wokeup.gd: อนิเมชันใน '%s' ชื่อ '%s' มีช่องว่างเกินมา (ต้องการ '%s') — ควรแก้ชื่อใน SpriteFrames" \
				% [anim.name, anim_name, wanted])
			return anim_name
	return ""


## เล่นเสียงข้อความเข้าตามจำนวนที่ตั้ง เว้นจังหวะระหว่างครั้ง
func _play_notifications() -> void:
	if _notify_player == null or notify_sound == null:
		push_warning("wokeup.gd: ไม่มีเสียงข้อความเข้า ข้ามไปหยิบโทรศัพท์เลย")
		return

	for i in notify_count:
		_notify_player.play()
		await get_tree().create_timer(notify_gap).timeout

	await get_tree().create_timer(notify_to_phone_delay).timeout


## หากล่องคำพูดในซีน ถ้าไม่มีก็สร้างเพิ่มให้
## ทำแบบนี้เพื่อไม่ต้องลากใส่ทุกซีน และไม่สร้างซ้ำถ้าซีนมีอยู่แล้ว
func _get_dialogue_box() -> Node:
	if _dialogue_box and is_instance_valid(_dialogue_box):
		return _dialogue_box

	var existing := get_tree().get_first_node_in_group("dialogue_ui")
	if existing and existing.has_method("start_dialogue"):
		_dialogue_box = existing
		return _dialogue_box

	_dialogue_box = DIALOGUE_BOX.instantiate()
	add_child(_dialogue_box)
	return _dialogue_box


func _show_chat() -> void:
	if _chat and is_instance_valid(_chat):
		return
	_chat = CHAT.instantiate()
	add_child(_chat)
