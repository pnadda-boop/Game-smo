class_name NPCData
extends Resource

## ข้อมูลประจำตัว NPC หนึ่งตัว
##
## แยกออกมาเป็น Resource เพื่อให้ NPC ทุกตัวใช้ซีนแม่ `npc_base.tscn` ร่วมกันได้
## เพิ่ม NPC ใหม่ = สร้าง `.tres` ใหม่ + ซีนสืบทอด 1 ซีน **ไม่ต้องแตะสคริปต์เลย**
##
## ⚠️ ค่าที่ควรอยู่ตรงนี้คือ "สิ่งที่ต่างกันรายตัว" เท่านั้น
## อะไรที่ NPC ทุกตัวเหมือนกันให้ไปอยู่ใน `npc_base.gd` / `npc_base.tscn`
## ไม่งั้นจะกลายเป็นต้องไล่แก้ทีละ `.tres` ซึ่งคือปัญหาเดิมที่หนีมา

## ชื่อที่โชว์ในกล่องคำพูด — ต้องตรงกับคีย์ `"name"` ในบทพูด
@export var display_name: String = ""

## คีย์บทพูด ใช้เปิดหาบทใน DialogueData
@export var dialogue_id: String = ""

## ชุดอนิเมชันของ NPC ตัวนี้ — สคริปต์ยัดใส่ AnimatedSprite2D ให้ตอนรัน
##
## ปล่อย null ได้ = ใช้ของที่ตั้งไว้ในซีนแทน (ดู `_apply_data()` ใน npc_base.gd)
@export var frames: SpriteFrames = null

## อนิเมชันที่เล่นตอนยืนเฉย ๆ
##
## ⚠️ ชุดของวาวาใช้ชื่อ `idle` เฉย ๆ **ไม่ใช่ `idle_down`** แบบที่ `NPC.gd` เดิมเรียก
## ตั้งได้รายตัวเพราะแต่ละคนอาจตั้งชื่อชุดคนละแบบ
## ชื่อไม่ตรงจะขึ้น warning บอกว่ามีชุดไหนให้เลือกบ้าง แล้วเล่นชุดแรกแทน (ไม่ crash)
@export var default_anim: String = "idle"

## ชุดที่ใช้ตอน `face_player()` หันไปหาผู้เล่น
##
## ทางซ้ายขวาใช้ชุดเดียวกันแล้ว flip เอา ส่วนหันลงใช้ `default_anim` ข้างบน
## ชื่อไม่ตรงจะไม่เปลี่ยนท่า (ยืนหน้าเดิม) แทนที่จะพังหรือหายไป
@export var anim_up: String = "idle_up"
@export var anim_side: String = "idle_side"

## เลื่อนสไปรท์เทียบกับจุดกึ่งกลางตัว
## ตัวละครสูงต่ำไม่เท่ากัน เท้าจะได้อยู่ระดับเดียวกับ collision
@export var sprite_offset: Vector2 = Vector2.ZERO

## ตำแหน่งบับเบิลบอกว่า "คุยได้" — ปกติลอยเหนือหัว
@export var indicator_offset: Vector2 = Vector2(0, -40)

## ปิดสำหรับ NPC ที่เป็นฉากหลัง — เดินชนได้แต่กด E ไม่ขึ้นอะไร
@export var can_interact: bool = true
