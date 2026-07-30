extends CanvasLayer
## ==============================================
## หน้าจอแชทกรุ๊ปสโม
## ==============================================
## ติดสคริปต์นี้ที่ node ราก (Phone) ของ Phone.tscn
##
## โครงสร้าง node ที่สคริปต์นี้ใช้:
##   Phone (CanvasLayer)  <- สคริปต์นี้
##   └── Control
##       ├── Header/VBoxContainer/Label2      ป้าย "N online"
##       ├── ScrollContainer
##       │   └── MessageList (VBoxContainer)  ที่เก็บบับเบิลทั้งหมด (ต้องว่างเปล่า)
##       └── Down
##           └── ChoiceContainer (VBoxContainer)
##
## วิธีใช้จากที่อื่น:
##   await $Phone.play_chat([
##       {"sender": "wawa", "text": "..."},
##   ])

## ส่งเมื่อเล่นบทแชทจนจบ
signal chat_finished
## ส่งเมื่อผู้เล่นเลือกตัวเลือกตอบ (index เริ่มจาก 0)
signal choice_selected(index: int)

const MESSAGE_BUBBLE := preload("res://message_bubble.tscn")
## ฟอนต์เดียวกับที่ใช้ทั้งหน้าจอแชท - ถ้าไม่ตั้ง Label ที่สร้างจากโค้ดจะใช้ฟอนต์ default ของ Godot
## แล้วตัวคั่นเวลาจะดูหลุดจากงานที่เหลือทันที
const DIVIDER_FONT := preload("res://font/2005_iannnnnAMD.ttf")

## หน้าตาของตัวคั่นเวลา - ปรับได้ที่ Inspector ของ node Phone
@export var divider_font_size: int = 38
@export var divider_color: Color = Color(1, 1, 1, 0.45)

## หน่วงเวลาระหว่างข้อความ ให้รู้สึกเหมือนอีกฝ่ายกำลังพิมพ์
## ข้อความยาว = หน่วงนานกว่า แต่ไม่เกิน delay_max
@export var delay_base: float = 0.6
@export var delay_per_char: float = 0.02
@export var delay_max: float = 2.5

## ระยะห่างระหว่างข้อความแต่ละอัน (พิกเซล)
## ค่าเริ่มต้นของ VBoxContainer คือ 4 ซึ่งอัดกันแน่นเกินไปสำหรับแชท
@export var message_spacing: int = 28

## เล่นบททดสอบเองตอนเปิดฉากนี้ - ใช้ดูผลระหว่างพัฒนา
## เอาไปใช้จริงในเกมแล้วให้ปิดตัวนี้ แล้วเรียก play_chat() จากข้างนอกแทน
@export var autoplay_test: bool = true

## บททดสอบ - แก้ได้ตามใจ ไม่กระทบระบบ
##
## รายการที่มีคีย์ "time" = ตัวคั่นเวลา (ไม่ใช่ข้อความ) แทรกได้ทุกจุดในบทแชท
## รายการที่มีคีย์ "sender" = ข้อความปกติ
const TEST_CHAT := [
	{
		"time": "5:30",
	},
	{
		"sender": "wawa",
		"text": "นัดหมายวันงานรับน้องพรุ่งนี้ มาเตรียมตัวก่อนเวลา 06.00 น. ที่หน้าห้องประชุมเมืองพะเยา\n- แต่งกายเสื้อสโมICT กางเกงขายาว รองเท้าผ้าใบ\n- อย่าลืมซื้อข้าวเช้ามาด้วยนะคะ!",
	},
	{
		"sender": "somsom",
		"text": "รับทราบค่ะ",
	},
	{
		"sender": "chochang",
		"text": "ใครไม่มีรถขึ้นมอ ทักมาหาพี่นะครับ",
	},
	{
		"sender": "jean",
		"text": "เดี๋ยวหนูกับเพื่อนทักไปค่ะครับ",
	},
	{
		"sender": "namking",
		"text": "อย่าลืมกินข้าวเช้ากันด้วยนะ",
	},
	{
		"sender": "namking",
		"text": "เดี๋ยวเป็นลมตอนทำกิจกรรม",
	},
	{
		"sender": "jaja",
		"text": "คนที่มาถึงแล้วแยกย้ายไปหาหัวหน้าฝ่ายของตนได้เลยค่ะ",
	},
	{
		"sender": "wawa",
		"text": "ฝ่ายสวัสดิการ เช็คข้อความในกลุ่มสวัสกันด้วยน้า",
	},
	{
		"sender": "wawa",
		"text": "เผื่อพี่มอบหมายงานให้",
	},
]

