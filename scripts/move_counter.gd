class_name MoveCounter
extends Label
## ==============================================
## ตัวนับจำนวนครั้งที่เหลือ (Moves)
## ==============================================
## แนบที่ Label ที่โชว์ตัวเลข (`CanvasLayer/TextureRect2/VBoxContainer/Number` ใน `align_1.tscn`)
##
## **จับ NPC วางลงที่นั่งสำเร็จ 1 ครั้ง = เสีย 1 move** เลขลดลงเรื่อย ๆ
## ย้ายไปพักที่ช่องยืนไม่เสีย · วางไม่ลงแล้วเด้งกลับก็ไม่เสีย
##
## ⚠️ **ตัวเลขในซีนถูกเขียนทับด้วย `max_moves` ตอนเปิดฉาก**
## แก้จำนวนครั้งที่ช่อง `Max Moves` ใน Inspector ที่เดียว ไม่ใช่ไปพิมพ์ในช่อง Text
## (พิมพ์ที่ Text จะเห็นถูกตอนแก้ซีน แล้วเด้งกลับเป็นค่าเดิมทันทีที่กดรัน — หาสาเหตุยาก)

## กลุ่มที่ `click.gd` ใช้หาตัวนับ — เข้ากลุ่มเองจากโค้ด ไม่ต้องตั้งในซีน
const GROUP := "move_counter"

## ส่งทุกครั้งที่เลขเปลี่ยน (ให้ UI อื่นเกาะได้ เช่นเปลี่ยนสีตอนใกล้หมด)
signal moves_changed(remaining: int)

## ส่งตอนใช้ครบโควตาพอดี
##
## ⚠️ **ยังไม่มีใครรับสัญญาณนี้** — ยังไม่ได้ตัดสินใจว่าหมดแล้วจะเกิดอะไร
## (แพ้? เริ่มใหม่? เล่นต่อได้แต่ไม่นับ?) ทำไว้ให้เกาะทีหลังโดยไม่ต้องแก้ไฟล์นี้
signal moves_exhausted

@export var max_moves: int = 15

var moves_left: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	reset()


func reset() -> void:
	moves_left = max_moves
	_refresh()


## ใช้ไป 1 ครั้ง — คืน `false` ถ้าโควตาหมดแล้ว
##
## คืนค่าเป็น bool เผื่อวันหลังอยากให้ "หมดแล้ววางไม่ได้อีก" —
## ฝั่ง `click.gd` จะได้เช็คผลก่อนตัดสินใจ โดยไม่ต้องรื้อ API ใหม่
func spend(amount: int = 1) -> bool:
	if moves_left <= 0:
		return false

	## ไม่ให้ติดลบ — เลขติดลบบนจอผู้เล่นอ่านแล้วงงกว่าเลข 0 ค้างไว้
	moves_left = maxi(moves_left - amount, 0)
	_refresh()
	moves_changed.emit(moves_left)

	if moves_left == 0:
		moves_exhausted.emit()

	return true


func _refresh() -> void:
	text = str(moves_left)
