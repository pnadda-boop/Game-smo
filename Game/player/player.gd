class_name Player

extends CharacterBody2D

var move_speed: float = 200.0

var last_direction: Vector2 = Vector2.DOWN
var animation_direction: Vector2 = Vector2.DOWN

## เกินค่านี้ทั้งสองแกน = ถือว่าเดินเฉียง
##
## กดสองปุ่มพร้อมกันแล้ว normalize ได้ (±0.707, ±0.707) ส่วนทิศตรงได้ (±1, 0) หรือ (0, ±1)
## ตั้งไว้ต่ำกว่า 0.707 เยอะ ๆ เพื่อเผื่ออนาล็อกสติ๊กที่ดันไม่ถึงมุม 45° เป๊ะ
## แต่ยังสูงพอไม่ให้ค่าที่แกว่งใกล้ศูนย์กลายเป็นเฉียงไปเอง
const DIAGONAL_THRESHOLD := 0.35

## บิตของ layer ที่ NPC อยู่ — Layer 3 ในหน้า Inspector = ค่า 4
## (ต้องตรงกับ `collision_layer = 4` ของ `npc/npc_base.tscn`)
const NPC_COLLISION_BIT := 4

var can_move := true

## ==============================================
## ถือของอยู่หรือเปล่า
## ==============================================
## จริง = ทุกท่าสลับไปใช้ชุดที่ลงท้าย `_box` (ท่าเดียวกันแต่มีของอยู่ในมือ)
## สั่งจากข้างนอกได้ตรง ๆ `player.carrying = true` — ไม่ต้องเรียกอะไรเพิ่ม
## เพราะ `_process()` เล่นอนิเมชันใหม่ทุกเฟรมอยู่แล้ว ภาพจะเปลี่ยนทันทีในเฟรมถัดไป
##
## ⚠️ ตัวแปรนี้คุมแค่ "ภาพ" ไม่ได้เก็บว่าถืออะไรอยู่ — ตัวของจริงเป็นหน้าที่ของระบบหยิบของ
## ที่จะต้องตั้งค่านี้ควบคู่ไปกับการซ่อน/ย้ายโหนดของชิ้นนั้น (`interact_box.gd` · `box_drop_point.gd`)
##
## 🚨 **เขียนกลับลง `GameState.carrying_box` ทุกครั้งที่เปลี่ยน**
## ผู้เล่นถูก instance ใหม่ทุกฉาก ค่านี้จึงรีเซ็ตเป็น false เสมอตอนเปลี่ยนฉาก
## ถ้าไม่ฝากไว้ที่ GameState ผู้เล่นจะถือกล่องข้ามฉากไม่ได้เลย
## (ตัวจำอยู่ที่ GameState — ตัวนี้เป็นแค่ "สำเนาที่ใช้เลือกอนิเมชันในฉากนี้")
##
## ⚠️ ทำเป็น setter ไม่ใช่ให้คนเรียกไปตั้ง GameState เอง — มีที่ตั้งค่านี้หลายที่
## (หยิบกล่อง · วางกล่อง · เนื้อเรื่องในอนาคต) ลืมที่ใดที่หนึ่งแล้วจะจำผิดแบบเงียบ ๆ
var carrying: bool = false:
	set(value):
		carrying = value
		GameState.carrying_box = value

## ส่วนท้ายชื่อชุดถือของ — ต่อ**หลังทิศ** เช่น `walk_obliquelyL` + `_box`
const CARRY_SUFFIX := "_box"

## ชื่ออนิเมชันที่เตือนไปแล้ว — กันไม่ให้ push_warning ซ้ำทุกเฟรม
var _warned_anims: Dictionary = {}

var on_stairs: bool = false
var stair_dir: Vector2 = Vector2.ZERO

## ==============================================
## เป้าหมายที่กด E ได้ (NPC / ของในฉาก)
## ==============================================
## ⚠️ **ผู้เล่นเป็นคนเลือกว่าจะคุยกับใคร ไม่ใช่ให้แต่ละตัวแย่งกันดักปุ่มเอง**
##
## แบบเดิม NPC แต่ละตัวดัก E เองใน `_unhandled_input` แล้วใครได้คิวก่อนก็ชนะ
## ซึ่ง**ขึ้นกับลำดับใน tree ล้วน ๆ** — ยืนตรงกลางระหว่างวาวากับกล่อง
## จะได้ตัวไหนก็เดาไม่ได้ และไม่มีทางบอกว่า "คนสำคัญกว่าของ"
##
## ตัวที่เข้าระยะเป็นคน **ลงทะเบียนตัวเองเข้ามา** (`add_nearby_target`)
## ไม่ใช่ผู้เล่นมี Area2D ของตัวเองไปคลำหา — เพราะทั้ง NPC และกล่องมี `InteractArea`
## ที่จับผู้เล่นอยู่แล้ว ใช้ของเดิมจึงไม่ต้องเพิ่มโหนดในซีนไหนเลย
var nearby_targets: Array[Node2D] = []


