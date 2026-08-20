class_name UIRoot
extends Node

## ==============================================
## ที่แขวน UI ที่อยู่ข้ามฉาก
## ==============================================
## UI อย่าง HUD ช่องของ · ตัวบอกเควส · แมพ ไม่ได้เป็นของฉากใดฉากหนึ่ง —
## มันอยู่กับ **ผู้เล่น** ซึ่งเดินข้ามฉากไปเรื่อย ๆ
##
## ```gdscript
## UIRoot.show_ui("hud")      ## สร้างถ้ายังไม่มี แล้วโชว์ (เรียกซ้ำได้ ไม่สร้างซ้ำ)
## UIRoot.hide_ui("hud")
## UIRoot.hide_all()          ## เข้าเมนูหลัก / ฉากคัตซีน
## var hud = UIRoot.get_ui("hud")   ## เอาไปสั่งงานตรง ๆ
## ```
##
## 🚨 **ไม่ใช่ autoload โดยตั้งใจ** — โปรเจกต์นี้เติม autoload ลง `project.godot` เองไม่ได้
## (Godot ลบทิ้งเงียบ ๆ เมื่อผู้ใช้แตะ Project Settings — เกิดมาแล้ว 2 ครั้ง ดู DEVLOG 2026-07-30)
## แขวนโหนดไว้ที่ `get_tree().root` แทน ซึ่งรอดจาก `change_scene_to_file()`
## **กลไกเดียวกับ `scripts/music.gd`** ไม่ได้คิดวิธีใหม่
##
## ⚠️ **ทำไมไม่ลาก `hud.tscn` เข้าไปในทุกซีนแทน**
## UI 1 ตัว × ฉาก 8 ฉาก = ลากเข้าซีน 8 ครั้ง · พอมี 4 UI ก็ 32 ครั้ง
## ลืมฉากเดียว = บั๊กที่เจอตอนเล่นไปถึงฉากนั้นแล้วเท่านั้น
## · แลกกับการที่**มองไม่เห็น UI ตอนแก้ซีนในเอดิเตอร์** ซึ่งรับได้เพราะ UI พวกนี้
## ยึดขอบจอ ไม่ต้องจัดตำแหน่งเทียบกับของในฉาก

## ชื่อโหนดใต้ root — ใช้หาตัวเดิมให้เจอหลังเปลี่ยนฉาก
const NODE_NAME := "UIRoot"

## ==============================================
## ทะเบียน UI — เพิ่ม UI ใหม่ = เพิ่ม 1 บรรทัดที่นี่
## ==============================================
## `layer` = ลำดับการวาดของ CanvasLayer · **ต้องตั้งให้ชัดเจนเสมอ อย่าปล่อย default 1**
## CanvasLayer ที่ `layer` เท่ากันเรียงตามลำดับใน tree ซึ่งเดาไม่ได้ (ดู CLAUDE.md)
##
## | ช่วง | ใช้กับ | ตอนนี้มีอะไร |
## |---|---|---|
## | 1–9 | UI ประจำฉาก (สร้าง/ตายพร้อมฉาก) | `DialogueBox` · `Chat` = 1 |
## | 10–29 | UI ที่อยู่ตลอดเวลา ไม่บังการเล่น | `hud` = 20 |
## | 30–49 | แผงที่เปิดทับการเล่น (แมพ · เมนูพัก) | — |
## | 100 | เอฟเฟกต์คลิก | `ClickEffect` |
## | 128 | ม่านเฟดเปลี่ยนฉาก | `SceneTransition` |
##
## ⚠️ **UI ที่เปิดทับการเล่น (30–49) ต้องล็อกผู้เล่นเองด้วย** (`player.can_move = false`)
## `layer` คุมแค่ "ใครวาดทับใคร" ไม่ได้กันอินพุตให้
##
## ⚠️ ใช้ path เป็น String ไม่ใช่ `preload()` — `preload` จะโหลดซีน UI **ทุกตัว**
## เข้าหน่วยความจำตั้งแต่เกมเริ่ม ทั้งที่บางตัวอาจไม่ถูกเปิดเลยทั้งรอบการเล่น
const UI_SCENES := {
	"hud": {"scene": "res://hud.tscn", "layer": 20},
	## ตัวอย่างของที่จะมาทีหลัง — เพิ่มบรรทัดแบบนี้แล้วเรียก UIRoot.show_ui("quest") ได้เลย
	## "quest": {"scene": "res://ui/quest_tracker.tscn", "layer": 21},
	## "map":   {"scene": "res://ui/map.tscn", "layer": 30},
}

## ตัวที่สร้างแล้วแต่ยังไม่เข้า tree (รอ `call_deferred`)
##
## 🚨 กันสร้างซ้ำเมื่อมีคนเรียกสองครั้งในเฟรมเดียวกัน — `add_child` ถูกเลื่อนไปท้ายเฟรม
## การค้นหาใน root ตอนนั้นจึงยังหาไม่เจอ แล้วจะได้ UIRoot สองตัวซ้อนกัน
## (ปัญหาเดียวกับที่ `music.gd` เจอ)
static var _pending: UIRoot = null

## id -> instance ที่สร้างแล้ว
var _uis: Dictionary = {}


