extends CanvasLayer

## ชั้นการวาดของม่านเฟด - ต้องสูงกว่า CanvasLayer อื่นทุกตัวในเกม
##
## ⚠️ CanvasLayer ที่ layer เท่ากันจะเรียงตามลำดับใน tree ซึ่งเดาไม่ได้
## ตอนแรกทุกตัวเป็น 1 หมด (Chat, DialogueBox, SceneTransition) UI จึงลอยอยู่เหนือม่านเฟด
## เปลี่ยนฉากทีไร กล่องแชทกับกล่องคำพูดไม่ยอมมืดตามไปด้วย
##
## ตั้งจากโค้ดแทนการตั้งในซีน เพื่อให้ได้ผลแน่นอนแม้ซีนถูกเซฟทับ
## 128 = ค่าสูงสุดที่ Godot รับ (สูงกว่า ClickEffect ที่ 100 ด้วย)
@export var fade_layer: int = 128

@onready var shader := $ColorRect2.material as ShaderMaterial


func _ready() -> void:
	layer = fade_layer


## เปลี่ยนฉากพร้อมเฟด - จบในตัวเอง ผู้เรียกไม่ต้อง await อะไรต่อ
##
## ⚠️ ต้อง add_child ตัวนี้ไว้ที่ get_tree().root เท่านั้น ห้ามใส่ในซีนที่กำลังจะถูกเปลี่ยน
## เพราะ change_scene_to_file() ลบซีนเดิมทิ้ง ถ้า node นี้อยู่ในนั้นจะถูกลบไปด้วย
## แล้ว await ที่ค้างอยู่จะไม่ทำงานต่อ -> จอค้างดำถาวร
##
## เหตุผลที่แยกเมธอดนี้ออกมา: เดิมผู้เรียกต้องทำ fade_out -> change_scene -> fade_in เอง
## ซึ่ง**ผู้เรียกถูกลบทิ้งไปแล้ว**ตั้งแต่บรรทัด change_scene โค้ดหลังจากนั้นจึงเสี่ยงมาก
func transition_to(scene_path: String) -> void:
	await fade_out()
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await fade_in()

func fade_out():

	shader.set_shader_parameter("progress",0.0)

	var tween = create_tween()

	tween.tween_property(
		shader,
		"shader_parameter/progress",
		1.0,
		1.0
	)

	await tween.finished


func fade_in():

	shader.set_shader_parameter("progress",1.0)

	var tween = create_tween()

	tween.tween_property(
		shader,
		"shader_parameter/progress",
		0.0,
		1.0
	)

	await tween.finished

	queue_free()
