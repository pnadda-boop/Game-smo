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

## ส่งเมื่อบทสนทนาจบ - ใช้ต่อคิวเหตุการณ์ถัดไปตามเนื้อเรื่อง
signal dialogue_finished

var dialogue_queue: Array = []
var index := 0
var is_talking := false
var tween: Tween
var current_npc = null

@export var typing_speed: float = 0.05

## เสียงพิมพ์ระหว่างตัวอักษรทยอยขึ้น
##
## ⚠️ ไฟล์นี้เป็น "เสียงพิมพ์ต่อเนื่องยาว" (keyboard.mp3 ≈ 19 วินาที)
## จึงเล่นครั้งเดียวตอนเริ่มพิมพ์ แล้วหยุดตอนพิมพ์จบ
## ห้ามใช้ Timer สั่ง play() ซ้ำเป็นจังหวะ เพราะจะได้ยินแค่เศษเสี้ยวแรกของไฟล์วนไปเรื่อย ๆ
## (และ mp3 มักมีความเงียบต้นไฟล์จากการเข้ารหัส = ไม่ได้ยินอะไรเลย)
@export var typing_sound: AudioStream = preload("res://soud_effects/keyboard.mp3")
@export var typing_sound_volume_db: float = -8.0
## สุ่มระดับเสียงเล็กน้อยในแต่ละบรรทัด กันฟังซ้ำเดิมทุกครั้ง
@export var typing_sound_pitch_variation: float = 0.08

## อนิเมชันที่ใช้เมื่อบรรทัดนั้นไม่ระบุคีย์ anim
@export var default_anim: String = "talk"

## โชว์เฉพาะรูปของคนที่มีบทพูดในบทสนทนานั้น
##
## เดิม `portraits.visible = true` โชว์ตัวละคร**ทุกตัว**ที่มีใน Root/Portraits พร้อมกัน
## บทที่มีคนพูดคนเดียวจึงมีรูปคนอื่นอีก 3 คนยืนหมอง ๆ อยู่ด้วยโดยไม่มีเหตุผล
## เปิดค่านี้ = ดูจากคีย์ "name" ในบททั้งชุด แล้วซ่อนคนที่ไม่ได้อยู่ในฉากนั้น
##
## ปิดเป็น false ถ้าอยากให้ทุกคนอยู่ในเฟรมตลอด (เช่นฉากประชุมที่ทุกคนนั่งอยู่จริง)
@export var only_show_speakers: bool = true

## หน้าตาของคนที่กำลังพูด vs คนที่ไม่ได้พูด - ปรับได้ที่ Inspector
@export var color_active: Color = Color.WHITE
@export var color_idle: Color = Color(0.35, 0.35, 0.35, 1.0)
@export var base_scale: float = 2.5     ## ขนาดพื้นฐานของรูปตัวละคร
@export var scale_active: float = 1.05  ## คนพูด ขยายขึ้นเล็กน้อย
@export var scale_idle: float = 0.9     ## คนไม่พูด ย่อลง
@export var focus_time: float = 0.2     ## เวลาที่ใช้เปลี่ยนสี/ขนาด

## ใช้ get_node_or_null ทั้งหมด เพื่อให้เปลี่ยนชื่อ/ย้าย node ใน editor แล้ว
## ได้ข้อความบอกชัดว่า node ไหนหาไม่เจอ ไม่ใช่ crash แบบไม่รู้สาเหตุ
@onready var name_plate: Control = get_node_or_null("Root/Box/NamePlate")
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


var _typing_player: AudioStreamPlayer = null


func _ready():
	visible = false
	set_process_input(true)
	_setup_typing_sound()
	_check_nodes()
	if text_label:
		text_label.bbcode_enabled = true
	_reset_all_characters()


## สร้างตัวเล่นเสียงพิมพ์จากโค้ด ไม่ต้องเพิ่ม node ในซีน
func _setup_typing_sound() -> void:
	_typing_player = AudioStreamPlayer.new()
	_typing_player.stream = typing_sound
	_typing_player.volume_db = typing_sound_volume_db
	add_child(_typing_player)


