extends Node2D

@onready var player = $player
@onready var bus = $Bus

var bus_leave := false

func _process(delta):
	if bus_leave:
		return

	if player.global_position.distance_to(bus.global_position) > 180:
		bus_leave = true

		await get_tree().create_timer(1.0).timeout

		bus.start_drive()
