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
## ⚠️ ชื่อไฟล์รูปต้องพิมพ์ให้ตรงตัวพิมพ์เล็กใหญ่เป๊ะ ๆ (เช่น Wawa.png แต่ chochang.png)
##    Windows ไม่สนตัวพิมพ์ แต่ res:// ของ Godot สนตอน export -> รูปจะหายตอน build
##
## side: "left"  = คนอื่น -> โชว์รูป + ชื่อ
##       "right" = น้ำฟ้า (ตัวเอก) -> ไม่โชว์รูปและชื่อ เพราะเป็นผู้ส่งเอง

const SENDERS: Dictionary = {
	"wawa": {
		"name": "พี่วาวา หัวหน้าสวัสดิการ",
		"avatar": preload("res://image_avatar/Wawa.png"),
		"side": "left",
	},
	"somsom": {
		"name": "น้องส้มส้ม สวัสดิการ",
		"avatar": preload("res://image_avatar/Somsom.png"),
		"side": "left",
	},
	"namking": {
		"name": "พี่น้ำขิง รองประธาน",
		"avatar": preload("res://image_avatar/Namking.png"),
		"side": "left",
	},
	"jaja": {
		"name": "พี่จ๊ะจ๋า ประธาน",
		"avatar": preload("res://image_avatar/Jaja.png"),
		"side": "left",
	},
	"chochang": {
		"name": "พี่โช สถานที่",
		## ⚠️ ไฟล์จริงชื่อ chochang.png (c เล็ก) ตัวเดียวในโฟลเดอร์ที่ขึ้นต้นตัวเล็ก
		"avatar": preload("res://image_avatar/chochang.png"),
		"side": "left",
	},
	"kaem": {
		"name": "น้องแก้ม สวัสดิการ",
		"avatar": preload("res://image_avatar/kame.png"),
		"side": "left",
	},
	## --- ตัวเอก: เป็นผู้ส่ง ไม่ต้องมีรูป ---
	"namfa": {
		"name": "น้ำฟ้า",
		"avatar": null,
		"side": "right",
	},
}


## ==============================================
## ทะเบียนกลุ่มแชท
## ==============================================
## เพิ่มกลุ่มใหม่ = เพิ่มรายการที่นี่ที่เดียว ไม่ต้องแตะซีน
##   name    = ชื่อกลุ่มที่โชว์บนหัว
##   icon    = ไอคอนกลุ่ม (null = ใช้รูปที่ตั้งไว้ในซีน ไม่เขียนทับ)
##   members = รายชื่อ sender_id ที่อยู่ในกลุ่ม -> ใช้นับ "N online"
const GROUPS: Dictionary = {
	"smo": {
		"name": "SMO",
		"icon": preload("res://image/smo (2).png"),
		"members": ["jaja", "namking", "wawa", "chochang", "somsom", "kaem", "namfa"],
	},
	"sawat": {
		"name": "ฝ่ายสวัสดิการ",
		"icon": preload("res://image_avatar/Chicken.png"),
		## เดาจากชื่อในทะเบียน: วาวา=หัวหน้าสวัสดิการ, ส้มส้ม/แก้ม=สวัสดิการ
		## ⚠️ ถ้ามีคนอื่นอีก เติมที่นี่แล้วเลข "N online" จะถูกเอง
		"members": ["wawa", "somsom", "kaem", "namfa"],
	},
}


## ==============================================
## บทแชทของแต่ละกลุ่ม
## ==============================================
## HISTORY  = ประวัติที่มีอยู่ก่อนแล้ว ขึ้นครบทันทีตอนเปิดห้อง
## INCOMING = ข้อความที่ยังไม่ถูกส่ง จะทยอยเข้ามาหลังเปิดห้อง พร้อมบับเบิล "กำลังพิมพ์"
##
## รายการที่มีคีย์ "time" = ตัวคั่นเวลา · มีคีย์ "sender" = ข้อความ
## เก็บไว้ที่นี่แทนที่จะฝังในซีน เพราะหน้ารายการแชทต้องอ่านข้อความล่าสุด
## ของทุกกลุ่มได้โดยไม่ต้องเปิดห้องนั้นก่อน

