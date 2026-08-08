extends CanvasLayer
## ==============================================
## หน้าจอโทรศัพท์ - ตัวคุมว่าตอนนี้แสดงอะไร
## ==============================================
## ติดสคริปต์นี้ที่ node ราก (Chat) ของ Chat.tscn
##
## สคริปต์นี้ "ไม่ยุ่ง" กับข้อความหรือหน้าตาของห้องแชท
## งานทั้งหมดนั้นอยู่ที่ chat_group.gd ของแต่ละ instance
## ตัวนี้ทำแค่ตัดสินใจว่าจะโชว์หน้ารายการ หรือโชว์ห้องไหน
##
## โครงสร้างที่คาดหวัง:
##   Chat (CanvasLayer)  <- สคริปต์นี้
##   ├── ChatList   (Control, ไม่บังคับ)         หน้ารายการแชท
##   ├── Group_smo  (instance ของ Chat_group.tscn)  group_id = "smo"
##   └── Group_...  (instance เพิ่มได้ตามต้องการ)
##
## เพิ่มกลุ่มใหม่ = ลาก Chat_group.tscn เข้ามาอีก 1 instance แล้วตั้ง group_id
## ไม่ต้องแก้สคริปต์นี้เลย

## ส่งเมื่อเปลี่ยนหน้า (group_id ว่าง = กลับไปหน้ารายการ)
signal view_changed(group_id: String)

## เปิดกลุ่มไหนทันทีตอนเริ่ม - ปล่อยว่าง = แสดงหน้ารายการแชท
## ใช้ตอนทดสอบ หรือตอนเนื้อเรื่องพาเข้าห้องใดห้องหนึ่งโดยตรง
@export var start_group: String = "smo"

## --- ทรานสิชั่นตอนแผงแชทโผล่ ---
## แผงแชทเลื่อนขึ้นมาจากด้านล่างพร้อมจางเข้า เหมือนยกโทรศัพท์ขึ้นมาดู
## ถ้าเด้งขึ้นมาเฉย ๆ จะดูเหมือนภาพกระตุก ไม่ใช่การเปลี่ยนฉาก
@export_group("ทรานสิชั่นตอนเปิดแชท")
@export var open_fade_time: float = 0.45
## เริ่มเลื่อนจากตรงไหน เทียบกับตำแหน่งจริงของแผง (y บวก = โผล่จากด้านล่าง)
@export var open_slide_from: Vector2 = Vector2(0, 140)
@export_group("")

## --- กลุ่มที่เด้งออกมาข้าง ๆ ---
## เล่าเรื่อง: วาวาบอกในกลุ่ม SMO ให้ไปเช็คกลุ่มสวัสดิการ
## พอกลุ่มแรกคุยจบ กลุ่มที่สองจึงเลื่อนออกมาโผล่ข้าง ๆ แทนที่จะต้องกดหาเอง
## ทั้งสองกลุ่มค้างอยู่บนจอพร้อมกัน ผู้เล่นเห็นได้ว่าเรื่องต่อกันยังไง
@export_group("กลุ่มที่เด้งออกมา")
## กลุ่มไหนคุยจบแล้วถึงจะเด้ง - ปล่อยว่าง = ไม่เด้งเอง (ให้โค้ดอื่นสั่ง popout_group())
@export var popout_after_group: String = "smo"
## กลุ่มที่จะเด้งออกมา
@export var popout_target_group: String = "sawat"
## เด้งไปโผล่ตรงไหน เทียบกับตำแหน่งเดิมของกลุ่มแรก
## ค่าติดลบ = ไปทางซ้าย (แผงกว้าง 600px + เว้นช่อง 20px)
@export var popout_offset: Vector2 = Vector2(-620, 0)
## เริ่มเลื่อนจากตรงไหน - บวกจาก popout_offset ให้ดูเหมือนไถลออกมาจากหลังแผงแรก
@export var popout_slide_from: Vector2 = Vector2(160, 0)
@export var popout_time: float = 0.45
## หน่วงหลังกลุ่มแรกคุยจบ ก่อนกลุ่มใหม่จะเด้ง - เผื่อเวลาให้ผู้เล่นอ่านข้อความสุดท้าย
@export var popout_delay: float = 1.2
@export_group("")