## ลงทะเบียนเป็นเป้าหมาย — เรียกจาก `InteractArea` ของ NPC/ของ ตอนผู้เล่นเข้าระยะ
func add_nearby_target(target: Node2D) -> void:
	if target == null or nearby_targets.has(target):
		return
	nearby_targets.append(target)


func remove_nearby_target(target: Node2D) -> void:
	nearby_targets.erase(target)


## เลือกเป้าหมายที่เหมาะที่สุด — `priority` สูงกว่าชนะก่อน เสมอกันค่อยวัดระยะ
##
## `priority` ไม่ได้กำหนด = 0 (ของในฉาก) · NPC = 1 → **คนสำคัญกว่าของเสมอ**
## ยืนตรงจุดที่ทั้งวาวาและกล่องอยู่ในระยะ กด E จะได้คุยกับวาวา ไม่ใช่ไปยุ่งกับกล่อง
## ซึ่งตรงกับสิ่งที่ผู้เล่นตั้งใจเกือบทุกครั้ง (คนเดินเข้าไปหา "คน" ไม่ได้เดินเข้าไปหาเฟอร์นิเจอร์)
##
## ⚠️ เทียบ `distance_squared_to` ไม่ใช่ `distance_to` — ผลการเรียงเหมือนกันเป๊ะ
## แต่ไม่ต้องถอดรากที่สอง (เราต้องการแค่ "ใกล้กว่า" ไม่ได้ต้องการตัวเลขระยะจริง)
func pick_interact_target() -> Node2D:
	## เก็บกวาดตัวที่ถูกลบไปแล้วก่อน — ของในฉากอาจ `queue_free()` ตอนที่ผู้เล่นยังยืนทับอยู่
	## แล้ว `body_exited` จะไม่มีวันยิง ทำให้มีผีค้างในรายการตลอดฉาก
	nearby_targets = nearby_targets.filter(func(t: Node2D) -> bool: return is_instance_valid(t))

	return _pick_best(nearby_targets)


## เลือกตัวที่ดีที่สุดจากรายการที่ให้มา — ใช้ร่วมกันทั้งการกด E และการคลิก
## (คลิกโดนของซ้อนกันสองชิ้นจะได้กฎเดียวกับกด E ไม่ใช่ "ตัวไหนอยู่บนสุดใน tree")
func _pick_best(candidates: Array) -> Node2D:
	var best: Node2D = null
	var best_priority: int = 0
	var best_distance: float = 0.0

	for target: Node2D in candidates:
		if not _can_interact_with(target):
			continue

		var target_priority: int = int(target.get("priority")) if "priority" in target else 0
		var distance: float = global_position.distance_squared_to(target.global_position)

		if best == null \
				or target_priority > best_priority \
				or (target_priority == best_priority and distance < best_distance):
			best = target
			best_priority = target_priority
			best_distance = distance

	return best


## หันหน้าไปทางตำแหน่งที่กำหนด — `npc_base.gd` เรียกตอนเริ่มบทสนทนา
##
## คุยกันแล้วยืนหันหลังให้อีกฝ่ายดูแปลกมาก NPC หันมาหาผู้เล่นอยู่แล้ว (`face_player()`)
## ฝั่งผู้เล่นก็ต้องหันกลับไปด้วยถึงจะดูเหมือนคุยกันจริง
##
## ⚠️ **สแนปเข้าทิศตรงเสมอ (บน/ล่าง/ข้าง) ไม่ใช้ทิศเฉียง**
## เทียบว่าแกนไหนห่างกว่าเป็นตัวตัดสิน — กฎเดียวกับ `NPCBase.face_player()` จะได้หันเข้าหากันจริง ๆ
## (ปล่อยเป็นเฉียงจะไปตกที่ `_side` อยู่ดีเพราะไม่มีชุด `idle_obliquely*`
##  แต่ผลลัพธ์จะขึ้นกับมุมที่เดินเข้าไปแบบเดาไม่ได้)
##
## ตั้ง `animation_direction` ด้วย ไม่ใช่แค่เล่นอนิเมชันครั้งเดียว
## เพราะ `_process()` เล่นท่ายืนจากค่านั้นทุกเฟรมระหว่างที่ถูกล็อก — ไม่ตั้งจะโดนทับในเฟรมถัดไป
func face_toward(target_position: Vector2) -> void:
	var diff: Vector2 = target_position - global_position
	if diff == Vector2.ZERO:
		return

	var dir: Vector2 = Vector2(signf(diff.x), 0.0) if absf(diff.x) > absf(diff.y) \
		else Vector2(0.0, signf(diff.y))

	last_direction = dir
	animation_direction = dir
	play_animation("idle", dir)


