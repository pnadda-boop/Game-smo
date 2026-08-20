@tool
class_name NPCBase
extends CharacterBody2D

## ซีนแม่ของ NPC ทุกตัว
##
## NPC หนึ่งตัว = ซีนสืบทอด (inherited scene) ของ `npc_base.tscn` + ไฟล์ `NPCData` ของตัวเอง
## แก้ระบบตรงนี้ทีเดียวกระทบทุกตัว แต่ยังปรับ collision รายตัวได้ที่ซีนลูก
##
## 🚨 **ชื่อโหนดลูกห้ามเปลี่ยน** — ผูกไว้กับ `$` path ในบล็อก @onready ข้างล่าง
## เปลี่ยนชื่อใน editor แล้วจะพังทุกตัวพร้อมกัน ไม่ใช่แค่ตัวที่แก้

## ส่งตอนผู้เล่นกด interact ใส่ NPC ตัวนี้
## ให้ฝั่งเนื้อเรื่อง/เควสต์ดักได้โดยไม่ต้องสืบทอดสคริปต์
signal interacted(npc: NPCBase)

## ข้อมูลประจำตัว — ตั้งที่ซีนลูกให้ชี้ไฟล์ `.tres` ของตัวเอง
##
## มี setter เพื่อให้เปลี่ยนไฟล์ใน Inspector แล้ว **เห็นผลทันทีในเอดิเตอร์**
## ไม่ต้องกดรันเกมเพื่อดูว่าใส่ถูกตัวไหม
@export var data: NPCData = null:
	set(value):
		data = value
		_refresh_editor_preview()

## บับเบิลบอกว่า "คุยได้"
##
## อยู่ตรงนี้ไม่ใช่ใน NPCData เพราะเป็นของ **ระบบ** ทุกตัวใช้ใบเดียวกัน
## ถ้าไปอยู่ใน .tres จะต้องมานั่งกรอกซ้ำทุกตัว แล้ววันหนึ่งอยากเปลี่ยนรูปบับเบิล
## ก็ต้องไล่แก้ทีละไฟล์ ซึ่งคือปัญหาเดิมที่ระบบซีนแม่พยายามหนี
## (ยังตั้งทับรายตัวได้ที่ Inspector ของซีนลูก ถ้ามี NPC ที่ต้องใช้ไอคอนต่างออกไป)
@export_group("บับเบิลบอกว่าคุยได้")
@export var indicator_frames: SpriteFrames = preload("res://npc/data/bubble_frames.tres")
@export var indicator_anim: String = "Bubble"
## 64×64 เต็ม ๆ ใหญ่เท่าหัวตัวละคร ต้องย่อ (ของเดิมใน wawa.tscn ใช้ ~0.4)
@export var indicator_scale: Vector2 = Vector2(0.4, 0.4)
@export var indicator_float_distance: float = 5.0
@export var indicator_float_speed: float = 5.0
@export_group("")

## ไอคอนเควสลอยเหนือหัว — "ตัวนี้มีเรื่องให้ทำ"
##
## ใช้ **ตำแหน่งและการลอยชุดเดียวกับบับเบิล** (`data.indicator_offset` ·
## `indicator_float_distance` · `indicator_float_speed`) เพื่อให้สองสัญญาณนี้
## อยู่จุดเดียวกันเป๊ะ ไม่ใช่ลอยคนละที่คนละจังหวะ
##
## ⚠️ **เปิด/ปิดรายตัวด้วยช่อง `Visible` ของโหนด `Quest` ใน Inspector**
## ไม่ได้ทำ `@export has_quest` แยก เพราะจะกลายเป็นสองที่ที่พูดเรื่องเดียวกัน
## แล้วติ๊กไม่ตรงกันเมื่อไหร่จะงงว่าทำไมไอคอนไม่ขึ้น
@export_group("ไอคอนเควส")
@export var quest_texture: Texture2D = preload("res://image_ui/Quest.PNG")
## 64×64 เท่าบับเบิลเป๊ะ จึงย่อเท่ากัน
@export var quest_scale: Vector2 = Vector2(0.4, 0.4)
@export_group("")

## ทิศที่ NPC หันตอนเปิดฉาก — ก่อนผู้เล่นเดินเข้ามาคุย
##
## | ค่า | ท่าที่เล่น | flip |
## |---|---|---|
## | `DEFAULT` | `data.default_anim` ตามเดิม (ไม่ทับอะไร) | ไม่แตะ |
## | `DOWN` | `data.default_anim` (หันลงมาหาผู้เล่น) | ไม่ flip |
## | `UP` | `data.anim_up` (หันเข้าไปในฉาก) | ไม่ flip |
## | `LEFT` / `RIGHT` | `data.anim_side` | `RIGHT` = flip |
##
## ตั้งที่ **ตัวโหนดในซีนแมพ** ไม่ใช่ใน `.tres` — ทิศที่ยืนหันขึ้นกับตำแหน่งที่วางในแมพ
## (คนที่ยืนหันข้างริมทางเดินกับคนเดียวกันที่นั่งหันหน้าเข้าห้องคือคนเดียวกัน คนละที่ยืน)
##
## 🚨 **อย่าแก้ `default_anim` ใน `.tres` เพื่อให้ยืนหันข้าง** — `face_player()` ใช้ค่านั้น
## เป็น "ท่าหันลง" ด้วย เปลี่ยนแล้วตัวละครจะหันลงไม่เป็นอีกเลยทุกฉาก
##
## ⚠️ ค่านี้ถูกเก็บเป็น `_initial_anim` / `_initial_flip` → **คุยจบแล้ว `reset_direction()`
## พากลับมาหันข้างเหมือนเดิม** ไม่ใช่ค้างหันหน้าหาผู้เล่นตลอดไป
enum Facing { DEFAULT, DOWN, UP, LEFT, RIGHT }
@export var initial_facing: Facing = Facing.DEFAULT:
	set(value):
		initial_facing = value
		_refresh_editor_preview()

