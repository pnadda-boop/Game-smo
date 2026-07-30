extends HBoxContainer
## ==============================================
## บับเบิลข้อความหนึ่งใบในกรุ๊ปแชท
## ==============================================
## ติดสคริปต์นี้ที่ node ราก (MessageBubble) ของ message_bubble.tscn
##
## โครงสร้าง node ที่สคริปต์นี้ใช้:
##   MessageBubble (HBoxContainer)  <- สคริปต์นี้
##   ├── TextureRect  (TextureRect)          รูปโปรไฟล์ผู้ส่ง (อยู่นอกบับเบิล)
##   └── Column       (VBoxContainer)
##       ├── SenderName  (Label)
##       └── PanelContainer
##           └── MarginContainer
##               └── Content  (VBoxContainer)
##                   ├── TextureRect  (TextureRect)   รูปแนบในข้อความ (ซ่อนถ้าไม่มีรูป)
##                   └── Text         (RichTextLabel)
##
## ไม่ต้องตั้ง custom_minimum_size / fit_content / scroll_active ใน editor
## สคริปต์นี้เซ็ตให้เองทุกครั้งตอน setup() เพื่อให้บับเบิลกว้างและสูงตามเนื้อหาจริง

## เผื่อความกว้างเล็กน้อยกันข้อความตกบรรทัดจากการปัดเศษ
## (ค่าที่วัดจากฟอนต์กับที่ container คำนวณจริงอาจต่างกันเศษพิกเซล)
const TEXT_PADDING := 4.0

## ความกว้างสูงสุดของบับเบิล - เกินกว่านี้จะตัดบรรทัดแทนที่จะยืดยาวออกไป
@export var max_width: float = 420.0

## ขนาดรูปโปรไฟล์ (รูปต้นฉบับ 256x256 ย่อลงมา)
## ปรับได้ใน Inspector ที่ node MessageBubble ถ้าอยากได้ใหญ่/เล็กกว่านี้
@export var avatar_size: float = 56.0

@onready var avatar: TextureRect = get_node_or_null("TextureRect")
@onready var column: VBoxContainer = get_node_or_null("Column")
@onready var sender_name: Label = get_node_or_null("Column/SenderName")
@onready var attach_image: TextureRect = get_node_or_null("Column/PanelContainer/MarginContainer/Content/TextureRect")
@onready var text_label: RichTextLabel = get_node_or_null("Column/PanelContainer/MarginContainer/Content/Text")

## เก็บไว้เพื่อเอากลับมาแสดงได้ ตอนสลับซ่อน/โชว์รูปโปรไฟล์
var _avatar_texture: Texture2D = null
## ข้อความฝั่งขวา (น้ำฟ้า) ไม่มีรูปอยู่แล้ว จึงไม่ต้องจัดการเรื่องรูปซ้ำ
var _is_right: bool = false


## ตั้งค่าบับเบิลจาก sender_id ที่มีใน ChatDatabase
## เรียกหลัง add_child() แล้วเท่านั้น (ต้องรอให้ @onready ทำงานก่อน)
## image = รูปแนบในข้อความ ใส่ null ถ้าเป็นข้อความล้วน
func setup(sender_id: String, text: String, image: Texture2D = null) -> void:
	if text_label == null:
		push_error("message_bubble.gd: ไม่พบ Column/PanelContainer/MarginContainer/Content/Text — เช็คชื่อ node")
		return

	var sender := ChatDatabase.get_sender(sender_id)
	if sender.is_empty():
		return

	_setup_text(text)
	_setup_attach_image(image)

	## ให้ Column กว้างเท่าเนื้อหาจริง ไม่ยืดเต็มแถว
	## (ถ้ายืดเต็ม การจัดชิดซ้าย/ขวาจะไม่มีผลเพราะไม่เหลือที่ว่างให้ดัน)
	if column:
		column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	_avatar_texture = sender["avatar"]
	_is_right = sender["side"] == "right"

	if _is_right:
		## น้ำฟ้าเป็นผู้ส่งเอง -> ชิดขวา ไม่ต้องบอกว่าใครพูด
		alignment = BoxContainer.ALIGNMENT_END
		if avatar:
			avatar.hide()
		if sender_name:
			sender_name.hide()   ## อยากให้โชว์ชื่อตัวเองด้วย ลบ 2 บรรทัดนี้ทิ้ง
	else:
		alignment = BoxContainer.ALIGNMENT_BEGIN
		if avatar:
			avatar.show()
			avatar.texture = _avatar_texture
			avatar.custom_minimum_size = Vector2(avatar_size, avatar_size)
			avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			## เกาะขอบบน ไม่งั้นพอข้อความยาวหลายบรรทัด รูปจะลอยไปกลางบับเบิล
			avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if sender_name:
			sender_name.show()
			sender_name.text = sender["name"]


