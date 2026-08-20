class_name Music
extends AudioStreamPlayer

## ==============================================
## เพลงประกอบที่เล่นข้ามฉาก
## ==============================================
## เพลงประจำ "ช่วงของเนื้อเรื่อง" ไม่ใช่ประจำฉาก — สั่งเปลี่ยนครั้งเดียวแล้วเล่นต่อไปเรื่อย ๆ
## ผ่านการเปลี่ยนฉากกี่ครั้งก็ได้ จนกว่าจะมีใครสั่งเปลี่ยนเป็นเพลงอื่น
##
## ```gdscript
## Music.play_track("rest")   ## เริ่มเพลงพัก — เรียกซ้ำเท่าไหร่ก็ไม่รีสตาร์ท
## Music.play_track("work")   ## เปลี่ยนเพลง — ครอสเฟดให้เอง
## Music.stop_music()     ## หยุด (ค่อย ๆ เบาลง)
## ```
##
## 🚨 **ไม่ใช่ autoload โดยตั้งใจ** — โปรเจกต์นี้เติม autoload ลง `project.godot` เองไม่ได้
## (Godot เขียนไฟล์ใหม่จากรายการในหน่วยความจำทุกครั้งที่ผู้ใช้แตะ Project Settings
##  แล้ว autoload ที่เติมจากข้างนอกจะถูกลบทิ้งเงียบ ๆ — เกิดมาแล้ว 2 ครั้ง ดู DEVLOG 2026-07-30)
##
## ใช้วิธี **แขวนโหนดไว้ที่ `get_tree().root`** แทน ซึ่งรอดจาก `change_scene_to_file()`
## เพราะตัว root ไม่ถูกลบ — เป็นกลไกเดียวกับที่ `scene_transition.tscn` ใช้อยู่แล้ว
## · เข้าถึงผ่าน static method จึงเรียกจากที่ไหนก็ได้โดยไม่ต้องหา node เอง

## ชื่อโหนดใต้ root — ใช้หาตัวเดิมให้เจอตอนเปลี่ยนฉากแล้วมีคนเรียกซ้ำ
const NODE_NAME := "MusicPlayer"

## ทะเบียนเพลง — เรียกด้วยคีย์สั้น ๆ ไม่ต้องจำ path
##
## ⚠️ **แก้ path ที่นี่ที่เดียว** — ที่เรียกใช้ทุกแห่งส่งแค่คีย์
## เปลี่ยนชื่อไฟล์เพลงแล้วไม่ต้องไล่แก้ทุกฉาก (Godot ไม่ตามแก้ string ใน `.gd` ให้อยู่แล้ว)
const TRACKS := {
	"rest": "res://soud/restSong.mp3",
	"morning_bus": "res://soud/Morning Bus Stop.mp3",
	"work_start": "res://soud/WorkStart.ogg",
}

const DEFAULT_VOLUME_DB := -12.0
const DEFAULT_FADE := 2.0

## ตัวที่สร้างแล้วแต่ยังไม่เข้า tree (รอ `call_deferred`)
##
## 🚨 มีไว้กันสร้างซ้ำเมื่อมีคนเรียก `play()` สองครั้งในเฟรมเดียวกัน
## `add_child` ถูกเลื่อนไปท้ายเฟรม การค้นหาใน root ตอนนั้นจึงยังหาไม่เจอ
## แล้วจะได้ตัวเล่นสองตัวเล่นเพลงซ้อนกันแบบหาสาเหตุยากมาก
static var _pending: Music = null

var _fade_tween: Tween = null

## ค่าที่ฝากไว้ตอนยังไม่เข้า tree — `_ready()` จะหยิบไปใช้
var _queued_stream: AudioStream = null
var _queued_fade := 0.0
var _queued_volume := DEFAULT_VOLUME_DB


## ==============================================
## API — เรียกจากที่ไหนก็ได้
## ==============================================