## แหล่งบทพูด
##
## ปล่อยว่าง = สร้าง `DialogueData.new()` เอาค่า default จากสคริปต์
##
## 🚨 **จงใจไม่ preload `new_resource.tres`** — ไฟล์นั้นว่างเปล่าและยืมค่า default อยู่
## พอมีใครเผลอแก้ `dialogues` ใน Inspector Godot จะบันทึกสำเนาลง `.tres`
## แล้วบทพูดจะแช่แข็งทันที แก้ `DialogueData.gd` ไม่มีผลอีก (ดูคำเตือนใน CLAUDE.md)
## สร้างใหม่จากสคริปต์แบบนี้จะตรงกับไฟล์ `.gd` เสมอ
@export var dialogue_data: DialogueData = null

## บทพูดเฉพาะตัวนี้ — ทับ `dialogue_id` ที่ตั้งไว้ใน `NPCData`
##
## ปล่อยว่าง = ใช้คีย์จาก `.tres` ตามปกติ
##
## มีไว้เพราะ **ตัวละครคนเดียวกันพูดคนละเรื่องตามฉาก/บท**
## วาวาใน `decor/under_ch_1.tscn` กับวาวาใน `level_2.tscn` ใช้ `wawa.tres` ใบเดียวกัน
## (สไปรท์ ชื่อ ท่ายืน เหมือนกันหมด) ต่างกันแค่บทพูดอย่างเดียว
##
## 🚨 **อย่าแก้ `dialogue_id` ใน `.tres` เพื่อเปลี่ยนบทของฉากใดฉากหนึ่ง** — จะเปลี่ยนพร้อมกันทุกฉาก
## และการก๊อป `.tres` แยกใบก็จะได้ `SpriteFrames` ซ้ำอีกชุด = ปัญหาเดิมที่ระบบซีนแม่หนีมา
@export var dialogue_id_override: String = ""

## คุยได้ครั้งเดียว — คุยจบแล้วกด E ไม่ขึ้นอะไรอีก และบับเบิลไม่กลับมา
##
## ใช้กับ NPC ที่บทเป็น "เหตุการณ์" ไม่ใช่ "คำทักทาย" เช่นวาวาที่ฝากกล่องให้ไปวาง
## คุยซ้ำได้จะกลายเป็นฝากซ้ำ ๆ ทั้งที่เนื้อเรื่องเดินไปแล้ว
##
## ตั้งที่ตัวโหนดเหมือน `dialogue_id_override` ไม่ใช่ใน `NPCData`
## เพราะ `.tres` ใช้ร่วมกันหลายฉาก — วาวาในห้องใต้ตึกคุยครั้งเดียว
## แต่วาวาที่ `level_2.tscn` ยังต้องคุยซ้ำได้ตามปกติ
##
## ⚠️ **จำแค่ภายในฉากนี้** — เดินออกไปแล้วกลับเข้ามาใหม่ NPC ถูกสร้างใหม่ ค่าจะรีเซ็ต
## อยากให้จำถาวรต้องผูกกับ `GameState` (ยังไม่ได้ทำ)
@export var talk_once: bool = false

## ความสำคัญตอนผู้เล่นเลือกเป้าหมาย — สูงกว่าชนะก่อน เสมอกันค่อยวัดระยะ
##
## NPC = 1 · ของในฉาก = 0 → **คนสำคัญกว่าของเสมอ** แม้กล่องจะอยู่ใกล้ตัวกว่า
## ตั้งสูงขึ้นรายตัวได้ถ้ามี NPC ที่ต้องชนะ NPC ด้วยกัน (เช่นคนที่เนื้อเรื่องกำลังรออยู่)
## ตรรกะการเลือกอยู่ที่ `player.gd` → `pick_interact_target()`
@export var priority: int = 1

## บทที่ใช้ **หลังคุยบทหลักจบแล้ว** — ปล่อยว่าง = ไม่มีบทสำรอง
##
## เนื้อเรื่องเดินไปแล้วแต่ผู้เล่นยังเดินกลับมากด E ได้อยู่ดี
## บทหลักจะเล่นซ้ำไม่ได้ (วาวาจะฝากกล่องซ้ำทั้งที่ฝากไปแล้ว) แต่การไม่ขึ้นอะไรเลย
## ก็ดูเหมือนเกมค้าง — ให้มีบทสั้น ๆ ไว้ตอบแทน
##
## 🚨 **ตั้งค่านี้แล้ว `talk_once` จะไม่มีผล** — คุยได้ต่อไปเรื่อย ๆ แค่เปลี่ยนบท
## สองอันนี้เป็นคนละความตั้งใจ: `talk_once` = "พูดจบแล้วเงียบ" · ตัวนี้ = "พูดจบแล้วเปลี่ยนเรื่อง"
@export var dialogue_id_after: String = ""

