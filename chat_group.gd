extends Control
## ==============================================
## ห้องแชทหนึ่งกลุ่ม
## ==============================================
## ติดสคริปต์นี้ที่ node ราก (Control) ของ Chat_group.tscn
##
## แต่ละ instance = หนึ่งกลุ่ม ตั้ง group_id ที่ Inspector ให้ตรงกับคีย์ใน ChatDatabase.GROUPS
## ชื่อกลุ่ม / ไอคอน / จำนวนคน / บทแชท ดึงจากทะเบียนทั้งหมด ไม่ต้องกรอกในซีน
##
## โครงสร้าง node ที่สคริปต์นี้ใช้ (อ้างจากตัวเอง):
##   ScrollContainer/MessageList        VBoxContainer  ที่เก็บบับเบิล (ต้องว่างเปล่า)
##   Header/VBoxContainer/Avatar        TextureRect    ไอคอนกลุ่ม
##   Header/VBoxContainer/Label         Label          ชื่อกลุ่ม
##   Header/VBoxContainer/Label2        Label          "N online"
##   Header/TextureButton               TextureButton  ปุ่มย้อนกลับ
##   Down/InputBar/{LineEdit,SendButton}               แถบพิมพ์ (ของประดับ)
##
## ⚠️ ตัวเลือกคำตอบ "ไม่ต้องสร้าง node ในซีน" - สคริปต์สร้างเองตอนเรียกใช้
##    แล้วลบทิ้งเมื่อผู้เล่นเลือกเสร็จ ปรับหน้าตาได้จาก @export กลุ่ม "ตัวเลือกคำตอบ"

## ส่งเมื่อเล่นบทแชทจนจบ
signal chat_finished
## ส่งเมื่อผู้เล่นเลือกตัวเลือกตอบ (index เริ่มจาก 0)
signal choice_selected(index: int)
## ส่งเมื่อผู้เล่นกดปุ่มย้อนกลับ - phone.gd รับไปสลับกลับหน้ารายการแชท
signal back_pressed

const MESSAGE_BUBBLE := preload("res://message_bubble.tscn")
## ฟอนต์เดียวกับที่ใช้ทั้งหน้าจอแชท - ถ้าไม่ตั้ง Label ที่สร้างจากโค้ดจะใช้ฟอนต์ default ของ Godot
## แล้วตัวคั่นเวลาจะดูหลุดจากงานที่เหลือทันที
const DIVIDER_FONT := preload("res://font/2005_iannnnnAMD.ttf")

## กลุ่มไหน - ต้องตรงกับคีย์ใน ChatDatabase.GROUPS
@export var group_id: String = "smo"

## หน้าตาของตัวคั่นเวลา
@export var divider_font_size: int = 38
@export var divider_color: Color = Color(1, 1, 1, 0.45)

## ระยะห่างระหว่างข้อความแต่ละอัน (พิกเซล)
## ค่าเริ่มต้นของ VBoxContainer คือ 4 ซึ่งอัดกันแน่นเกินไปสำหรับแชท
@export var message_spacing: int = 28

## หน่วงเวลาระหว่างข้อความใน play_chat()
@export var delay_base: float = 0.6
@export var delay_per_char: float = 0.02
@export var delay_max: float = 2.5

## ข้อความที่แสดงในบับเบิล "กำลังพิมพ์"
@export var typing_text: String = "..."
## เวลาที่ค้าง "กำลังพิมพ์" ก่อนส่งข้อความจริง - ข้อความยาวใช้เวลาพิมพ์นานกว่า
@export var typing_base: float = 1.4
@export var typing_per_char: float = 0.045
@export var typing_max: float = 4.5
## หน่วงหลังเปิดห้อง ก่อนข้อความใหม่จะเริ่มเข้ามา
@export var incoming_delay: float = 0.35

