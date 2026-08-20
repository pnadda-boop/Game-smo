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

## ส่งตอนผู้เล่นกดเลือกคำตอบ - `show_choices()` รอสัญญาณนี้อยู่
signal choice_made(index: int)

var dialogue_queue: Array = []
var index := 0
var is_talking := false
var tween: Tween
var current_npc = null

## id ของ HUD ช่องของในทะเบียน `UI_SCENES` ของ `scripts/ui_root.gd`
const HUD_UI_ID := "hud"

## เราเป็นคนซ่อน HUD ไว้เองไหม — ตัวตัดสินว่าจบบทแล้วต้องเอากลับมาไหม
var _hud_hidden_by_dialogue := false

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


## ==============================================
## กล่องเลือกคำตอบ
## ==============================================
## ⚠️ `ChoiceBox` เป็นลูกของ **CanvasLayer ตัวนี้โดยตรง** ไม่ได้อยู่ใต้ `Root`
## (ต่างจาก NamePlate / TextPanel / Portraits ที่อยู่ใต้ Root ทั้งหมด)
@onready var choice_box: Control = get_node_or_null("ChoiceBox")

## ลำดับปุ่มตัวเลือก — index ในบท → โหนดจริงในซีน
##
## 🚨 **เรียงสลับฝั่งโดยตั้งใจ ไม่ได้เรียงตามชื่อโหนด**
## มี 2 ตัวเลือกจะได้อยู่คนละฝั่งซ้าย-ขวา (ตอบตกลง | ปฏิเสธ) ไม่ใช่กองกันฝั่งซ้ายแล้วขวาโล่ง
## ชื่อโหนดในซีนเรียง `Choice0,1` = ซ้าย · `Choice2,3` = ขวา ซึ่งคนละลำดับกับที่เห็นบนจอ
## อยากเปลี่ยนการจัดวาง **แก้ที่ตารางนี้ที่เดียว** ไม่ต้องเปลี่ยนชื่อโหนดในซีน
const CHOICE_BUTTON_PATHS: Array[String] = [
	"ChoiceBox/LeftBox/Choice0",
	"ChoiceBox/RightBox/Choice2",
	"ChoiceBox/LeftBox/Choice1",
	"ChoiceBox/RightBox/Choice3",
]

## ปุ่มจริงเรียงตาม index ของตัวเลือก (ไม่ใช่ตามชื่อโหนด — ดู CHOICE_BUTTON_PATHS)
var choice_buttons: Array[Button] = []

## คลิกซ้ายตรงไหนก็ได้เพื่อเลื่อนบท (เหมือนกด E)
##
## ปิดได้ถ้าวันหลังมีฉากที่ต้องคลิกอย่างอื่นระหว่างบทสนทนา
## (ตอนนี้ยังไม่มี — ผู้เล่นถูกล็อกตลอดช่วงที่กล่องคำพูดเปิดอยู่)
@export var advance_on_click: bool = true

## ==============================================
## ความกว้างปุ่มตัวเลือก — บังคับให้ทุกปุ่มเท่ากัน
## ==============================================
## 🚨 **`custom_minimum_size` ในซีนเป็นแค่ "ค่าต่ำสุด" ไม่ใช่ความกว้างจริง**
## `Button` ขยายตัวตามความกว้างข้อความเสมอ → ปุ่ม "กล่องไหนเหรอคะ" กับ "ไม่มีค่ะ"
## จึงกว้างไม่เท่ากันราว 30px ทั้งที่ตั้งค่าในซีนเหมือนกันเป๊ะ (ผู้ใช้ทักเรื่องนี้ 2026-08-20)
##
## แก้ที่นี่ไม่ใช่ในซีนด้วยเหตุผลเดียวกับสีตอนชี้: ความกว้างที่ถูกต้องขึ้นกับ**ข้อความของบทนั้น ๆ**
## ซึ่งเปลี่ยนทุกครั้งที่เรียก `show_choices()` — กรอกตายตัวในซีนให้ตรงทุกบทเป็นไปไม่ได้
@export_group("ความกว้างปุ่มตัวเลือก")

## เพดานความกว้าง — เกินเท่านี้แล้วข้อความตกบรรทัดใหม่แทนการยืดออกข้าง
##
## 🚨 **ค่านี้บังคับได้ก็ต่อเมื่อปุ่มเปิด `autowrap_mode`** (ตั้งให้ใน `_setup_choices()`)
## `custom_minimum_size` เป็นแค่ "ค่าต่ำสุด" — ไม่มี autowrap เมื่อไหร่ `Button` จะยืด
## ตามความยาวข้อความเสมอ แล้วเพดานตรงนี้จะเป็นตัวเลขที่ไม่มีผลกับภาพเลยสักพิกเซล
## (เป็นแบบนั้นอยู่จนถึง 2026-08-20 — โค้ดเตือนว่า "หั่นแล้ว" ทั้งที่ไม่เคยหั่นได้จริง)
##
## ⚠️ **ไม่ใช่ตัวกันปุ่มสองฝั่งชนกันอีกแล้ว** — งานนั้นเป็นของ `grow_horizontal`
## ใน `_align_choice_columns()` ซึ่งตรึงขอบด้านในของสองคอลัมน์ไว้ ต่อให้ปุ่มกว้างแค่ไหน
## ก็โตหนีออกด้านนอก · ค่านี้เหลือหน้าที่เดียว: **ปุ่มกว้างแค่ไหนถึงจะดูดี**
## (240 = ความกว้างที่ใช้อยู่เดิม · เพิ่มได้ถ้าอยากได้ปุ่มบรรทัดเดียวยาว ๆ)
@export var choice_button_max_width: float = 240.0

## เผื่อความกว้างกันตัวอักษรตัวสุดท้ายโดนตัด (ค่าที่วัดจากฟอนต์กับที่ container คำนวณต่างกันเศษพิกเซล)
##
## ⚠️ **ไม่ใช่ระยะขอบที่มองเห็น** — ตัวนั้นคือ `choice_padding_h` ข้างล่าง
## ตัวนี้เป็นเศษเผื่อทางเทคนิคล้วน ๆ ไม่ควรใช้จัดหน้าตา
@export var choice_button_padding: float = 24.0
@export_group("")

## ==============================================
## ระยะขอบในปุ่มตัวเลือก — ขอบกล่องถึงตัวอักษร
## ==============================================
## ตั้งจากโค้ดเพราะ StyleBox ของปุ่มถูกก๊อปไปใช้ต่ออีก 3 สถานะ (`hover` · `hover_pressed` · `pressed`)
## กรอกในซีนต้องกรอก 4 ใบ × 4 ด้าน ให้ตรงกัน ลืมใบเดียว = ตัวอักษรขยับตอนเอาเมาส์ชี้
##
## ค่าเริ่มต้นเท่ากับปุ่มตัวเลือกในแชท (`chat_group.gd` → `_choice_style()`) จะได้ดูเป็นชุดเดียวกัน
## ⚠️ เดิม `StyleBoxFlat_l44sp` ในซีน**ไม่ได้ตั้ง content margin เลย** = ตัวอักษรชิดขอบ
## อยากได้แบบเดิมเป๊ะให้ตั้งสองค่านี้เป็น 0
@export_group("ระยะขอบในปุ่มตัวเลือก")
@export var choice_padding_h: float = 16.0
@export var choice_padding_v: float = 10.0
@export_group("")

