# GameSmo

เกม **Pixel Art Top-Down Narrative Simulator** ภาษาไทย เล่าเรื่องของ **น้ำฟ้า** กับการทำงาน **สโม** (สโมสรนักศึกษา)

ฟีเจอร์หลักของเกม: ระบบบทสนทนา, **ระบบแชทข้อความ**, และ **อีเวนท์** ต่าง ๆ

- Engine: **Godot 4.6** (GL Compatibility), viewport 1920×1080, stretch mode `viewport`
- ภาษา: GDScript — คอมเมนต์และบทพูดในเกมเป็น **ภาษาไทย** เขียนโค้ดใหม่ให้คงสไตล์นี้
- Main scene: `start_manu.tscn`

## 📌 กฎการทำงานในโปรเจกต์นี้ (สำคัญ — อ่านก่อนเริ่ม)

1. **จดสิ่งที่คุยกันลง MD** — ข้อสรุปจากบทสนทนาต้องถูกบันทึก ไม่ปล่อยให้หายไปกับ session
2. **การตัดสินใจที่กระทบแนวคิดพื้นฐานของเกม → จดลง [DEVLOG.md](DEVLOG.md) ทุกครั้ง** (ใหม่สุดไว้บนสุด)
3. **แก้อะไรต้องแสดงเหตุผล** — บอกว่าจะแก้อะไร เพราะอะไร พิจารณาทางเลือกอื่นอะไรบ้าง ไม่แก้เงียบ ๆ
4. **ตรวจด้วย Godot headless ก่อนบอกว่าเสร็จ** — ดูคำสั่งหัวข้อถัดไป

**แบ่งหน้าที่เอกสาร:** ไฟล์นี้ (`CLAUDE.md`) = *"ตอนนี้เกมเป็นยังไง"* เขียนทับให้ทันสมัยเสมอ ·
[`DEVLOG.md`](DEVLOG.md) = *"ทำไมถึงมาเป็นแบบนี้"* สะสมไปเรื่อย ๆ ไม่ลบของเก่า

## คำสั่งตรวจสอบ (ใช้ทุกครั้งหลังแก้โค้ด)

Godot อยู่ที่ `D:\Godot_v4.6.2-stable_win64_console.exe` (ไม่ได้อยู่ใน PATH)

```bash
# ตรวจว่าโปรเจกต์ทั้งหมด import ผ่าน / สคริปต์คอมไพล์ได้
"D:\Godot_v4.6.2-stable_win64_console.exe" --headless --path "D:\game-smo" --import

# ตรวจ syntax สคริปต์เดียว
"D:\Godot_v4.6.2-stable_win64_console.exe" --headless --path "D:\game-smo" --check-only --script "res://NPC.gd"

# รันฉากใดฉากหนึ่งเพื่อดู error ตอน runtime
"D:\Godot_v4.6.2-stable_win64_console.exe" --headless --path "D:\game-smo" "res://level1.tscn" --quit-after 60
```

## Autoload (ตั้งใน project.godot แล้ว)

| ชื่อ | ไฟล์ | หน้าที่ |
|---|---|---|
| `Global` | `Global.gd` | ตำแหน่ง/ทิศทางที่ผู้เล่นจะ spawn |
| `GameState` | `Game_State.gd` | `next_spawn_point` — บอกฉากปลายทางว่าให้ผู้เล่นโผล่ตรงไหน |
| `NPCalignDatabase` | `npcalign_database.gd` | ฐานข้อมูล NPC: ชื่อ, บทพูด, เพศ, เงื่อนไขที่นั่ง |
| `SeatManager` | `SeatManager.gd` | ตัวกลางคุมระบบที่นั่งทั้งหมด + ตรวจเงื่อนไข |

> ⚠️ คอมเมนต์หัวไฟล์ `npcalign_database.gd` บอกให้ตั้งชื่อ autoload ว่า `NPCDatabase` — **เป็นคอมเมนต์เก่าที่ผิด** ชื่อจริงคือ `NPCalignDatabase` (โค้ดที่เรียกใช้ถูกต้องแล้ว)

## Flow ของเกม

```
start_manu.tscn ──ปุ่ม "WORK START"(Start.gd)──► wokeup.tscn
                                                    │ มินิเกมคลิกปลุกตัวเอง
                                                    │ idle → halfasleep → wokeup → sit
                                                    ▼
                                            parking / bus.tscn
                                            (เดินห่างรถ >180px แล้วรถออก)
                                                    ▼
                              level1.tscn ⇄ level_2.tscn ⇄ level_3.tscn
                              ตึก 3 ชั้น — กด E ที่บันได → StairMenu เลือกชั้น
                                                    ▼
                          คุย NPC (กด E) + ปริศนาจัดที่นั่ง (align_*.tscn)
```

### การเปลี่ยนฉาก / spawn point

`stair_menu.gd` ถือตาราง `floor_targets` ที่ map (ชั้น + ตัวเลือก) → (scene ปลายทาง + ชื่อ spawn point)
ก่อนเปลี่ยนฉากจะเซ็ต `GameState.next_spawn_point` ไว้ ให้ฉากปลายทางอ่านไปใช้

**เพิ่มทางเชื่อมใหม่ต้องแก้ 2 ที่:** `floor_targets` ใน `stair_menu.gd` และ spawn point ในฉากปลายทาง

## ระบบหลัก

### 1. ปริศนาจัดที่นั่ง — ระบบที่ซับซ้อนที่สุด (ทำงานได้แล้ว)

