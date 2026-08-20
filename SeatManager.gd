extends Node

## ==============================================
## ตัวกลางคุมระบบที่นั่งทั้งหมด + ตรวจสอบเงื่อนไข
## ==============================================
## วิธีติดตั้ง: Project > Project Settings > Autoload
##   เลือกไฟล์นี้ -> ตั้งชื่อ Node Name เป็น "SeatManager" -> กด Add

## เก็บที่นั่งทั้งหมด key = Vector2i(row, column) -> Seat node
var _seats: Dictionary = {}


## ช่องที่กำลังมี NPC ถูกลากมาลอยอยู่เหนือ (null = ไม่มี)
##
## อยู่ตรงนี้ไม่ใช่ในตัวที่นั่งแต่ละช่อง เพราะเป็นสถานะที่ **มีได้ทีละช่องเดียวทั้งกระดาน**
## เก็บไว้ที่แต่ละช่องจะต้องคอยไล่บอกช่องอื่นให้ดับเอง ซึ่งเป็นงานของตัวกลางอยู่แล้ว
var _hovered_seat: Seat = null


## เรียกจาก seat.gd ตอน _ready() เพื่อลงทะเบียนที่นั่งเข้าระบบอัตโนมัติ
func register_seat(seat: Seat) -> void:
	var key := Vector2i(seat.row, seat.column)
	_seats[key] = seat


## บอกว่าตอนนี้ลาก NPC มาลอยเหนือช่องไหน — `click.gd` เรียกทุกเฟรมระหว่างลาก
## ส่ง null ตอนปล่อยเมาส์
func set_hovered_seat(seat: Seat) -> void:
	if _hovered_seat == seat:
		return

	var previous: Seat = _hovered_seat
	_hovered_seat = seat

	## อัปเดตเฉพาะช่องที่สถานะเปลี่ยนจริง ไม่ไล่รีเฟรชทั้งกระดานทุกเฟรม
	if is_instance_valid(previous):
		previous.refresh_visual()
	if is_instance_valid(seat):
		seat.refresh_visual()


func is_hovered(seat: Seat) -> bool:
	return _hovered_seat == seat


func get_seat(row: int, column: int) -> Seat:
	return _seats.get(Vector2i(row, column), null)


func get_left_neighbor(seat: Seat) -> Seat:
	return get_seat(seat.row, seat.column - 1)


func get_right_neighbor(seat: Seat) -> Seat:
	return get_seat(seat.row, seat.column + 1)


## ที่นั่งแถวหน้าของตัวเอง (แถวเลขน้อยกว่า = อยู่ใกล้ด้านหน้ากว่า) คอลัมน์เดียวกัน
func get_front_neighbor(seat: Seat) -> Seat:
	return get_seat(seat.row - 1, seat.column)


## ที่นั่งแถวหลังของตัวเอง คอลัมน์เดียวกัน
func get_back_neighbor(seat: Seat) -> Seat:
	return get_seat(seat.row + 1, seat.column)


## แถวหน้าสุด/หลังสุดของทั้งระบบ (คำนวณจากที่นั่งที่ลงทะเบียนไว้จริง ไม่ต้อง hardcode)
func get_min_row() -> int:
	var rows: Array = []
	for key in _seats.keys():
		rows.append(key.x)
	return rows.min() if rows.size() > 0 else 1


func get_max_row() -> int:
	var rows: Array = []
	for key in _seats.keys():
		rows.append(key.x)
	return rows.max() if rows.size() > 0 else 1


## คอลัมน์ริมซ้ายสุด/ริมขวาสุดของทั้งระบบ (คำนวณจากที่นั่งที่ลงทะเบียนไว้จริง)
func get_min_column() -> int:
	var columns: Array = []
	for key in _seats.keys():
		columns.append(key.y)
	return columns.min() if columns.size() > 0 else 1


func get_max_column() -> int:
	var columns: Array = []
	for key in _seats.keys():
		columns.append(key.y)
	return columns.max() if columns.size() > 0 else 1


## เช็คว่าที่นั่งนี้ (และ NPC ที่นั่งอยู่) ถูกต้องตามเงื่อนไขไหม
## ที่นั่งว่าง = ถือว่า "ถูก" (ไม่มีอะไรให้ผิด)
## รองรับทั้ง NPC ที่มีเงื่อนไขเดียว (condition เป็น String) และหลายเงื่อนไขพร้อมกัน (condition เป็น Array)
## ถ้ามีหลายเงื่อนไข ต้องผ่าน "ทุกข้อ" ถึงจะถือว่าถูก (AND)
func check_seat(seat: Seat) -> bool:
	if seat == null or seat.current_npc == null:
		return true

	var npc: Node = seat.current_npc
	var condition = NPCalignDatabase.get_condition(npc.npc_id)

	if condition is Array:
		for single_condition in condition:
			if not _check_single_condition(seat, single_condition):
				return false
		return true
	else:
		return _check_single_condition(seat, condition)