## --- คุยจบแล้วไปต่อ ---
## ตอบตัวเลือกในกลุ่มสุดท้ายเสร็จ = จบฉากแชท เฟดไปฉากถัดไปเลย
@export_group("คุยจบแล้วเปลี่ยนฉาก")
## กลุ่มไหนคุยจบแล้วถึงจะเปลี่ยนฉาก - ปล่อยว่าง = ไม่เปลี่ยน (อยู่หน้าแชทต่อ)
@export var end_after_group: String = "sawat"
@export_file("*.tscn") var end_scene: String = "res://p.tscn"
## ค้างไว้กี่วินาทีหลังตอบ ก่อนเริ่มเฟด - ให้ผู้เล่นได้เห็นข้อความที่ตัวเองส่ง
@export var end_delay: float = 1.2
## ชื่อฉากอินโทรที่จะฝากไปให้ฉากปลายทางเล่น (ดู GameState.pending_intro)
@export var end_intro_id: String = "arrive_bus"
@export_group("")

const SCENE_TRANSITION := preload("res://scene_transition.tscn")

## หน้ารายการแชท (ไม่บังคับ - ยังไม่มีก็ทำงานได้)
var chat_list: Control = null
## group_id -> instance ของห้องแชท
var _groups: Dictionary = {}
## group_id -> ตำแหน่งที่ตั้งไว้ในซีน
## ต้องจำไว้ตั้งแต่ก่อนเริ่มขยับ ไม่งั้นทรานสิชั่นรอบสองจะคำนวณจากตำแหน่งที่เพี้ยนไปแล้ว
var _base_pos: Dictionary = {}
var _current_group: String = ""
## กลุ่มที่เด้งออกมาแล้ว - ต้องไม่ถูกซ่อนตอนสลับห้องอื่น
var _popped: Dictionary = {}
## จบฉากแชทแล้ว - ล็อกไม่ให้กดอะไรได้อีก และกันสั่งเปลี่ยนฉากซ้ำ
var _ending := false


func _ready() -> void:
	_collect_groups()

	if _groups.is_empty():
		push_error("phone.gd: ไม่พบห้องแชทเลย — ต้องมี instance ของ Chat_group.tscn อย่างน้อย 1 อัน และติดสคริปต์ chat_group.gd ที่ราก")
		return

	_setup_popout()
	_setup_ending()

	if start_group != "" and _groups.has(start_group):
		open_group(start_group)
	else:
		show_list()


## รอให้กลุ่มต้นทางคุยจบ แล้วค่อยเด้งกลุ่มปลายทางออกมา
## ใช้ CONNECT_ONE_SHOT เพราะต้องเด้งครั้งเดียว - ถ้ามีบทรอบสองในกลุ่มเดิม
## chat_finished จะยิงอีก แล้วแผงจะกระตุกเลื่อนซ้ำ
func _setup_popout() -> void:
	if popout_after_group == "" or popout_target_group == "":
		return
	if not _groups.has(popout_after_group) or not _groups.has(popout_target_group):
		return

	_groups[popout_after_group].chat_finished.connect(
		func() -> void:
			await get_tree().create_timer(popout_delay).timeout
			popout_group(popout_target_group),
		CONNECT_ONE_SHOT
	)


## เก็บห้องแชททั้งหมดที่เป็นลูกของ node นี้
## ดูจาก "มีเมธอด open() ไหม" แทนการดูชื่อ node
## -> เปลี่ยนชื่อ instance ใน editor ยังไงก็ไม่พัง (เจอปัญหานี้มาหลายรอบแล้ว)
func _collect_groups() -> void:
	_groups.clear()

	for child in get_children():
		if child is Control and child.name.begins_with("ChatList"):
			chat_list = child
			continue

		if child.has_method("open") and "group_id" in child:
			var id: String = child.group_id
			if id == "":
				push_warning("phone.gd: '%s' ไม่ได้ตั้ง group_id — ข้ามไป" % child.name)
				continue
			if _groups.has(id):
				push_warning("phone.gd: มีห้องซ้ำ group_id '%s' (%s) — ใช้ตัวแรกที่เจอ" % [id, child.name])
				continue
			_groups[id] = child
			_base_pos[id] = child.position
			## ปุ่มย้อนกลับของทุกห้อง -> กลับหน้ารายการ
			if child.has_signal("back_pressed"):
				child.back_pressed.connect(show_list)


