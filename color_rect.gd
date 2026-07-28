extends ColorRect

@onready var shader_mat := material as ShaderMaterial

func dissolve():
	shader_mat.set_shader_parameter("progress", 0.0)

	var tween = create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, 1.5)

func _set_progress(value):
	shader_mat.set_shader_parameter("progress", value)