## ==============================================
## API — เรียกจากที่ไหนก็ได้
## ==============================================

## โชว์ UI ตัวนั้น (สร้างให้ถ้ายังไม่มี) — คืน instance หรือ null ถ้าคีย์ผิด
static func show_ui(id: String) -> CanvasLayer:
	var ui: CanvasLayer = _get_or_create(id)
	if ui != null:
		ui.visible = true
	return ui


## ซ่อน UI ตัวนั้น — **ไม่ลบทิ้ง** สถานะข้างในยังอยู่ครบ
##
## ⚠️ ซ่อนไม่ใช่ลบโดยตั้งใจ — HUD ที่ถูกลบแล้วสร้างใหม่จะลืมว่าผู้เล่นเลือกช่องไหนอยู่
## และต้องไปอ่านสถานะจาก `GameState` ใหม่ทุกครั้ง
static func hide_ui(id: String) -> void:
	var root: UIRoot = _find()
	if root == null:
		return   ## ยังไม่เคยสร้างอะไรเลย = ไม่มีอะไรให้ซ่อน
	var ui: CanvasLayer = root._uis.get(id, null)
	if ui != null and is_instance_valid(ui):
		ui.visible = false


## ซ่อนทุกตัว — ใช้ตอนเข้าเมนูหลัก หรือฉากที่ไม่ควรมี UI การเล่น
static func hide_all() -> void:
	var root: UIRoot = _find()
	if root == null:
		return
	for id: String in root._uis.keys():
		var ui: CanvasLayer = root._uis[id]
		if is_instance_valid(ui):
			ui.visible = false


## เอา instance ไปสั่งงานตรง ๆ — คืน null ถ้ายังไม่เคยถูกสร้าง
##
## ⚠️ **ไม่สร้างให้** ต่างจาก `show_ui()` — ตัวนี้มีไว้ถามว่า "มีอยู่ไหม"
## สร้างให้ด้วยจะทำให้แค่ไปอ่านค่าก็เผลอสร้าง UI ที่ไม่มีใครตั้งใจเปิดขึ้นมา
static func get_ui(id: String) -> CanvasLayer:
	var root: UIRoot = _find()
	if root == null:
		return null
	var ui: CanvasLayer = root._uis.get(id, null)
	return ui if is_instance_valid(ui) else null


static func is_showing(id: String) -> bool:
	var ui: CanvasLayer = get_ui(id)
	return ui != null and ui.visible


## ==============================================
## ภายใน
## ==============================================

static func _get_or_create(id: String) -> CanvasLayer:
	if not UI_SCENES.has(id):
		push_error("ui_root.gd: ไม่รู้จัก UI '%s' (ที่มี: %s) — เพิ่มใน UI_SCENES ก่อน" \
			% [id, ", ".join(PackedStringArray(UI_SCENES.keys()))])
		return null

	var root: UIRoot = _ensure()
	if root == null:
		return null

	var existing: CanvasLayer = root._uis.get(id, null)
	if is_instance_valid(existing):
		return existing

	return root._spawn(id)


func _spawn(id: String) -> CanvasLayer:
	var info: Dictionary = UI_SCENES[id]
	var path: String = info.get("scene", "")

	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("ui_root.gd: โหลดซีน UI '%s' ไม่ได้ (%s)" % [id, path])
		return null

	var ui: CanvasLayer = packed.instantiate() as CanvasLayer
	if ui == null:
		push_error("ui_root.gd: รากของ '%s' ไม่ใช่ CanvasLayer — ตั้ง layer ไม่ได้" % path)
		return null

	## 🚨 ตั้ง `layer` จากโค้ด ไม่พึ่งค่าในซีน
	## ค่าใน `.tscn` ถูกเซฟทับได้ตอนใครไปแก้ซีนนั้น แล้ว UI จะไปโผล่ผิดชั้นแบบเงียบ ๆ
	## (เหตุผลเดียวกับที่ `scene_transition.tscn` ตั้ง layer ใน `_ready()`)
	ui.layer = int(info.get("layer", 10))
	ui.name = id.capitalize()

	_uis[id] = ui
	add_child(ui)
	return ui


## หาตัวที่มีอยู่ — ไม่สร้างใหม่
static func _find() -> UIRoot:
	if is_instance_valid(_pending):
		return _pending

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NODE_NAME) as UIRoot


## หาตัวที่มีอยู่ ไม่มีก็สร้าง
static func _ensure() -> UIRoot:
	var found: UIRoot = _find()
	if found != null:
		return found

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		push_error("ui_root.gd: ยังไม่มี SceneTree — เรียกเร็วเกินไป")
		return null

	var created := UIRoot.new()
	created.name = NODE_NAME
	_pending = created

	## ⚠️ ต้อง `call_deferred` เสมอ — ผู้เรียกมักอยู่ใน `_ready()` ของซีนหลัก
	## ซึ่งตอนนั้น root ยัง busy setting up children อยู่ `add_child` ตรง ๆ จะ error
	tree.root.call_deferred("add_child", created)
	return created


func _ready() -> void:
	## เข้า tree แล้ว ไม่ต้องจำว่า "กำลังรอ" อีก — ครั้งหน้า `_find()` เจอจาก root เอง
	_pending = null
