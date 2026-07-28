extends Label

@export var target_scene: String = "res://p.tscn"
@export var normal_color := Color(0.53, 0.53, 0.53, 1.0)
@export var hover_color := Color(1.2, 0.942, 0.0, 1.0)
@export var hover_scale := Vector2(0.95, 0.95)
@export var normal_scale := Vector2(1, 1)
@export var shrink_scale := Vector2(0.8, 0.8)
@export var tween_duration := 0.2

var current_tween: Tween
var is_transitioning := false

func _ready():
	print("Start.gd _ready() called | path: ", get_path(), " | instance_id: ", get_instance_id())
	mouse_filter = Control.MOUSE_FILTER_STOP
	print_stack()
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size / 2

	modulate = normal_color
	scale = normal_scale

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func _on_mouse_entered():
	if is_transitioning:
		return
	_kill_tween()
	current_tween = create_tween().set_parallel(true)
	current_tween.tween_property(self, "modulate", hover_color, tween_duration)
	current_tween.tween_property(self, "scale", hover_scale, tween_duration)

	add_theme_constant_override("outline_size", 4)
	add_theme_color_override("font_outline_color", Color(1, 1, 0, 0.5))

func _on_mouse_exited():
	if is_transitioning:
		return
	_kill_tween()
	current_tween = create_tween().set_parallel(true)
	current_tween.tween_property(self, "modulate", normal_color, tween_duration)
	current_tween.tween_property(self, "scale", normal_scale, tween_duration)

	add_theme_constant_override("outline_size", 0)

func _on_gui_input(event):
	if is_transitioning:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_transitioning = true
		_kill_tween()

		current_tween = create_tween()
		current_tween.tween_property(self, "scale", shrink_scale, 0.1)
		current_tween.tween_property(self, "scale", normal_scale, 0.1)
		await current_tween.finished

		var fade = preload("res://scene_transition.tscn").instantiate()
		get_tree().root.add_child(fade)

		await fade.fade_out()
		get_tree().change_scene_to_file(target_scene)

		# ใช้ get_tree() จาก fade แทน self เพราะ self อาจถูก free ไปแล้ว
		await fade.get_tree().process_frame
		await fade.fade_in()
func _kill_tween():
	if current_tween and current_tween.is_valid():
		current_tween.kill()