## ซ่อน/โชว์รูปโปรไฟล์ - ใช้ตอนข้อความติดกันจากคนเดิม (สไตล์ Messenger)
## รูปจะขึ้นแค่ที่ข้อความสุดท้ายของชุด ข้อความก่อนหน้าเว้นที่ว่างไว้เฉย ๆ
##
## ⚠️ ต้องลบแค่ texture ห้ามใช้ hide()
## เพราะ Container ถือว่า node ที่ hide ไม่มีตัวตน แล้วบับเบิลจะเลื่อนไปชิดซ้าย
## ไม่ตรงแนวกับบับเบิลที่มีรูป
func set_avatar_visible(shown: bool) -> void:
	if avatar == null or _is_right:
		return
	avatar.texture = _avatar_texture if shown else null


## ซ่อน/โชว์ชื่อผู้ส่ง - ชื่อขึ้นแค่ข้อความแรกของชุด
## อันนี้ใช้ hide() ได้ เพราะอยากให้บับเบิลขยับขึ้นมาชิด ไม่ต้องเว้นที่
func set_name_visible(shown: bool) -> void:
	if sender_name == null or _is_right:
		return
	sender_name.visible = shown


## ใส่ข้อความ + คุมความกว้าง/ความสูงของบับเบิล
func _setup_text(text: String) -> void:
	text_label.text = text
	## RichTextLabel ใน container ต้องตั้ง 2 ค่านี้ ไม่งั้นสูงคงที่แล้วมี scrollbar ในบับเบิล
	text_label.fit_content = true
	text_label.scroll_active = false

	var font_info := _get_font_info()
	var font: Font = font_info[0]
	var font_size: int = font_info[1]
	if font == null:
		push_warning("message_bubble.gd: Text ไม่มีฟอนต์ ข้ามการคำนวณความกว้าง")
		return

	## วัดทีละบรรทัดแล้วเอาบรรทัดที่กว้างสุด
	## (get_string_size ไม่เข้าใจ \n จะนับรวมเป็นบรรทัดเดียวยาวเหยียด)
	var widest := 0.0
	for line in text.split("\n"):
		var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		widest = maxf(widest, w)

	## ปักความกว้างเสมอ = ความกว้างข้อความจริง แต่ไม่เกิน max_width
	##
	## ⚠️ ห้ามตั้งเป็น 0 เพื่อ "ปล่อยให้หดตามเนื้อหา" เด็ดขาด
	## วิธีนั้นใช้ได้กับ Label แต่ RichTextLabel ที่เปิด autowrap
	## มี minimum width เกือบเป็นศูนย์ (มันยอมตัดทีละตัวอักษรได้)
	## ถ้าไม่ปัก container จะบีบจนบับเบิลเหลือกว้างเท่าตัวอักษรเดียว
	##
	## y = 0 เสมอ เพื่อให้ความสูงมาจากจำนวนบรรทัดจริง ไม่ใช่ค่าตายตัว
	var target_width := minf(widest + TEXT_PADDING, max_width)
	text_label.custom_minimum_size = Vector2(target_width, 0.0)


## รูปแนบในข้อความ - ซ่อนไว้ถ้าไม่ได้ส่งรูปมา
func _setup_attach_image(image: Texture2D) -> void:
	if attach_image == null:
		return
	if image == null:
		attach_image.hide()
	else:
		attach_image.show()
		attach_image.texture = image


## RichTextLabel กับ Label ใช้ชื่อ theme override คนละชื่อ
## รองรับทั้งคู่ เผื่อวันหลังเปลี่ยนกลับไปใช้ Label
func _get_font_info() -> Array:
	if text_label is RichTextLabel:
		return [
			text_label.get_theme_font("normal_font"),
			text_label.get_theme_font_size("normal_font_size"),
		]
	return [
		text_label.get_theme_font("font"),
		text_label.get_theme_font_size("font_size"),
	]
