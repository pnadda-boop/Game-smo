extends Node2D
## ==============================================
## ลานจอดรถ / ป้ายรถเมล์ (p.tscn)
## ==============================================
## รถเมล์ออกได้ 2 ทาง:
##   1. ปกติ - ผู้เล่นเดินห่างรถเกิน bus_leave_distance แล้วรถค่อยออก
##   2. อินโทร - มาถึงจากฉากแชท รถออกเองทันที ผู้เล่นขยับไม่ได้ แล้วน้ำฟ้าพูด
##
## ทาง 2 ทำงานเมื่อ GameState.pending_intro ตรงกับ INTRO_ARRIVE_BUS เท่านั้น
## เข้าฉากนี้จากประตูอื่นจะได้พฤติกรรมเดิมทุกอย่าง

const DIALOGUE_BOX := preload("res://DialogueBox.tscn")

@onready var player = $player
@onready var bus = $Bus

## เดินห่างรถเกินกี่พิกเซลแล้วรถถึงจะออก (ทางที่ 1)
@export var bus_leave_distance: float = 180.0
## หน่วงหลังเดินห่างพอ ก่อนรถออก
@export var bus_leave_delay: float = 1.0

@export_group("อินโทรตอนมาจากแชท")
## หน่วงหลังเข้าฉาก ก่อนรถออก - เผื่อเวลาให้จอเฟดเข้ามาจนเห็นภาพก่อน
## ถ้าให้รถออกทันทีตั้งแต่จอยังดำ ผู้เล่นจะพลาดจังหวะรถออกไปเลย
@export var arrive_bus_delay: float = 1.0
## หน่วงหลังรถเริ่มออก ก่อนบทพูดโผล่ - ให้เห็นรถวิ่งไปสักพักก่อน
@export var arrive_line_delay: float = 1.6
@export var arrive_speaker: String = "น้ำฟ้า"
@export_multiline var arrive_line: String = "สุดท้ายก็มาสายจนได้ต้องรีบแล้ว"
## อนิเมชันของรูปตอนพูดบรรทัดนี้ - ต้องมีชื่อนี้จริงใน SpriteFrames ของตัวละครนั้น
## ปล่อยว่าง = ใช้ default_anim ของ dialogue_system ("talk")
@export var arrive_anim: String = "happy_tired"
## โชว์รูปครึ่งตัวในกล่องคำพูดไหม - ปิดถ้าอยากให้เห็นฉากเต็ม ๆ
@export var arrive_show_portrait: bool = true
@export_group("")

var bus_leave := false
var _dialogue_box: Node = null


func _ready() -> void:
	if GameState.pending_intro != GameState.INTRO_ARRIVE_BUS:
		return

	## ⚠️ ล้างทิ้งทันทีที่อ่าน ไม่งั้นเดินออกแล้วกลับเข้ามาใหม่ อินโทรจะเล่นซ้ำ
	GameState.pending_intro = ""
	_play_arrival_intro()


func _process(_delta: float) -> void:
	if bus_leave:
		return
	## รถถูกลบทิ้งเมื่อวิ่งพ้นจอ (bus.gd) - ต้องเช็คก่อนอ่านตำแหน่ง
	if not is_instance_valid(bus) or not is_instance_valid(player):
		return

	if player.global_position.distance_to(bus.global_position) > bus_leave_distance:
		bus_leave = true
		await get_tree().create_timer(bus_leave_delay).timeout
		if is_instance_valid(bus):
			bus.start_drive()


## มาถึงจากฉากแชท: รถออกก่อน แล้วค่อยเล่าเรื่อง ผู้เล่นขยับไม่ได้ตลอดช่วงนี้
##
## ลำดับนี้จงใจให้รถออก "ก่อน" บทพูด เพราะบทพูดคือปฏิกิริยาต่อการตกรถ
## ถ้าพูดก่อนแล้วรถค่อยออก เหตุกับผลจะสลับกัน
func _play_arrival_intro() -> void:
	## ปิดตัวตรวจจับระยะไปเลย ไม่งั้นพอผู้เล่นขยับได้แล้วมันจะสั่งรถออกซ้ำ
	bus_leave = true
	_set_player_can_move(false)

	await get_tree().create_timer(arrive_bus_delay).timeout
	if is_instance_valid(bus):
		bus.start_drive()

	await get_tree().create_timer(arrive_line_delay).timeout

	var box := _get_dialogue_box()
	if box == null or not box.has_method("start_dialogue"):
		push_error("parking.gd: ไม่พบกล่องคำพูดที่ใช้ได้ — ปลดล็อกผู้เล่นแทน")
		_set_player_can_move(true)
		return

	## CONNECT_ONE_SHOT: ต่อครั้งเดียวแล้วตัดเอง
	## ไม่งั้นบทสนทนากับ NPC ตัวอื่นในฉากนี้จบเมื่อไหร่ ก็จะมาปลดล็อกซ้ำ
	box.dialogue_finished.connect(_on_arrival_line_finished, CONNECT_ONE_SHOT)
	var line := {"name": arrive_speaker, "text": arrive_line}
	if arrive_anim != "":
		line["anim"] = arrive_anim

	box.start_dialogue([line], null, arrive_show_portrait)


func _on_arrival_line_finished() -> void:
	_set_player_can_move(true)


func _set_player_can_move(value: bool) -> void:
	if is_instance_valid(player) and "can_move" in player:
		player.can_move = value


## หากล่องคำพูดในซีน ถ้าไม่มีก็สร้างเพิ่มให้
## ทำแบบนี้เพื่อไม่ต้องลากใส่ทุกซีน และไม่สร้างซ้ำถ้าซีนมีอยู่แล้ว
## (ตัวเดียวกับที่ wokeup.gd ใช้)
func _get_dialogue_box() -> Node:
	if _dialogue_box and is_instance_valid(_dialogue_box):
		return _dialogue_box

	var existing := get_tree().get_first_node_in_group("dialogue_ui")
	if existing and existing.has_method("start_dialogue"):
		_dialogue_box = existing
		return _dialogue_box

	_dialogue_box = DIALOGUE_BOX.instantiate()
	add_child(_dialogue_box)
	return _dialogue_box
