extends CanvasLayer
## ==============================================
## หน้าเมนูเริ่มเกม (start_manu.tscn)
## ==============================================
## - วิดีโอพื้นหลังเล่นวนไม่รู้จบ
## - เปิดเกมมาแล้วจอค่อย ๆ สว่างขึ้นจากดำ ไม่ใช่เด้งโผล่มาทันที
##
## ปุ่ม "WORK START" กับการเฟดออกไปฉากถัดไปอยู่ที่ Start.gd (ติดที่ node Label)

const SCENE_TRANSITION := preload("res://scene_transition.tscn")

## เปิดเกมมาแล้วค่อย ๆ สว่างขึ้นจากจอดำ - ปิดได้ถ้าอยากให้เมนูขึ้นทันที
@export var fade_in_on_start: bool = true

@onready var vdo_player = get_node_or_null("VideoStreamPlayer")


func _ready() -> void:
	if fade_in_on_start:
		_play_fade_in()

	if vdo_player == null:
		push_warning("start_manu.gd: ไม่พบ node 'VideoStreamPlayer' — หน้าเมนูจะไม่มีวิดีโอพื้นหลัง")
		return

	vdo_player.play()
	vdo_player.finished.connect(_on_video_finished)


## จอดำแล้วค่อยจางออกให้เห็นเมนู
##
## ⚠️ add_child ที่ตัวเอง ไม่ใช่ที่ get_tree().root
## ตอน _ready() ของซีนหลัก root ยัง "busy setting up children" อยู่ ใส่ตรงนั้นจะ error
## และซีนนี้ไม่ถูกเปลี่ยนระหว่างเฟดเข้า จึงไม่มีปัญหาแบบตอน transition_to()
## (ตัวเฟดตั้ง layer = 128 ของตัวเอง ซ้อนใน CanvasLayer ก็ยังอยู่บนสุดอยู่ดี)
func _play_fade_in() -> void:
	var fade := SCENE_TRANSITION.instantiate()
	add_child(fade)
	fade.fade_in()


func _on_video_finished() -> void:
	vdo_player.play()
