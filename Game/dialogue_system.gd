extends CanvasLayer
## ==============================================
## ระบบกล่องคำพูด
## ==============================================
## ⚠️ ใส่กลุ่ม "dialogue_ui" ที่ node นี้ (CanvasLayer) เท่านั้น
##    ห้ามใส่ให้ Control หรือ Label ที่เป็นลูก เพราะ NPC.gd หาด้วย
##    get_first_node_in_group("dialogue_ui") ซึ่งอาจคืน node ลูกที่ไม่มีเมธอด start_dialogue()
##
## รูปแบบข้อมูลบทพูด (คีย์ anim ใส่หรือไม่ใส่ก็ได้):
##   [
##     {"name": "พี่วา",  "text": "อรุณสวัสดิ์จ้า",     "anim": "happy"},
##     {"name": "พี่วา",  "text": "แต่พี่มีเรื่องจะบอก", "anim": "worried"},
##     {"name": "น้ำฟ้า", "text": "อะไรคะ"},   <- ไม่ใส่ anim = ใช้ default_anim
##   ]

var dialogue_queue: Array = []
var index := 0
var is_talking := false
var tween: Tween
var current_npc = null

@export var typing_speed: float = 0.05

## อนิเมชันที่ใช้เมื่อบรรทัดนั้นไม่ระบุคีย์ anim
@export var default_anim: String = "talk"

## หน้าตาของคนที่กำลังพูด vs คนที่ไม่ได้พูด - ปรับได้ที่ Inspector
@export var color_active: Color = Color.WHITE
@export var color_idle: Color = Color(0.35, 0.35, 0.35, 1.0)
@export var base_scale: float = 2.5     ## ขนาดพื้นฐานของรูปตัวละคร
@export var scale_active: float = 1.05  ## คนพูด ขยายขึ้นเล็กน้อย
@export var scale_idle: float = 0.9     ## คนไม่พูด ย่อลง
@export var focus_time: float = 0.2     ## เวลาที่ใช้เปลี่ยนสี/ขนาด

## ใช้ get_node_or_null ทั้งหมด เพื่อให้เปลี่ยนชื่อ/ย้าย node ใน editor แล้ว
## ได้ข้อความบอกชัดว่า node ไหนหาไม่เจอ ไม่ใช่ crash แบบไม่รู้สาเหตุ
@onready var name_label: Label = get_node_or_null("Root/Box/NamePlate/NameLabel")
@onready var text_label: RichTextLabel = get_node_or_null("Root/Box/TextPanel/TextLabel")
## ก้อนรูปตัวละครทั้งหมด - ซ่อนก้อนนี้ = โหมดข้อความล้วน
@onready var portraits: Node = get_node_or_null("Root/Portraits")

## รูปตัวละคร - key ต้องตรงกับค่า "name" ในบทพูดเป๊ะ
@onready var characters := {
	"น้ำฟ้า": get_node_or_null("Root/Portraits/Namfha"),
	"วาวา": get_node_or_null("Root/Portraits/Wawa"),
	"โชแชง": get_node_or_null("Root/Portraits/Chochang"),
	"คีริน": get_node_or_null("Root/Portraits/Kirin"),
}


func _ready():
	visible = false
	set_process_input(true)
	_check_nodes()
	if text_label:
		text_label.bbcode_enabled = true
	_reset_all_characters()


## ตรวจว่า node ที่จำเป็นครบไหม บอกชื่อที่หายให้ชัดตอนเริ่ม
## ดีกว่าปล่อยให้ไปพังตอนกลางบทสนทนาแล้วไม่รู้ว่าเพราะอะไร
func _check_nodes() -> void:
	if name_label == null:
		push_error("dialogue_system: ไม่พบ Root/Box/NamePlate/NameLabel")
	if text_label == null:
		push_error("dialogue_system: ไม่พบ Root/Box/TextPanel/TextLabel")
	if portraits == null:
		push_warning("dialogue_system: ไม่พบ Root/Portraits — สลับโหมดมีรูป/ไม่มีรูปจะไม่ทำงาน")
	for char_name in characters.keys():
		if characters[char_name] == null:
			push_warning("dialogue_system: ไม่พบรูปของ '%s' ใต้ Root/Portraits" % char_name)


# ==============================================
# เริ่ม / จบ บทสนทนา
# ==============================================

## เริ่มบทสนทนา
## show_portraits = false -> โหมดข้อความล้วน ไม่โชว์รูปตัวละคร
## (ใช้กับเสียงบรรยาย เสียงประกาศ หรือคนที่ยังไม่มีรูป)
func start_dialogue(lines: Array, npc = null, show_portraits: bool = true):
	if is_talking:
		return
	if lines.is_empty():
		return

	current_npc = npc
	dialogue_queue = lines
	index = 0
	is_talking = true
	visible = true

	if portraits:
		portraits.visible = show_portraits

	_set_player_can_move(false)
	show_line()