## เสียงเตือนตอนมีข้อความใหม่เข้ามา (ไฟล์เดียวกับตอนน้ำฟ้าเพิ่งตื่นใน wokeup)
##
## ดังเฉพาะข้อความที่ "เข้ามาสด" จากคนอื่นเท่านั้น
## ไม่ดังกับ: ประวัติเก่า (load_history) และข้อความที่น้ำฟ้าส่งเอง - ไม่มีใครเตือนตัวเอง
## ปิดเป็นรายบรรทัดได้ด้วยคีย์ "sound": false
@export var notify_sound: AudioStream = preload("res://soud_effects/notification.mp3")
@export_range(-40.0, 12.0) var notify_volume_db: float = -4.0

## --- ตัวเลือกคำตอบ ---
## ตัวเลือกโผล่ที่ท้ายรายการข้อความ ชิดขวาเหมือนข้อความของน้ำฟ้า
## เลือกแล้วตัวที่กดจะกลายเป็นข้อความจริง ตัวอื่นหายไปทั้งหมด
@export_group("ตัวเลือกคำตอบ")
## กว้างสุดของปุ่ม - เท่ากับ max_width ของบับเบิลเพื่อให้แนวเดียวกัน
@export var choice_max_width: float = 420.0
## ฟอนต์ของปุ่มตัวเลือก - ปล่อย null = ใช้ฟอนต์เดียวกับทั้งเกม (2005_iannnnnAMD.ttf)
@export var choice_font: Font = null
@export var choice_font_size: int = 34
## พื้นหลังโปร่ง + ขอบสีม่วง = ดูออกว่ากดได้ ต่างจากบับเบิลข้อความที่ส่งไปแล้ว
@export var choice_bg: Color = Color(0.06, 0.06, 0.06, 0.6)
@export var choice_border: Color = Color(0.33733332, 0.29000002, 1, 1)
@export var choice_text_color: Color = Color(1, 1, 1, 1)
## สีตอนเอาเมาส์ชี้ - ทึบขึ้นเพื่อบอกว่ากำลังจะกดอันนี้
@export var choice_hover_bg: Color = Color(0.33733332, 0.29000002, 1, 1)
## ระยะขอบในปุ่ม — ขอบกล่องถึงตัวอักษร (เดิม hardcode ไว้ที่ 16 / 10)
##
## ⚠️ `_make_choice_button()` บวก `choice_padding_h * 2` เข้าไปในความกว้างที่ปักไว้ด้วย
## ปุ่มเปิด autowrap ซึ่งมี minimum width เกือบศูนย์ — ไม่บวกเผื่อ ข้อความจะตกบรรทัดเร็วกว่าที่ควร
@export var choice_padding_h: float = 16.0
@export var choice_padding_v: float = 10.0
## เวลาที่ตัวเลือกค่อย ๆ จางเข้ามา
@export var choice_fade_time: float = 0.25
@export_group("")

var scroll: ScrollContainer = null
var message_list: VBoxContainer = null
var group_label: Label = null
var online_label: Label = null
var group_avatar: TextureRect = null
var back_button: BaseButton = null
var input_bar: Container = null
var line_edit: LineEdit = null
var send_button: Button = null
## กล่องตัวเลือกที่กำลังแสดงอยู่ (สร้างตอนเรียก show_choices แล้วลบทิ้งเมื่อเลือกเสร็จ)
var _choice_box: VBoxContainer = null
## ตัวเล่นเสียงเตือน - สร้างจากโค้ดเพื่อไม่ต้องเพิ่ม node ในซีน
var _notify_player: AudioStreamPlayer = null

## ใช้จัดกลุ่มข้อความที่ติดกันจากคนเดิม (สไตล์ Messenger)
## ชื่อขึ้นที่ข้อความแรกของชุด รูปโปรไฟล์ขึ้นที่ข้อความสุดท้ายของชุด
var _last_sender: String = ""
var _last_bubble: Node = null
## บับเบิล "กำลังพิมพ์" ที่กำลังแสดงอยู่ (ถ้ามี)
var _typing_bubble: Node = null
## โหลดบทไปแล้วหรือยัง - กันโหลดซ้ำเวลาสลับกลับเข้ามาดูห้องเดิม
var _loaded := false


func _ready() -> void:
	_resolve_nodes()

	if message_list == null:
		push_error("chat_group.gd [%s]: ไม่พบ VBoxContainer ใต้ ScrollContainer" % group_id)
		return

	_setup_scroll()
	_setup_input_bar()
	_setup_back_button()
	_setup_notify_player()
	clear_messages()
	apply_group_info()


