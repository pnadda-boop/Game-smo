extends Node
## ==============================================
## ฐานข้อมูลบทพูด NPC รวมไว้ที่เดียว
## ==============================================
## วิธีติดตั้ง (ทำครั้งเดียว):
##   Project > Project Settings > Autoload
##   กดเลือกไฟล์นี้ -> ตั้งชื่อ Node Name เป็น "NPCDatabase" -> กด Add
## จากนั้นเรียกใช้จากที่ไหนก็ได้ในโปรเจกต์ผ่าน NPCDatabase.get_dialogue("NPC1")
## เพิ่ม/แก้ไข/ลบ NPC ได้ที่ dictionary นี้ที่เดียว ไม่ต้องสร้างไฟล์แยก
## key = npc_id (ต้องไม่ซ้ำกัน), value = ข้อมูลของ NPC ตัวนั้น
const NPC_DATA: Dictionary = {
	"NPC1": {
		"name": "NPC 1",
		"text": "-ฉันมีโบว์สีแดง",
		"gender": "male",
		"condition": "right_edge",
	},
	"NPC2": {
		"name": "NPC 2",
		"text": "-ฉันอยากนั่งหลังใครสักคน",
		"gender": "male",
		"condition":  "someone_in_front",
	},
	"NPC3": {
		"name": "NPC 3",
		"text": "-ฉันสายตาสั้นอยากอยู่ด้านหน้า ",
		"gender": "male",
		"condition":  "front_row",
	},
	"NPC4": {
		"name": "NPC 4",
		"text": "-ฉันไม่อยากอยู่ด้านหน้า",
		"gender": "female",
		"condition":  "not_front_row",
	},
	"NPC5": {
		"name": "NPC 5",
		"text": "-ฉันอยากนั่งข้างผู้หญิง",
		"gender": "female",
		"condition": "next_to_girl",
	},
	"NPC6": {
	"name": "NPC 6",
	"text": "- ฉันแอบเล่นเกม\n -ฉันอยากอยู่ด้านหลัง",
	"gender": "female",
	"condition":  "back_row",
	},
	"NPC7": {
		"name": "NPC 7",
		"text": "-ฉันไม่อยากนั่งด้านหน้า\n -ฉันไม่อยากมีคนบัง",
		"gender": "male",
		"condition": ["no_one_in_front", "not_front_row"],
	},
	"NPC8": {
		"name": "NPC 8",
		"text": "-ฉันมีโบว์สีฟ้า",
		"gender": "female",
		"condition": "right_edge",
	},
	"NPC9": {
		"name": "NPC 9",
		"text": "-ฉันมีโบว์สีขาว",
		"gender": "male",
		"condition": "right_edge",
	},
	"NPC10": {
		"name": "NPC 10",
		"text": "-ฉันไม่อยากมีคนนั่งบัง",
		"gender": "male",
		"condition": "no_one_in_front",
	},
}
## ดึงบทพูดของ NPC ตาม id เช่น NPCDatabase.get_dialogue("NPC1")
func get_dialogue(npc_id: String) -> String:
	if NPC_DATA.has(npc_id):
		return NPC_DATA[npc_id].get("text", "")
	push_warning("ไม่พบ NPC id: '%s' ใน NPCDatabase" % npc_id)
	return ""
## ดึงชื่อของ NPC ตาม id
func get_name_of(npc_id: String) -> String:
	if NPC_DATA.has(npc_id):
		return NPC_DATA[npc_id].get("name", npc_id)
	return npc_id
## ดึงเพศของ NPC ตาม id ("male" / "female") - ใช้เช็คเงื่อนไข next_to_boy/girl ใน SeatManager
func get_gender(npc_id: String) -> String:
	if NPC_DATA.has(npc_id):
		return NPC_DATA[npc_id].get("gender", "")
	return ""
## ดึงเงื่อนไข (condition) ของ NPC ตาม id
func get_condition(npc_id: String):
	if NPC_DATA.has(npc_id):
		return NPC_DATA[npc_id].get("condition", "any")
	return "any"
## เช็คว่ามี id นี้อยู่ในฐานข้อมูลไหม - SeatManager และ npc.gd เรียกใช้ก่อนแสดงบับเบิ้ล/เช็คเงื่อนไขทุกครั้ง
func has_npc(npc_id: String) -> bool:
	return NPC_DATA.has(npc_id)