## เป้าหมายนี้กดได้จริงไหม
##
## เช็คด้วย `has_method` ไม่ผูกกับ `class_name` ใดเลย — ของในฉากที่อยากให้กดได้
## แค่มีเมธอด `interact()` ก็พอ ไม่ต้องสืบทอดจากคลาสกลางหรือแก้ไฟล์นี้
## (`can_interact()` มีก็เช็คให้ ไม่มีก็ถือว่ากดได้ — กล่องที่ยังล็อกอยู่จะถูกข้ามด้วยกฎนี้)
func _can_interact_with(target: Node2D) -> bool:
	if not target.has_method("interact"):
		return false
	if target.has_method("can_interact"):
		return target.can_interact()
	return true


## จำนวนของที่ยอมตรวจต่อการคลิกหนึ่งครั้ง — จุดเดียวมีของทับกันเกินนี้ไม่มีทางเกิดในเกมนี้
const MAX_CLICK_HITS := 32


## หาเป้าหมายที่อยู่ใต้เมาส์
##
## ยิงจุดเดียวเข้าไปในโลกฟิสิกส์แล้วดูว่าโดนอะไรบ้าง — ใช้ **รูปร่างจริง**ของแต่ละตัว
## ไม่ต้องเดาระยะเอาเองและไม่ต้องเพิ่มโหนดรับคลิกให้ใครเลย
##
## ⚠️ ต้องเปิดทั้ง areas และ bodies เพราะสองระบบวางรูปร่างไว้คนละที่:
## NPC เป็น `CharacterBody2D` (โดนที่ตัวเอง) · กล่องเป็นสไปรท์ที่มี `InteractArea` เป็นลูก (โดนที่ลูก)
## จึงต้องเช็คทั้งตัวที่โดนและพ่อของมัน
##
## 🚨 **ยังต้องอยู่ในระยะ (`nearby_targets`) เหมือนกด E ทุกอย่าง**
## ไม่งั้นจะคลิกคุยกับ NPC ข้ามครึ่งแมพได้ ซึ่งเป็นคนละกฎกับที่เกมใช้อยู่
## (อยากให้คลิกไกลได้ค่อยเพิ่มทีหลัง — ผ่อนกฎง่ายกว่าเก็บกฎที่ปล่อยหลุดไปแล้ว)
##
## ⚠️ รับ **พิกัดจากตัวอีเวนต์** ไม่ใช่ `get_global_mouse_position()`
## ตัวหลังคือ "เมาส์อยู่ตรงไหนตอนนี้" ซึ่งไม่จำเป็นต้องเป็น "คลิกลงตรงไหน"
## (เมาส์ขยับต่อระหว่างเฟรม · จอสัมผัส · อีเวนต์ที่ยิงจากโค้ด)
func _target_under_mouse(world_position: Vector2) -> Node2D:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_position
	params.collide_with_areas = true
	params.collide_with_bodies = true

	var candidates: Array[Node2D] = []
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_point(params, MAX_CLICK_HITS):
		var collider: Node = hit.get("collider") as Node
		if collider == null:
			continue

		for candidate: Node in [collider, collider.get_parent()]:
			if candidate is Node2D and nearby_targets.has(candidate) and not candidates.has(candidate):
				candidates.append(candidate)

	return _pick_best(candidates)


