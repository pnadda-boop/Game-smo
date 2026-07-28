extends Node2D
class_name MorningLightEffect

## Scene tree ที่แนะนำ:
##   MorningLightEffect (Node2D)  <- ติด script นี้ (วางไว้ level เดียวกับตัวละคร/ฉาก)
##   ├─ LightRay (Polygon2D)       <- ใส่ light_ray.gdshader ใน Material
##   └─ AmbientGlow (ColorRect)    <- ใส่ morning_glow.gdshader ใน Material, Full Rect

@onready var light_ray: Polygon2D = $LightRay
@onready var ambient_glow: ColorRect = $AmbientGlow

## ความสว่างสูงสุดของลำแสงตอนแสดงผลเต็มที่ (ตรงกับ uniform "intensity" ใน light_ray.gdshader)
@export var ray_max_intensity: float = 1.0
## ความสว่างสูงสุดของโทนอบอุ่นทั่วซีน (ตรงกับ uniform "intensity" ใน morning_glow.gdshader)
@export var glow_max_intensity: float = 0.15

## มุมแกว่งเบาๆ ของลำแสง (องศา) ให้ดูเหมือนมีลมพัด/ไม่นิ่งตาย
## 🆕 ปิดไว้เป็นค่าเริ่มต้น (0.0) เพราะการหมุนทำให้ลำแสงกวาดผ่านพื้นหลังสว่าง-มืดต่างกัน ดูเหมือนกระพริบเป็นจังหวะ
## อยากได้ผลนี้กลับมา ค่อยปรับเป็นค่าอื่น (เช่น 1.0-1.5) เองทีหลัง
@export var sway_degrees: float = 0.0
@export var sway_duration: float = 4.0


func _ready() -> void:
	# 🆕 โชว์เต็มความสว่างทันที ไม่ต้องรอเรียก fade_in() ถึงจะขึ้น (ตรงกับที่ต้องการแสงคงที่)
	# ถ้าอยากได้จังหวะเฟดเข้าแบบเดิม เปลี่ยนบรรทัดล่างเป็น _set_intensity(0.0) แล้วไปเรียก fade_in() เองจากสคริปต์ซีน
	_set_intensity(1.0)
	_start_sway()


## เรียกตอนอยากให้แสงค่อยๆ โผล่ขึ้นมา (เช่น เรียกพร้อมกับ fade_in ของฉาก)
func fade_in(duration: float = 3.0) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_ray_intensity, 0.0, ray_max_intensity, duration)
	tween.tween_method(_set_glow_intensity, 0.0, glow_max_intensity, duration)


## เรียกตอนอยากให้แสงค่อยๆ หายไป (เช่น ก่อนตัดฉาก)
func fade_out(duration: float = 1.0) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_ray_intensity, ray_max_intensity, 0.0, duration)
	tween.tween_method(_set_glow_intensity, glow_max_intensity, 0.0, duration)


func _set_intensity(value: float) -> void:
	_set_ray_intensity(value)
	_set_glow_intensity(value * glow_max_intensity)


func _set_ray_intensity(value: float) -> void:
	if light_ray and light_ray.material is ShaderMaterial:
		light_ray.material.set_shader_parameter("intensity", value)


func _set_glow_intensity(value: float) -> void:
	if ambient_glow and ambient_glow.material is ShaderMaterial:
		ambient_glow.material.set_shader_parameter("intensity", value)


## แกว่งลำแสงเบาๆ วนไปเรื่อยๆ ให้ดูมีชีวิต ไม่นิ่งเป็นภาพตาย
func _start_sway() -> void:
	if light_ray == null:
		return
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(light_ray, "rotation_degrees", sway_degrees, sway_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(light_ray, "rotation_degrees", -sway_degrees, sway_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