## เคยคุยไปแล้วหรือยัง — มีผลเมื่อ `talk_once` เปิดเท่านั้น
var _talked: bool = false

## ใช้บทหลักไปแล้วหรือยัง — ครั้งถัดไปจะสลับไป `dialogue_id_after`
##
## ⚠️ **แยกจาก `_talked` เพราะจังหวะต่างกัน**
## `_talked` ตั้งตั้งแต่ *เริ่ม* คุย (ใน `interact()`) ซึ่งเกิด **ก่อน** ดึงบทพูด
## เอามาใช้ตัดสินบทตรง ๆ จะกลายเป็นว่าครั้งแรกก็ได้บทสำรองไปเลย
## ตัวนี้ตั้งตอนดึงบทหลักสำเร็จแล้วเท่านั้น
var _main_dialogue_used: bool = false

## ผู้เล่นอยู่ในระยะคุยไหม — ฝั่งที่รับอินพุตอ่านค่านี้ไปตัดสิน
var player_in_range: bool = false

## นับเวลาให้บับเบิลลอยขึ้นลง (เดินเฉพาะตอนบับเบิลโผล่)
var _indicator_time: float = 0.0

## นับเวลาให้ไอคอนเควสลอย — แยกตัวจากบับเบิลเพราะ `_indicator_time` ถูกรีเซ็ตเป็น 0
## ทุกครั้งที่บับเบิลป่องออกมา (ตั้งใจ — จะได้เริ่มจากจุดกลางพอดี)
## ใช้ตัวเดียวกันเมื่อไหร่ ไอคอนเควสจะกระตุกกลับทุกครั้งที่ผู้เล่นเดินเข้าระยะ
var _quest_time: float = 0.0

## ซีนตั้งให้ไอคอนเควสโชว์ไหม — จำไว้ตอน `_ready` เพราะระหว่างเล่นเราซ่อนมันชั่วคราว
## ตอนบับเบิลขึ้น แล้วต้องรู้ว่าจะคืนสถานะเป็นอะไร
var _quest_wanted: bool = false

## ตัวผู้เล่นที่เดินเข้ามา
##
## ⚠️ เก็บจาก `body_entered` ไม่ใช่ `get_first_node_in_group("player")` ตอน _ready
## แบบเดิมค้นตอน _ready ซึ่งผู้เล่นอาจยังไม่เข้า tree (ได้ null ค้างตลอดฉาก)
## และถ้าผู้เล่นถูกสร้างใหม่ ตัวที่เก็บไว้จะกลายเป็น node ที่ถูกลบไปแล้ว
var _player: Node2D = null

## ท่ายืนตั้งต้น — เก็บไว้คืนค่าหลังคุยจบ
var _initial_anim: String = ""
var _initial_flip: bool = false

## ⚠️ ผูก node ครั้งเดียวตอน @onready ไม่เรียก `get_node()` / `$` ซ้ำระหว่างเล่น
## การหา node ด้วย path เป็นการไล่ชื่อลูกทีละชั้น ทำทุกเฟรมคือจ่ายฟรี
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_area: Area2D = $InteractArea
@onready var indicator: AnimatedSprite2D = $Indicator
@onready var quest: Sprite2D = $Quest


func _ready() -> void:
	## 🚨 ในเอดิเตอร์ทำแค่ "ให้มองเห็น" เท่านั้น
	## ไม่เข้ากลุ่ม ไม่ต่อสัญญาณ ไม่รับปุ่ม — ของพวกนั้นเป็นเรื่องของตอนเล่นจริง
	## เผลอปล่อยให้ทำงานในเอดิเตอร์จะได้ node ค้าง ๆ กับพฤติกรรมประหลาดเวลาแก้ซีน
	if Engine.is_editor_hint():
		set_process(false)
		_refresh_editor_preview()
		return

	add_to_group("npc")

	## ซ่อนไว้ก่อนเสมอ ค่อยโผล่ตอนผู้เล่นเข้าระยะ
	indicator.visible = false
	_setup_indicator()
	_setup_quest()

	## ⚠️ _process ทำงานเฉพาะตอนมีอะไรลอยอยู่จริง
	## แมพหนึ่งมี NPC หลายตัว ปล่อยให้ทุกตัวเข้า _process ทุกเฟรมเพื่อ return ทิ้ง
	## คือจ่ายฟรีเปล่า ๆ — เปิดเอาตอนใช้จริงดีกว่า
	_update_float_process()

	## ต่อสัญญาณจากโค้ด ไม่ต่อจาก editor
	##
	## ⚠️ ซีนลูกสืบทอด "การเชื่อมต่อ" มาด้วย ถ้าต่อไว้ที่ editor ของซีนแม่
	## แล้วเผลอต่อซ้ำที่ซีนลูก จะเข้าเมธอดสองรอบต่อการชนหนึ่งครั้ง
	## ต่อจากโค้ดที่เดียวแบบนี้ไม่มีทางซ้ำ (เจอปัญหาต่อซ้ำมาแล้วใน Start.gd)
	interact_area.body_entered.connect(_on_interact_area_body_entered)
	interact_area.body_exited.connect(_on_interact_area_body_exited)

	if data == null:
		## ไม่ crash — ปล่อยให้ NPC ยืนเป็นก้อน collision เฉย ๆ
		## เห็น warning แล้วรู้ว่าลืมใส่ data ตัวไหน ดีกว่าเกมดับทั้งฉาก
		push_warning("npc_base.gd: `%s` ยังไม่ได้ใส่ data (NPCData) — ตัวนี้จะคุยไม่ได้" % name)
		return

	_apply_data()