## ความกว้างที่ซีนตั้งไว้ — ใช้เป็นพื้นขั้นต่ำ ไม่ให้ปุ่มข้อความสั้นหดจนเล็กกว่าที่ออกแบบไว้
var _choice_base_width: float = 0.0

## ==============================================
## หน้าตาปุ่มตัวเลือกตอนเมาส์ชี้
## ==============================================
## ตั้งจากโค้ดไม่ใช่ในซีน เพราะปุ่มมี 4 ตัว × 3 สถานะ × (พื้นหลัง + สีอักษร)
## = 24 ช่องที่ต้องกรอกให้ตรงกันเป๊ะด้วยมือ ลืมช่องเดียวก็มีปุ่มหนึ่งตัวสีเพี้ยนแบบหาไม่เจอ
@export_group("ปุ่มตัวเลือกตอนชี้")
@export var choice_hover_color: Color = Color("564aff")
@export var choice_hover_font_color: Color = Color.BLACK
@export_group("")

## สถานะที่ถือว่า "กำลังชี้/กำลังกดปุ่มนี้อยู่" — ใช้หน้าตาชุดเดียวกันหมด
##
## ⚠️ ต้องคลุม `pressed` กับ `hover_pressed` ด้วย ไม่ใช่แค่ `hover`
## ทับแค่ `hover` แล้วตอนกดค้างปุ่มจะเด้งกลับไปใช้สีเทาของธีมมาตรฐาน Godot หนึ่งจังหวะ
## (`normal` ในซีนถูกทับไว้ แต่สถานะอื่นยังเป็นของธีมเดิมทั้งหมด)
##
## 🚨 **ห้ามใส่ `focus`** — สถานะโฟกัสวาดทับบน `normal` ซึ่งพื้นดำ
## ถ้าเผลอเปลี่ยนสีอักษรตอนโฟกัสเป็นดำด้วย ตัวหนังสือจะหายไปเลยตอนเลื่อนเลือกด้วยคีย์บอร์ด
const CHOICE_ACTIVE_STYLES: Array[String] = ["hover", "hover_pressed", "pressed"]
const CHOICE_ACTIVE_FONT_COLORS: Array[String] = [
	"font_hover_color", "font_hover_pressed_color", "font_pressed_color",
]


## ==============================================
## ปุ่ม "ไปต่อ"
## ==============================================
## ทำงานเหมือนกด E ทุกประการ (ข้ามการพิมพ์ / ไปบรรทัดถัดไป / บรรทัดสุดท้ายกดแล้วปิดบท)
##
## ⚠️ หาโหนดด้วย **ชื่อ** ไม่ใช่ path ตายตัว เพราะปุ่มนี้ย้ายที่ได้ตลอด
## (อยู่ใต้ TextPanel มุมขวาล่างบ้าง อยู่นอกกล่องบ้าง แล้วแต่การจัดหน้าจอ)
## ผูก path ไว้ = ขยับปุ่มใน editor ทีไรปุ่มก็ตายเงียบ ๆ โดยไม่มีอะไรบอก
const NEXT_BUTTON_NAME := "Next"

## 🚨 ประกาศเป็น `BaseButton` ไม่ใช่ `Button`
## `TextureButton` **ไม่ได้สืบทอดมาจาก `Button`** — ทั้งคู่แยกสายกันใต้ `BaseButton`
## (`Button` = ปุ่มมีข้อความ+สไตล์ · `TextureButton` = ปุ่มรูปล้วน)
## แคสต์เป็น `Button` แล้วเอาปุ่มรูปมาใส่จะได้ null เงียบ ๆ แล้วปุ่มไม่ทำงานทั้งที่วางไว้ถูกทุกอย่าง
var next_button: BaseButton = null

## กำลังรอผู้เล่นกดเลือกอยู่ไหม
##
## 🚨 ระหว่างรอ ต้อง **ห้ามบทเดินต่อ** ทั้งจากการกด E และจาก tween ของคีย์ "hold"
## ไม่งั้นผู้เล่นกด E หนีคำถามได้ แล้วบทจะเดินไปโดยที่ `await` ยังค้างรออยู่
var _waiting: bool = false


var _typing_player: AudioStreamPlayer = null


func _ready():
	visible = false
	set_process_input(true)
	_setup_typing_sound()
	_setup_choices()
	_setup_next_button()
	_check_nodes()
	if text_label:
		text_label.bbcode_enabled = true
	## ⚠️ ป้ายชื่อตอนถูกซ่อนจะ "จางเป็น 0 แต่ยังกินที่อยู่" (ดู `_set_name_plate_shown`)
	## ปล่อย mouse_filter เป็นค่าเริ่มต้น (STOP) จะกลายเป็นแถบใสที่กินคลิกโดยไม่มีใครรู้
	if name_plate:
		name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
# ตัวเลือกคำตอบ
# ==============================================

