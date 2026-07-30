extends CanvasLayer
## ==============================================
## เอฟเฟกต์ตอนคลิก - วงกลมกระเพื่อม + เสียง
## ==============================================
## ตั้งเป็น Autoload เพื่อให้ทำงานทุกซีนโดยไม่ต้องลากใส่ทีละซีน:
##   Project > Project Settings > Autoload
##   เลือก click_effect.tscn -> ตั้งชื่อ "ClickEffect" -> กด Add
##
## โครงสร้าง node:
##   ClickEffect (CanvasLayer, layer = 100)  <- สคริปต์นี้
##   ├── Effects            (Control, mouse_filter = Ignore)  ที่เก็บวงกลม
##   └── AudioStreamPlayer  (AudioStreamPlayer)               เสียงคลิก
##
## ⚠️ ต้องลากไฟล์เสียงใส่ช่อง Stream ของ AudioStreamPlayer ใน Inspector
##    ถ้าไม่ใส่ จะมีเสียงเตือนใน Output ตอนรัน แต่วงกลมยังทำงานปกติ

const RIPPLE = preload("res://ui_ripple.tscn")

## สุ่มระดับเสียงสูง-ต่ำเล็กน้อยทุกครั้งที่คลิก
## เกมนี้มีฉากที่ต้องกดรัว ๆ 20-30 ที (ปลุกน้ำฟ้าบนรถเมล์)
## ถ้าเสียงเหมือนกันเป๊ะทุกครั้งจะฟังดูเหมือนเครื่องจักรและน่ารำคาญเร็ว
## สุ่มนิดเดียวก็ช่วยได้มาก - ตั้งเป็น 0.0 ถ้าอยากให้เสียงคงที่
@export var pitch_variation: float = 0.12

@onready var effects: Control = $Effects
@onready var audio: AudioStreamPlayer = $soud


func _ready() -> void:
	if audio and audio.stream == null:
		push_warning("click_effect.gd: AudioStreamPlayer ยังไม่มีไฟล์เสียง — ลากไฟล์เสียงใส่ช่อง Stream ใน Inspector")


## ใช้ _input ไม่ใช่ _unhandled_input เพื่อให้เอฟเฟกต์เกิดทุกครั้งที่คลิก
## _unhandled_input ทำงานหลังสุด ถ้าคลิกโดนปุ่มหรือ Control ที่ mouse_filter = Stop
## ตัวนั้นจะกินคลิกไปก่อน แล้ว ripple จะไม่เกิด
## _input ได้รับ event ก่อนใคร และเราไม่เรียก set_input_as_handled()
## คลิกจึงยังส่งต่อไปให้ปุ่มทำงานตามปกติ แค่แถม ripple เพิ่มเข้าไป
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		_spawn_ripple(event.position)
		_play_click_sound()


func _spawn_ripple(pos: Vector2) -> void:
	if effects == null:
		return
	var ripple := RIPPLE.instantiate()
	effects.add_child(ripple)
	ripple.global_position = pos


## เล่นเสียงคลิก
## เรียก play() ซ้ำระหว่างที่เสียงเดิมยังไม่จบ = ตัดเสียงเดิมแล้วเริ่มใหม่
## ซึ่งเป็นพฤติกรรมที่ต้องการสำหรับเสียงคลิก (ตอบสนองทันทีทุกครั้งที่กด)
func _play_click_sound() -> void:
	if audio == null or audio.stream == null:
		return
	audio.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	audio.play()