Constraint satisfaction puzzle: NPC แต่ละตัวมีเงื่อนไขที่นั่งของตัวเอง ผู้เล่นต้องจัดให้ผ่านครบทุกคน

- `seat.gd` (`class_name Seat`) — ที่นั่งหนึ่งช่อง มี `row`/`column` (`@export`) ลงทะเบียนตัวเองเข้า `SeatManager` ตอน `_ready()`
- `SeatManager.gd` — รองรับ **15 เงื่อนไข**: `front_row`, `back_row`, `not_front_row`, `not_middle_row`, `any`, `next_to_boy`, `next_to_girl`, `not_next_to_boy`, `not_next_to_girl`, `no_one_in_front`, `someone_in_front`, `left_edge`, `right_edge`, `edge`, `not_edge`, `middle_seat`
- `condition` เป็น **Array ได้** = ต้องผ่านทุกข้อ (AND) เช่น NPC7 = `["no_one_in_front", "not_front_row"]`
- Feedback: ที่นั่ง**เขียว = ถูก / แดง = ผิด** (`set_highlight`) และ NPC เปลี่ยนเป็น `sit_happy` / `sit_angry`
- `check_all()` คืน `true` เมื่อทุกที่นั่งถูกหมด → ใช้ตัดสินชนะ; `all_seats_filled()` เช็คว่านั่งครบทุกช่อง

**สำคัญ:** ขอบเขตแถว/คอลัมน์คำนวณจากที่นั่งที่ลงทะเบียนจริง (`get_min_row()` ฯลฯ) ไม่ hardcode → เพิ่ม/ลดที่นั่งได้โดยไม่ต้องแก้ logic
เรียก `SeatManager.check_all()` **ทุกครั้ง**ที่วาง/ย้าย NPC เพราะกระทบเพื่อนบ้านข้าง ๆ ด้วย

**เพิ่ม NPC ใหม่:** แก้ `NPC_DATA` ใน `npcalign_database.gd` ที่เดียว
**เพิ่มเงื่อนไขใหม่:** เพิ่ม `match` case ใน `_check_single_condition()` (`SeatManager.gd`)

### 2. ระบบบทสนทนา (ทำงานได้แล้ว)

- `DialogData/DialogueData.gd` (`class_name DialogueData`) — Resource เก็บบทพูดเป็น dict: `dialogue_id` → array ของ `{name, text}`
- `NPC.gd` — เข้าใกล้แล้วขึ้นบับเบิล, กด `interact` (E) แล้ว NPC หันหน้าหาผู้เล่นและเริ่มบทสนทนา
- NPC หา UI ด้วย `get_tree().get_first_node_in_group("dialogue_ui")` — **node ที่ทำหน้าที่ UI บทสนทนาต้องอยู่ใน group `dialogue_ui`** ไม่งั้น `push_error`
- ตัวละครที่มีแล้ว: น้ำฟ้า (ตัวเอก), พี่วา, พี่โช

### 3. ระบบแชทข้อความ — ⚠️ ยังเป็น UI เปล่า ยังไม่มีโค้ด

- `Phone.tscn` — พาเนลแชทชิดขวาจอ (x 1107–1717), header ฟ้า, avatar โลโก้ SMO, ป้าย "7 online", แถบพิมพ์ข้อความล่าง
- `message_bubble.tscn` — เทมเพลตบับเบิลข้อความเปล่า (HBox > Panel > Margin > Label)
- **ยังไม่มีไฟล์ `.gd` ผูกกับทั้งสอง scene, `message_bubble.tscn` ไม่ถูกเรียกใช้ที่ไหน, `Phone.tscn` ยังไม่ถูก instantiate ในฉากไหน**

## Input actions ที่ใช้

`interact` (E), `up`, `down`, `cancel` — ดูรายละเอียดใน `project.godot`

## ปัญหาที่รู้อยู่แล้ว (ยังไม่แก้)

1. **TileSet อ้างพิกัดเกินขอบภาพ** — errors ~4,000 บรรทัด เกิดตอน **runtime จริง** ไม่ใช่แค่ใน editor
   `texture_region_size` = 32×32 แต่ฉากนิยาม tile เกินขนาดภาพจริง เช่น `image/walk.png` กว้าง 192px (คอลัมน์ 0–5) แต่ถูกอ้างถึง (6,0) และ (7,0)
   สาเหตุ: ไฟล์ภาพถูกเปลี่ยนเป็นขนาดเล็กลงทีหลัง แต่ tile ที่วางไว้ยังอ้างพิกัดของภาพเวอร์ชันเดิม
   กระทบ: `level1.tscn`, `under.tscn`, `p.tscn` → tile บางช่องจะหายไปในเกม

2. **Signal ต่อซ้ำ** — `Start.gd:24-25` ต่อ signal ด้วยโค้ด แต่ `start_manu.tscn:70-71` ก็ต่อจาก editor อีก
   ตอนนี้ Godot บล็อกการต่อซ้ำไว้ให้ (ยังไม่พัง) แต่ถ้าลบฝั่งใดฝั่งหนึ่งจะเกิดบั๊ก — ควรเก็บทางเดียว

3. **โค้ด debug ค้าง** — `Start.gd:15` (`print`), `Start.gd:17` (`print_stack`), และ `Start.gd:16,18` ตั้ง `mouse_filter` ค่าเดิมซ้ำสองบรรทัด

## Git

- Branch `main` → remote `origin` = https://github.com/pnadda-boop/Game-smo (**private**)
- `.gitignore` กัน `.godot/` (cache) และ `/SmoGame/` (exported build 127MB — เกินลิมิต 100MB ของ GitHub)