func end_dialogue():
	if current_npc:
		current_npc.reset_direction()
		current_npc = null

	is_talking = false
	visible = false
	_set_player_can_move(true)
	dialogue_queue.clear()
	index = 0
	# จบบทสนทนาแล้วล้างอารมณ์ทิ้ง บทถัดไปเริ่มจากศูนย์
	# (การค้างอารมณ์มีผลแค่ "ภายในบทสนทนาเดียวกัน")
	_reset_all_characters()


## ล็อก/ปลดล็อกการเดินของผู้เล่น
## หาสดทุกครั้งและเช็ค null เพราะบางซีนไม่มีผู้เล่นให้เดิน
## เช่นฉากบนรถเมล์ที่เป็นบทพูดอัตโนมัติตามเนื้อเรื่อง
## ถ้าไม่เช็ค บทพูดอัตโนมัติในซีนเหล่านั้นจะ crash ทันที
func _set_player_can_move(value: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and "can_move" in player:
		player.can_move = value


# ==============================================
# แสดงบทพูดทีละบรรทัด
# ==============================================

func show_line():
	if text_label == null:
		return

	var line: Dictionary = dialogue_queue[index]
	var speaker: String = line.get("name", "")

	if name_label:
		name_label.text = speaker
	text_label.text = line.get("text", "")
	text_label.visible_ratio = 0.0

	update_character_focus(speaker, line.get("anim", default_anim))

	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(
		text_label,
		"visible_ratio",
		1.0,
		text_label.text.length() * typing_speed
	)


func _input(event):
	if !is_talking or text_label == null:
		return
	if !event.is_action_pressed("interact"):
		return

	# ยังพิมพ์ไม่จบ -> กดครั้งแรกข้ามการพิมพ์
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


# ==============================================
# ไฮไลต์คนที่กำลังพูด
# ==============================================

## คนพูด    : สว่างเต็ม + ขยาย + เล่นอนิเมชันที่บรรทัดนั้นกำหนด
## คนไม่พูด : ย่อลง + มืดลง แต่ "ไม่แตะอนิเมชัน"
##
## ⭐ จุดสำคัญ: ไม่เรียก play() กับคนที่ไม่ได้พูด
## อารมณ์จึงค้างไว้เองโดยไม่ต้องเขียนระบบจำสถานะเพิ่ม
## ถ้าพี่วาวาโกรธแล้วน้ำฟ้าพูดตอบ พี่วาวาจะยังโกรธค้าง (แค่หมองลงและย่อลง)
## จนกว่าจะมีบรรทัดของเธอสั่งเปลี่ยนอนิเมชัน
func update_character_focus(active_name: String, anim_name: String) -> void:
	var tw := create_tween().set_parallel(true)
	var found := false

	for char_name in characters.keys():
		var sprite: AnimatedSprite2D = characters[char_name]
		if sprite == null:
			continue

		if char_name == active_name:
			found = true
			tw.tween_property(sprite, "modulate", color_active, focus_time)
			tw.tween_property(sprite, "scale", Vector2.ONE * scale_active * base_scale, focus_time)
			_play_anim(sprite, char_name, anim_name)
		else:
			tw.tween_property(sprite, "modulate", color_idle, focus_time)
			tw.tween_property(sprite, "scale", Vector2.ONE * scale_idle * base_scale, focus_time)
			# ไม่เรียก play() ตรงนี้ - ปล่อยให้อนิเมชันเดิมค้างไว้

	if not found and active_name != "":
		push_warning("dialogue_system: ไม่พบตัวละคร '%s' ในรายการ characters — ไม่มีรูปไหนถูกไฮไลต์" % active_name)


## เล่นอนิเมชัน ถ้าไม่มีชื่อนั้นให้ถอยไปใช้ default_anim แล้วเตือนพร้อมบอกชื่อที่ผิด
##
## จำเป็นมาก เพราะจะพิมพ์ชื่ออนิเมชันเป็นร้อยครั้งตอนเขียนบท พิมพ์ผิดแน่นอน
## ถ้าไม่มีตัวกันไว้ รูปจะค้างแบบไม่มีอะไรบอกว่าผิดที่บรรทัดไหนในบทที่ยาวเป็นร้อยบรรทัด
func _play_anim(sprite: AnimatedSprite2D, char_name: String, anim_name: String) -> void:
	if sprite.sprite_frames == null:
		push_warning("dialogue_system: ตัวละคร '%s' ยังไม่มี SpriteFrames" % char_name)
		return

	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		return

	push_warning("dialogue_system: ตัวละคร '%s' ไม่มีอนิเมชัน '%s' — เล่น '%s' แทน" \
		% [char_name, anim_name, default_anim])
	if sprite.sprite_frames.has_animation(default_anim):
		sprite.play(default_anim)


## คืนทุกตัวละครเป็นสภาพเริ่มต้น (หมอง ย่อ เล่น idle)
func _reset_all_characters() -> void:
	for char_name in characters.keys():
		var sprite: AnimatedSprite2D = characters[char_name]
		if sprite == null:
			continue
		sprite.modulate = color_idle
		sprite.scale = Vector2.ONE * scale_idle * base_scale
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