## เช็คเงื่อนไขเดียว (เรียกจาก check_seat ทั้งกรณีเงื่อนไขเดียวและหลายเงื่อนไข)
func _check_single_condition(seat: Seat, condition: String) -> bool:
	var npc: Node = seat.current_npc
	var local_row := seat.row - get_min_row() + 1
	var local_col := seat.column - get_min_column() + 1

	match condition:
		"front_row":
			return seat.row == get_min_row()
		"back_row":
			return seat.row == get_max_row()
		"not_front_row":
			# ไม่อยากนั่งแถวหน้า -> นั่งแถวไหนก็ได้ยกเว้นแถวหน้าสุด (local_row 1)
			return local_row != 1
		"not_middle_row":
			# ไม่อยากนั่งแถวกลาง -> นั่งแถวไหนก็ได้ยกเว้นแถวกลาง (local_row 2)
			return local_row != 2
		"any":
			return true
		"next_to_boy":
			return _has_neighbor_gender(seat, "male")
		"next_to_girl":
			return _has_neighbor_gender(seat, "female")
		"not_next_to_boy":
			return not _has_neighbor_gender(seat, "male")
		"not_next_to_girl":
			return not _has_neighbor_gender(seat, "female")
		"no_one_in_front":
			var front := get_front_neighbor(seat)
			return front == null or front.is_empty()
		"someone_in_front":
			var front2 := get_front_neighbor(seat)
			return front2 != null and not front2.is_empty()
		"left_edge":
			return seat.column == get_min_column()
		"right_edge":
			return seat.column == get_max_column()
		"edge":
			return seat.column == get_min_column() or seat.column == get_max_column()
		"not_edge":
			# ไม่อยากนั่งริม -> ตรงไหนก็ได้ยกเว้นริมซ้ายสุดและริมขวาสุด
			return seat.column != get_min_column() and seat.column != get_max_column()
		"middle_seat":
			return local_row == 2 and local_col >= 2 and local_col <= 4
		_:
			push_warning("ไม่รู้จัก condition: '%s' (npc_id: %s)" % [condition, npc.npc_id])
			return true


func _has_neighbor_gender(seat: Seat, gender: String) -> bool:
	for neighbor in [get_left_neighbor(seat), get_right_neighbor(seat)]:
		if neighbor and neighbor.current_npc:
			if NPCalignDatabase.get_gender(neighbor.current_npc.npc_id) == gender:
				return true
	return false


## เช็คที่นั่งทั้งหมดในระบบทีเดียว พร้อมอัปเดตสี highlight ให้แต่ละที่นั่งด้วย
## เรียกฟังก์ชันนี้ทุกครั้งที่มีการวาง/ย้าย NPC (เพราะกระทบเพื่อนบ้านข้างๆ ด้วย)
## คืนค่า true ถ้าทุกที่นั่งที่มีคนนั่งถูกต้องหมด (ใช้เช็คเงื่อนไขชนะเกมได้)
func check_all() -> bool:
	var all_correct := true
	for seat in _seats.values():
		var correct := check_seat(seat)
		seat.set_highlight(correct)

		## 🚨 ต้องอัปเดตอารมณ์ **ทุกกรณี** ไม่ใช่เฉพาะตอนผิด
		## ของเดิมเขียน `if ... and not correct: set_seated_mood(correct)`
		## ซึ่ง `correct` ตรงนั้นเป็น false เสมอ = ตั้งได้แค่ `sit_angry` ทางเดียว
		## พอเพื่อนบ้านย้ายออกแล้วคนที่เหลือกลายเป็นนั่งถูก หน้าก็ยังบึ้งค้างตลอดไป
		## (เห็นชัดขึ้นตั้งแต่มีช่องยืน เพราะย้ายคนออกจากที่นั่งได้โดยไม่ต้องเอาไปนั่งที่อื่น)
		if seat.current_npc:
			seat.current_npc.set_seated_mood(correct)

		if not correct:
			all_correct = false

	return all_correct


## เช็คว่าที่นั่งทุกช่องมีคนนั่งครบหรือยัง (เผื่อเช็คเงื่อนไข "จบเกม")
func all_seats_filled() -> bool:
	for seat in _seats.values():
		if seat.is_empty():
			return false
	return true 
