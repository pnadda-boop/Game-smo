extends Node2D

@export var float_speed := 5.0
@export var float_range := 5.0

var time := 0.0
var start_y := 0.0

func _ready():
	start_y = position.y

func _process(delta):
	time += delta
	position.y = start_y + sin(time * float_speed) * float_range