## เริ่มเสียงพิมพ์ - เล่นไฟล์ต่อเนื่องครั้งเดียว
func _start_typing_sound() -> void:
	if _typing_player == null or typing_sound == null:
		return
	_typing_player.pitch_scale = 1.0 + randf_range(-typing_sound_pitch_variation, typing_sound_pitch_variation)
	_typing_player.play()


## หยุดเสียงพิมพ์ - ต้องเรียกให้ครบทุกทางที่การพิมพ์จบลง
## ไม่งั้นเสียงจะดังค้างต่อไปอีก 19 วินาทีหลังข้อความขึ้นครบแล้ว
func _stop_typing_sound() -> void:
	if _typing_player:
		_typing_player.stop()


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
	if show_portraits:
		_apply_portrait_cast(lines)

	_set_player_can_move(false)
	show_line()


## เลือกว่าจะเอารูปใครขึ้นจอบ้างในบทสนทนาชุดนี้
##
## ไล่หาคีย์ "name" ทุกบรรทัดก่อนเริ่มเล่น ไม่ใช่ทยอยโชว์ทีละคนตอนถึงคิว
## เพราะถ้าโผล่มากลางบทจะดูเหมือนตัวละครวาร์ปเข้าฉาก - ต้องยืนรออยู่แล้วตั้งแต่ต้น
##
## ⚠️ ชื่อใน "name" ต้องตรงกับคีย์ใน characters เป๊ะ ถ้าสะกดไม่ตรงจะไม่มีรูปไหนขึ้นเลย
## (update_character_focus จะเตือนให้อีกทีตอนถึงบรรทัดนั้น)
func _apply_portrait_cast(lines: Array) -> void:
	var cast := {}
	if only_show_speakers:
		for line in lines:
			var speaker: String = line.get("name", "")
			if speaker != "":
				cast[speaker] = true

	for char_name in characters.keys():
		var sprite: AnimatedSprite2D = characters[char_name]
		if sprite == null:
			continue
		## ปิดตัวเลือกนี้ = ทุกคนขึ้นหมดเหมือนเดิม
		sprite.visible = (not only_show_speakers) or cast.has(char_name)


func end_dialogue():
	if current_npc:
		current_npc.reset_direction()
		current_npc = null

	# ฆ่า tween ค้างก่อน กัน callback ของคีย์ "hold" ยิงหลังจบไปแล้ว
	if tween:
		tween.kill()
		tween = null
	_stop_typing_sound()

	is_talking = false
	visible = false
	_set_player_can_move(true)
	dialogue_queue.clear()
	index = 0
	# จบบทสนทนาแล้วล้างอารมณ์ทิ้ง บทถัดไปเริ่มจากศูนย์
	# (การค้างอารมณ์มีผลแค่ "ภายในบทสนทนาเดียวกัน")
	_reset_all_characters()

	dialogue_finished.emit()


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
	## ไม่ระบุ "name" = ซ่อนป้ายชื่อทั้งอัน (ใช้กับความคิดในใจ / เสียงบรรยาย)
	## ถ้าไม่ซ่อน จะเหลือกล่องเปล่า ๆ ลอยอยู่เหนือกล่องข้อความ
	if name_plate:
		name_plate.visible = speaker != ""

	text_label.text = line.get("text", "")
	text_label.visible_ratio = 0.0

	update_character_focus(speaker, line.get("anim", default_anim))

	if tween:
		tween.kill()

	_start_typing_sound()

	tween = create_tween()
	tween.tween_property(
		text_label,
		"visible_ratio",
		1.0,
		text_label.text.length() * typing_speed
	)
	## หยุดเสียงทันทีที่พิมพ์จบ ต่อท้าย property tween เลย
	## (tween ทำงานเรียงลำดับ ตัวนี้จึงยิงหลังพิมพ์เสร็จพอดี ก่อน "hold" ที่ต่อทีหลัง)
	tween.tween_callback(_stop_typing_sound)

	## บรรทัดที่มีคีย์ "hold" จะไปต่อเองหลังพิมพ์จบแล้วค้างไว้ตามเวลาที่กำหนด
	## ใช้กับบทพูดอัตโนมัติตามเนื้อเรื่องที่ไม่ต้องให้ผู้เล่นกด E
	## ผู้เล่นยังกด E เพื่อข้ามได้ (การกดจะ kill tween นี้ทิ้ง กันเลื่อนซ้อนกัน)
	if line.has("hold"):
		tween.tween_interval(float(line["hold"]))
		tween.tween_callback(_advance)