## ผูกปุ่มครั้งเดียวตอนเปิดฉาก
##
## ⚠️ ต่อสัญญาณจากโค้ดที่เดียว ไม่ต่อจาก editor — ต่อสองที่จะเข้าเมธอดสองรอบต่อการกดหนึ่งครั้ง
## (เคยเจอปัญหาต่อซ้ำมาแล้วใน Start.gd)
func _setup_choices() -> void:
	if choice_box == null:
		push_warning("dialogue_system: ไม่พบ ChoiceBox — ตัวเลือกคำตอบจะใช้ไม่ได้")
		return

	choice_box.visible = false

	## หาให้ครบก่อนค่อยผูก — ขาดปุ่มแล้วผูกครึ่ง ๆ index จะเลื่อนจนกดผิดข้อแบบเงียบ ๆ
	var found: Array[Button] = []
	for path: String in CHOICE_BUTTON_PATHS:
		var btn: Button = get_node_or_null(path) as Button
		if btn == null:
			push_error("dialogue_system: ไม่พบปุ่มตัวเลือก `%s` — ระบบตัวเลือกคำตอบถูกปิดทั้งระบบ" % path)
			return
		found.append(btn)

	choice_buttons = found
	for i: int in choice_buttons.size():
		choice_buttons[i].pressed.connect(_on_choice_pressed.bind(i))
		## 🚨 **ต้องมาก่อน `_apply_choice_hover_style()`**
		## ตัวนั้นก๊อป StyleBox ของ `normal` ไปทำสถานะตอนชี้ — ใส่ระยะขอบทีหลัง
		## จะได้ปุ่มที่ตัวอักษร**ขยับตำแหน่งตอนเอาเมาส์ชี้** เพราะสองสถานะมีระยะขอบไม่เท่ากัน
		_apply_choice_padding(choice_buttons[i])
		_apply_choice_hover_style(choice_buttons[i])
		## 🚨 **นี่คือสิ่งที่ทำให้ `choice_button_max_width` บังคับได้จริง**
		## ปิดอยู่ = `Button` ยืดตามความยาวข้อความเสมอ เพราะ `custom_minimum_size`
		## เป็นแค่ "ค่าต่ำสุด" ไม่ใช่ "ค่าสูงสุด" — เพดานที่ตั้งไว้จึงไม่เคยมีผลกับภาพเลย
		## เปิดแล้วข้อความยาวจะ **ตกบรรทัดใหม่ (ปุ่มสูงขึ้น) แทนการยืดออกข้าง**
		##
		## ⚠️ ตัดตามคำ ไม่ใช่ตัดกลางคำ — ภาษาไทยไม่มีช่องว่างระหว่างคำ
		## `WORD_SMART` ยอมตัดกลางคำเฉพาะตอนคำเดียวยาวเกินปุ่มจริง ๆ
		choice_buttons[i].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		## จำความกว้างที่ตั้งไว้ในซีนเป็น "พื้นขั้นต่ำ" ก่อนที่โค้ดจะไปเขียนทับ
		_choice_base_width = maxf(_choice_base_width, choice_buttons[i].custom_minimum_size.x)

	_align_choice_columns()


## ตั้งระยะขอบในปุ่ม — ขอบกล่องถึงตัวอักษร
##
## ⚠️ **ก๊อป StyleBox มาแก้ ไม่ได้แก้ใบในซีนโดยตรง** — ปุ่มทั้ง 4 ตัวใช้ StyleBox
## ใบเดียวกัน (`StyleBoxFlat_l44sp` ในซีน) แก้ใบนั้นตรง ๆ = ไปแก้ทรัพยากรที่ซีนเป็นเจ้าของ
## ซึ่งใครมาใช้ต่อในอนาคตก็โดนด้วยโดยไม่รู้ตัว
##
## ⚠️ ก๊อปแล้วต้อง `add_theme_stylebox_override` ทับกลับไป ไม่งั้น `_apply_choice_hover_style()`
## จะยังอ่านเจอใบเดิมที่ไม่มีระยะขอบ แล้วสถานะตอนชี้จะกลับไปชิดขอบเหมือนเดิม
func _apply_choice_padding(btn: Button) -> void:
	var base: StyleBox = btn.get_theme_stylebox("normal")
	if base == null:
		push_warning("dialogue_system: ปุ่ม `%s` ไม่มี StyleBox `normal` — ตั้งระยะขอบในปุ่มไม่ได้" % btn.name)
		return

	var padded: StyleBox = base.duplicate()
	padded.content_margin_left = choice_padding_h
	padded.content_margin_right = choice_padding_h
	padded.content_margin_top = choice_padding_v
	padded.content_margin_bottom = choice_padding_v
	btn.add_theme_stylebox_override("normal", padded)


## ทาสีปุ่มตอนเมาส์ชี้ — พื้นเปลี่ยนสี ตัวอักษรเปลี่ยนสี
##
## ⚠️ **ก๊อป `normal` ของปุ่มนั้นมาแก้เฉพาะสีพื้น** ไม่ได้สร้าง StyleBox ใหม่เปล่า ๆ
## ค่าอื่น (มุมโค้ง ขอบ ระยะขอบใน) จะได้เหมือนตอนไม่ชี้เป๊ะ ๆ
## วันหลังไปใส่มุมโค้งในซีน ตอนชี้ก็โค้งตามเอง ไม่ต้องกลับมาแก้ที่นี่อีก
func _apply_choice_hover_style(btn: Button) -> void:
	var base: StyleBox = btn.get_theme_stylebox("normal")
	var hover: StyleBox = base.duplicate() if base != null else StyleBoxFlat.new()

	if hover is StyleBoxFlat:
		## ใช้สีตามที่ตั้งไว้ทั้งดุ้นรวมความโปร่งใส — อยากให้จาง ๆ ก็ลดค่า A ที่ Inspector
		(hover as StyleBoxFlat).bg_color = choice_hover_color
	else:
		push_warning("dialogue_system: `normal` ของปุ่ม `%s` ไม่ใช่ StyleBoxFlat — เปลี่ยนสีพื้นตอนชี้ไม่ได้" % btn.name)

	## ใช้ StyleBox ใบเดียวกันทั้งสามสถานะได้ เพราะหน้าตาเหมือนกันหมด
	for style_name: String in CHOICE_ACTIVE_STYLES:
		btn.add_theme_stylebox_override(style_name, hover)

	for color_name: String in CHOICE_ACTIVE_FONT_COLORS:
		btn.add_theme_color_override(color_name, choice_hover_font_color)


## จัดสองคอลัมน์ซ้าย-ขวาให้วางลูกแบบเดียวกัน (ทำครั้งเดียวตอน _ready)
##
## ⚠️ ในซีน `LeftBox` ตั้ง `alignment = 1` แต่ `RightBox` ไม่ได้ตั้ง
## ตอนมีข้างละปุ่มยังไม่เห็นผล แต่พอตัวเลือกมี 3-4 ข้อ (ซ้าย 2 ขวา 1)
## ปุ่มสองฝั่งจะไม่อยู่ระดับเดียวกัน — ค่าคนละอย่างในสองกล่องที่ควรเป็นฝาแฝดกัน
func _align_choice_columns() -> void:
	for btn: Button in choice_buttons:
		var column := btn.get_parent() as BoxContainer
		if column == null:
			continue
		column.alignment = BoxContainer.ALIGNMENT_CENTER

		## 🚨 **ตรึงขอบด้านในของสองคอลัมน์ — ช่องว่างกลางจอจะไม่มีวันหุบ**
		##
		## `grow_horizontal` ตัดสินว่า Control จะโตไปทางไหนเมื่อ min size โตเกินกรอบ anchor
		## ค่าเริ่มต้นคือ `END` (โตขวา) **ทั้งสองคอลัมน์** → `LeftBox` ที่ x=700..900
		## โตขวาตรงเข้าหา `RightBox` ที่ x=1000 พอดี (บั๊กที่ผู้ใช้เจอ 2026-08-20)
		##
		## ตอนนี้: คอลัมน์ที่ยึดขอบขวาของจอโตออกขวา · ที่ยึดขอบซ้ายโตออกซ้าย
		## = **โตหนีออกจากกัน** ขอบด้านใน (900 กับ 1000) ถูกตรึงไว้เท่าเดิมเสมอ
		##
		## ⚠️ ดูจาก `anchor_left` ไม่ใช่ชื่อโหนด — ย้าย/เปลี่ยนชื่อกล่องในซีนแล้วยังถูกอยู่
		## ผลพลอยได้: สองคอลัมน์สมมาตรกันเสมอไม่ว่าปุ่มจะกว้างเท่าไหร่
		## (เดิมจุดกึ่งกลางของคู่ปุ่มเลื่อนตามความยาวข้อความ)
		column.grow_horizontal = Control.GROW_DIRECTION_END if column.anchor_left >= 0.5 \
			else Control.GROW_DIRECTION_BEGIN


