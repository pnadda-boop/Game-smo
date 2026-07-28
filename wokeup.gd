extends Node2D
class_name wokeup



@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = $Timer
@onready var area: Area2D =  $AnimatedSprite2D/Area2D # 🆕

var animations = [
	"idle",
	"halfasleep",
	"wokeup"
]
var stage := 0
var click_count := 0
var clicks_needed := 0


func _ready():
	randomize()
	anim.play(animations[stage])
	roll_next_target()
	timer.one_shot = true
	timer.wait_time = 1.0 # หยุดคลิกเกิน 1 วินาที รีเซ็ต
	timer.timeout.connect(_on_timer_timeout)
	anim.animation_finished.connect(_on_animation_finished)
	# 🆕 เปลี่ยนจาก _input (รับคลิกทั้งจอ) มาเป็น Area2D (รับคลิกเฉพาะโดนตัวละคร)
	area.input_event.connect(_on_area_input_event)


# 🆕 แทนที่ _input(event) เดิม - ทำงานเหมือนเดิมทุกอย่าง แค่เปลี่ยนช่องทางรับ event
func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		# ถ้าอยู่ช่วงสุดท้ายแล้ว ไม่ต้องคลิกอีก
		if stage >= animations.size() - 1:
			return
		click_count += 1
		timer.start()
		print("%d / %d" % [click_count, clicks_needed])
		if click_count >= clicks_needed:
			stage += 1
			click_count = 0
			anim.play(animations[stage])
			# ถ้ายังไม่ใช่ wokeup ให้สุ่มจำนวนคลิกใหม่
			if stage < animations.size() - 1:
				roll_next_target()


func roll_next_target():
	match stage:
		0:
			clicks_needed = randi_range(3, 5) # idle -> halfasleep
		1:
			clicks_needed = randi_range(5, 8) # halfasleep -> wokeup


func _on_timer_timeout():
	click_count = 0
	print("รีเซ็ตการคลิก")


func _on_animation_finished():
	if anim.animation == "wokeup":
		anim.play("sit")