func _input(event):
	if !is_talking or text_label == null:
		return
	if !event.is_action_pressed("interact"):
		return

	# ยังพิมพ์ไม่จบ -> กดครั้งแรกข้ามการพิมพ์
	if text_label.visible_ratio < 1.0:
		if tween:
			tween.kill()
		# ต้องหยุดเสียงเองตรงนี้ เพราะ kill() ทำให้ callback ที่ต่อไว้ไม่ทำงาน
		_stop_typing_sound()
		text_label.visible_ratio = 1.0
		return

	_advance()


## ไปบรรทัดถัดไป หรือจบถ้าหมดแล้ว
## แยกออกมาเพราะถูกเรียกจาก 2 ทาง: ผู้เล่นกด E และ tween ของคีย์ "hold"
func _advance() -> void:
	if not is_talking:
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

	var resolved := _resolve_anim_name(sprite.sprite_frames, char_name, anim_name)
	if resolved != "":
		sprite.play(resolved)
		return

	push_warning("dialogue_system: ตัวละคร '%s' ไม่มีอนิเมชัน '%s' — เล่น '%s' แทน" \
		% [char_name, anim_name, default_anim])

	var fallback := _resolve_anim_name(sprite.sprite_frames, char_name, default_anim)
	if fallback != "":
		sprite.play(fallback)


## หาชื่ออนิเมชันจริงใน SpriteFrames คืน "" ถ้าไม่มีจริง ๆ
##
## ลองตามลำดับ:
##   1. ตรงเป๊ะ
##   2. ตัดช่องว่างหัวท้ายแล้วเทียบ  — กันชื่อแบบ " phone" ที่มีช่องว่างแอบอยู่
##   3. ไม่สนตัวพิมพ์เล็กใหญ่        — กันกรณี "Angry" vs "angry"
##
## ⚠️ ทั้งสองกรณี "มองไม่เห็น" หรือ "มองข้ามง่าย" ใน editor
## ถ้าไม่มีตัวช่วยนี้ อนิเมชันจะไม่เล่นแบบเงียบ ๆ แล้วไล่หาสาเหตุยากมาก
## แต่ยังเตือนทุกครั้งที่ต้องพึ่งข้อ 2-3 เพื่อให้ไปแก้ที่ต้นเหตุได้
func _resolve_anim_name(frames: SpriteFrames, char_name: String, wanted: String) -> String:
	if frames == null or wanted == "":
		return ""

	if frames.has_animation(wanted):
		return wanted

	var target := wanted.strip_edges()
	var names := frames.get_animation_names()

	for n in names:
		if String(n).strip_edges() == target:
			push_warning("dialogue_system: '%s' มีอนิเมชัน '%s' ที่มีช่องว่างเกินมา (บทเขียน '%s') — ควรแก้ชื่อใน SpriteFrames" \
				% [char_name, n, wanted])
			return n

	for n in names:
		if String(n).strip_edges().to_lower() == target.to_lower():
			push_warning("dialogue_system: '%s' ใช้ชื่อ '%s' แต่บทเขียน '%s' — ตัวพิมพ์เล็กใหญ่ไม่ตรงกัน ควรทำให้เหมือนกัน" \
				% [char_name, n, wanted])
			return n

	return ""


## คืนทุกตัวละครเป็นสภาพเริ่มต้น (หมอง ย่อ เล่น idle)
func _reset_all_characters() -> void:
	for char_name in characters.keys():
		var sprite: AnimatedSprite2D = characters[char_name]
		if sprite == null:
			continue
		sprite.modulate = color_idle
		sprite.scale = Vector2.ONE * scale_idle * base_scale
		## คืนสถานะให้ครบ รวมถึงการมองเห็น
		## ไม่งั้นบทถัดไปที่ปิด only_show_speakers จะยังมีคนหายอยู่จากบทก่อน
		sprite.visible = true
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