@onready var scroll: ScrollContainer = get_node_or_null("Control/ScrollContainer")
@onready var online_label: Label = get_node_or_null("Control/Header/VBoxContainer/Label2")
## แถบพิมพ์ข้อความล่างจอ - อยู่ตลอดเวลา
@onready var input_bar: Container = get_node_or_null("Control/Down/InputBar")
@onready var line_edit: LineEdit = get_node_or_null("Control/Down/InputBar/LineEdit")
@onready var send_button: Button = get_node_or_null("Control/Down/InputBar/SendButton")

## ปุ่มตัวเลือกคำตอบ - โผล่มาแล้วหายไปเมื่อเลือกเสร็จ
## ต้องแยก node กับ InputBar เพราะ clear_choices() ลบลูกทุกตัวทิ้ง
## ถ้าอยู่รวมกัน LineEdit กับ SendButton จะโดนลบไปด้วย
@onready var choice_container: Container = get_node_or_null("Control/ChoiceContainer")

var message_list: VBoxContainer = null

## ใช้จัดกลุ่มข้อความที่ติดกันจากคนเดิม (สไตล์ Messenger)
## ชื่อขึ้นที่ข้อความแรกของชุด รูปโปรไฟล์ขึ้นที่ข้อความสุดท้ายของชุด
var _last_sender: String = ""
var _last_bubble: Node = null


func _ready() -> void:
	message_list = _find_message_list()
	if message_list == null:
		push_error("phone.gd: ไม่พบ VBoxContainer ใต้ Control/ScrollContainer — ต้องมี node ชื่อ MessageList")
		return

	## ป้ายจำนวนคนออนไลน์ นับจากทะเบียนจริง ไม่ต้องมาแก้มือเวลาเพิ่มคน
	if online_label:
		online_label.text = "%d online" % ChatDatabase.online_count()

	_setup_scroll()
	_setup_input_bar()
	clear_messages()
	if choice_container:
		choice_container.hide()

	if autoplay_test:
		load_history(TEST_CHAT)


## ตั้งค่า ScrollContainer ให้เลื่อนได้ถูกต้อง
## 1) ปิดการเลื่อนแนวนอน - แชทเลื่อนขึ้นลงอย่างเดียว
##    ถ้าไม่ปิด บับเบิลที่กว้างเกินจะทำให้มี scrollbar ล่างโผล่มา
## 2) ให้ MessageList กว้างเต็ม ScrollContainer
##    ถ้าไม่ตั้ง VBox จะหดเท่าบับเบิลที่กว้างที่สุด แล้วข้อความฝั่งขวาจะไม่ชิดขวาจริง
##    เพราะไม่เหลือที่ว่างให้ดัน
## 3) เว้นระยะระหว่างข้อความ ให้อ่านง่ายขึ้น
func _setup_scroll() -> void:
	if scroll:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if message_list:
		message_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		message_list.add_theme_constant_override("separation", message_spacing)