## หา node ที่ต้องใช้ทั้งหมด อ้างจากตัวเอง (ไม่ใช่จาก Chat.tscn)
func _resolve_nodes() -> void:
	scroll = get_node_or_null("ScrollContainer")
	group_avatar = get_node_or_null("Header/VBoxContainer/Avatar")
	group_label = get_node_or_null("Header/VBoxContainer/Label")
	online_label = get_node_or_null("Header/VBoxContainer/Label2")
	back_button = get_node_or_null("Header/TextureButton")
	input_bar = get_node_or_null("Down/InputBar")
	line_edit = get_node_or_null("Down/InputBar/LineEdit")
	send_button = get_node_or_null("Down/InputBar/SendButton")
	message_list = _find_message_list()


## ใส่ชื่อกลุ่ม ไอคอน และจำนวนคน จากทะเบียน
## เรียกซ้ำได้ - ถ้าเปลี่ยน group_id แล้วเรียกใหม่ หัวจะอัปเดตตาม
func apply_group_info() -> void:
	var info := ChatDatabase.get_group(group_id)
	if info.is_empty():
		return

	if group_label:
		group_label.text = info.get("name", group_id)
	if online_label:
		online_label.text = "%d online" % ChatDatabase.group_member_count(group_id)
	## icon = null แปลว่ายังไม่มีไอคอนกลุ่มนี้ -> ไม่เขียนทับรูปที่ตั้งไว้ในซีน
	if group_avatar and info.get("icon") != null:
		group_avatar.texture = info["icon"]


## โหลดบทของกลุ่มนี้จากทะเบียน แล้วปล่อยข้อความใหม่เข้ามา
## เรียกซ้ำได้ปลอดภัย - โหลดแค่ครั้งแรกครั้งเดียว
func open() -> void:
	if _loaded:
		return
	_loaded = true

	await load_history(ChatDatabase.get_history(group_id))

	var incoming := ChatDatabase.get_incoming(group_id)
	if incoming.is_empty():
		## ⚠️ ต้องยิง chat_finished ถึงแม้ไม่มีข้อความใหม่
		## ห้องที่มีแต่ประวัติเก่าก็ถือว่า "เล่าบทจบแล้ว" เหมือนกัน
		## ถ้าไม่ยิง กลุ่มที่รอเด้งต่อจากห้องนี้ (phone.gd) จะไม่โผล่มาเลย
		chat_finished.emit()
		return

	await get_tree().create_timer(incoming_delay).timeout
	await receive_messages(incoming)


# ==============================================
# ตั้งค่า node
# ==============================================

## 1) ปิดการเลื่อนแนวนอน - แชทเลื่อนขึ้นลงอย่างเดียว
##    ถ้าไม่ปิด บับเบิลที่กว้างเกินจะทำให้มี scrollbar ล่างโผล่มา
## 2) ให้ MessageList กว้างเต็ม ScrollContainer
##    ถ้าไม่ตั้ง VBox จะหดเท่าบับเบิลที่กว้างที่สุด แล้วข้อความฝั่งขวาจะไม่ชิดขวาจริง
## 3) เว้นระยะระหว่างข้อความ ให้อ่านง่ายขึ้น
func _setup_scroll() -> void:
	if scroll:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if message_list:
		message_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		message_list.add_theme_constant_override("separation", message_spacing)


## ตั้งแถบพิมพ์ให้เป็น "ของประดับ" - ผู้เล่นพิมพ์เองไม่ได้
## ตอนต้องให้ผู้เล่นตอบจริง จะใช้ show_choices() แสดงปุ่มตัวเลือกแทน
##
## ⚠️ ห้ามตั้ง line_edit.editable = false
## LineEdit ที่ editable = false จะสลับไปใช้ StyleBox ชื่อ "read_only" ไม่ใช่ "normal"
## สไตล์แคปซูลมนที่ตั้งไว้จะหายตอนรัน แล้วหน้าตาไม่ตรงกับที่เห็นใน editor
func _setup_input_bar() -> void:
	if line_edit:
		line_edit.focus_mode = Control.FOCUS_NONE
		line_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if send_button:
		send_button.focus_mode = Control.FOCUS_NONE
		send_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _setup_back_button() -> void:
	if back_button:
		back_button.pressed.connect(func(): back_pressed.emit())