## บังคับให้ปุ่มที่โชว์อยู่ทุกตัวกว้างเท่ากัน = ตัวที่ข้อความยาวที่สุด
##
## 🚨 **วัดจากฟอนต์เอง ไม่ใช่อ่าน `get_minimum_size()`**
## ขนาดต่ำสุดของ Control ถูกคำนวณใหม่ตอนท้ายเฟรม — อ่านทันทีหลังเซ็ต `text`
## จะได้ค่าของ**ข้อความรอบก่อน** แล้วปุ่มจะกว้างตามบทที่แล้วเสมอ ซึ่งดูเหมือนสุ่ม
## (วิธีเดียวกับที่ `message_bubble.gd` ใช้วัดความกว้างบับเบิลแชท)
func _equalize_choice_widths() -> void:
	var font: Font = null
	var font_size: int = 0
	var widest: float = _choice_base_width

	for btn: Button in choice_buttons:
		if not btn.visible:
			continue
		if font == null:
			font = btn.get_theme_font("font")
			font_size = btn.get_theme_font_size("font_size")
		if font == null:
			continue
		## 🚨 **ต้องบวกระยะขอบในปุ่มเข้าไปด้วย** — `content_margin` กินพื้นที่ของตัวอักษรจริง ๆ
		## ลืมบวก = ตั้งระยะขอบเพิ่มเมื่อไหร่ ข้อความจะตกบรรทัดเร็วกว่าที่ควร
		## ทั้งที่ปุ่มกว้างพอ (อาการ: ปรับ `choice_padding_h` แล้วปุ่มสูงขึ้นเองแบบไม่มีเหตุผล)
		widest = maxf(widest, font.get_string_size(
			btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x \
			+ choice_padding_h * 2.0 + choice_button_padding)

	if font == null:
		push_warning("dialogue_system: ปุ่มตัวเลือกไม่มีฟอนต์ — ข้ามการปรับความกว้างให้เท่ากัน")
		return

	## ⚠️ เกินเพดานแล้ว **ข้อความไม่หาย** — `autowrap_mode` พาไปขึ้นบรรทัดใหม่ ปุ่มสูงขึ้นแทน
	## เตือนไว้เพราะปุ่มสองบรรทัดคือสิ่งที่ควรรู้ตัว ไม่ใช่สิ่งที่ควรค้นพบเอาตอนเห็นบนจอ
	if widest > choice_button_max_width:
		push_warning(("dialogue_system: ตัวเลือกยาวเกินเพดาน (ต้องการ %.0fpx เพดาน %.0fpx) " \
			+ "— ข้อความจะตกบรรทัดใหม่ ปุ่มจะสูงขึ้น · ย่อข้อความบนปุ่ม " \
			+ "หรือเพิ่ม `choice_button_max_width` ถ้ายังมีที่ว่างพอ") \
			% [widest, choice_button_max_width])
		widest = choice_button_max_width

	## ตั้งให้ **ทุกปุ่ม** รวมตัวที่ซ่อนอยู่ด้วย — ตัวที่ซ่อนไม่กินที่ก็จริง
	## แต่ปล่อยค่าเก่าค้างไว้จะไปโผล่ผิดขนาดหนึ่งเฟรมตอนถูกเปิดใช้รอบหน้า
	for btn: Button in choice_buttons:
		btn.custom_minimum_size.x = widest


## โชว์ตัวเลือกแล้วรอจนกด — คืน index ที่เลือก (-1 = ใช้ไม่ได้)
##
## ⚠️ ต้อง `await` เสมอ: `var i: int = await ui.show_choices([...])`
##
## รับ `Array` ธรรมดา ไม่ใช่ `Array[String]` เพราะบทพูดใน `DialogueData` เป็น Array ไม่มีชนิด
## ประกาศเป็น `Array[String]` แล้วส่งบทเข้ามาตรง ๆ จะ error ตอนรัน — แปลงเป็นข้อความให้ตรงนี้แทน
func show_choices(options: Array) -> int:
	if choice_box == null or choice_buttons.is_empty():
		push_error("dialogue_system: show_choices ถูกเรียกทั้งที่ระบบตัวเลือกใช้ไม่ได้")
		return -1

	if options.is_empty():
		push_warning("dialogue_system: show_choices ได้รับ array ว่าง")
		return -1

	var count: int = mini(options.size(), choice_buttons.size())
	if options.size() > choice_buttons.size():
		push_warning("dialogue_system: ตัวเลือกมี %d ข้อ แต่ซีนมีปุ่มแค่ %d — ส่วนเกินถูกตัดทิ้ง" \
			% [options.size(), choice_buttons.size()])

	for i: int in choice_buttons.size():
		var btn: Button = choice_buttons[i]
		btn.visible = i < count
		if i < count:
			btn.text = str(options[i])

	## ต้องทำ **หลัง** ใส่ข้อความครบทุกปุ่มแล้ว — ความกว้างขึ้นกับข้อความที่ยาวที่สุดในรอบนี้
	_equalize_choice_widths()

	choice_box.visible = true
	_waiting = true
	## 🚨 ซ่อนปุ่มไปต่อระหว่างรอเลือก — เหลือปุ่มค้างไว้ = ผู้เล่นกดหนีคำถามได้ด้วยเมาส์
	## (ทางฝั่งคีย์บอร์ดกันไว้แล้วที่ `_input` ด้วยการเช็ค `_waiting`)
	_set_next_button_visible(false)
	## โฟกัสปุ่มแรกไว้ให้เล่นด้วยคีย์บอร์ดได้ (Enter/Space = ui_accept ของ Godot)
	## ปุ่มที่ซ่อนอยู่รับโฟกัสไม่ได้ จึงกด Tab วนไปโดนข้อที่ไม่มีอยู่จริงไม่ได้
	choice_buttons[0].grab_focus()

	var index: int = await choice_made

	## `_waiting` ถูกปิดไปแล้วตั้งแต่ใน _on_choice_pressed (ปิดก่อน emit เพื่อกันกดซ้ำ)
	choice_box.visible = false
	_set_next_button_visible(true)
	return index


func _on_choice_pressed(index: int) -> void:
	if not _waiting:
		return

	## 🚨 ปิดสวิตช์ **ก่อน** emit — กดปุ่มที่สองในเฟรมเดียวกัน (คลิกพร้อมเคาะ Enter)
	## จะยิงสัญญาณซ้ำโดยไม่มีใครรับ ปิดก่อนแล้วการกดครั้งที่สองจะถูกตีตกตรงบรรทัดบน
	_waiting = false
	choice_made.emit(index)


# ==============================================
# ปุ่ม "ไปต่อ"
# ==============================================

## ผูกปุ่ม Next ครั้งเดียวตอนเปิดฉาก — ไม่มีปุ่มก็เล่นด้วย E ได้ตามปกติ (เตือนอย่างเดียว ไม่ error)
##
## ⚠️ ต่อสัญญาณจากโค้ดที่เดียว **ห้ามต่อจาก editor ซ้ำ** ไม่งั้นกดครั้งเดียวบทจะเลื่อน 2 บรรทัด
## (ปัญหาเดียวกับที่เคยเจอใน Start.gd — เช็ค is_connected ไว้กันพลาดอีกชั้น)
func _setup_next_button() -> void:
	next_button = find_child(NEXT_BUTTON_NAME, true, false) as BaseButton
	if next_button == null:
		push_warning("dialogue_system: ไม่พบปุ่ม '%s' (ต้องเป็น Button หรือ TextureButton) — ใช้ปุ่ม E เลื่อนบทได้อย่างเดียว" % NEXT_BUTTON_NAME)
		return

	_ensure_next_button_size()

	## 🚨 ปิดโฟกัสคีย์บอร์ด — ปุ่มที่ถือโฟกัสอยู่จะกินปุ่ม Enter/Space (ui_accept ของ Godot)
	## กดเลื่อนบทด้วยเมาส์หนึ่งครั้งแล้วปุ่มค้างโฟกัส ต่อจากนั้นเคาะ Enter ก็เลื่อนบทได้ด้วย
	## ซึ่งไม่ใช่ปุ่มที่เกมประกาศไว้ และไปแย่งโฟกัสจากปุ่มตัวเลือกตอนถึงคิวเลือกคำตอบ
	next_button.focus_mode = Control.FOCUS_NONE

	if not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)