## ตั้งแถบพิมพ์ให้เป็น "ของประดับ" - ผู้เล่นพิมพ์เองไม่ได้
##
## มีไว้ให้หน้าจอดูเหมือนแอปแชทจริงเท่านั้น
## ตอนต้องให้ผู้เล่นตอบจริง จะใช้ show_choices() แสดงปุ่มตัวเลือกแทน
##
## ใช้ MOUSE_FILTER_IGNORE แทน disabled = true เพราะ disabled จะทำให้ปุ่ม
## จางลงดูเหมือน "ใช้ไม่ได้ชั่วคราว" แต่เราอยากให้มันดูปกติ แค่กดไม่ได้
## และ IGNORE ยังตัด hover/pressed ออกด้วย ไม่มีอะไรกะพริบตอนเมาส์ผ่าน
## ซึ่งจะหลอกผู้เล่นว่ากดได้
##
## ⚠️ ห้ามตั้ง line_edit.editable = false
## LineEdit ที่ editable = false จะสลับไปใช้ StyleBox ชื่อ "read_only" ไม่ใช่ "normal"
## สไตล์แคปซูลมนที่ตั้งไว้ที่ "normal" จะหายไป กลายเป็นสไตล์ default ของ Godot
## แล้วหน้าตาตอน F5 จะไม่ตรงกับที่เห็นใน editor (เพราะใน editor editable ยังเป็น true)
##
## focus_mode = NONE + mouse_filter = IGNORE กันการพิมพ์ได้อยู่แล้ว
## (โฟกัสไม่ได้ = พิมพ์ไม่ได้) และไม่ต้องดูแล StyleBox สองชุดให้เหมือนกัน
func _setup_input_bar() -> void:
	if line_edit:
		line_edit.focus_mode = Control.FOCUS_NONE
		line_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if send_button:
		send_button.focus_mode = Control.FOCUS_NONE
		send_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


## หา MessageList แบบยืดหยุ่น
## รับชื่ออื่นได้ด้วยเพื่อไม่ให้ติดตอนกำลังจัด node อยู่ แต่จะเตือนให้เปลี่ยนชื่อ
func _find_message_list() -> VBoxContainer:
	if scroll == null:
		return null
	var wanted := scroll.get_node_or_null("MessageList")
	if wanted is VBoxContainer:
		return wanted
	## fallback: เอา VBoxContainer ตัวแรกที่เจอใต้ ScrollContainer
	for child in scroll.get_children():
		if child is VBoxContainer:
			push_warning("phone.gd: ใช้ '%s' เป็นที่เก็บข้อความ — ควรเปลี่ยนชื่อเป็น 'MessageList' เพื่อไม่ให้สับสนกับตัวบับเบิล" % child.name)
			return child
	return null


## โหลดประวัติแชทที่มีอยู่ก่อนแล้ว - ขึ้นครบทันที ไม่มีหน่วง
## ใช้ตอนเปิดโทรศัพท์ ผู้เล่นจะเห็นข้อความเก่าทั้งหมดและเลื่อนขึ้นลงอ่านได้เลย
## lines = Array ของ {"sender": String, "text": String, "image": Texture2D (ไม่ใส่ก็ได้)}
func load_history(lines: Array) -> void:
	if message_list == null:
		return

	for line in lines:
		if line.has("time"):
			add_time_divider(line["time"])
			continue
		_add_bubble(line["sender"], line["text"], line.get("image", null))

	## เลื่อนลงล่างสุดครั้งเดียวตอนจบ (ไม่ต้องเลื่อนทีละข้อความให้เสียเวลา)
	## เริ่มที่ข้อความล่าสุดเหมือนแอปแชทจริง แล้วผู้เล่นเลื่อนขึ้นดูของเก่าได้
	await _scroll_to_bottom()


## เล่นบทแชทแบบทยอยขึ้นทีละข้อความ - ใช้กับข้อความใหม่ที่เด้งเข้ามาระหว่างเล่นเกม
## ถ้าเป็นประวัติเก่าที่มีอยู่แล้ว ใช้ load_history() แทน
## lines = Array ของ {"sender": String, "text": String, "image": Texture2D (ไม่ใส่ก็ได้)}
func play_chat(lines: Array) -> void:
	for line in lines:
		if line.has("time"):
			add_time_divider(line["time"])
			continue
		await add_message(line["sender"], line["text"], line.get("image", null))
		await get_tree().create_timer(_delay_for(line["text"])).timeout
	chat_finished.emit()