## รอให้กลุ่มสุดท้ายคุยจบ (= ผู้เล่นตอบตัวเลือกเสร็จ) แล้วเฟดไปฉากถัดไป
##
## ⚠️ ห้ามต่อ ONE_SHOT ตรงนี้ ต้องเช็ค _ending เอง
## เพราะกลุ่มนี้อาจยิง chat_finished หลายรอบ (เช่นตัวเลือกที่มี "then" ต่อท้าย)
## แต่การเปลี่ยนฉากต้องเกิดครั้งเดียวจริง ๆ
func _setup_ending() -> void:
	if end_after_group == "" or end_scene == "":
		return
	if not _groups.has(end_after_group):
		push_warning("phone.gd: ไม่พบกลุ่ม '%s' ที่ตั้งไว้ให้จบแล้วเปลี่ยนฉาก" % end_after_group)
		return

	_groups[end_after_group].chat_finished.connect(_on_final_chat_finished)


func _on_final_chat_finished() -> void:
	if _ending:
		return
	_ending = true

	## ล็อกทันทีที่ตอบเสร็จ ไม่ต้องรอเฟด
	## ระหว่างหน่วง end_delay ผู้เล่นยังกดปุ่มย้อนกลับหรือคลิกอะไรได้ ถ้าไม่ล็อกไว้ก่อน
	lock_input()

	await get_tree().create_timer(end_delay).timeout

	## ฝากให้ฉากปลายทางรู้ว่าต้องเล่นอินโทร (รถออก + บทพูด)
	if end_intro_id != "":
		GameState.pending_intro = end_intro_id

	## ⚠️ ต้องแขวนไว้ที่ root ไม่ใช่ใต้ node นี้
	## เพราะซีนแชททั้งซีนจะถูกลบตอนเปลี่ยนฉาก ถ้าตัวเฟดอยู่ในนั้นจะหายไปด้วย
	var fade := SCENE_TRANSITION.instantiate()
	get_tree().root.add_child(fade)
	fade.transition_to(end_scene)


## ล็อกไม่ให้ผู้เล่นกดอะไรในหน้าจอแชทได้อีก
## ใช้ตอนจบฉาก - ไม่ใช่แค่ซ่อนปุ่ม เพราะการกดค้างหรือคลิกรัวยังผ่านเข้ามาได้
func lock_input() -> void:
	for id in _groups.keys():
		var view: Control = _groups[id]
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lock_buttons(view)
	if chat_list:
		chat_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lock_buttons(chat_list)


## ปิดปุ่มทุกตัวในกิ่งนั้น - ตั้ง mouse_filter ที่ตัวแม่อย่างเดียวไม่พอ
## ปุ่มลูกตั้ง filter ของตัวเองไว้ ยังรับคลิกได้อยู่
func _lock_buttons(root: Node) -> void:
	for child in root.get_children():
		if child is BaseButton:
			child.disabled = true
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lock_buttons(child)


