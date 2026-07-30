extends Node
## ==============================================
## ทะเบียนผู้ส่งข้อความในกรุ๊ปแชทสโม
## ==============================================
## วิธีติดตั้ง: Project > Project Settings > Autoload
##   เลือกไฟล์นี้ -> ตั้งชื่อ Node Name เป็น "ChatDatabase" -> กด Add
##
## แนวคิด: แยก "ใครเป็นใคร" ออกจาก "พูดอะไร"
##   บทแชทอ้างถึงคนด้วย sender_id เท่านั้น ส่วนชื่อ/รูป/ฝั่ง ดึงจากที่นี่
##   เปลี่ยนรูปหรือชื่อของใคร แก้ที่นี่ที่เดียว ทุกข้อความเปลี่ยนตามหมด
##
## ⚠️ นามสกุลไฟล์รูปเป็น .PNG ตัวใหญ่ ห้ามเขียนเป็น .png
##    Windows ไม่สนตัวพิมพ์ แต่ res:// ของ Godot สนตอน export -> รูปจะหายตอน build
##
## side: "left"  = คนอื่น -> โชว์รูป + ชื่อ
##       "right" = น้ำฟ้า (ตัวเอก) -> ไม่โชว์รูปและชื่อ เพราะเป็นผู้ส่งเอง

const SENDERS: Dictionary = {
	"wawa": {
		"name": "พี่วาวา หัวหน้าสวัสดิการ",
		"avatar": preload("res://image_avatar/WawaPF.PNG"),
		"side": "left",
	},
	"somsom": {
		"name": "น้องส้มส้ม",
		"avatar": preload("res://image_avatar/lemon.PNG"),
		"side": "left",
	},
	"namking": {
		"name": "พี่น้ำขิง รองประธาน",
		"avatar": preload("res://image_avatar/NamkingPF.PNG"),
		"side": "left",
	},
	"jaja": {
		"name": "พี่จ๊ะจ๋า ประธาน",
		"avatar": preload("res://image_avatar/Jaja.PNG"),
		"side": "left",
	},
	"chochang": {
		"name": "พี่โช สถานที่",
		"avatar": preload("res://image_avatar/cat.PNG"),
		"side": "left",
	},
	"jean": {
		"name": "น้องจีน",
		"avatar": preload("res://image_avatar/colver.PNG"),
		"side": "left",
	},
	## --- ตัวเอก: เป็นผู้ส่ง ไม่ต้องมีรูป ---
	"namfa": {
		"name": "น้ำฟ้า",
		"avatar": null,
		"side": "right",
	},
}


## ดึงข้อมูลผู้ส่งทั้งก้อน คืน {} ถ้าไม่พบ (ผู้เรียกต้องเช็ค is_empty() เอง)
func get_sender(sender_id: String) -> Dictionary:
	if not SENDERS.has(sender_id):
		push_error("ไม่พบผู้ส่ง '%s' ใน ChatDatabase" % sender_id)
		return {}
	return SENDERS[sender_id]


func get_name_of(sender_id: String) -> String:
	return SENDERS.get(sender_id, {}).get("name", sender_id)


func get_avatar(sender_id: String) -> Texture2D:
	return SENDERS.get(sender_id, {}).get("avatar", null)


## true = ข้อความอยู่ฝั่งขวา (น้ำฟ้าเป็นคนส่ง)
func is_right_side(sender_id: String) -> bool:
	return SENDERS.get(sender_id, {}).get("side", "left") == "right"


## จำนวนคนในกลุ่ม - ใช้กับป้าย "N online" ที่ header
func online_count() -> int:
	return SENDERS.size()