## กด E หรือคลิกซ้าย — เลือกเป้าหมายแล้วสั่งคุย/ใช้งาน
##
## ⚠️ ใช้ `_unhandled_input` ไม่ใช่ `_input` เพื่อให้ UI ได้กินก่อน
## กล่องคำพูดกิน E ไปเลื่อนบรรทัด (`set_input_as_handled`) อีเวนต์จึงไม่ไหลมาถึงตรงนี้
## ระหว่างคุยอยู่ = ไม่มีทางเริ่มบทใหม่ทับ (บั๊ก "บทเด้งกลับไปเริ่มใหม่" 2026-08-15)
## ฝั่งคลิกก็ได้ผลเดียวกัน — ปุ่มตัวเลือก/ปุ่ม Next กินคลิกไปก่อนถึงจะมาถึงตรงนี้
##
## เช็ค `can_move` ด้วยอีกชั้น — ถูกล็อกอยู่แปลว่ามีอย่างอื่นคุมฉากอยู่ (บทสนทนา/อินโทร)
##
## ℹ️ `ClickEffect` (autoload) ใช้ `_input` และไม่กินอีเวนต์ วงกลมกระเพื่อมจึงยังขึ้นตามปกติ
func _unhandled_input(event: InputEvent) -> void:
	if not can_move:
		return

	var target: Node2D = null

	if event.is_action_pressed("interact"):
		target = pick_interact_target()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		## แปลงพิกัดในจอ -> พิกัดในโลก (กล้องเลื่อน/ซูมได้ ใช้ค่าดิบตรง ๆ ไม่ได้)
		var click_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() \
			* (event as InputEventMouseButton).position
		target = _target_under_mouse(click_position)
	else:
		return

	if target == null:
		return

	## กินอีเวนต์เฉพาะตอนมีเป้าหมายจริง — ไม่งั้นจะไปบังปุ่ม E / คลิก ของระบบอื่นในฉาก
	## (บันได `stair.gd` ก็ใช้ E เหมือนกัน แต่ไม่ได้ลงทะเบียนเป็น target)
	get_viewport().set_input_as_handled()
	target.interact()

## เสียงฝีเท้า
##
## ⚠️ walk.ogg เป็นเสียงเดิน "ต่อเนื่อง" ไม่ใช่เสียงก้าวเดียว
## จึงต้องเล่นครั้งเดียวตอนเริ่มเดิน แล้วหยุดตอนหยุด + เปิดวนลูปไว้
## ห้ามสั่ง play() ซ้ำทุกเฟรม เพราะจะได้ยินแค่เศษเสี้ยวแรกของไฟล์วนรัว ๆ
## (เคยพลาดแบบเดียวกันมาแล้วกับเสียงพิมพ์ใน dialogue_system)
##
## ⚠️ ใช้ .ogg ไม่ใช่ .mp3 — mp3 มีความเงียบที่ตัวเข้ารหัสเติมหัวท้ายไฟล์เสมอ
## ต่อให้ตัดเสียงมาเป๊ะแค่ไหน วนลูปแล้วก็จะได้ยินช่องว่างตรงรอยต่อ
##
## ใช้เป็น "ตัวสำรอง" เท่านั้น - ถ้ามี AudioStreamPlayer ในซีนที่ใส่ไฟล์ไว้แล้ว จะใช้ของนั้นก่อน
@export var walk_sound: AudioStream = preload("res://soud_effects/walk.ogg")

## ⚠️ ไม่มี @export ของระดับเสียงโดยตั้งใจ
## ระดับเสียงตั้งที่ `Volume Db` ของ node WalkSoud ใน player.tscn ที่เดียว
## เคยมี walk_sound_volume_db แล้วสับสนมาก เพราะค่าที่ node ทับเสมอ
## ปรับ export แล้วไม่มีอะไรเปลี่ยน - หาสาเหตุไม่เจอเลยว่าทำไม
const FALLBACK_VOLUME_DB := -6.0

## ช่วงที่ใช้จริงในไฟล์เสียง (วินาที) - เล่นถึง end แล้วกระโดดกลับไป start วนไปเรื่อย ๆ
##
## ⚠️ ต้องคุมเองด้วยการ seek เพราะ AudioStream ของ Godot มีแค่ `loop_offset`
## (จุดที่จะกลับไปเมื่อเล่นจนจบไฟล์) แต่ **ไม่มีจุดจบของลูป** ตั้งได้
## ปล่อยให้มันเล่นจนสุดไฟล์จะติดหางเสียงเงียบ ๆ ท้ายไฟล์ แล้วจังหวะก้าวจะเพี้ยนตรงรอยต่อ
##
## ตั้ง end = 0 = ใช้ทั้งไฟล์ ปล่อยให้ลูปของ AudioStream ทำงานเอง
## (ใช้ได้เฉพาะไฟล์ที่ตัดมาพอดีหนึ่งรอบก้าวเป๊ะ ๆ เท่านั้น)
##
## walk.ogg ยาว 8.098 วิ - เสียงก้าวจริงอยู่ช่วง 0.20-7.50 ที่เหลือเป็นหัวท้ายที่ไม่ใช้
@export var walk_sound_start: float = 1.0
@export var walk_sound_end: float = 5.0