## เปิดห้องแชทของกลุ่มนั้น ซ่อนหน้าอื่นทั้งหมด
func open_group(group_id: String) -> void:
	if not _groups.has(group_id):
		push_error("phone.gd: ไม่พบห้องแชทของกลุ่ม '%s'" % group_id)
		return

	if chat_list:
		chat_list.hide()

	## จำไว้ก่อนสลับ ว่าแผงนี้เพิ่งโผล่มาหรือเห็นอยู่แล้ว
	## เห็นอยู่แล้ว = แค่กดกลับเข้ามาดู ไม่ต้องเล่นทรานสิชั่นซ้ำให้เวียนหัว
	var was_hidden: bool = not _groups[group_id].visible

	for id in _groups.keys():
		## กลุ่มที่เด้งออกมาแล้วต้องค้างอยู่ ไม่ถูกซ่อนตอนสลับห้องอื่น
		## ไม่งั้นพอผู้เล่นกดกลับเข้ากลุ่มแรก แผงที่เพิ่งเด้งจะหายไปเฉย ๆ
		_groups[id].visible = (id == group_id) or _popped.has(id)

	if was_hidden:
		_play_open_transition(_groups[group_id], group_id)

	_current_group = group_id
	## โหลดบทครั้งแรกที่เข้า - เข้าซ้ำจะไม่โหลดใหม่ ข้อความและตำแหน่งเลื่อนคงอยู่
	_groups[group_id].open()
	view_changed.emit(group_id)


## แผงเลื่อนขึ้นมาจากด้านล่างพร้อมจางเข้า
## ตั้ง open_fade_time = 0 ที่ Inspector เพื่อปิดทรานสิชั่นได้
func _play_open_transition(view: Control, group_id: String) -> void:
	var target: Vector2 = _base_pos.get(group_id, Vector2.ZERO)
	if open_fade_time <= 0.0:
		view.position = target
		view.modulate.a = 1.0
		return

	view.position = target + open_slide_from
	view.modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(view, "position", target, open_fade_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "modulate:a", 1.0, open_fade_time * 0.8)


## เด้งห้องแชทออกมาโผล่ข้าง ๆ ห้องที่เปิดอยู่ - ทั้งสองแผงอยู่บนจอพร้อมกัน
##
## ต่างจาก open_group() ตรงที่ "ไม่ซ่อนห้องอื่น" ใช้ตอนอยากให้ผู้เล่นเห็นว่า
## ข้อความจากกลุ่มหนึ่งพาไปสู่อีกกลุ่มหนึ่ง โดยไม่ต้องกดสลับหน้าเอง
func popout_group(group_id: String) -> void:
	if not _groups.has(group_id):
		push_error("phone.gd: ไม่พบห้องแชทของกลุ่ม '%s'" % group_id)
		return

	var view: Control = _groups[group_id]
	if _popped.has(group_id):
		return

	_popped[group_id] = true

	## เทียบจากตำแหน่งที่ตั้งไว้ในซีน ไม่ใช่ (0,0)
	## ถ้าวันหลังย้ายแผงใน editor ระยะเด้งจะยังถูกอยู่
	var target: Vector2 = _base_pos.get(group_id, Vector2.ZERO) + popout_offset

	## เริ่มจากตำแหน่งที่เยื้องไปทางแผงเดิม + จางสนิท แล้วไถลออกมา
	view.position = target + popout_slide_from
	view.modulate.a = 0.0
	view.show()

	var tween := create_tween().set_parallel(true)
	tween.tween_property(view, "position", target, popout_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "modulate:a", 1.0, popout_time * 0.7)

	await tween.finished
	## เริ่มบทของกลุ่มใหม่หลังแผงเข้าที่แล้ว ไม่งั้นข้อความจะวิ่งมาพร้อมแผงที่ยังเลื่อนอยู่
	view.open()
	view_changed.emit(group_id)


## กลับไปหน้ารายการแชท ซ่อนห้องทั้งหมด
func show_list() -> void:
	for id in _groups.keys():
		_groups[id].hide()
	## กลับหน้ารายการ = ปิดโหมดเด้งคู่ ครั้งหน้าเปิดห้องไหนก็เห็นห้องนั้นห้องเดียว
	_popped.clear()

	if chat_list:
		chat_list.show()
	else:
		push_warning("phone.gd: ยังไม่มี node หน้ารายการแชท (ควรชื่อขึ้นต้นด้วย 'ChatList')")

	_current_group = ""
	view_changed.emit("")


## ห้องที่กำลังแสดงอยู่ ("" = อยู่หน้ารายการ)
func current_group() -> String:
	return _current_group


## ดึง instance ของห้องแชท เผื่อต้องสั่งงานตรง ๆ เช่น show_choices()
func get_group_view(group_id: String) -> Node:
	return _groups.get(group_id, null)
