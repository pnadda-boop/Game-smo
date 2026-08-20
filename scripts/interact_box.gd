extends AnimatedSprite2D
## ==============================================
## กล่องที่เปลี่ยนท่าตอนผู้เล่นเข้าใกล้ (ปลดล็อกด้วยบทสนทนา)
## ==============================================
## ผู้เล่นเดินเข้า `InteractArea` → สลับไปอนิเมชัน `nearby`
## เดินออก → กลับไป `normal`
##
## 🚨 **ทำงานเฉพาะหลังคุยกับ NPC ที่กำหนดจบแล้วเท่านั้น**
## ก่อนหน้านั้นกล่องเป็นแค่ของตกแต่ง เดินชนยังไงก็ไม่มีอะไรเกิดขึ้น
## (วาวาเป็นคนฝากให้ไปวาง — กล่องที่ตอบสนองก่อนได้รับมอบหมายคือการสปอยล์ว่าตรงนี้มีอะไร)
##
## ⚠️ สลับด้วย **ชื่ออนิเมชัน** ไม่ใช่เลขเฟรม
## ชื่อบอกความหมายในตัว (`nearby` ไม่ใช่ `frame = 1`) และเผื่อวันหลังอยากให้กล่องขยับจริง ๆ
## แค่เพิ่มเฟรมใน `nearby` ก็จบ ไม่ต้องกลับมาแก้สคริปต์

## ส่งตอนกล่องพร้อมใช้งาน — ให้ระบบหยิบของ (ยังไม่มี) มาดักต่อได้โดยไม่ต้องแก้ไฟล์นี้
signal unlocked

## ส่งตอนผู้เล่นกด E ใส่กล่องนี้
signal interacted(item: Node2D)

## ส่งตอนกล่องถูกหยิบขึ้นมา — ให้เนื้อเรื่อง/เควสต์ดักได้โดยไม่ต้องแก้ไฟล์นี้
signal picked_up(item: Node2D)

## ความสำคัญตอนผู้เล่นเลือกเป้าหมาย — ของในฉาก = 0 · NPC = 1
##
## ยืนตรงจุดที่ทั้งวาวาและกล่องอยู่ในระยะ กด E จะได้คุยกับวาวาก่อนเสมอ
## ตรรกะการเลือกอยู่ที่ `player.gd` → `pick_interact_target()`
@export var priority: int = 0

## ชื่ออนิเมชันสองสถานะ — ต้องตรงกับที่ตั้งไว้ใน SpriteFrames เป๊ะ ๆ
@export var normal_anim: String = "normal"
@export var nearby_anim: String = "nearby"

## เดินออกแล้วกลับท่าเดิมไหม
## ปิด = เข้าครั้งแรกแล้วค้างท่าใหม่ตลอด (ใช้กับกล่องที่ "เปิดแล้วเปิดเลย")
@export var revert_on_exit: bool = true

@export_group("เงื่อนไขปลดล็อก")
## ต้องคุยกับใครให้จบก่อน — ปล่อยว่าง = ใช้งานได้ตั้งแต่เริ่มฉาก
##
## ชี้ที่ตัวโหนด NPC ไม่ใช่ชื่อบท เพราะกล่องสนแค่ว่า "คุยจบหรือยัง"
## ไม่ได้สนว่าบทนั้นชื่ออะไร — เปลี่ยนบทของวาวาแล้วไม่ต้องกลับมาแก้ตรงนี้
@export var unlock_after_npc: NodePath = ^"../Wawa"
@export_group("")

## ปลดล็อกแล้วหรือยัง (คุยกับ NPC จบแล้ว)
var _unlocked: bool = false

## ผู้เล่นยืนอยู่ในระยะไหม
##
## ⚠️ เก็บแยกจาก `_unlocked` และอัปเดต **ตลอดเวลา** แม้ยังล็อกอยู่
## เพราะผู้เล่นอาจยืนแช่อยู่ข้างกล่องตั้งแต่ก่อนคุย พอคุยจบกล่องต้องเปลี่ยนท่าทันที
## ไม่ใช่ต้องเดินออกแล้วเดินกลับเข้ามาใหม่
var _player_inside: bool = false

## กำลังรอบทสนทนาจบอยู่ — กัน await ซ้อนกันหลายเส้นถ้า NPC คุยได้หลายรอบ
var _awaiting_dialogue: bool = false

## ถูกหยิบไปแล้วหรือยัง
##
## ⚠️ **ซ่อนไว้เฉย ๆ ไม่ได้ `queue_free()`** — เผื่อระบบวางของ (ยังไม่มี) จะเอากลับมาโชว์
## ลบทิ้งแล้วจะสร้างใหม่ไม่ได้ ต้องไปหาตำแหน่ง/อนิเมชันเดิมมาใส่เองทั้งหมด
var _carried: bool = false

## ตัวผู้เล่นที่อยู่ในระยะ — เก็บจาก `body_entered` แบบเดียวกับ `npc_base.gd`
## (ไม่ค้นจากกลุ่มตอน `_ready` เพราะผู้เล่นอาจยังไม่เข้า tree แล้วจะได้ null ค้างตลอดฉาก)
var _player: Node2D = null