## กันปุ่มขนาด 0×0 — มองไม่เห็นและกดไม่โดน
##
## 🚨 `TextureButton` ที่ติ๊ก `ignore_texture_size` จะ **ไม่ยืดตามขนาดรูปให้เอง**
## ถ้าไม่ได้ลากขนาดในเอดิเตอร์ กรอบจะเป็น 0×0 ทั้งที่ใส่รูปไว้เรียบร้อยแล้ว
## อาการคือ "ปุ่มอยู่ตรงนั้นแต่กดไม่ได้" ซึ่งดูเหมือนสัญญาณไม่ได้ต่อ ทำให้ไล่หาผิดจุด
##
## ยืดให้เท่าขนาดรูปแล้วเตือน — ปุ่มขนาดศูนย์ไม่เคยเป็นสิ่งที่ตั้งใจ
## แต่ก็บอกให้ไปตั้งในซีนด้วย เพราะการจัดหน้าจอควรเห็นผลตั้งแต่ในเอดิเตอร์
func _ensure_next_button_size() -> void:
	if next_button.size != Vector2.ZERO or next_button.custom_minimum_size != Vector2.ZERO:
		return

	var tex: Texture2D = next_button.get("texture_normal") as Texture2D
	if tex == null:
		push_warning("dialogue_system: ปุ่ม '%s' มีขนาด 0×0 — ลากขนาดในเอดิเตอร์ก่อน ไม่งั้นกดไม่โดน" % NEXT_BUTTON_NAME)
		return

	next_button.custom_minimum_size = tex.get_size()
	push_warning("dialogue_system: ปุ่ม '%s' มีขนาด 0×0 — ยืดให้เท่ารูป (%s) ให้ชั่วคราว\n" % [NEXT_BUTTON_NAME, tex.get_size()] \
		+ "   ควรแก้ในซีน: ลากขนาดปุ่มเอง หรือปิด `Ignore Texture Size` เพื่อให้ยืดตามรูปอัตโนมัติ")


## กดปุ่ม = กด E ทุกประการ — เรียก `_step()` ตัวเดียวกัน ไม่ก๊อปตรรกะมาไว้อีกชุด
## (ถ้าแยกกัน วันหลังแก้เงื่อนไขที่ `_input` แล้วลืมแก้ตรงนี้ พฤติกรรมสองทางจะเพี้ยนคนละแบบ)
func _on_next_pressed() -> void:
	if not is_talking:
		return
	## รอเลือกคำตอบอยู่ ห้ามไปต่อ — ปกติปุ่มถูกซ่อนไปแล้ว แต่กันไว้เผื่อซ่อนไม่ทัน
	if _waiting:
		return
	_step()


## ซ่อน/โชว์ปุ่มไปต่อ — ระหว่างรอเลือกคำตอบต้องไม่มีทางกดหนีคำถาม
func _set_next_button_visible(value: bool) -> void:
	if next_button:
		next_button.visible = value


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
	## 🚨 ต้อง duplicate ไม่ใช้ตัวเดิม — บทที่มีตัวเลือกจะ `insert()` บทย่อยเข้าคิวระหว่างเล่น
	## ถ้าใช้ Array ตัวเดียวกับใน DialogueData จะเป็นการ**แก้บทต้นฉบับถาวร**
	## คุยรอบสองบทจะบวมขึ้นเรื่อย ๆ ทุกครั้งที่เลือก (ตื้นพอ เพราะเราไม่แก้ Dictionary ข้างใน)
	dialogue_queue = lines.duplicate()
	index = 0
	is_talking = true
	visible = true
	## เริ่มบทใหม่ต้องเห็นปุ่มเสมอ — บทก่อนหน้าอาจถูกสั่งจบตอนที่ปุ่มยังซ่อนอยู่ระหว่างรอเลือกคำตอบ
	_set_next_button_visible(true)

	if portraits:
		portraits.visible = show_portraits
	if show_portraits:
		_apply_portrait_cast(lines)

	_set_player_can_move(false)
	_hide_hud_for_dialogue()
	show_line()


## ==============================================
## HUD ช่องของ — หลบให้กล่องคำพูดระหว่างคุย แล้วกลับมาตอนบทจบ
## ==============================================
## HUD นั่งอยู่ที่ y 950–1030 ส่วนกล่องข้อความกิน 780–1047 — ทับกันพอดีกลางกล่อง
##
## ⚠️ **ซ่อน ไม่ใช่ลบ** — `UIRoot.hide_ui()` เก็บโหนดไว้ครบทั้งของในช่องและช่องที่เลือกอยู่
## (ดูเหตุผลที่ `ui_root.gd`: HUD ที่ถูกลบแล้วสร้างใหม่จะลืมว่าผู้เล่นเลือกช่องไหน)
func _hide_hud_for_dialogue() -> void:
	var hud: CanvasLayer = UIRoot.get_ui(HUD_UI_ID)
	## จำว่า "เราเป็นคนซ่อน" ไม่ใช่แค่ "ตอนนี้ซ่อนอยู่" — จบบทแล้วจะได้ไม่ไปเปิด HUD
	## ที่คนอื่นตั้งใจซ่อนไว้ (หรือที่ยังไม่เคยมีตัวตน)
	_hud_hidden_by_dialogue = hud != null and hud.visible
	if _hud_hidden_by_dialogue:
		UIRoot.hide_ui(HUD_UI_ID)