@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var _walk_player: AudioStreamPlayer = null
## walk_sound_end หลังตัดให้ไม่เกินความยาวไฟล์จริง
var _loop_end: float = 0.0


func _ready():
	## คืนสถานะถือของจากฉากก่อนหน้า — ต้องอยู่ก่อน `_process()` เฟรมแรก
	## ไม่งั้นจะเห็นท่ามือเปล่าแวบหนึ่งตอนเข้าฉากใหม่ทั้งที่ยังถือกล่องอยู่
	carrying = GameState.carrying_box

	_ensure_npc_collision()
	_setup_walk_sound()
	await get_tree().process_frame


## ==============================================
## เดินชน NPC ได้ — เปิดบิตของ layer NPC ให้ `collision_mask` เสมอ
## ==============================================
## 🚨 **ทำจากโค้ด เพราะ "ทุกซีนตั้ง mask ของผู้เล่นเอง และตั้งไม่ตรงกัน"**
## `player.tscn` ต้นฉบับไม่ได้ตั้งอะไรเลย (ได้ default 1) แล้วแต่ละซีนไป override ทับ:
##
## | ซีน | `collision_mask` ที่ override | ชนอะไรได้ |
## |---|---|---|
## | `under.tscn` · `level_2.tscn` | 16 | กำแพงอย่างเดียว |
## | `level1.tscn` | 17 | layer 1 + กำแพง |
## | `p.tscn` | 17 (+ `collision_layer` 17) | layer 1 + กำแพง |
##
## **ไม่มีซีนไหนเปิดบิต 4 เลย** → NPC (layer 3 = ค่า 4) ถูกเดินทะลุทุกฉาก
## แก้ที่ `player.tscn` ที่เดียวไม่พอ เพราะ override ที่ instance ชนะค่าจากซีนต้นฉบับเสมอ
##
## ⚠️ **ทางที่ถูกกว่าคือไล่ลบ `collision_mask` ที่ override ไว้ทั้ง 4 ซีนทิ้ง**
## แล้วตั้งค่าเดียวที่ `player.tscn` — แต่นั่นต้องแก้ `.tscn` 4 ไฟล์ และค่าที่ override
## ไว้ต่างกันอาจตั้งใจต่างกันจริง (ยังไม่รู้ว่าทำไม `p.tscn` ถึงต้องมี layer 17)
## · จนกว่าจะยุบให้เหลือค่าเดียว บรรทัดนี้เป็นตาข่ายรับที่ทำงานทุกฉากรวมถึงฉากที่ยังไม่ได้สร้าง
##
## ⚠️ **`|=` ไม่ใช่ `=`** — ทับทื่อ ๆ จะลบบิตกำแพง (16) ทิ้ง แล้วผู้เล่นจะเดินทะลุกำแพงแทน
func _ensure_npc_collision() -> void:
	collision_mask |= NPC_COLLISION_BIT


## เตรียมตัวเล่นเสียงฝีเท้า
##
## มี AudioStreamPlayer อยู่ในซีนแล้ว -> ใช้ตัวนั้น (ปรับ stream/volume ที่ Inspector ได้)
## ไม่มี -> สร้างจากโค้ดให้เอง (ผู้เล่นถูก instance หลายซีน จะได้ไม่ต้องเพิ่มทีละที่)
##
## ⚠️ ต้องหาของเดิมก่อนเสมอ ถ้าสร้างใหม่ทื่อ ๆ จะได้ตัวเล่น 2 ตัว
## แล้วค่าที่ตั้งไว้ที่ node ในซีนจะไม่มีผลอะไรเลย - หาสาเหตุยากมาก
func _setup_walk_sound() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			_walk_player = child
			break

	if _walk_player == null:
		if walk_sound == null:
			return
		_walk_player = AudioStreamPlayer.new()
		_walk_player.volume_db = FALLBACK_VOLUME_DB
		add_child(_walk_player)

	## node ในซีนใส่ไฟล์เสียงไว้แล้วก็ใช้ของมัน ไม่เขียนทับ
	if _walk_player.stream == null:
		_walk_player.stream = walk_sound

	## loop อยู่ที่ตัวทรัพยากร ไม่ใช่ที่ตัวเล่น - ไม่เปิดจะเงียบไปเองหลังเล่นจบไฟล์
	if _walk_player.stream and "loop" in _walk_player.stream:
		_walk_player.stream.loop = true
	## กันเหนียว: ถ้าหลุดไปจนสุดไฟล์จริง ๆ ให้วนกลับที่ start ไม่ใช่ 0
	## (ปกติ _update_walk_sound จะ seek ก่อนถึงตรงนั้นอยู่แล้ว)
	if _walk_player.stream and "loop_offset" in _walk_player.stream:
		_walk_player.stream.loop_offset = walk_sound_start

	_resolve_loop_range()