## โชว์ตัวละครในเอดิเตอร์ (ทำงานเฉพาะตอนแก้ซีน ไม่เกี่ยวกับตอนเล่น)
##
## ⚠️ ถ้าไม่มีตัวนี้ NPC จะ **โปร่งใสตลอดในเอดิเตอร์** เพราะ sprite_frames
## ถูกใส่ตอน _ready() ซึ่งไม่ทำงานระหว่างแก้ซีน → ต้องลากของที่มองไม่เห็นไปวางบนแมพ
##
## ตั้งแค่ `animation` ไม่เรียก `play()` — เอดิเตอร์ต้องการแค่เฟรมนิ่ง ๆ ให้เล็งตำแหน่ง
## ไม่ต้องมีตัวละครเต้นอยู่ในหน้าต่างแก้ซีนตลอดเวลา
func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	## setter ของ data ถูกเรียกตั้งแต่ตอนโหลดซีน ซึ่ง @onready ยังไม่ผูก
	## ปล่อยผ่านไปก่อน เดี๋ยว _ready() เรียกซ้ำให้เอง
	if not is_node_ready() or data == null:
		return

	if data.frames != null:
		sprite.sprite_frames = data.frames
	sprite.position = data.sprite_offset
	indicator.position = data.indicator_offset
	## ไอคอนเควสใช้จุดเดียวกับบับเบิล — ในเอดิเตอร์ต้องเห็นรูปด้วย ไม่งั้นจัดตำแหน่งไม่ได้
	quest.position = data.indicator_offset
	if quest.texture == null and quest_texture != null:
		quest.texture = quest_texture
	quest.scale = quest_scale

	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(data.default_anim):
		sprite.animation = data.default_anim

	## ⚠️ ตั้ง `animation` ไม่ใช่ `play()` เหมือนบรรทัดบน — เอดิเตอร์ต้องการเฟรมนิ่ง
	## แต่ต้องโชว์ทิศที่เลือกไว้ ไม่งั้นจะเห็นโชแชงหันหน้าตอนแก้ซีนแล้วหันข้างตอนรัน
	var facing_anim: String = _initial_facing_anim()
	if not facing_anim.is_empty() and sprite.sprite_frames != null \
			and sprite.sprite_frames.has_animation(facing_anim):
		sprite.animation = facing_anim
		sprite.flip_h = _initial_facing_flip()


## ยกค่าจาก NPCData ไปใส่โหนดจริง
func _apply_data() -> void:
	## ⚠️ เขียนทับเฉพาะตอนมีของจริง
	## ยัด null ทับจะลบชุดอนิเมชันที่ตั้งไว้ในซีนลูกทิ้ง แล้ว NPC จะหายไปทั้งตัว
	## (เว้นช่อง frames ใน .tres ว่างไว้ = "ใช้ของที่ตั้งในซีน" ไม่ใช่ "ไม่มีรูป")
	if data.frames != null:
		sprite.sprite_frames = data.frames

	sprite.position = data.sprite_offset
	indicator.position = data.indicator_offset
	## ตำแหน่งเดียวกับบับเบิลเป๊ะ — ปรับที่ `indicator_offset` ใน `.tres` ที่เดียว ขยับทั้งคู่
	quest.position = data.indicator_offset

	_play_default_anim()
	_apply_initial_facing()

	## จำท่าตั้งต้นไว้หลัง _play_default_anim แล้ว
	## (ไม่ใช่ก่อนหน้า ไม่งั้นจะได้ค่าว่างของ AnimatedSprite2D ที่ยังไม่มีชุด)
	##
	## 🚨 **อยู่หลัง `_apply_initial_facing()` ด้วย** — สลับลำดับเมื่อไหร่ `reset_direction()`
	## จะพา NPC กลับไปหันตามค่าใน `.tres` แทนที่จะเป็นทิศที่ตั้งไว้ที่โหนด
	## (อาการ: หันข้างรออยู่ดี ๆ พอคุยจบแล้วหันหน้าค้างตลอดกาล)
	_initial_anim = sprite.animation
	_initial_flip = sprite.flip_h


## ทับท่ายืนตั้งต้นด้วยทิศที่ตั้งไว้ที่โหนด (`initial_facing`)
##
## ⚠️ **เรียกหลัง `_play_default_anim()` เสมอ ไม่ใช่แทนที่มัน**
## ตัวนั้นเป็นที่เดียวที่มี fallback + warning ตอนชื่อชุดใน `.tres` ไม่ตรงกับ SpriteFrames
## ข้ามไปแล้วจะได้ NPC ที่หายไปเงียบ ๆ โดยไม่มีอะไรบอกว่าตั้งชื่อชุดผิด
func _apply_initial_facing() -> void:
	var facing_anim: String = _initial_facing_anim()
	if facing_anim.is_empty():
		return

	## ตั้ง flip ก่อนเล่น — สลับลำดับจะเห็นภาพกลับด้านหนึ่งเฟรมตอนเปิดฉาก
	sprite.flip_h = _initial_facing_flip()
	_play_if_exists(facing_anim)