## 🚨 **ห้ามเรียก `UIRoot.show_ui()` ทื่อ ๆ ตอนจบบท** — ตัวนั้น **สร้าง UI ให้ถ้ายังไม่มี**
## คุยกับ NPC ตั้งแต่ก่อนหยิบของชิ้นแรกแล้วจบบท จะได้ช่องของโผล่มาเองทั้งที่ผู้เล่น
## ยังไม่มีของสักชิ้น — ซึ่งขัดกับกฎที่ `ui_root.gd` เขียนไว้ว่าไม่มี UI ตัวไหนเปิดเองตั้งแต่เกมเริ่ม
func _restore_hud_after_dialogue() -> void:
	if not _hud_hidden_by_dialogue:
		return
	_hud_hidden_by_dialogue = false
	UIRoot.show_ui(HUD_UI_ID)


## 🚨 **กล่องคำพูดตายพร้อมฉาก แต่ HUD แขวนอยู่ที่ `root` ซึ่งข้ามฉาก**
## เปลี่ยนฉากระหว่างที่บทยังค้างอยู่ = ไม่มีใครเหลือให้เอา HUD กลับมา **ช่องของจะหายตลอดกาล**
## (และผู้เล่นจะเห็นเป็น "ของหาย" ทั้งที่ `GameState` ยังถืออยู่ครบ)
func _exit_tree() -> void:
	_restore_hud_after_dialogue()


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
		_collect_speakers(lines, cast)

	for char_name in characters.keys():
		var sprite: AnimatedSprite2D = characters[char_name]
		if sprite == null:
			continue
		## ปิดตัวเลือกนี้ = ทุกคนขึ้นหมดเหมือนเดิม
		sprite.visible = (not only_show_speakers) or cast.has(char_name)


## ไล่เก็บชื่อคนพูดทั้งบท รวมถึงบทย่อยที่ซ่อนอยู่ในตัวเลือก
##
## ⚠️ ต้องไล่เข้า `then` ของทุกตัวเลือกด้วย ไม่ใช่ดูแค่บรรทัดชั้นบนสุด
## ตัวละครที่โผล่เฉพาะสายใดสายหนึ่ง (เช่นพี่คีรินที่ถูกพูดถึงเฉพาะตอนตอบว่ายังไม่ได้กิน)
## จะถูกซ่อนไว้ตั้งแต่ต้นบท แล้วพอถึงคิวจริงก็ยังไม่โผล่ เพราะ `visible` ถูกปิดไปแล้ว
func _collect_speakers(lines: Array, cast: Dictionary) -> void:
	for line: Dictionary in lines:
		var speaker: String = line.get("name", "")
		if speaker != "":
			cast[speaker] = true

		if not line.has("choices"):
			continue
		for opt: Variant in line["choices"]:
			if opt is Dictionary and opt.has("then"):
				_collect_speakers(opt["then"], cast)


func end_dialogue():
	if current_npc:
		current_npc.reset_direction()
		current_npc = null

	# ฆ่า tween ค้างก่อน กัน callback ของคีย์ "hold" ยิงหลังจบไปแล้ว
	if tween:
		tween.kill()
		tween = null
	_stop_typing_sound()

	if choice_box:
		choice_box.visible = false

	is_talking = false
	visible = false
	_set_player_can_move(true)
	_restore_hud_after_dialogue()
	dialogue_queue.clear()
	index = 0
	# จบบทสนทนาแล้วล้างอารมณ์ทิ้ง บทถัดไปเริ่มจากศูนย์
	# (การค้างอารมณ์มีผลแค่ "ภายในบทสนทนาเดียวกัน")
	_reset_all_characters()

	## บทจบขณะยังรอเลือกอยู่ -> ปลด `await` ที่ค้างด้วยค่า -1 ไม่งั้น coroutine ค้างตลอดไป
	##
	## 🚨 ต้องทำ **หลัง** `is_talking = false` เท่านั้น
	## สัญญาณยิงแบบทันที ตัวที่รออยู่จะทำงานต่อทันทีในบรรทัดนี้เลย
	## ถ้ายิงก่อน มันจะสั่งบทเดินต่อทั้งที่เพิ่งสั่งจบไป
	if _waiting:
		push_warning("dialogue_system: บทสนทนาจบขณะยังรอผู้เล่นเลือกคำตอบอยู่")
		_waiting = false
		choice_made.emit(-1)

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

	## บรรทัดตัวเลือก — ไม่มีข้อความให้พิมพ์ ค้างข้อความเดิมไว้แล้วรอผู้เล่นกด
	## (ตั้งใจไม่ล้างกล่อง ผู้เล่นจะได้เห็นคำถามค้างอยู่พร้อมตัวเลือก)
	if line.has("choices"):
		_run_choice_line(line)
		return

	var speaker: String = line.get("name", "")

	if name_label:
		name_label.text = speaker
	_set_name_plate_shown(speaker != "")

	text_label.text = _resolve_text(line)
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


## ข้อความของบรรทัดนี้ — รองรับคีย์ `random_text` (สุ่มหนึ่งประโยค)
##
## ```gdscript
## {"name": "วาวา", "random_text": ["มีอะไรสงสัยไหม?", "อยากให้ช่วยอะไรเหรอ?"]}
## ```
##
## ใช้กับบทที่ผู้เล่นกลับมาคุยซ้ำได้เรื่อย ๆ — ประโยคเดิมทุกครั้งจะรู้สึกเหมือนตัวละครเป็นหุ่น
##
## ⚠️ แยกเป็นคีย์ใหม่ ไม่ยอมให้ `"text"` เป็น Array ได้ด้วย
## บทมีเป็นร้อยบรรทัด การอ่านผ่าน ๆ ต้องบอกได้ทันทีว่าบรรทัดไหนสุ่ม บรรทัดไหนตายตัว
func _resolve_text(line: Dictionary) -> String:
	if not line.has("random_text"):
		return str(line.get("text", ""))

	var options: Array = line["random_text"]
	if options.is_empty():
		push_warning("dialogue_system: `random_text` ว่างเปล่า — ใช้คีย์ `text` แทน")
		return str(line.get("text", ""))

	return _pick_random_text(options)


## ประโยคที่สุ่มได้ล่าสุด — กันพูดประโยคเดิมซ้ำติดกัน
var _last_random_text: String = ""


