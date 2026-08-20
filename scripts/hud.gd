extends CanvasLayer
## ==============================================
## ช่องของที่ถืออยู่ (HUD) — แนบที่โหนดราก `HUD` ของ `hud.tscn`
## ==============================================
## พาแนลเรียงกันด้านล่างจอ · ช่องที่มีของจะโชว์รูปไอเทม · ช่องที่ผู้เล่นเลือกขึ้นกรอบสี
##
## ⚠️ **นับพาแนลจากลูกในซีนอัตโนมัติ ไม่ผูกกับชื่อ `Panel1` / `Panel2`**
## เพิ่ม/ลดช่องในซีนได้เลย ไม่ต้องแตะโค้ด (กฎเดียวกับสมุดจดข้อกำหนดใน `npc_note.gd`
## และช่องยืนใน `stand_zone.gd`) · ลำดับที่เห็นบนจอ = ลำดับโหนดในซีน
##
## ⚠️ **รูปไอเทมกับกรอบเลือกสร้างจากโค้ดทั้งคู่ ไม่ต้องเพิ่ม node ในซีน**
## `hud.tscn` มีแค่พาแนลเปล่า ๆ — วันหลังเพิ่มช่องที่ 4 ก็แค่ก๊อปพาแนลในซีน

## ส่งตอนผู้เล่นเปลี่ยนช่องที่เลือก (-1 = ไม่ได้เลือกช่องไหน)
signal slot_selected(index: int)

## รูปกล่องที่วาวาฝากมา
##
## ⚠️ ชื่อไฟล์เป็น `.PNG` ตัวใหญ่ — `res://` ของ Godot สนตัวพิมพ์ตอน export
## พิมพ์เป็น `.png` จะใช้ได้บน Windows แต่รูปหายตอน build จริง
@export var box_icon: Texture2D = preload("res://item/ItemBox.PNG")

## กล่องไปอยู่ช่องไหน (0 = พาแนลแรก)
@export var box_slot: int = 0

@export_group("กรอบตอนเลือก")
## สีกรอบของช่องที่ผู้เล่นเลือกอยู่
@export var selected_border_color: Color = Color("fbebe3")
@export var selected_border_width: int = 4
@export_group("")

## ระยะจากขอบพาแนลถึงรูปไอเทม — รูปเต็มช่องพอดีจะทับกรอบตอนเลือกจนมองไม่เห็น
@export var icon_padding: float = 10.0

## พาแนลทุกช่องเรียงตามลำดับในซีน
var _slots: Array[Panel] = []
## รูปไอเทมของแต่ละช่อง (สร้างจากโค้ด ดัชนีตรงกับ `_slots`)
var _icons: Array[TextureRect] = []
## StyleBox สองชุดของแต่ละช่อง — ก๊อปจากใบในซีนคนละใบต่อช่อง
var _normal_styles: Array[StyleBox] = []
var _selected_styles: Array[StyleBox] = []

## ช่องที่เลือกอยู่ (-1 = ยังไม่ได้เลือก)
var _selected: int = -1


func _ready() -> void:
	_collect_slots()
	if _slots.is_empty():
		push_warning("hud.gd: ไม่พบพาแนลสักช่องใน HUD — ช่องของที่ถืออยู่จะไม่แสดงอะไรเลย")
		return

	## 🚨 อ่านสถานะจาก GameState ตอนเปิดฉาก ไม่ใช่รอสัญญาณอย่างเดียว
	## HUD ถูก instance ใหม่ทุกฉาก — สัญญาณ "หยิบกล่อง" ยิงไปตั้งแต่ฉากห้องใต้ตึกแล้ว
	## รอสัญญาณอย่างเดียว = เดินขึ้นชั้น 2 ปุ๊บกล่องหายจากช่องทั้งที่ยังถืออยู่ในมือ
	_refresh_box(GameState.carrying_box)
	GameState.carrying_box_changed.connect(_refresh_box)


## เก็บพาแนลลูกทุกตัว แล้วเตรียมรูป + StyleBox ให้ทีละช่อง
##
## ⚠️ ค้นลึกลงไปทุกชั้น เพราะในซีนพาแนลอยู่ใต้ `HBoxContainer` อีกที
## วันหลังห่อเพิ่มอีกชั้น (เช่นใส่กรอบพื้นหลังรวม) ก็ยังหาเจอ
func _collect_slots() -> void:
	for panel: Panel in find_children("*", "Panel", true, false):
		var index: int = _slots.size()
		_slots.append(panel)
		_icons.append(_make_icon(panel))
		_build_styles(panel)

		## คลิกที่ช่อง = เลือกช่องนั้น
		panel.gui_input.connect(_on_slot_gui_input.bind(index))
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## รูปไอเทมในช่อง — ซ่อนไว้ก่อน ค่อยโผล่ตอนมีของ
func _make_icon(panel: Panel) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	## ⚠️ ต้องให้คลิกทะลุไปโดนพาแนล ไม่งั้นช่องที่มีของจะกดเลือกไม่ได้
	## (รูปคลุมเต็มช่อง คลิกยังไงก็โดนรูปก่อน)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false

	panel.add_child(icon)

	## ⚠️ ตั้ง preset ก่อนแล้วค่อยใส่ระยะขอบ — `set_anchors_preset()` ล้าง offset เป็น 0 ให้เอง
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = icon_padding
	icon.offset_top = icon_padding
	icon.offset_right = -icon_padding
	icon.offset_bottom = -icon_padding
	return icon


