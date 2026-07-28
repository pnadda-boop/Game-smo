extends Camera2D

@export var shake_strength := 2.0
@export var shake_speed := 1.0
@export var noise_strength := 1.0   # ความสั่นแบบสุ่ม จำลองถนนขรุขระ
@export var sway_strength := 0.5    # แกว่งซ้าย-ขวาเล็กน้อย

var t := 0.0
var noise := FastNoiseLite.new()

func _ready():
	noise.seed = randi()
	noise.frequency = 2.0

func _process(delta):
	t += delta

	# คลื่นหลักแบบ sine (จังหวะเครื่องยนต์/ล้อหมุน)
	var base_bounce = sin(t * shake_speed * TAU) * shake_strength

	# ผสมความถี่ที่สองเข้าไปให้ดูไม่นิ่งเกินไป
	var secondary_bounce = sin(t * shake_speed * TAU * 2.7) * shake_strength * 0.3

	# noise แบบสุ่ม จำลองถนนขรุขระ กระแทกไม่สม่ำเสมอ
	var road_noise = noise.get_noise_1d(t * 20.0) * noise_strength

	offset.y = base_bounce + secondary_bounce + road_noise

	# แกว่งซ้ายขวาเบาๆ ให้รู้สึกเหมือนรถโคลงตัว
	offset.x = sin(t * shake_speed * TAU * 0.5) * sway_strength
