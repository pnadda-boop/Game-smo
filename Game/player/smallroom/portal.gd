extends Area2D

@export_file("*.tscn") var target_scene : String
@export var target_spawn_point : String

@onready var prompt_e = $PromptE

var player_inside := false


func _ready():
	if prompt_e:
		prompt_e.visible = false
		prompt_e.set_process(false)


func _on_body_entered(body):
	if body.is_in_group("player"):
		player_inside = true
		if prompt_e:
			prompt_e.visible = true
			prompt_e.set_process(true)


func _on_body_exited(body):
	if body.is_in_group("player"):
		player_inside = false
		if prompt_e:
			prompt_e.visible = false
			prompt_e.set_process(false)


func _process(delta):
	if player_inside and Input.is_action_just_pressed("interact"):
		change_scene()


func change_scene():
	GameState.next_spawn_point = target_spawn_point
	get_tree().change_scene_to_file(target_scene)
