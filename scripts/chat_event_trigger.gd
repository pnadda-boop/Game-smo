extends Node
## ==============================================
## เหตุการณ์ในฉากเกิดขึ้น → โทรศัพท์เด้งขึ้นมาพร้อมข้อความใหม่
## ==============================================
## แนบที่โหนด `Node` เปล่า ๆ ในซีนแมพ (ตอนนี้ใช้ที่ `level_2_1.tscn` — วางกล่องเสร็จ → โชทักในกลุ่มสโม)
##
## 🚨 **แยกออกมาเป็นสคริปต์ต่างหาก ไม่ยัดลง `box_drop_point.gd`**
## ไฟล์นั้นเขียนกำกับไว้เองว่าสัญญาณ `placed` มีไว้ "ให้เนื้อเรื่อง/เควสต์ดักต่อโดยไม่ต้องแก้ไฟล์นี้"
## จุดวางกล่องเป็น**ของในฉาก** ส่วนแชทที่เด้งตามมาเป็น**เนื้อเรื่อง** — คนละอายุกัน
## วันหลังเปลี่ยนใจให้แชทเด้งตอนอื่นแทน ก็ย้ายโหนดนี้ ไม่ต้องแตะระบบวางกล่องเลย
##
## ⚠️ **ใช้ `Chat.tscn` ใบเดียวกับฉาก `wokeup`** — สร้างจากโค้ดตอนถึงคิว ไม่ได้วางค้างไว้ในซีน
## (`wokeup.gd` ก็ทำแบบเดียวกัน) UI แชททั้งใบอยู่บนจอแค่ช่วงสั้น ๆ ไม่ต้องแบกไว้ทั้งฉาก

## เปิดแชทเรียบร้อยแล้ว / ผู้เล่นเก็บโทรศัพท์แล้ว — เผื่อเนื้อเรื่องอยากดักต่อ
signal chat_opened
signal chat_closed

const CHAT := preload("res://Chat.tscn")

## คีย์ใน `ChatDatabase.EVENTS` — ตัวนี้บอกทั้งบทและกลุ่มที่จะเปิด
@export var event_id: String = "box_delivered"

## จุดวางกล่องที่รอสัญญาณ `placed` อยู่
##
## ⚠️ **ปล่อยว่างได้ = ค้นหา `BoxDropPoint` ในฉากให้เอง**
## ซีนชั้น 2 ถูกจัดกลุ่มใหม่บ่อย (`AllLevel2` → `Level2_1` → …) path แบบ `$ชื่อโหนด`
## พังเงียบทุกครั้งที่ห่อเพิ่มอีกชั้น และ `--import` จับไม่ได้เพราะเป็นการค้นตอนรัน
@export var drop_point_path: NodePath

@export_group("จังหวะ")
## หน่วงหลังวางกล่องเสร็จ ก่อนโทรศัพท์จะเด้ง — ให้ผู้เล่นได้เห็นกล่องลงที่ก่อน
@export var open_delay: float = 1.2
## หน่วงหลังประวัติแชทเก่าขึ้นครบ ก่อนข้อความใหม่จะเริ่มเข้ามา
@export var message_delay: float = 0.8
@export var close_fade_time: float = 0.25
@export_group("")

## โทรศัพท์ที่เปิดอยู่ (null = ไม่ได้เปิด)
var _chat: CanvasLayer = null

## 🚨 ปิดไม่ได้จนกว่าข้อความจะมาถึงครบ
## เหตุการณ์นี้เกิดครั้งเดียวตลอดเกม — ผู้เล่นที่รัวปุ่มอยู่พอดีตอนโทรศัพท์เด้ง
## จะปิดทิ้งก่อนโชพิมพ์เสร็จ แล้ว**ไม่มีทางกลับมาอ่านได้อีกเลย**
var _can_close: bool = false


