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

## หน่วงก่อนรีเซ็ตความคืบหน้าการคลิก - หยุดคลิกนานเกินนี้แล้วต้องเริ่มนับใหม่
@export var click_reset_delay: float = 1.0

## จำนวนคลิกที่ต้องกดในแต่ละช่วง สุ่มในช่วงนี้ทุกครั้ง
## เพื่อให้ผู้เล่นไม่รู้ล่วงหน้าว่าเหลืออีกกี่ที ต้องกดย้ำ ๆ ไปเรื่อย ๆ เหมือนปลุกคนจริง
@export var clicks_stage1_min: int = 8   ## idle -> halfasleep
@export var clicks_stage1_max: int = 12
@export var clicks_stage2_min: int = 14  ## halfasleep -> wokeup
@export var clicks_stage2_max: int = 20


func _ready():
	randomize()
	anim.play(animations[stage])
	roll_next_target()
	timer.one_shot = true
	timer.wait_time = click_reset_delay
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
			else:
				# ตื่นแล้ว ไม่ต้องนับถอยหลังรีเซ็ตอีก
				timer.stop()


func roll_next_target():
	match stage:
		0:
			clicks_needed = randi_range(clicks_stage1_min, clicks_stage1_max)
		1:
			clicks_needed = randi_range(clicks_stage2_min, clicks_stage2_max)


func _on_timer_timeout():
	click_count = 0
	print("รีเซ็ตการคลิก")


func _on_animation_finished():
	if anim.animation == "wokeup":
		anim.play("sit")
