extends CanvasLayer

@onready var vdo_player = $VideoStreamPlayer

func _ready():
	vdo_player.play()
	vdo_player.finished.connect(_on_video_finished)

func _on_video_finished():
	vdo_player.play()