## ตัดช่วงลูปให้อยู่ในไฟล์จริง แล้วบอกให้รู้ถ้าตั้งเกิน
##
## ตั้งเลยความยาวไฟล์แล้วจะ "ไม่พัง" แต่ seek จะไม่เคยทำงาน
## เสียงจะไปวนที่ปลายไฟล์แทนแบบเงียบ ๆ - ต้องเตือนไม่งั้นหาสาเหตุไม่เจอ
func _resolve_loop_range() -> void:
	_loop_end = walk_sound_end
	if _walk_player == null or _walk_player.stream == null:
		return

	var length := _walk_player.stream.get_length()
	if length <= 0.0:
		return

	if walk_sound_start >= length:
		push_warning("player.gd: Walk Sound Start = %.2f วิ เกินความยาวไฟล์ (%.2f วิ) — เริ่มที่ 0 แทน" \
			% [walk_sound_start, length])
		walk_sound_start = 0.0

	## 0 = ไม่ตัดช่วง ใช้ทั้งไฟล์ (ลูปของ AudioStream เนียนกว่าการ seek เอง)
	if walk_sound_end <= 0.0:
		_loop_end = 0.0
		return

	if walk_sound_end > length:
		push_warning("player.gd: Walk Sound End = %.2f วิ แต่ไฟล์ยาวแค่ %.2f วิ — ใช้ทั้งไฟล์แทน" \
			% [walk_sound_end, length])
		_loop_end = 0.0


## เปิด/ปิดเสียงเดินตามสถานะจริง + วนเฉพาะช่วง start..end
## เช็ค playing ก่อนเสมอ ไม่งั้นสั่ง play() ซ้ำทุกเฟรมแล้วเสียงจะกระตุกอยู่ที่จุดเริ่มไฟล์
func _update_walk_sound(moving: bool) -> void:
	if _walk_player == null:
		return

	if not moving:
		if _walk_player.playing:
			_walk_player.stop()
		return

	if not _walk_player.playing:
		_walk_player.play(walk_sound_start)
		return

	if _loop_end <= walk_sound_start:
		return

	var pos := _walk_player.get_playback_position()
	if pos < _loop_end:
		return

	## ถึงปลายช่วงแล้ว -> ตีกลับไปต้นช่วง
	## ใช้ seek() แทน play() ใหม่ เพราะ play() จะรีเซ็ตทั้ง playback เสียงจะสะดุดได้ยิน
	##
	## ⚠️ ต้องบวก "ส่วนที่เลยมา" กลับเข้าไปด้วย
	## เราเช็คได้แค่เฟรมละครั้ง (60fps = คลาดได้ถึง 17ms) ถ้า seek กลับไปที่ start ตรง ๆ
	## รอบลูปจะยาวกว่าที่ตั้งไว้นิดหน่อยแบบสุ่มทุกรอบ -> จังหวะก้าวเพี้ยนสะสม
	## บวกส่วนเกินกลับไปแล้วคาบของลูปจะเท่ากับ (end - start) เป๊ะ ไม่ว่าเฟรมเรตเท่าไหร่
	var overshoot := pos - _loop_end
	var span := _loop_end - walk_sound_start
	## เฟรมกระตุกหนักจนเลยไปเกินหนึ่งรอบ - วนกลับให้อยู่ในช่วง
	if overshoot >= span:
		overshoot = fmod(overshoot, span)
	_walk_player.seek(walk_sound_start + overshoot)