## แปลง `initial_facing` → ชื่อชุดอนิเมชัน ("" = ไม่ทับ ใช้ค่าตั้งต้นตามเดิม)
##
## ⚠️ อ่านชื่อชุดจาก `data` ไม่ได้เขียนชื่อ `"idle_side"` ตรง ๆ ในนี้
## แต่ละตัวละครตั้งชื่อชุดคนละแบบได้ (ดูคำเตือนใน `npc_data.gd`) —
## hardcode เมื่อไหร่ ตัวที่ตั้งชื่อไม่เหมือนชาวบ้านจะหันไม่ได้แบบเงียบ ๆ
func _initial_facing_anim() -> String:
	if data == null:
		return ""
	match initial_facing:
		Facing.DOWN:
			return data.default_anim
		Facing.UP:
			return data.anim_up
		Facing.LEFT, Facing.RIGHT:
			return data.anim_side
	return ""


## หันขวา = flip ภาพชุด `anim_side`
##
## ⚠️ ทิศทางต้องตรงกับ `face_player()` — ตรงนั้นใช้ `flip_h = diff.x > 0`
## (ผู้เล่นอยู่ทางขวา → flip) แปลว่า **ภาพที่ไม่ flip คือหันซ้าย**
## คิดกลับด้านเมื่อไหร่ NPC จะหันข้างคนละทางกับตอนคุยจบแล้วรีเซ็ต
func _initial_facing_flip() -> bool:
	return initial_facing == Facing.RIGHT


## เริ่มเล่นอนิเมชันยืนเฉย
##
## ⚠️ ไม่เรียก play() ทื่อ ๆ — ชื่อผิดแล้ว Godot จะขึ้น error แดงเต็มจอทุกเฟรม
## เช็คก่อนแล้วบอกให้รู้ว่ามีชุดอะไรให้เลือกบ้าง จะได้แก้ถูกที่ (เจอบ่อยตอนตั้งชื่อไม่ตรง)
func _play_default_anim() -> void:
	if sprite.sprite_frames == null:
		push_warning("npc_base.gd: `%s` ยังไม่ได้ใส่ SpriteFrames — จะมองไม่เห็นตัวละคร" % name)
		return

	if sprite.sprite_frames.has_animation(data.default_anim):
		sprite.play(data.default_anim)
		return

	var available: PackedStringArray = sprite.sprite_frames.get_animation_names()
	if available.is_empty():
		push_warning("npc_base.gd: `%s` มี SpriteFrames แต่ไม่มีอนิเมชันสักชุด" % name)
		return

	push_warning("npc_base.gd: `%s` ไม่มีอนิเมชันชื่อ `%s` — เล่น `%s` แทน (ที่มี: %s)" \
		% [name, data.default_anim, available[0], ", ".join(available)])
	sprite.play(available[0])


## เตรียมบับเบิล — ใส่รูปให้ถ้าซีนยังไม่ได้ตั้งไว้
func _setup_indicator() -> void:
	## ซีนลูกตั้ง sprite_frames เองแล้วก็เคารพของมัน ไม่เขียนทับ
	if indicator.sprite_frames == null and indicator_frames != null:
		indicator.sprite_frames = indicator_frames

	## ⚠️ เก็บ scale ที่ตั้งใจไว้เป็นเป้าหมายของ tween ไม่ใช่ค่าปัจจุบัน
	## เพราะตอนโผล่จะย่อลงเป็น 0 ก่อนแล้วค่อยป่องออก ถ้าอ่านค่าปัจจุบันตอนนั้น
	## จะได้ 0 แล้วบับเบิลจะหายไปเลยตั้งแต่ครั้งที่สอง
	indicator.scale = indicator_scale


## เตรียมไอคอนเควส — กฎเดียวกับบับเบิล: ซีนลูกตั้งเองแล้วเคารพของมัน
func _setup_quest() -> void:
	if quest.texture == null and quest_texture != null:
		quest.texture = quest_texture
	quest.scale = quest_scale

	## ช่อง `Visible` ของโหนดในซีน = "NPC ตัวนี้มีเควสไหม"
	_quest_wanted = quest.visible
	_refresh_quest_icon()


## ไอคอนเควสควรโชว์ตอนนี้ไหม
##
## **ยังไม่เคยคุยบทหลัก → ไอคอนเควส · คุยจบแล้ว → บับเบิลตามปกติ**
## เป็นสัญญาณสองจังหวะของเรื่องเดียวกัน: "มีเรื่องมาฝาก" แล้วจึงเป็น "คุยได้"
##
## 🚨 **ผูกกับ `_main_dialogue_used` ไม่ใช่ `_talked`** — `_talked` ถูกตั้งตั้งแต่
## *เริ่ม* คุยซึ่งเกิด**ก่อน**ดึงบทพูด · และถ้าพิมพ์คีย์บทผิดจนหาบทไม่เจอ
## `_main_dialogue_used` จะไม่ถูกตั้ง = ไอคอนเควสยังอยู่ ซึ่งถูกแล้ว
## เพราะผู้เล่นยังไม่ได้รับเรื่องอะไรไปจริง ๆ (ดูเหตุผลเดียวกันที่ `_get_dialogue_lines()`)
func _should_show_quest() -> bool:
	return _quest_wanted and not _main_dialogue_used