## Area2D ของตัวเอง — เก็บไว้ปิด monitoring ตอนถูกหยิบไปแล้ว
var _interact_area: Area2D = null


func _ready() -> void:
	_check_anims()
	_play_if_exists(normal_anim)
	_setup_area()
	_setup_unlock()


## เตือนตั้งแต่เปิดฉากถ้าชื่ออนิเมชันไม่ตรงกับที่มีจริง
##
## จำเป็นเพราะพิมพ์ชื่อผิดจะ **ไม่มีอะไรบอกเลย** — กล่องแค่ไม่ขยับ
## แล้วจะไปนั่งไล่หาสาเหตุที่ Area2D / เงื่อนไขปลดล็อก ทั้งที่ผิดแค่ตัวอักษรเดียว
func _check_anims() -> void:
	if sprite_frames == null:
		push_warning("interact_box.gd: `%s` ยังไม่ได้ใส่ SpriteFrames" % name)
		return

	for anim: String in [normal_anim, nearby_anim]:
		if not sprite_frames.has_animation(anim):
			push_warning("interact_box.gd: `%s` ไม่มีอนิเมชันชื่อ `%s` (ที่มี: %s)" \
				% [name, anim, ", ".join(sprite_frames.get_animation_names())])


## ต่อสัญญาณของ Area2D จากโค้ด — ไม่ต่อจาก editor (ต่อซ้ำ = เข้าเมธอดสองรอบต่อการเดินเข้าหนึ่งครั้ง)
func _setup_area() -> void:
	_interact_area = get_node_or_null("InteractArea") as Area2D
	if _interact_area == null:
		push_error("interact_box.gd: `%s` ไม่พบ Area2D ชื่อ `InteractArea` — กล่องจะไม่รู้ว่าผู้เล่นเข้ามา" % name)
		return

	_interact_area.body_entered.connect(_on_body_entered)
	_interact_area.body_exited.connect(_on_body_exited)


## ผูกเงื่อนไขปลดล็อกเข้ากับ NPC
func _setup_unlock() -> void:
	if unlock_after_npc.is_empty():
		## ไม่ต้องรอใคร — เป็นกล่องธรรมดาที่ใช้ได้ตั้งแต่ต้นฉาก
		_unlock()
		return

	var npc: Node = get_node_or_null(unlock_after_npc)
	if npc == null or not npc.has_signal("interacted"):
		## 🚨 หาไม่เจอแล้ว **ล็อกไว้** ไม่ใช่ปล่อยผ่าน
		## ปล่อยผ่านคือกล่องทำงานผิดลำดับเนื้อเรื่องแบบเงียบ ๆ ซึ่งเจอยากกว่ากล่องที่ไม่ขยับเลย
		## (ใช้ push_error ไม่ใช่ warning เพราะกล่องที่ล็อกค้าง = ฟีเจอร์ตายทั้งอัน ต้องเห็นชัด)
		push_error("interact_box.gd: `%s` หา NPC ที่ `%s` ไม่เจอ (หรือไม่ใช่ NPCBase) — กล่องจะล็อกตลอดฉาก" \
			% [name, unlock_after_npc])
		return

	npc.interacted.connect(_on_npc_interacted)


## NPC เริ่มคุย — รอจนบทจบก่อนค่อยปลดล็อก
##
## ⚠️ ดัก `interacted` (ตอน**เริ่ม**คุย) แล้วรอ `dialogue_finished` เอง
## ไม่ดัก `dialogue_finished` ตรง ๆ ตั้งแต่ _ready เพราะสัญญาณนั้นเป็นของ**กล่องคำพูดกลาง**
## ยิงตอนบทของใครจบก็ได้ — คุยกับ NPC ตัวอื่นในฉากแล้วกล่องจะปลดล็อกไปด้วย
func _on_npc_interacted(_npc: Node) -> void:
	if _unlocked or _awaiting_dialogue:
		return

	var ui: Node = get_tree().get_first_node_in_group("dialogue_ui")
	if ui == null:
		## ไม่มีกล่องคำพูดในฉาก = ไม่มีบทให้รอจบ ถือว่าคุยเสร็จแล้ว
		_unlock()
		return

	_awaiting_dialogue = true
	await ui.dialogue_finished
	_awaiting_dialogue = false
	_unlock()


func _unlock() -> void:
	if _unlocked:
		return
	_unlocked = true

	## ยืนแช่อยู่ข้างกล่องตั้งแต่ก่อนคุยจบ — ต้องเปลี่ยนท่าทันที ไม่ต้องเดินออกแล้วเข้าใหม่
	if _player_inside:
		_play_if_exists(nearby_anim)

	unlocked.emit()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	_player = body
	_player_inside = true

	## ⚠️ ลงทะเบียนแม้ยังล็อกอยู่ — ผู้เล่นกรองด้วย `can_interact()` ตอนกดอีกที
	## สถานะปลดล็อกเปลี่ยนได้ระหว่างที่ยืนอยู่ในระยะ (คุยกับวาวาจบตรงข้างกล่องเลย)
	if body.has_method("add_nearby_target"):
		body.add_nearby_target(self)

	if _unlocked:
		_play_if_exists(nearby_anim)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("remove_nearby_target"):
		body.remove_nearby_target(self)

	_player = null
	_player_inside = false
	if revert_on_exit:
		_play_if_exists(normal_anim)