## แทรกตัวคั่นเวลา เช่น "5:30" เป็นแถวของตัวเองกลางรายการ
## ไม่ใช่ส่วนหนึ่งของบับเบิล จึงไม่ต้องแก้ message_bubble.tscn
func add_time_divider(text: String) -> void:
	if message_list == null:
		return

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	## ต้อง EXPAND_FILL ไม่งั้น Label จะหดเท่าข้อความแล้วไปกองซ้ายสุด จัดกลางไม่ได้
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", DIVIDER_FONT)
	label.add_theme_font_size_override("font_size", divider_font_size)
	label.add_theme_color_override("font_color", divider_color)

	message_list.add_child(label)

	## ตัวคั่นเวลามาขวาง = ขึ้นชุดใหม่
	## ถ้าไม่รีเซ็ต คนที่พูดก่อนและหลังตัวคั่นจะถูกนับเป็นชุดเดียวกัน
	## แล้วข้อความแรกหลังตัวคั่นจะไม่มีชื่อขึ้น
	_last_sender = ""
	_last_bubble = null


## เพิ่มข้อความเดียวเข้าแชท แล้วเลื่อนจอลงล่างสุด
func add_message(sender_id: String, text: String, image: Texture2D = null) -> void:
	if message_list == null:
		return

	_add_bubble(sender_id, text, image)
	await _scroll_to_bottom()


## สร้างบับเบิลหนึ่งใบ พร้อมจัดกลุ่มข้อความที่ติดกันจากคนเดิม (สไตล์ Messenger)
##
## คนเดิมพูดต่อ -> ซ่อนชื่อของใบใหม่ และ "ย้อนกลับไป" ลบรูปของใบก่อนหน้า
## ผลคือรูปโปรไฟล์จะเลื่อนตามลงมาอยู่ที่ข้อความสุดท้ายของชุดเสมอ
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


## แสดงตัวเลือกให้น้ำฟ้าตอบ - รอจนผู้เล่นเลือก แล้วคืน index ที่เลือก
func show_choices(options: Array) -> int:
	if choice_container == null:
		push_error("phone.gd: ไม่พบ Control/Down/ChoiceContainer")
		return -1

	clear_choices()
	for i in options.size():
		var btn := Button.new()
		btn.text = str(options[i])
		btn.pressed.connect(_on_choice_pressed.bind(i))
		choice_container.add_child(btn)
	choice_container.show()

	var index: int = await choice_selected
	return index


func clear_messages() -> void:
	if message_list == null:
		return
	for child in message_list.get_children():
		child.queue_free()
	## ล้างข้อความแล้วต้องล้างสถานะจับกลุ่มด้วย ไม่งั้นข้อความแรกของบทถัดไป
	## จะถูกนับว่าติดกับข้อความสุดท้ายของบทเก่าที่ลบไปแล้ว
	_last_sender = ""
	_last_bubble = null


func clear_choices() -> void:
	if choice_container == null:
		return
	for child in choice_container.get_children():
		child.queue_free()


func _on_choice_pressed(index: int) -> void:
	choice_container.hide()
	clear_choices()
	choice_selected.emit(index)


## หน่วงตามความยาวข้อความ - ข้อความสั้นเด้งเร็ว ข้อความยาวรอนานขึ้น
func _delay_for(text: String) -> float:
	return minf(delay_base + text.length() * delay_per_char, delay_max)


## เลื่อนจอลงล่างสุด
## ต้องรอ 2 เฟรม: เฟรมแรก VBox คำนวณความสูงใหม่หลังเพิ่มบับเบิล
## เฟรมที่สอง scrollbar ถึงอัปเดต max_value - ถ้าเลื่อนทันทีจะได้ค่าเก่า
func _scroll_to_bottom() -> void:
	if scroll == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