## จุดเดียวที่แตะ `quest.visible` — เรียกทุกครั้งที่สถานะอาจเปลี่ยน
##
## ⚠️ ล้าง `offset.y` ตอนซ่อนด้วย ไม่งั้นรอบหน้าที่โผล่มาจะเริ่มจากตำแหน่งค้างของรอบก่อน
func _refresh_quest_icon() -> void:
	quest.visible = _should_show_quest()
	if not quest.visible:
		quest.offset.y = 0.0
		_quest_time = 0.0
	_update_float_process()


## เปิด `_process` เฉพาะตอนมีอะไรลอยอยู่จริง
##
## 🚨 **ต้องดูทั้งสองตัว** — เดิม `hide_indicator()` สั่ง `set_process(false)` ทื่อ ๆ
## พอมีไอคอนเควสเข้ามา การเดินออกนอกระยะจะไปหยุดการลอยของไอคอนเควสด้วย
## แล้วมันจะค้างนิ่งอยู่กลางอากาศตลอดฉาก
func _update_float_process() -> void:
	set_process(indicator.visible or quest.visible)


## เข้าระยะคุย
func _on_interact_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	_player = body
	player_in_range = true

	## ⚠️ ลงทะเบียนแม้ `can_interact()` จะเป็น false — ผู้เล่นเป็นคนกรองตอนกดอีกที
	## สถานะกดได้/ไม่ได้เปลี่ยนระหว่างที่ยืนอยู่ในระยะได้ (เช่น `talk_once` หลังคุยจบ)
	## กรองตั้งแต่ตอนลงทะเบียนแล้วรายการจะค้างสถานะเก่าจนกว่าจะเดินออกแล้วเข้าใหม่
	if body.has_method("add_nearby_target"):
		body.add_nearby_target(self)

	## NPC ฉากหลังไม่ต้องขึ้นบับเบิลหลอกให้กด
	if can_interact():
		show_indicator()


## ออกนอกระยะคุย
func _on_interact_area_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("remove_nearby_target"):
		body.remove_nearby_target(self)

	_player = null
	player_in_range = false
	hide_indicator()


## หันหน้าไปทางผู้เล่น
##
## เทียบระยะแกนไหนห่างกว่าเป็นตัวตัดสิน — ยืนเฉียง ๆ จะได้ไม่สั่นสลับไปมา
func face_player() -> void:
	if _player == null:
		return

	var diff: Vector2 = _player.global_position - global_position
	if absf(diff.x) > absf(diff.y):
		_play_if_exists(data.anim_side)
		sprite.flip_h = diff.x > 0
		return

	sprite.flip_h = false
	_play_if_exists(data.anim_up if diff.y < 0 else data.default_anim)


## กลับไปยืนท่าตั้งต้น — `dialogue_system.gd` เรียกตัวนี้ตอนบทจบ
func reset_direction() -> void:
	sprite.flip_h = _initial_flip
	_play_if_exists(_initial_anim)

	## คุยจบแล้วยังยืนอยู่ใกล้ ๆ ก็เอาบับเบิลกลับมา ไม่งั้นจะดูเหมือนคุยซ้ำไม่ได้
	if player_in_range and can_interact():
		show_indicator()


## เล่นอนิเมชันแบบไม่พังถ้าชื่อไม่มีอยู่จริง
func _play_if_exists(anim: String) -> void:
	if sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(anim):
		return
	sprite.play(anim)


## บับเบิลป่องออกมา + เริ่มลอย
func show_indicator() -> void:
	## 🚨 **ยังไม่เคยคุย = ไอคอนเควสยืนแทน บับเบิลไม่ต้องขึ้น**
	## สองอันอยู่ตำแหน่งเดียวกันเป๊ะ โชว์พร้อมกันจะทับกันเป็นก้อนเดียวอ่านไม่ออก
	## · ครั้งแรกที่เจอ ผู้เล่นควรอ่านได้ว่า "ตัวนี้มีเรื่องมาฝาก" ไม่ใช่แค่ "คุยได้"
	##   ส่วนบับเบิลเป็นสัญญาณประจำวันหลังรับเรื่องไปแล้ว
	if _should_show_quest():
		_refresh_quest_icon()
		return

	quest.visible = false

	indicator.visible = true
	indicator.modulate.a = 0.0
	indicator.scale = Vector2.ZERO
	_indicator_time = 0.0
	_update_float_process()

	if indicator.sprite_frames != null and indicator.sprite_frames.has_animation(indicator_anim):
		indicator.play(indicator_anim)

	var tween: Tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(indicator, "modulate:a", 1.0, 0.3)
	tween.tween_property(indicator, "scale", indicator_scale, 0.3)


## เก็บบับเบิล
func hide_indicator() -> void:
	indicator.stop()
	indicator.visible = false
	indicator.frame = 0
	indicator.offset.y = 0.0

	## คืนไอคอนเควสตามสถานะ ไม่ใช่เปิดทื่อ ๆ — NPC ที่ไม่มีเควส (หรือคุยจบแล้ว) จะได้ไม่มีไอคอนงอก
	_refresh_quest_icon()