## กดได้เมื่อปลดล็อกแล้ว และยังไม่ถูกหยิบไป
func can_interact() -> bool:
	return _unlocked and not _carried


## ผู้เล่นกด E ใส่กล่อง → หยิบขึ้นมา
func interact() -> void:
	if not can_interact():
		return

	interacted.emit(self)
	_pick_up()


## หยิบกล่องขึ้นมา — ผู้เล่นสลับไปชุดอนิเมชัน `_box` แล้วกล่องหายจากพื้น
##
## ⚠️ **ไม่ได้ย้ายโหนดกล่องไปแปะไว้ที่มือผู้เล่น** — ชุด `_box` ของผู้เล่น
## วาดกล่องมาในภาพอยู่แล้ว มีกล่องจริงลอยตามอีกใบจะเห็นเป็นสองใบ
##
## ⚠️ **ซ่อน ไม่ใช่ `queue_free()`** — เผื่อระบบวางของเอากลับมาโชว์ (ดู `_carried`)
func _pick_up() -> void:
	if _player == null:
		push_warning("interact_box.gd: `%s` ถูกกดโดยที่ไม่รู้ว่าใครกด — ไม่ได้สลับอนิเมชันถือของ" % name)
		return

	_carried = true

	## ฝั่งภาพของผู้เล่นทำงานเอง — `player._process()` เล่นอนิเมชันใหม่ทุกเฟรมอยู่แล้ว
	## จึงสลับเป็นชุด `_box` ให้ตั้งแต่เฟรมถัดไปโดยไม่ต้องสั่งอะไรเพิ่ม
	if "carrying" in _player:
		_player.carrying = true
	else:
		push_warning("interact_box.gd: ผู้เล่นไม่มีตัวแปร `carrying` — อนิเมชันถือของจะไม่เปลี่ยน")

	## หันหน้ามาทางกล่องก่อนก้มหยิบ — เหมือนตอนคุยกับ NPC
	##
	## ⚠️ ต้องอยู่ **หลัง** ตั้ง `carrying` — `face_toward()` เล่นท่ายืนทันทีในบรรทัดนั้น
	## สลับลำดับจะได้ท่ามือเปล่าหนึ่งเฟรมก่อนเปลี่ยนเป็นชุดถือของ (ตากระตุกจับได้)
	if _player.has_method("face_toward"):
		_player.face_toward(global_position)

	visible = false

	## ถอดออกจากรายการเป้าหมายทันที ไม่ต้องรอเดินออกนอกระยะ
	## (ไม่ถอด = กด E ซ้ำตรงนั้นจะเลือกกล่องที่ถืออยู่แล้วแทนที่จะเป็น NPC ข้าง ๆ)
	if _player.has_method("remove_nearby_target"):
		_player.remove_nearby_target(self)

	## ปิด monitoring กัน `body_entered` ยิงซ้ำตอนเดินออกแล้วเดินกลับเข้ามา
	if _interact_area:
		_interact_area.monitoring = false

	## ได้ของชิ้นแรก = ช่องของโผล่มา แล้ว **อยู่ยาวตลอดเกม**
	##
	## 🚨 **เรียกครั้งเดียวพอ ไม่ต้องสั่งซ้ำทุกฉาก** — `UIRoot` แขวนอยู่ที่ `get_tree().root`
	## ซึ่งรอดจาก `change_scene_to_file()` · โชว์ทีเดียวแล้วติดค้างข้ามฉากไปเอง
	## (ถ้าเผลอไปสั่งซ้ำก็ไม่เสียหาย `show_ui()` ไม่สร้างตัวใหม่)
	##
	## ⚠️ อยู่ที่นี่เพราะ **"ผู้เล่นได้ของชิ้นแรก"** ไม่ใช่ "เควสต์กล่องเริ่มแล้ว" —
	## ไฟล์นี้เป็นสคริปต์กลางของของที่หยิบได้ทุกชิ้น ของชิ้นต่อ ๆ ไปจึงได้พฤติกรรมนี้ฟรี
	UIRoot.show_ui("hud")

	picked_up.emit(self)


## เล่นอนิเมชันแบบไม่พังถ้าชื่อไม่มีอยู่จริง
## (เตือนไปแล้วครั้งเดียวตอน _ready — ตรงนี้เงียบไว้ ไม่งั้นจะพ่นซ้ำทุกครั้งที่เดินผ่าน)
func _play_if_exists(anim: String) -> void:
	if sprite_frames == null or not sprite_frames.has_animation(anim):
		return
	play(anim)