## เตรียม StyleBox 2 ใบต่อช่อง — ปกติ กับ ตอนถูกเลือก
##
## 🚨 **ก๊อปคนละใบต่อช่อง ไม่แก้ใบในซีนโดยตรง**
## ในซีนพาแนลทั้ง 3 ช่องใช้ `StyleBoxFlat_n2snw` **ใบเดียวกัน** —
## แก้ใบนั้นตรง ๆ = กรอบขึ้นพร้อมกันทั้งสามช่อง แล้วจะดูเหมือนเลือกทุกช่องอยู่ตลอดเวลา
## (กับดักเดียวกับปุ่มตัวเลือกในกล่องคำพูดที่ใช้ StyleBox ร่วมกัน)
func _build_styles(panel: Panel) -> void:
	var base: StyleBox = panel.get_theme_stylebox("panel")
	if base == null:
		base = StyleBoxFlat.new()

	var normal: StyleBox = base.duplicate()
	var selected: StyleBox = base.duplicate()

	if selected is StyleBoxFlat:
		var flat := selected as StyleBoxFlat
		flat.border_color = selected_border_color
		flat.set_border_width_all(selected_border_width)
	else:
		push_warning("hud.gd: StyleBox ของพาแนลไม่ใช่ StyleBoxFlat — ใส่กรอบตอนเลือกไม่ได้")

	_normal_styles.append(normal)
	_selected_styles.append(selected)
	panel.add_theme_stylebox_override("panel", normal)


## ==============================================
## ของในช่อง
## ==============================================

## หยิบกล่องขึ้น = รูปโผล่ที่ช่องแรก · วางลง = รูปหาย
##
## ⚠️ **วางกล่องเสร็จแล้วรูปหายไปจากช่องด้วย** — ช่องนี้คือ "ของที่ถืออยู่ตอนนี้"
## ไม่ใช่ "รายการงานที่เคยทำ" · ส่งของแล้วยังค้างอยู่ในมือจะอ่านว่ายังไม่ได้ส่ง
func _refresh_box(carrying: bool) -> void:
	set_item(box_slot, box_icon if carrying else null)


## ใส่/เอาของออกจากช่อง — ส่ง null = ช่องว่าง
func set_item(slot: int, texture: Texture2D) -> void:
	if slot < 0 or slot >= _icons.size():
		push_warning("hud.gd: ไม่มีช่องที่ %d (มีทั้งหมด %d ช่อง)" % [slot, _icons.size()])
		return

	_icons[slot].texture = texture
	_icons[slot].visible = texture != null


## ==============================================
## ช่องที่ผู้เล่นเลือก
## ==============================================

## กดเลข 1-9 = เลือกช่องนั้น
##
## 🚨 **อ่าน keycode ตรง ๆ ไม่ได้เพิ่ม input action ใหม่**
## การเพิ่ม action ต้องเขียนลง `project.godot` ซึ่งโปรเจกต์นี้เติมเองไม่ได้ —
## Godot เขียนไฟล์ใหม่จากรายการในหน่วยความจำทุกครั้งที่ผู้ใช้แตะ Project Settings
## แล้วของที่เติมจากข้างนอกหายเงียบ (เกิดกับ autoload มาแล้ว 2 ครั้ง ดู DEVLOG 2026-07-30)
## · อยากได้ action จริงต้องไปเพิ่มเองใน Project Settings แล้วค่อยแก้ตรงนี้
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	var index: int = key.keycode - KEY_1
	if index < 0 or index >= _slots.size():
		return

	get_viewport().set_input_as_handled()
	select_slot(index)


## คลิกที่ช่อง = เลือกช่องนั้น
##
## ⚠️ พาแนลกินคลิกไปแล้วเพราะเป็น Control ที่ `mouse_filter = STOP`
## → คลิกตรงพาแนล **จะไม่เลื่อนบทสนทนา** (ระบบนั้นดักที่ `_unhandled_input`
## ซึ่งได้เฉพาะคลิกที่ไม่โดน GUI) เป็นพฤติกรรมที่ถูก แต่ต้องรู้ไว้
func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	select_slot(index)


## เลือกช่อง — เลือกช่องเดิมซ้ำ = ยกเลิกการเลือก
func select_slot(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return

	## กดช่องเดิมซ้ำแล้วปล่อยให้ติดค้างไว้ = ผู้เล่นเอากรอบออกไม่ได้เลย
	_selected = -1 if index == _selected else index
	_refresh_selection()
	slot_selected.emit(_selected)


## ช่องที่เลือกอยู่ (-1 = ไม่ได้เลือก)
func selected_slot() -> int:
	return _selected


## 🚨 **จุดเดียวที่สลับ StyleBox ของทุกช่อง**
## สั่งเปิด/ปิดกรอบกระจายตามแต่ละเหตุการณ์ = มีลำดับที่ทำให้กรอบค้างสองช่อง
## (บทเรียนเดียวกับ `_refresh()` ของ `drop_zone_hint.gd`)
func _refresh_selection() -> void:
	for i: int in _slots.size():
		var style: StyleBox = _selected_styles[i] if i == _selected else _normal_styles[i]
		_slots[i].add_theme_stylebox_override("panel", style)