func _process(delta):
	if !can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		play_animation("idle", animation_direction)
		## ต้องหยุดเสียงตรงนี้ด้วย ไม่งั้นถ้าโดนล็อกตอนกำลังเดินอยู่
		## (เช่นเริ่มบทสนทนา หรืออินโทรตอนมาถึงลานจอดรถ) เสียงจะดังค้างไปเรื่อย ๆ
		_update_walk_sound(false)
		return

	# รับค่าทิศทางจากการกดปุ่ม
	var direction: Vector2 = Vector2.ZERO
	direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")

	if direction != Vector2.ZERO:
		direction = direction.normalized()

		if on_stairs:
			# เดินตามแนวบันได
			if direction.dot(stair_dir) < 0:
				velocity = -stair_dir.normalized() * move_speed
				last_direction = -stair_dir.normalized()
			else:
				velocity = stair_dir.normalized() * move_speed
				last_direction = stair_dir.normalized()

			# ไม่เปลี่ยน animation_direction
			# เพื่อให้อนิเมชันคงเดิมตอนเข้าบันได

		else:
			velocity = direction * move_speed
			last_direction = direction
			animation_direction = direction

	else:
		velocity = Vector2.ZERO

	move_and_slide()

	process_animation(animation_direction)
	## อ่านค่าหลัง move_and_slide เพราะมันปรับ velocity ตามการชนแล้ว
	## เสียงจึงตรงกับอนิเมชันเสมอ - เดินชนกำแพงอยู่กับที่ก็ไม่มีเสียงฝีเท้า
	_update_walk_sound(velocity != Vector2.ZERO)


func process_animation(direction) -> void:
	if velocity != Vector2.ZERO:
		play_animation("walk", direction)
	else:
		play_animation("idle", direction)


func play_animation(prefix: String, dir: Vector2) -> void:
	## ⚠️ ต้องเช็คเฉียงก่อนทิศตรงเสมอ เพราะทิศเฉียงมีค่าทั้งสองแกน
	## ไล่ `dir.y < 0` ก่อนแบบเดิม เฉียงบนทั้งซ้ายขวาจะตกเข้าเดินขึ้นตรง ๆ หมด
	## (เดินเฉียงได้จริงมาตั้งแต่แรก แต่ภาพที่เห็นเป็นเดินขึ้น/ลง)
	if absf(dir.x) > DIAGONAL_THRESHOLD and absf(dir.y) > DIAGONAL_THRESHOLD:
		_play_diagonal(prefix, dir)
		return

	if dir.y < 0:
		_play(prefix + "_up", false)

	elif dir.y > 0:
		_play(prefix + "_down", false)

	elif dir.x < 0:
		_play(prefix + "_side", false)

	elif dir.x > 0:
		_play(prefix + "_side", true)


## ชุดที่ "วาดตรงทิศนั้นจริง ๆ" — ใช้ก่อนเสมอ ไม่ต้อง flip
##
## key = `<up|down>_<left|right>` · ค่า = ส่วนท้ายชื่ออนิเมชัน (ต่อจาก prefix)
## 🚨 **วาดชุดใหม่เพิ่มเมื่อไหร่ เติมชื่อตรงนี้ที่เดียวจบ** ไม่ต้องแตะตรรกะข้างล่าง
## และใช้ได้กับทุก prefix ทันที (มี `idle_obliquelyL` เมื่อไหร่ ยืนนิ่งเฉียงซ้ายล่างก็จะหยิบไปใช้เอง)
const DIAGONAL_EXACT_SUFFIX := {
	"down_left": "_obliquelyL",
	"down_right": "_obliquelyR",
}

## ชุดสำรอง — วาดไว้ทางเดียวแล้วพลิกภาพเอาอีกทาง
##
## 🚨 สองชุดนี้วาดหันคนละทางกัน เงื่อนไข flip จึงกลับด้านกัน รวมเป็นสูตรเดียวไม่ได้
## `_obliquelyup` วาดเฉียง**ซ้าย**บน · `_obliquelydown` วาดเฉียง**ขวา**ล่าง
## (`_side` วาดหันซ้ายเหมือน `_obliquelyup` — มีแค่ `_obliquelydown` ที่สวนทางชาวบ้าน)
##
## ⚠️ `_obliquelydown` **ไม่มีใน player.tscn แล้ว** — ถูกแยกเป็น `_obliquelyL` / `_obliquelyR`
## เก็บ 2 บรรทัดล่างไว้เป็นตาข่ายรับ เผื่อชุดสไปรท์ที่ยังใช้ชื่อรวมแบบเดิม
##
## ค่า = [ส่วนท้ายชื่ออนิเมชัน, ต้อง flip ไหม]
const DIAGONAL_FLIP_FALLBACK := {
	"up_left": ["_obliquelyup", false],
	"up_right": ["_obliquelyup", true],
	"down_left": ["_obliquelydown", true],
	"down_right": ["_obliquelydown", false],
}