## ลอยขึ้นลงเบา ๆ — เปิดเฉพาะตอนมีอะไรลอยอยู่ (ดู `_update_float_process()`)
##
## ⚠️ ขยับ `offset` ไม่ใช่ `position` — `position` คือจุดที่ `data.indicator_offset` ตั้งไว้
## เขียนทับเมื่อไหร่ ตำแหน่งที่ตั้งใน `.tres` จะหายไปตั้งแต่เฟรมแรกที่ลอย
func _process(delta: float) -> void:
	if indicator.visible:
		_indicator_time += delta * indicator_float_speed
		indicator.offset.y = sin(_indicator_time) * indicator_float_distance

	if quest.visible:
		_quest_time += delta * indicator_float_speed
		quest.offset.y = sin(_quest_time) * indicator_float_distance


## คุยกับ NPC ตัวนี้ได้ไหม (มีข้อมูล + ไม่ได้ปิดไว้ + ยังไม่หมดสิทธิ์คุย)
##
## ตัวนี้คุมทั้งการกด E และการโผล่ของบับเบิล — คืน false แล้วผู้เล่นจะไม่เห็นสัญญาณชวนคุยด้วย
func can_interact() -> bool:
	if data == null or not data.can_interact:
		return false
	## มีบทสำรองแล้วคุยได้เสมอ — `talk_once` ถูกทับด้วยความตั้งใจ (ดูคำอธิบายที่ `dialogue_id_after`)
	if not dialogue_id_after.is_empty():
		return true
	return not (talk_once and _talked)


## 🚨 **NPC ไม่ดักปุ่ม E เองแล้ว** (เดิมมี `_unhandled_input` ตรงนี้ = ทางเลือก ก)
##
## ย้ายไปให้ `player.gd` เป็นคนเลือกเป้าหมาย (ทางเลือก ข ที่คุยกันไว้ตั้งแต่แรก)
## เพราะแบบเดิม "ใครได้คิวก่อน" ขึ้นกับลำดับใน tree ล้วน ๆ — ยืนคาบเกี่ยววาวากับกล่อง
## จะได้ตัวไหนก็เดาไม่ได้ และบอกไม่ได้ว่า NPC ควรสำคัญกว่าของในฉาก
##
## ตอนนี้ NPC แค่ลงทะเบียนตัวเองเข้า `nearby_targets` ของผู้เล่น (ดู `_on_interact_area_body_entered`)
## แล้วรอให้ผู้เล่นเรียก `interact()` — ตัวเลือกทั้งหมดอยู่ที่ `player.pick_interact_target()`
##
## ⚠️ **อย่าเพิ่ม `_unhandled_input` กลับเข้ามาที่นี่** จะกลายเป็นกด E ครั้งเดียวทำงานสองทาง
## (การกันเด้งบทซ้ำตอนคุยอยู่ ตอนนี้อาศัย `dialogue_system._input()` ที่กิน E
##  ด้วย `set_input_as_handled()` + `can_move` ของผู้เล่นที่ถูกล็อกระหว่างบท)


## ทางเข้าเดียวของการกดคุย — ฝั่งผู้เล่น/อินพุตเรียกตัวนี้
func interact() -> void:
	if not can_interact():
		return

	## ⚠️ ตั้งธงตั้งแต่ "เริ่มคุย" ไม่ใช่ตอนบทจบ
	## ผู้เล่นที่ออกจากบทกลางคันก็ถือว่าได้คุยแล้ว และกันการเด้งซ้ำในเฟรมเดียวกันไปด้วย
	_talked = true

	## เก็บบับเบิลก่อนเข้าบทสนทนา ไม่งั้นมันจะลอยค้างทับกล่องคำพูด
	hide_indicator()

	## ให้ผู้เล่นหันหน้ามาหา NPC ด้วย (NPC หันไปหาผู้เล่นใน `_on_interact()` อยู่แล้ว)
	## คุยกันแล้วยืนหันหลังให้อีกฝ่ายดูแปลกมาก
	##
	## ⚠️ อยู่ใน `interact()` ไม่ใช่ `_on_interact()` — ตัวหลังให้ซีนลูก override ได้
	## NPC ที่เขียนพฤติกรรมพิเศษทับโดยไม่เรียก `super()` จะไม่หลุดข้อนี้ไป
	if _player != null and _player.has_method("face_toward"):
		_player.face_toward(global_position)

	interacted.emit(self)
	_on_interact()

	## 🚨 **ต้องอยู่หลัง `_on_interact()`** — `_main_dialogue_used` ถูกตั้งตอนดึงบทพูดในนั้น
	## ไว้ก่อนหน้าจะยังอ่านค่าเก่า แล้วไอคอนเควสจะลอยค้างอยู่ระหว่างที่กล่องคำพูดเปิดอยู่
	##
	## ⚠️ **ไม่ใช้ธง `_in_dialogue` แยก** — `_on_interact()` มีทางออกก่อนเปิดบทได้ 2 ทาง
	## (ไม่มีบทตามคีย์นั้น / หา `dialogue_ui` ไม่เจอ) แล้วธงจะค้างจนไอคอนหายถาวร
	## · อ่านสถานะจริงแทน = บทไม่ได้เปิด ไอคอนก็กลับมาเอง ซึ่งถูกแล้ว
	_refresh_quest_icon()


