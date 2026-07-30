extends Control

func _ready():

	pivot_offset = size / 2

	scale = Vector2.ZERO
	modulate.a = 0.35

	var tween = create_tween()

	tween.parallel().tween_property(
		self,
		"scale",
		Vector2(5,5),
		0.35
	)

	tween.parallel().tween_property(
		self,
		"modulate:a",
		0.0,
		0.35
	)

	await tween.finished

	queue_free()