func _setup_notify_player() -> void:
	if notify_sound == null:
		return
	_notify_player = AudioStreamPlayer.new()
	_notify_player.stream = notify_sound
	_notify_player.volume_db = notify_volume_db
	add_child(_notify_player)


## เล่นเสียงเตือน - ตัดเสียงเดิมทิ้งถ้ายังดังค้างอยู่
## ข้อความที่มาติด ๆ กันจะได้ยินเป็นจังหวะแยกกัน ไม่ทับกันจนฟังเป็นเสียงเดียว
func _play_notify() -> void:
	if _notify_player == null:
		return
	_notify_player.stop()
	_notify_player.play()


## หา MessageList แบบยืดหยุ่น รับชื่ออื่นได้แต่จะเตือนให้เปลี่ยนชื่อ
func _find_message_list() -> VBoxContainer:
	if scroll == null:
		return null

	var wanted := scroll.get_node_or_null("MessageList")
	if wanted is VBoxContainer:
		return wanted

	for child in scroll.get_children():
		if child is VBoxContainer:
			push_warning("chat_group.gd [%s]: ใช้ '%s' เป็นที่เก็บข้อความ — ควรเปลี่ยนชื่อเป็น 'MessageList' เพื่อไม่ให้สับสนกับตัวบับเบิล" \
				% [group_id, child.name])
			return child
	return null


# ==============================================
# แสดงข้อความ
# ==============================================

## โหลดประวัติที่มีอยู่ก่อนแล้ว - ขึ้นครบทันที ไม่มีหน่วง
##
## บรรทัด {"choices": [...]} ในประวัติจะถูกข้าม เพราะประวัติคือเรื่องที่ผ่านไปแล้ว
## ผู้เล่นเลือกไปแล้วในอดีต ไม่ควรเด้งให้เลือกซ้ำตอนเปิดห้องดูย้อนหลัง
func load_history(lines: Array) -> void:
	if message_list == null:
		return

	for line in lines:
		if line.has("time"):
			add_time_divider(line["time"])
			continue
		if line.has("choices"):
			continue
		_add_bubble(line["sender"], line["text"], line.get("image", null))

	## เลื่อนลงล่างสุดครั้งเดียวตอนจบ เริ่มที่ข้อความล่าสุดเหมือนแอปแชทจริง
	await _scroll_to_bottom()


## รับข้อความใหม่แบบสด - แสดงบับเบิล "กำลังพิมพ์" ก่อนแล้วค่อยส่งข้อความจริง
func receive_messages(lines: Array) -> void:
	await _play_lines(lines, true)
	chat_finished.emit()


## เล่นบทแบบทยอยขึ้นทีละข้อความ (ไม่มีบับเบิลกำลังพิมพ์)
func play_chat(lines: Array) -> void:
	await _play_lines(lines, false)
	chat_finished.emit()