const HISTORY: Dictionary = {
	"smo": [
		{"time": "ศ. 19:30 น."},
		{
			"sender": "wawa",
			"text": "นัดหมายวันงานรับน้องพรุ่งนี้ มาเตรียมตัวก่อนเวลา 06.00 น. ที่หน้าห้องประชุมเมืองพะเยา\n- แต่งกายเสื้อสโมICT กางเกงขายาว รองเท้าผ้าใบ\n- อย่าลืมซื้อข้าวเช้ามาด้วยนะคะ!",
		},
		{"sender": "somsom", "text": "รับทราบค่ะ"},
		{"sender": "chochang", "text": "ใครไม่มีรถขึ้นมอ ทักมาหาพี่นะครับ"},
		{"sender": "kaem", "text": "เดี๋ยวหนูกับเพื่อนทักไปค่ะครับ"},
		{"sender": "namking", "text": "อย่าลืมกินข้าวเช้ากันด้วยนะ"},
		{"sender": "namking", "text": "เดี๋ยวเป็นลมตอนทำกิจกรรม"},
		{"time": "06:30 น."},
		{"sender": "jaja", "text": "คนที่มาถึงแล้วแยกย้ายไปหาหัวหน้าฝ่ายของตนได้เลยค่ะ"},
		## สองข้อความนี้คือเสียงเตือน 2 ครั้งที่ดังตอนน้ำฟ้าเพิ่งตื่นใน wokeup
		## มาถึงก่อนที่ผู้เล่นจะหยิบโทรศัพท์ขึ้นมาดู -> ต้องขึ้นรออยู่แล้วตอนเปิด UI
		## และเป็นเหตุผลที่พาผู้เล่นไปกลุ่มฝ่ายสวัสดิการต่อ
		{"sender": "wawa", "text": "ฝ่ายสวัสดิการ เช็คข้อความในกลุ่มสวัสกันด้วยน้า"},
		{"sender": "wawa", "text": "เผื่อพี่มอบหมายงานให้"},
	],
	## กลุ่มสวัสดิการเพิ่งเด้งขึ้นมา ยังไม่มีประวัติเก่า - ทุกอย่างอยู่ใน INCOMING
	"sawat": [],
}

## รูปแบบบรรทัดที่ INCOMING รับได้:
##   {"sender": ..., "text": ...}          ข้อความปกติ
##   {"sender": ..., "text": ..., "typing": 2.5}   กำหนดเวลา "กำลังพิมพ์" เองเป็นวินาที
##   {"time": "06:30 น."}                  ตัวคั่นเวลา
##   {"choices": [...]}                    ถึงคิวผู้เล่นตอบ - หยุดรอจนกว่าจะกด
##
## ตัวเลือกใส่ได้ 2 แบบ ผสมกันในรอบเดียวก็ได้ จำนวนไม่จำกัด:
##   "ข้อความ"                                  ตอบแล้วจบ
##   {"text": "ข้อความ", "then": [ ...บท... ]}   ตอบแล้วมีคนตอบกลับต่อ
const INCOMING: Dictionary = {
	## กลุ่ม SMO ไม่มีข้อความใหม่แล้ว - ทุกอย่างมาถึงก่อนผู้เล่นเปิดโทรศัพท์
	"smo": [],
	"sawat": [
		## ข้อความเปิดกลุ่ม - ตั้ง "typing" สั้นเป็นพิเศษ ไม่ให้ผู้เล่นนั่งรอ
		## (ข้อความนี้ยาว ถ้าปล่อยให้คำนวณเองจะได้ 4.1 วิ นานเกินไปสำหรับข้อความแรกที่เห็น)
		{"sender": "wawa", "text": "พี่ขอคนมาช่วย ขนของจากห้องสโมสรไปห้องประชุม หน่อยค้าบ ขอ 4 คนน้า", "typing": 0.9},
		{"sender": "somsom", "text": "หนูกับเพื่อนกำลังไปค่ะ"},
		## ตอบอันไหนก็ได้ เรื่องเดินต่อเหมือนกัน (เฟดไปฉากลานจอดรถ)
		## เติมเพิ่มในลิสต์นี้ได้เรื่อย ๆ ไม่จำกัดจำนวน
		{"choices": [
			"หนูกำลังไปค่ะ",
			"หนูถึงแล้วค่ะ",
		]},
	],
}


func get_history(group_id: String) -> Array:
	return HISTORY.get(group_id, [])


func get_incoming(group_id: String) -> Array:
	return INCOMING.get(group_id, [])


## ข้อความล่าสุด + เวลาล่าสุดของกลุ่ม สำหรับแสดงในหน้ารายการแชท
##
## คำนวณจากบทแชทจริง ไม่ต้องกรอกซ้ำ -> แก้บทแล้วหน้ารายการอัปเดตตามเอง
## ถ้าให้กรอกมือจะเพี้ยนแน่นอนเมื่อบทเปลี่ยนแล้วลืมแก้อีกที่
func get_preview(group_id: String) -> Dictionary:
	var lines: Array = []
	lines.append_array(get_history(group_id))
	lines.append_array(get_incoming(group_id))

	var last_text := ""
	var last_time := ""
	for line in lines:
		if line.has("time"):
			last_time = line["time"]
		elif line.has("text"):
			last_text = line["text"]

	return {"text": last_text, "time": last_time}


## ดึงข้อมูลกลุ่มทั้งก้อน คืน {} ถ้าไม่พบ
func get_group(group_id: String) -> Dictionary:
	if not GROUPS.has(group_id):
		push_error("ไม่พบกลุ่ม '%s' ใน ChatDatabase.GROUPS" % group_id)
		return {}
	return GROUPS[group_id]


## จำนวนสมาชิกของกลุ่มนั้น - ใช้กับป้าย "N online" ที่หัวแชท
func group_member_count(group_id: String) -> int:
	return GROUPS.get(group_id, {}).get("members", []).size()


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