func _ready() -> void:
	set_process_unhandled_input(false)

	var point: Node = _find_drop_point()
	if point == null:
		push_error("chat_event_trigger.gd: ไม่พบจุดวางกล่อง (BoxDropPoint) — แชทหลังวางกล่องจะไม่เด้ง")
		return

	## CONNECT_ONE_SHOT: วางได้ครั้งเดียวอยู่แล้ว แต่กันไว้ไม่ให้เปิดโทรศัพท์ซ้อนกันสองใบ
	## ถ้าวันหลังมีระบบหยิบ-วางซ้ำได้
	point.placed.connect(_on_box_placed, CONNECT_ONE_SHOT)


## หาจุดวางกล่อง — ตามช่องที่กรอกไว้ก่อน ไม่มีค่อยค้นทั้งฉาก
##
## ⚠️ ค้นจาก `get_tree().current_scene` ไม่ใช่จากตัวเอง — โหนดนี้อยู่ใน `level_2_1.tscn`
## ซึ่งถูก instance เข้าไปใน `all_level_2.tscn` อีกที ค้นจากตัวเองจะเห็นแค่พี่น้องในซีนย่อย
func _find_drop_point() -> Node:
	if not drop_point_path.is_empty():
		var by_path: Node = get_node_or_null(drop_point_path)
		if by_path != null:
			return by_path
		push_warning("chat_event_trigger.gd: `drop_point_path` ชี้ไปที่ไม่มีอยู่จริง — ค้นหาเองแทน")

	var root: Node = get_tree().current_scene
	if root == null:
		return null

	var found: Array[Node] = root.find_children("*", "BoxDropPoint", true, false)
	if found.is_empty():
		return null
	if found.size() > 1:
		push_warning("chat_event_trigger.gd: เจอจุดวางกล่าง %d จุดในฉาก — ใช้จุดแรก (`%s`) · กรอก `drop_point_path` ถ้าต้องการจุดอื่น" \
			% [found.size(), found[0].name])
	return found[0]


func _on_box_placed(_point: Node) -> void:
	## 🚨 **ล็อกตั้งแต่วินาทีที่วางเสร็จ ไม่ใช่ตอนโทรศัพท์เด้ง**
	## ระหว่าง `open_delay` ผู้เล่นยังกดเดินได้ แล้วจะโดนหยุดกลางก้าวตอนแผงแชทโผล่
	## ซึ่งดูเหมือนเกมค้าง ไม่ใช่เหมือน "มีสายเข้า"
	## · ช่วงนี้ผู้เล่นเพิ่งกด E วางกล่องอยู่ดี ยังไม่ทันขยับ การหยุดคุมจึงไม่สะดุด
	_set_player_locked(true)

	await get_tree().create_timer(open_delay).timeout

	## ออกจากฉากระหว่างหน่วงอยู่ (ขึ้นบันได/เปลี่ยนฉาก) — โหนดนี้ถูกลบไปแล้ว
	## ไม่เช็คแล้วจะได้ error "call function on previously freed instance"
	if not is_inside_tree():
		return

	_open_chat()