## แกนกลางที่ receive_messages / play_chat / บทตามหลังตัวเลือก ใช้ร่วมกัน
##
## แยกออกมาเพราะบทที่ตามหลังตัวเลือก ("then") ต้องเล่นด้วยกฎเดียวกันเป๊ะ
## แต่ต้องไม่ยิง chat_finished ซ้ำกลางทาง - ผู้เรียกด้านนอกเป็นคนยิงเองครั้งเดียว
##
## live = true  -> มีบับเบิล "กำลังพิมพ์" นำก่อน (ข้อความที่เข้ามาสด)
## live = false -> ขึ้นเลยแล้วหน่วงสั้น ๆ ต่อ (เล่าบทย้อนหลังให้ดูมีจังหวะ)
func _play_lines(lines: Array, live: bool) -> void:
	if message_list == null:
		return

	for line in lines:
		if line.has("time"):
			add_time_divider(line["time"])
			continue

		## ถึงคิวผู้เล่นตอบ - หยุดรอจนกว่าจะกดเลือก
		if line.has("choices"):
			await show_choices(line["choices"])
			continue

		var text: String = line.get("text", "")
		## ใส่คีย์ "typing" ในบรรทัดนั้นเพื่อกำหนดเวลาพิมพ์เองได้ (วินาที)
		## "typing": 0 = ข้ามช่วงกำลังพิมพ์ไปเลย ข้อความเด้งมาเฉย ๆ
		var wait: float = float(line["typing"]) if line.has("typing") else _typing_duration(text)

		if live and wait > 0.0:
			await _show_typing(line["sender"])
			await get_tree().create_timer(wait).timeout
			_hide_typing()
		else:
			## ไม่มีช่วงกำลังพิมพ์ ต้องเว้นจังหวะก่อนข้อความโผล่แทน
			## ไม่งั้นข้อความติด ๆ กันจะเด้งมาพร้อมกันหมดในเฟรมเดียว อ่านไม่ทัน
			await get_tree().create_timer(_delay_for(text)).timeout

		## เสียงดังพร้อมข้อความโผล่ ไม่ใช่ตอนเริ่มพิมพ์
		if live and line.get("sound", true) and not ChatDatabase.is_right_side(line["sender"]):
			_play_notify()
		await add_message(line["sender"], text, line.get("image", null))


## เพิ่มข้อความเดียว แล้วเลื่อนจอลงล่างสุด
func add_message(sender_id: String, text: String, image: Texture2D = null) -> void:
	if message_list == null:
		return
	_add_bubble(sender_id, text, image)
	await _scroll_to_bottom()


## สร้างบับเบิลหนึ่งใบ พร้อมจัดกลุ่มข้อความที่ติดกันจากคนเดิม (สไตล์ Messenger)
##
## คนเดิมพูดต่อ -> ซ่อนชื่อของใบใหม่ และ "ย้อนกลับไป" ลบรูปของใบก่อนหน้า
## ผลคือรูปโปรไฟล์เลื่อนตามลงมาอยู่ที่ข้อความสุดท้ายของชุดเสมอ
func _add_bubble(sender_id: String, text: String, image: Texture2D = null) -> Node:
	var bubble := MESSAGE_BUBBLE.instantiate()
	## ต้อง add_child ก่อน setup เพราะ @onready ใน bubble ทำงานตอนเข้า tree
	message_list.add_child(bubble)
	bubble.setup(sender_id, text, image)

	if sender_id == _last_sender and is_instance_valid(_last_bubble):
		bubble.set_name_visible(false)
		_last_bubble.set_avatar_visible(false)

	_last_sender = sender_id
	_last_bubble = bubble
	return bubble


## แทรกตัวคั่นเวลาเป็นแถวของตัวเองกลางรายการ
func add_time_divider(text: String) -> void:
	if message_list == null:
		return

	var label := Label.new()
	## add_child ก่อนตั้ง theme override เพื่อให้ Label มี theme context ตั้งแต่ต้น
	message_list.add_child(label)

	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	## ต้อง EXPAND_FILL ไม่งั้น Label จะหดเท่าข้อความแล้วไปกองซ้ายสุด จัดกลางไม่ได้
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", DIVIDER_FONT)
	label.add_theme_font_size_override("font_size", divider_font_size)
	label.add_theme_color_override("font_color", divider_color)

	## ตัวคั่นเวลามาขวาง = ขึ้นชุดใหม่
	## ถ้าไม่รีเซ็ต คนก่อนและหลังตัวคั่นจะถูกนับเป็นชุดเดียวกัน แล้วชื่อจะไม่ขึ้น
	_last_sender = ""
	_last_bubble = null


# ==============================================
# บับเบิล "กำลังพิมพ์"
# ==============================================

## ⚠️ ไม่เรียกผ่าน _add_bubble() โดยเจตนา เพราะไม่ต้องการให้นับเข้าระบบจัดกลุ่ม
## ถ้านับ ข้อความจริงที่ตามมาจะถูกมองว่าเป็นข้อความที่ 2 ของชุด แล้วชื่อผู้ส่งจะไม่ขึ้น
func _show_typing(sender_id: String) -> void:
	_hide_typing()
	_typing_bubble = MESSAGE_BUBBLE.instantiate()
	message_list.add_child(_typing_bubble)
	_typing_bubble.setup(sender_id, typing_text)
	await _scroll_to_bottom()