## ให้ซีนลูก override — NPC ตัวไหนมีพฤติกรรมพิเศษเขียนทับตรงนี้
## เรียก `super()` ด้วยถ้ายังอยากได้บทสนทนาปกติ
func _on_interact() -> void:
	face_player()

	var lines: Array = _get_dialogue_lines()
	if lines.is_empty():
		return

	## ⚠️ หา node สดตอนใช้งาน ไม่ cache ตอน _ready
	## กล่องคำพูดอยู่คนละซีนกับ NPC และถูกสร้าง/ทิ้งตามฉาก
	## เก็บไว้ตั้งแต่ _ready จะกลายเป็น node ที่ถูกลบไปแล้วหลังเปลี่ยนฉาก
	var ui: Node = get_tree().get_first_node_in_group("dialogue_ui")
	if ui == null:
		push_error("npc_base.gd: ไม่พบ node กลุ่ม `dialogue_ui` — เช็คว่าฉากนี้มี DialogueBox.tscn แล้วหรือยัง")
		return

	## ส่ง self ไปด้วยเพื่อให้กล่องคำพูดเรียก reset_direction() คืนท่ายืนตอนบทจบ
	ui.start_dialogue(lines, self)


## ดึงบทพูดตามคีย์ของ NPC ตัวนี้
func _get_dialogue_lines() -> Array:
	var source: DialogueData = dialogue_data
	if source == null:
		## ค่า default ของ @export ใน DialogueData.gd — ตรงกับไฟล์สคริปต์เสมอ
		source = DialogueData.new()

	var key: String = _resolve_dialogue_key()

	if not source.dialogues.has(key):
		push_warning("npc_base.gd: `%s` ไม่มีบทชื่อ `%s` ใน DialogueData (ที่มี: %s)" \
			% [name, key, ", ".join(PackedStringArray(source.dialogues.keys()))])
		return []

	## 🚨 ตั้งธงหลังยืนยันว่าบทมีอยู่จริงเท่านั้น
	## พิมพ์คีย์ผิดแล้วนับว่า "คุยบทหลักไปแล้ว" = บทหลักหายไปเลยทั้งที่ยังไม่เคยเล่น
	## ⚠️ เทียบกับค่าที่ตัดช่องว่างแล้ว — `key` ผ่าน `_clean_key()` มาแล้ว
	## เทียบกับค่าดิบจะไม่มีวันเท่ากันถ้าช่องนั้นมีช่องว่างติดมา แล้วธงจะถูกตั้งผิด
	if key != dialogue_id_after.strip_edges():
		_main_dialogue_used = true

	return source.dialogues[key]


## เลือกคีย์บทของครั้งนี้
##
## | ลำดับ | ใช้เมื่อ |
## |---|---|
## | `dialogue_id_after` | คุยบทหลักไปแล้ว **และ** ตั้งช่องนี้ไว้ |
## | `dialogue_id_override` | ตั้งทับที่ตัวโหนด (บทเฉพาะฉาก) |
## | `data.dialogue_id` | คีย์กลางจาก `.tres` |
func _resolve_dialogue_key() -> String:
	if _main_dialogue_used:
		var after: String = _clean_key(dialogue_id_after, "Dialogue Id After")
		if not after.is_empty():
			return after

	var override: String = _clean_key(dialogue_id_override, "Dialogue Id Override")
	if not override.is_empty():
		return override

	return _clean_key(data.dialogue_id, "Dialogue Id (ใน .tres)")


## ชื่อคีย์ที่เคยเตือนไปแล้ว — เตือนซ้ำทุกครั้งที่กด E จะท่วมคอนโซล
var _warned_keys: Dictionary = {}


## ตัดช่องว่างหัวท้ายของคีย์บทพูด แล้วบอกให้ไปแก้ที่ต้นทาง
##
## 🚨 **ช่องว่างที่พิมพ์ติดมาใน Inspector มองไม่เห็นด้วยตา** แต่ทำให้หาบทไม่เจอ
## อาการคือกด E แล้ว "ไม่มีอะไรเกิดขึ้น" ซึ่งดูเหมือนระบบพังทั้งระบบ
## (เกิดจริงแล้ว 2026-08-16 กับ `"wawa_idle "` — เสียเวลาไล่หาสาเหตุผิดจุด)
##
## เลือกตัดให้แล้วเตือน ไม่ใช่ปล่อยพัง — คนพิมพ์ตั้งใจพิมพ์ `wawa_idle` อยู่แล้ว
## ช่องว่างเป็นอุบัติเหตุจากการพิมพ์/ก๊อป ไม่เคยเป็นสิ่งที่ตั้งใจ
func _clean_key(key: String, field_name: String) -> String:
	var cleaned: String = key.strip_edges()
	if cleaned == key:
		return cleaned

	if not _warned_keys.has(key):
		_warned_keys[key] = true
		push_warning("npc_base.gd: `%s` ช่อง %s มีช่องว่างเกินมา (\"%s\") — ใช้ \"%s\" แทน ควรลบช่องว่างใน Inspector" \
			% [name, field_name, key, cleaned])

	return cleaned
