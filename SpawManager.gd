extends Node

@export var player_path: NodePath
@export var spawn_root: NodePath

func _ready():
	if GameState.next_spawn_point == "":
		return
	
	var player = get_node_or_null(player_path)
	var root = get_node_or_null(spawn_root)
	
	if not player:
		push_error("ไม่พบ Player ที่ path: " + str(player_path))
		return
	if not root:
		push_error("ไม่พบ spawn_root ที่ path: " + str(spawn_root))
		return
	
	var spawn = root.get_node_or_null(GameState.next_spawn_point)
	if spawn:
		player.global_position = spawn.global_position
	else:
		push_error("ไม่พบ Spawn : " + GameState.next_spawn_point)
	
	GameState.next_spawn_point = ""