func _hide_typing() -> void:
	if _typing_bubble and is_instance_valid(_typing_bubble):
		## remove_child ก่อน queue_free เพื่อให้ layout อัปเดตทันที
		## ถ้า queue_free เฉย ๆ node จะยังอยู่ในต้นไม้จนจบเฟรม
		## แล้วจะเห็นบับเบิลกำลังพิมพ์กับข้อความจริงซ้อนกันแวบหนึ่ง
		message_list.remove_child(_typing_bubble)
		_typing_bubble.queue_free()
	_typing_bubble = null


func _typing_duration(text: String) -> float:
	return minf(typing_base + text.length() * typing_per_char, typing_max)


func _delay_for(text: String) -> float:
	return minf(delay_base + text.length() * delay_per_char, delay_max)


# ==============================================
# ตัวเลือกคำตอบ
# ==============================================

## แสดงตัวเลือกให้ผู้เล่นตอบ แล้วรอจนกด - คืน index ที่เลือก (-1 ถ้าไม่มีตัวเลือก)
##
## รูปแบบที่รับได้ ผสมกันในลิสต์เดียวก็ได้:
##   "ข้อความ"                                 ตอบแล้วจบ
##   {"text": "ข้อความ", "then": [ ...บท... ]}  ตอบแล้วมีคนตอบกลับต่อ
##
## จำนวนตัวเลือกไม่จำกัด ใส่กี่อันก็ได้ในแต่ละรอบ
##
## auto_send = true (ค่าปกติ) -> ตัวที่กดกลายเป็นข้อความของน้ำฟ้าทันที
##   ตั้ง false ถ้าอยากเอา index ไปตัดสินใจเองโดยยังไม่ส่งข้อความ
func show_choices(options: Array, auto_send: bool = true) -> int:
	if message_list == null or options.is_empty():
		return -1

	## ต้องล้างของค้างก่อน กันกรณีเรียกซ้อนโดยที่รอบก่อนยังไม่จบ
	_remove_choice_box()

	_choice_box = VBoxContainer.new()
	_choice_box.name = "ChoiceBox"
	_choice_box.add_theme_constant_override("separation", 12)
	## ให้กว้างเต็มแถว ตัวลูกถึงจะดันไปชิดขวาได้
	_choice_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_list.add_child(_choice_box)

	var buttons: Array[Button] = []
	for i in options.size():
		var btn := _make_choice_button(_choice_text(options[i]))
		_choice_box.add_child(btn)
		btn.pressed.connect(_on_choice_pressed.bind(i))
		buttons.append(btn)

	## ค่อย ๆ จางเข้ามา ไม่ให้เด้งโป๊ะขึ้นมาเฉย ๆ
	_choice_box.modulate.a = 0.0
	await _scroll_to_bottom()
	create_tween().tween_property(_choice_box, "modulate:a", 1.0, choice_fade_time)

	var index: int = await choice_selected

	## ปิดทุกปุ่มทันทีที่กด กันกดรัว ๆ ได้หลายอันในเฟรมเดียวกัน
	for btn in buttons:
		btn.disabled = true
	_remove_choice_box()

	if not auto_send:
		return index

	var picked: Variant = options[index]
	await add_message("namfa", _choice_text(picked))

	## บทที่ตามหลังคำตอบนี้ - เล่นแบบสด (มีกำลังพิมพ์) เหมือนคนตอบกลับจริง
	var follow: Array = picked.get("then", []) if picked is Dictionary else []
	if not follow.is_empty():
		await _play_lines(follow, true)

	return index


## รับได้ทั้ง String ตรง ๆ และ Dictionary ที่มีคีย์ "text"
func _choice_text(option: Variant) -> String:
	if option is Dictionary:
		return str(option.get("text", ""))
	return str(option)