## อนิเมชันเดินเฉียง 4 ทิศ — เลือกชุดตามลำดับ: วาดตรงทิศ -> พลิกภาพเอา -> ท่าด้านข้าง
##
## เลือกชุดที่วาดตรงทิศก่อนเพราะภาพที่ flip มาจะกลับด้านทั้งตัว
## (สะพายกระเป๋าสลับข้าง แสงเงาผิดด้าน ผมปัดคนละทาง) ตาจับได้ถ้ามีชุดจริงให้เทียบ
##
## เช็คด้วย `has_animation` ทุกชั้น ไม่ฮาร์ดโค้ดว่า prefix ต้องเป็น "walk"
## ตอนนี้มีแต่ `walk_obliquely*` ไม่มี `idle_obliquely*` ยืนนิ่งหันเฉียงจึงตกมาที่ `_side`
## เลือก `_side` เพราะเก็บ "หันซ้ายหรือขวา" ไว้ได้ ซึ่งตาจับได้ชัดกว่าการก้มเงย
func _play_diagonal(prefix: String, dir: Vector2) -> void:
	var key: String = ("up" if dir.y < 0 else "down") + ("_left" if dir.x < 0 else "_right")
	var frames: SpriteFrames = animated_sprite_2d.sprite_frames

	if frames != null and DIAGONAL_EXACT_SUFFIX.has(key):
		var exact_anim: String = prefix + DIAGONAL_EXACT_SUFFIX[key]
		if frames.has_animation(exact_anim):
			_play(exact_anim, false)
			return

	var fallback: Array = DIAGONAL_FLIP_FALLBACK[key]
	var anim: String = prefix + str(fallback[0])
	if frames != null and frames.has_animation(anim):
		_play(anim, bool(fallback[1]))
		return

	## ไม่มีชุดเฉียงของ prefix นี้เลย -> ถอยไปใช้ท่าด้านข้าง (วาดหันซ้าย)
	_play(prefix + "_side", dir.x > 0)


## เล่นอนิเมชันจริง — **จุดเดียวในไฟล์ที่เรียก `play()`**
##
## หน้าที่เดียวของมันคือเติม `_box` ตอนถือของ ทุกทางเดินของ `play_animation()`
## จึงต้องผ่านตรงนี้ ไม่งั้นจะมีท่าที่ลืมสลับเป็นชุดถือของแบบหาไม่เจอ
##
## ⚠️ **`_box` ต่อท้ายสุด หลังทิศ** (`walk_obliquelyL_box`) จะเติมได้ก็ต่อเมื่อ
## ประกอบชื่อทิศเสร็จแล้วเท่านั้น — เป็นเหตุผลที่ต้องมีฟังก์ชันนี้แทนการเติมที่ prefix
func _play(anim: String, flip: bool) -> void:
	if carrying:
		var frames: SpriteFrames = animated_sprite_2d.sprite_frames
		var carry_anim: String = anim + CARRY_SUFFIX
		if frames != null and frames.has_animation(carry_anim):
			anim = carry_anim
		elif not _warned_anims.has(carry_anim):
			## เตือนครั้งเดียวต่อชื่อ — ฟังก์ชันนี้ทำงานทุกเฟรม เตือนทุกครั้งจะท่วมคอนโซล
			_warned_anims[carry_anim] = true
			push_warning("player.gd: ไม่มีอนิเมชัน '%s' — ถือของอยู่แต่เล่นท่ามือเปล่า '%s' แทน" % [carry_anim, anim])

	animated_sprite_2d.play(anim)
	animated_sprite_2d.flip_h = flip


func _on_area_2d_body_entered(body: Node2D) -> void:
	pass


func _on_area_2d_body_exited(body: Node2D) -> void:
	pass


func _on_area_2_dsmallroom_body_exited(body: Node2D) -> void:
	pass


func _on_area_2_dmeetingroom_body_entered(body: Node2D) -> void:
	pass


func _on_area_2_dmeetingroom_body_exited(body: Node2D) -> void:
	pass


func _on_stair_area_2d_body_entered(body: Node2D) -> void:
	if body == self:
		on_stairs = true
		stair_dir = Vector2(1, -0.3)


func _on_stair_area_2d_body_exited(body: Node2D) -> void:
	if body == self:
		on_stairs = false
		stair_dir = Vector2.ZERO