## เริ่มเพลงตามคีย์ใน `TRACKS`
##
## ⚠️ **ชื่อ `play_track` ไม่ใช่ `play`** — `AudioStreamPlayer` มี `play()` / `is_playing()`
## ของตัวเองอยู่แล้ว ตั้งชื่อ static ชนกันจะขึ้น `Parse Error: Could not resolve external class member`
## ทั้งไฟล์ที่เรียกใช้ ซึ่ง error ไม่ได้ชี้มาที่ไฟล์นี้เลย (เจอจริงตอนเขียน)
##
## 🚨 **เรียกซ้ำด้วยเพลงเดิม = ไม่ทำอะไรเลย** (ไม่รีสตาร์ท ไม่กระตุก)
## เป็นหัวใจของ "เล่นจนกว่าจะบอกให้เปลี่ยน" — ฉากไหนอยากมั่นใจว่าเพลงถูกก็เรียกได้เลย
## ไม่ต้องเช็คก่อนว่ากำลังเล่นอยู่หรือเปล่า
static func play_track(track_key: String, fade: float = DEFAULT_FADE,
		volume_db: float = DEFAULT_VOLUME_DB) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	if not TRACKS.has(track_key):
		push_error("music.gd: ไม่มีเพลงชื่อ `%s` ในทะเบียน (ที่มี: %s)" \
			% [track_key, ", ".join(PackedStringArray(TRACKS.keys()))])
		return

	var stream: AudioStream = load(TRACKS[track_key])
	if stream == null:
		push_error("music.gd: โหลดไฟล์เพลงไม่ได้ — %s" % TRACKS[track_key])
		return

	## ⚠️ `loop` อยู่ที่ตัว **ทรัพยากร** ไม่ใช่ที่ AudioStreamPlayer
	## ไม่ตั้งตรงนี้เพลงจะเล่นรอบเดียวแล้วเงียบยาวข้ามฉากไปเลย
	if "loop" in stream:
		stream.loop = true

	var player := _resolve(tree)
	if player != null:
		player._switch_to(stream, fade, volume_db)
		return

	## ยังไม่มีตัวเล่น — สร้างใหม่แล้วฝากค่าไว้ให้ `_ready()`
	##
	## ⚠️ ต้อง `call_deferred` เสมอ — ผู้เรียกอาจอยู่ใน `_ready()` ของซีนหลัก
	## ซึ่งตอนนั้น root ยัง busy เพิ่มลูกอยู่ `add_child` ตรง ๆ จะ error
	var fresh := Music.new()
	fresh.name = NODE_NAME
	fresh._queued_stream = stream
	fresh._queued_fade = fade
	fresh._queued_volume = volume_db
	_pending = fresh
	tree.root.add_child.call_deferred(fresh)


## หยุดเพลง — ค่อย ๆ เบาลงแล้วค่อยหยุดจริง
##
## ⚠️ ชื่อ `stop_music` ไม่ใช่ `stop` เพราะ `AudioStreamPlayer` มี `stop()` ของตัวเองอยู่แล้ว
## ตั้งชื่อชนกันจะกลายเป็นการ override เมธอดของคลาสแม่โดยไม่ได้ตั้งใจ
static func stop_music(fade: float = DEFAULT_FADE) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var player := _resolve(tree)
	if player == null:
		return
	player._fade_out_then_stop(fade)


## กำลังเล่นเพลงคีย์นี้อยู่ไหม — ให้ฝั่งเนื้อเรื่องเช็คได้โดยไม่ต้องหา node เอง
static func is_track_playing(track_key: String) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not TRACKS.has(track_key):
		return false
	var player := _resolve(tree)
	if player == null or not player.playing:
		return false
	return player.stream != null and player.stream.resource_path == TRACKS[track_key]


## ==============================================
## ภายใน
## ==============================================

## หาตัวเล่นที่มีอยู่ — ทั้งตัวที่อยู่ใน tree แล้วและตัวที่ยังรอ deferred
static func _resolve(tree: SceneTree) -> Music:
	var found := tree.root.get_node_or_null(NODE_NAME)
	if found is Music:
		_pending = null
		return found
	if is_instance_valid(_pending):
		return _pending
	_pending = null
	return null


func _ready() -> void:
	## ⚠️ เพลงต้องดังต่อแม้เกมจะหยุด (เมนู/บทสนทนาที่ pause) — ไม่งั้นจะเงียบเป็นช่วง ๆ
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pending = null
	if _queued_stream != null:
		_switch_to(_queued_stream, _queued_fade, _queued_volume)
		_queued_stream = null


## เปลี่ยนไปเล่นเพลงใหม่ — เพลงเดิมจะครอสเฟดออก
##
## ⚠️ พารามิเตอร์ชื่อ `target_db` ไม่ใช่ `volume_db` — ชื่อหลังชนกับ property ของ
## `AudioStreamPlayer` แล้วจะบังกันจนเขียนค่าไม่เข้า (บั๊กเงียบสนิท เสียงจะไม่เปลี่ยนเลย)
func _switch_to(next_stream: AudioStream, fade: float, target_db: float) -> void:
	## 🚨 เพลงเดิมที่ยังเล่นอยู่ = ไม่แตะเลย
	## เทียบด้วย `resource_path` ไม่ใช่ `==` เพราะ `load()` อาจคืนคนละ instance
	## หลังจากทรัพยากรถูกปล่อยจากแคชแล้วโหลดใหม่ตอนเปลี่ยนฉาก
	if playing and stream != null and next_stream != null \
			and stream.resource_path == next_stream.resource_path:
		return

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	if fade <= 0.0:
		stream = next_stream
		volume_db = target_db
		play()
		return

	## มีเพลงเก่าอยู่ → เบาลงก่อนแล้วค่อยสลับ · ไม่มี → ขึ้นจากเงียบเลย
	_fade_tween = create_tween()
	if playing:
		_fade_tween.tween_property(self, "volume_db", -60.0, fade * 0.5)
	_fade_tween.tween_callback(_swap_stream.bind(next_stream))
	_fade_tween.tween_property(self, "volume_db", target_db, fade)


func _swap_stream(next_stream: AudioStream) -> void:
	stream = next_stream
	volume_db = -60.0
	play()


func _fade_out_then_stop(fade: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if fade <= 0.0 or not playing:
		stop()
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "volume_db", -60.0, fade)
	_fade_tween.tween_callback(stop)
