extends CanvasLayer

@onready var shader := $ColorRect2.material as ShaderMaterial

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