## สุ่มประโยค โดยเลี่ยงประโยคเดียวกับรอบที่แล้ว
##
## สุ่มล้วน ๆ กับตัวเลือก 2 ข้อ = มีโอกาส 50% ที่จะได้ประโยคเดิมซ้ำ
## ซึ่งผู้เล่นที่กด E รัว ๆ จะเจอแน่นอน แล้วจะดูเหมือนระบบสุ่มพัง
func _pick_random_text(options: Array) -> String:
	var count: int = options.size()
	var index: int = randi() % count

	if count > 1 and str(options[index]) == _last_random_text:
		index = (index + 1) % count

	_last_random_text = str(options[index])
	return _last_random_text


## โชว์/ซ่อนป้ายชื่อ — บทที่ไม่ระบุ `"name"` (ความคิดในใจ / เสียงบรรยาย) ต้องไม่มีป้าย
##
## 🚨 **ใช้ `modulate.a` ไม่ใช่ `visible`**
## `Root/Box` เป็น `VBoxContainer` ซึ่ง **ตัดลูกที่ `visible = false` ออกจากการจัดวางทั้งช่อง**
## กล่องข้อความจะเลื่อนขึ้นไปแทนที่ป้ายชื่อทันที → บทที่มีชื่อกับไม่มีชื่อ กล่องอยู่คนละที่ (ต่างกัน 67px)
## อาการที่เห็นคือ "ฉาก wokeup ใช้กล่องคำพูดผิดใบ" ทั้งที่เป็นไฟล์เดียวกันเป๊ะ (เจอ 2026-08-18)
##
## จางเป็น 0 แทน = ป้ายยังกินที่เท่าเดิม กล่องข้อความจึงอยู่ที่เดิมทุกบรรทัด
func _set_name_plate_shown(shown: bool) -> void:
	if name_plate == null:
		return
	name_plate.modulate.a = 1.0 if shown else 0.0


## บรรทัดที่เป็นตัวเลือก — โชว์ปุ่ม รอกด แล้วแทรกบทของข้อที่เลือกเข้าคิว
##
## รูปแบบ (เหมือนระบบแชทใน `chat_group.gd` จะได้จำแบบเดียวใช้ได้ทั้งสองที่):
##   {"choices": [
##       "ตอบสั้น ๆ แล้วบทเดินต่อเหมือนเดิม",
##       {"text": "ตอบแล้วแตกบทย่อย", "then": [ {...}, {...} ]},
##   ]}
##
## ⚠️ ข้อความบนปุ่มกับคำที่น้ำฟ้าพูดจริง **เป็นคนละอัน**
## อยากให้คำตอบขึ้นเป็นบทพูดด้วย ให้ใส่บรรทัดของน้ำฟ้าไว้ต้น `then` เอง
## (ปุ่มมีที่จำกัด คำพูดจริงมักยาวกว่า — บังคับให้เหมือนกันจะเขียนบทได้ไม่สวย)
##
## **ตัวเลือกที่โผล่เฉพาะบางสถานการณ์** — ใส่ `"if"` / `"unless"` ชี้ชื่อตัวแปรใน `GameState`
##   {"text": "กล่องวางตรงไหนเหรอคะ", "if": "carrying_box", "then": [...]}
##   {"text": "ขอบคุณสำหรับกล่องนะคะ", "unless": "carrying_box", "then": [...]}
func _run_choice_line(line: Dictionary) -> void:
	## 🚨 ต้องกรองก่อนสร้าง labels และต้องใช้ **ลิสต์ที่กรองแล้ว** ตอนอ่านผลลัพธ์ด้วย
	## `show_choices()` คืน index ของปุ่มที่เห็นบนจอ ไม่ใช่ index ในบทต้นฉบับ
	## เอาไปอ้างกับลิสต์ก่อนกรองเมื่อไหร่ = ผู้เล่นกดข้อหนึ่งแล้วได้บทของอีกข้อ
	var options: Array = _filter_choices(line["choices"])

	## ทุกข้อถูกกรองออกหมด -> ข้ามบรรทัดนี้ไป
	## ปล่อยให้เรียก `show_choices([])` จะได้กล่องเปล่า ๆ ที่ผู้เล่นกดอะไรไม่ได้เลย = บทค้าง
	if options.is_empty():
		_advance()
		return

	var labels: Array = []
	for opt: Variant in options:
		labels.append(str(opt["text"]) if opt is Dictionary else str(opt))

	var picked: int = await show_choices(labels)

	## ระบบตัวเลือกใช้ไม่ได้ หรือบทถูกสั่งจบระหว่างรอ -> ข้ามบรรทัดนี้ไป
	## (`_advance()` เช็ค `is_talking` ให้อยู่แล้ว บทที่จบไปแล้วจะไม่เดินต่อ)
	if picked < 0:
		_advance()
		return

	## ⚠️ อ่านจาก `options` ที่กรองแล้ว ตรงกับที่ `labels` สร้างมา
	var chosen: Variant = options[picked]
	if chosen is Dictionary and chosen.has("then"):
		## แทรกต่อจากบรรทัดตัวเลือกทันที เรียงตามลำดับเดิม
		var follow: Array = chosen["then"]
		for i: int in follow.size():
			dialogue_queue.insert(index + 1 + i, follow[i])

	_advance()


## คัดเฉพาะตัวเลือกที่ผ่านเงื่อนไข
##
## ตัวเลือกที่ไม่มี `"if"` / `"unless"` ผ่านเสมอ · ข้อความเปล่า ๆ (String) ก็ผ่านเสมอ
## → บทเดิมทุกบทในโปรเจกต์ยังทำงานเหมือนเดิมทุกประการ ไม่ต้องแก้อะไร
##
## 🚨 **กรองที่ "ตัวเลือก" ไม่ใช่ที่ "บททั้งบท"** — ตัวละครคนเดียวกันทักทายเหมือนเดิมทุกครั้ง
## เปลี่ยนแค่ว่ามีเรื่องอะไรให้ถามได้บ้างในตอนนั้น · แยกเป็นคนละบทตามสถานะจะได้บทที่
## ก๊อปกันมาแก้คำท้ายบรรทัด แล้ววันหลังแก้ไม่ครบทุกใบ
func _filter_choices(raw: Array) -> Array:
	var out: Array = []
	for opt: Variant in raw:
		if opt is Dictionary and not _choice_condition_passes(opt):
			continue
		out.append(opt)
	return out


func _choice_condition_passes(opt: Dictionary) -> bool:
	if opt.has("if") and not _game_state_flag(str(opt["if"])):
		return false
	if opt.has("unless") and _game_state_flag(str(opt["unless"])):
		return false
	return true