## ปุ่มตัวเลือกหนึ่งอัน - หน้าตาเลียนบับเบิลฝั่งขวา แต่ขอบม่วงเพื่อบอกว่ากดได้
##
## สร้างจากโค้ดทั้งหมดแทนที่จะทำเป็นซีนแยก เพราะเป็นของชั่วคราวที่โผล่มาแล้วหายไป
## ทำเป็นซีนจะต้องมานั่งตั้งค่าใน Inspector โดยที่ไม่มีใครเห็นมันตอนแก้ซีนอยู่ดี
func _make_choice_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.focus_mode = Control.FOCUS_NONE
	## ชิดขวา = อยู่แนวเดียวกับข้อความที่น้ำฟ้าส่งเอง
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	## ตั้งเป็น null ใน Inspector ได้ = ถอยไปใช้ฟอนต์กลางของเกม
	btn.add_theme_font_override("font", choice_font if choice_font else DIVIDER_FONT)
	btn.add_theme_font_size_override("font_size", choice_font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(state, choice_text_color)

	## ⚠️ ต้องปักความกว้างเอง เหมือนที่ message_bubble.gd ทำ
	## Button ที่เปิด autowrap มี minimum width เกือบเป็นศูนย์ (ตัดทีละคำได้)
	## ถ้าไม่ปัก VBox จะบีบจนปุ่มเหลือกว้างเท่าคำเดียว
	var font := btn.get_theme_font("font")
	if font:
		var widest := 0.0
		for line in text.split("\n"):
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, choice_font_size).x)
		## บวกระยะขอบซ้ายขวาของ StyleBox กลับเข้าไป (เดิมเป็นเลข 32 ตายตัว = 16 × 2)
		## อ่านจาก @export ตัวเดียวกับที่ _choice_style() ใช้ ปรับระยะขอบแล้วความกว้างตามเอง
		btn.custom_minimum_size.x = minf(widest + choice_padding_h * 2.0, choice_max_width)

	btn.add_theme_stylebox_override("normal", _choice_style(choice_bg))
	btn.add_theme_stylebox_override("hover", _choice_style(choice_hover_bg))
	btn.add_theme_stylebox_override("pressed", _choice_style(choice_hover_bg))
	btn.add_theme_stylebox_override("disabled", _choice_style(choice_bg))
	return btn


## มุมมน 20 เท่าบับเบิลข้อความ (message_bubble.tscn) ให้ดูเป็นชุดเดียวกัน
func _choice_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = choice_border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = choice_padding_h
	sb.content_margin_right = choice_padding_h
	sb.content_margin_top = choice_padding_v
	sb.content_margin_bottom = choice_padding_v
	return sb


func _on_choice_pressed(index: int) -> void:
	choice_selected.emit(index)


func _remove_choice_box() -> void:
	if _choice_box and is_instance_valid(_choice_box):
		## remove_child ก่อน queue_free เพื่อให้ layout ยุบทันที
		## ไม่งั้นจะเห็นช่องว่างค้างอยู่หนึ่งเฟรมตอนข้อความที่เลือกโผล่ขึ้นมา
		message_list.remove_child(_choice_box)
		_choice_box.queue_free()
	_choice_box = null


# ==============================================
# ล้าง / เลื่อนจอ
# ==============================================

func clear_messages() -> void:
	if message_list == null:
		return
	_choice_box = null   ## ถูกลบไปพร้อมลูกคนอื่นด้านล่าง อย่าให้เหลือ reference ค้าง
	for child in message_list.get_children():
		child.queue_free()
	## ล้างข้อความแล้วต้องล้างสถานะจับกลุ่มด้วย ไม่งั้นข้อความแรกของบทถัดไป
	## จะถูกนับว่าติดกับข้อความสุดท้ายของบทเก่าที่ลบไปแล้ว
	_last_sender = ""
	_last_bubble = null


## เลื่อนจอลงล่างสุด
## ต้องรอ 2 เฟรม: เฟรมแรก VBox คำนวณความสูงใหม่หลังเพิ่มบับเบิล
## เฟรมที่สอง scrollbar ถึงอัปเดต max_value - ถ้าเลื่อนทันทีจะได้ค่าเก่า
func _scroll_to_bottom() -> void:
	if scroll == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