func _open_chat() -> void:
	var event: Dictionary = ChatDatabase.get_event(event_id)
	if event.is_empty():
		## ⚠️ ปลดล็อกก่อนออก — ล็อกไปแล้วตั้งแต่ตอนวางกล่อง
		## ไม่ปลดคืน = พิมพ์ `event_id` ผิดแล้ว **ผู้เล่นขยับไม่ได้อีกเลยตลอดฉาก**
		## ซึ่งแย่กว่าการที่แชทไม่เด้งเฉย ๆ มาก
		_set_player_locked(false)
		return

	var group_id: String = event.get("group", "")
	var lines: Array = event.get("lines", [])

	_chat = CHAT.instantiate() as CanvasLayer

	## 🚨 **ต้องปิดสองช่องนี้ก่อน `add_child()` เสมอ**
	## `Chat.tscn` ถูกตั้งค่าไว้สำหรับเนื้อเรื่องตอนเช้าโดยเฉพาะ:
	##   `popout_after_group = "smo"`  → กลุ่มสโมคุยจบ = กลุ่มสวัสดิการเด้งตามมา
	##   `end_after_group = "sawat"`   → กลุ่มสวัสดิการจบ = **เฟดไป `res://p.tscn`**
	## ไม่ปิด = พอโชทักเสร็จ บทขนของตอนเช้าจะเล่นซ้ำ แล้วเกมจะพาผู้เล่นไปลานจอดรถ
	## ตั้งก่อน `add_child` เพราะ `_ready()` ของ `phone.gd` อ่านค่าพวกนี้ไปต่อสัญญาณทันที
	_chat.start_group = group_id
	_chat.popout_after_group = ""
	_chat.end_after_group = ""

	add_child(_chat)

	var view: Node = _chat.get_group_view(group_id)
	if view == null:
		push_error("chat_event_trigger.gd: `Chat.tscn` ไม่มีห้องของกลุ่ม '%s'" % group_id)
		_close_chat()
		return

	## ปุ่มย้อนกลับที่หัวแชท = "เก็บโทรศัพท์" ในบริบทนี้ ไม่ใช่ "กลับไปหน้ารายการแชท"
	##
	## ⚠️ `phone.gd` ต่อ `back_pressed` → `show_list()` ไว้ให้แล้วตอน `_ready()`
	## ปล่อยไว้จะได้ห้องแชทที่ถูกซ่อนทั้งหมด + warning "ยังไม่มี node หน้ารายการแชท"
	## แล้วเหลือจอเปล่าที่ปิดไม่ได้ — ต้องถอดของเดิมออกก่อนถึงจะต่อของเราได้
	if view.back_pressed.is_connected(_chat.show_list):
		view.back_pressed.disconnect(_chat.show_list)
	view.back_pressed.connect(_request_close)

	chat_opened.emit()

	## รอประวัติแชทเก่าขึ้นครบก่อน แล้วค่อยให้ข้อความใหม่เข้ามา
	##
	## ⚠️ `open()` ยิง `chat_finished` แม้ห้องนั้นไม่มี `INCOMING` เลย (ดู `chat_group.gd`)
	## และยิงหลัง `_scroll_to_bottom()` ซึ่งรอ 2 เฟรม → ตอนบรรทัดนี้ทำงาน สัญญาณยังไม่มา
	## จึงไม่มีปัญหา "await สัญญาณที่ยิงไปแล้ว" ที่จะค้างตลอดกาล
	await view.chat_finished
	await get_tree().create_timer(message_delay).timeout
	await view.receive_messages(lines)

	## อ่านจบแล้วถึงปิดได้ · เปิดรับปุ่มตอนนี้ ไม่ใช่ตั้งแต่แรก
	_can_close = true
	set_process_unhandled_input(true)


## กด E หรือ Esc = เก็บโทรศัพท์
##
## ⚠️ ใช้ `_unhandled_input` ไม่ใช่ `_input` — คลิกที่ปุ่มย้อนกลับต้องถึงตัวปุ่มก่อน
## (เหตุผลเดียวกับที่ `dialogue_system.gd` ดักคลิกที่ `_unhandled_input` ดู DEVLOG 2026-08-20 รอบ 6)
func _unhandled_input(event: InputEvent) -> void:
	if not _can_close or _chat == null:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_request_close()


func _request_close() -> void:
	if not _can_close:
		return
	_can_close = false
	set_process_unhandled_input(false)
	_close_chat()


func _close_chat() -> void:
	if _chat == null:
		_set_player_locked(false)
		return

	var chat: CanvasLayer = _chat
	## ล้าง reference ก่อน await — กันกดปิดซ้ำระหว่างที่ยังจางอยู่
	_chat = null

	if close_fade_time > 0.0:
		var tween: Tween = create_tween()
		tween.tween_property(chat, "offset", chat.offset + Vector2(0, 140), close_fade_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await tween.finished

	chat.queue_free()
	_set_player_locked(false)
	chat_closed.emit()


## ล็อกผู้เล่นระหว่างดูโทรศัพท์
##
## ⚠️ ค่าเดียวกับที่ `dialogue_system.gd` ใช้ล็อกระหว่างบทสนทนา — ไม่ได้สร้างระบบล็อกใหม่
## ไม่ล็อกไว้ = ผู้เล่นเดินไปทั่วแมพได้ทั้งที่มีแผงแชทบังจออยู่ครึ่งจอ
func _set_player_locked(locked: bool) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or not "can_move" in player:
		return
	player.can_move = not locked