## อ่านธงจาก `GameState` ตามชื่อ
##
## ⚠️ **พิมพ์ชื่อธงผิดต้อง `push_error` ไม่ใช่เงียบ ๆ ถือว่าเป็นเท็จ**
## ถือว่าเป็นเท็จเฉย ๆ = ตัวเลือกนั้นหายไปจากเกมตลอดกาลโดยไม่มีอะไรบอก
## ซึ่งดูเหมือน "เขียนบทไว้แล้วแต่ไม่เคยโผล่" — เป็นอาการที่ไล่หาสาเหตุยากที่สุดแบบหนึ่ง
func _game_state_flag(flag: String) -> bool:
	if not (flag in GameState):
		push_error("dialogue_system: ไม่มีตัวแปร `%s` ใน GameState — ตัวเลือกที่ใช้เงื่อนไขนี้จะไม่โผล่" % flag)
		return false
	return bool(GameState.get(flag))


func _input(event):
	if !is_talking:
		return
	if !event.is_action_pressed("interact"):
		return

	## 🚨 บอกว่ากินอีเวนต์นี้แล้ว — **จุดสำคัญ อย่าเอาออก**
	##
	## `NPCBase._unhandled_input()` ดัก E ไว้เพื่อเริ่มบทสนทนา และกันการเด้งซ้ำด้วยการเช็ค
	## `is_talking` ของกล่องคำพูด แต่กันไม่ได้ในจังหวะที่ **บทจบพอดีกับการกดครั้งนั้น**
	## (`_advance()` → `end_dialogue()` → `is_talking = false` เกิดในเฟรมเดียวกัน
	##  อีเวนต์เดิมไหลต่อไปถึง NPC ซึ่งเห็นว่า "ไม่ได้คุยอยู่" แล้วเริ่มบทใหม่ทันที)
	## อาการคือกด E ปิดบทแล้วบทเด้งกลับไปเริ่มบรรทัดแรกเอง
	get_viewport().set_input_as_handled()

	## รอผู้เล่นเลือกคำตอบอยู่ — กด E ต้องไม่ข้ามการพิมพ์ ไม่เลื่อนบรรทัด ไม่จบบท
	## ไม่กันไว้ = กด E หนีคำถามได้ แล้วบทเดินต่อทั้งที่ `await` ยังค้างรออยู่
	if _waiting:
		return

	_step()


## คลิกซ้ายตรงไหนก็ได้ = เลื่อนบทเหมือนกด E
##
## 🚨 **ใช้ `_unhandled_input` ไม่ใช่ `_input` (ต่างจากฝั่ง E ด้านบน) — เป็นหัวใจของข้อนี้**
## `_input` ทำงาน**ก่อน** ระบบ GUI · กินอีเวนต์ตรงนั้นเมื่อไหร่ **ปุ่ม `Next` กับปุ่มตัวเลือก
## จะกดไม่ได้ทั้งหมด** เพราะคลิกถูกดักไปก่อนที่ปุ่มจะได้เห็น
## `_unhandled_input` ทำงานหลัง GUI → คลิกที่โดนปุ่มถูกปุ่มกินไปแล้ว เหลือมาถึงตรงนี้
## เฉพาะคลิกที่ตกลงบนพื้นที่ว่าง **จึงไม่ต้องเช็คเองว่าคลิกโดนปุ่มไหนอยู่**
## (กดปุ่ม `Next` หนึ่งครั้งจึงเลื่อนบรรทัดเดียว ไม่ใช่สองบรรทัด)
##
## ⚠️ ไม่ชนกับการคลิกคุย NPC ของ `player.gd` — ตัวนั้นเช็ค `can_move` ซึ่งถูกล็อกอยู่ระหว่างบท
## ⚠️ `ClickEffect` (autoload) ใช้ `_input` และไม่กินอีเวนต์ วงกลมกระเพื่อมจึงยังขึ้นตามปกติ
func _unhandled_input(event: InputEvent) -> void:
	if not advance_on_click or not is_talking:
		return

	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return

	## รอเลือกคำตอบอยู่ — คลิกที่ว่างต้องไม่ข้ามคำถาม
	##
	## ⚠️ **ไม่กินอีเวนต์ในกรณีนี้** ต่างจากฝั่ง E ที่กินก่อนแล้วค่อยเช็ค
	## เพราะการกินคลิกทิ้งไม่ได้ช่วยอะไร (ผู้เล่นถูกล็อกอยู่แล้ว) แต่ทำให้ระบบอื่นที่รอคลิกอยู่เงียบไปด้วย
	if _waiting:
		return

	get_viewport().set_input_as_handled()
	_step()


## "ขอไปต่อหนึ่งจังหวะ" — ทางเดียวกันทั้งกด E และกดปุ่ม Next
##
## ยังพิมพ์ไม่จบ -> ข้ามการพิมพ์ให้ขึ้นเต็ม
## พิมพ์จบแล้ว   -> ไปบรรทัดถัดไป (หมดบทแล้วก็ปิดบทเอง ผ่าน `_advance()`)
func _step() -> void:
	if text_label == null:
		return

	# ยังพิมพ์ไม่จบ -> กดครั้งแรกข้ามการพิมพ์
	if text_label.visible_ratio < 1.0:
		if tween:
			tween.kill()
		# ต้องหยุดเสียงเองตรงนี้ เพราะ kill() ทำให้ callback ที่ต่อไว้ไม่ทำงาน
		_stop_typing_sound()
		text_label.visible_ratio = 1.0
		_restart_hold_if_needed()
		return

	_advance()


## ตั้งเวลาปิดเองใหม่ หลังผู้เล่นกด E ข้ามการพิมพ์
##
## 🚨 เวลาของคีย์ "hold" ถูกต่อท้าย tween ตัวเดียวกับการพิมพ์ (พิมพ์ → รอ → ไปต่อ)
## กด E ข้ามการพิมพ์ = `kill()` ทั้งสาย เวลาที่ตั้งไว้จึงหายไปด้วย
## ไม่ตั้งใหม่ = ข้ามการพิมพ์แล้วบทค้างรอกดตลอดไป ทั้งที่บรรทัดนี้ควรปิดเอง
func _restart_hold_if_needed() -> void:
	var line: Dictionary = dialogue_queue[index]
	if not line.has("hold"):
		return

	tween = create_tween()
	tween.tween_interval(float(line["hold"]))
	tween.tween_callback(_advance)


## ไปบรรทัดถัดไป หรือจบถ้าหมดแล้ว
## แยกออกมาเพราะถูกเรียกจาก 2 ทาง: ผู้เล่นกด E และ tween ของคีย์ "hold"
func _advance() -> void:
	if not is_talking:
		return
	## บรรทัดที่มีคีย์ "hold" ตั้ง tween เดินต่อเองไว้ — ถ้าบรรทัดนั้นมีตัวเลือกด้วย
	## เวลาจะเดินไปข้างหน้าทั้งที่ยังรอกดอยู่ ต้องกันตรงนี้ด้วย ไม่ใช่แค่ที่ _input
	if _waiting:
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
