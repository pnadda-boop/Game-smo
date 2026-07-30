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
# ✅ วิธีหลัก — ตรวจทั้งโปรเจกต์ คอมไพล์ทุกสคริปต์พร้อม autoload
"D:\Godot_v4.6.2-stable_win64_console.exe" --headless --path "D:\game-smo" --import

# รันฉากใดฉากหนึ่งเพื่อดู error ตอน runtime
"D:\Godot_v4.6.2-stable_win64_console.exe" --headless --path "D:\game-smo" "res://level1.tscn" --quit-after 60
```

> ⚠️ **อย่าใช้ `--check-only --script`** — โหมดนี้ **ไม่โหลด autoload** ทำให้สคริปต์ที่อ้างถึง
> `SeatManager`, `NPCalignDatabase`, `ChatDatabase`, `Global`, `GameState` ขึ้น
> `Compile Error: Identifier not found` ทั้งที่โค้ดถูกต้องและทำงานได้จริงในเกม
> (ยืนยันแล้ว: `SeatManager.gd` ที่ใช้งานได้ปกติก็ FAIL ในโหมดนี้) — ใช้ `--import` แทนเสมอ

**เวลาอ่านผล `--import`:** จะมี error เรื่อง TileSet ~4,000 บรรทัดเป็นปกติ (ปัญหาค้าง ดูหัวข้อล่าง)
ให้กรองออกก่อน แล้วดูเฉพาะ `SCRIPT ERROR` / `Compile Error` / `Parse Error`

## Autoload (ตั้งใน project.godot แล้ว)

| ชื่อ | ไฟล์ | หน้าที่ |
|---|---|---|
| `Global` | `Global.gd` | ตำแหน่ง/ทิศทางที่ผู้เล่นจะ spawn |
| `GameState` | `Game_State.gd` | `next_spawn_point` — บอกฉากปลายทางว่าให้ผู้เล่นโผล่ตรงไหน |
| `NPCalignDatabase` | `npcalign_database.gd` | ฐานข้อมูล NPC: ชื่อ, บทพูด, เพศ, เงื่อนไขที่นั่ง |
| `SeatManager` | `SeatManager.gd` | ตัวกลางคุมระบบที่นั่งทั้งหมด + ตรวจเงื่อนไข |
| `ChatDatabase` | `chat_database.gd` | ทะเบียนผู้ส่งข้อความในกรุ๊ปแชท (ชื่อ + รูป + ฝั่งซ้ายขวา) |
| `ClickEffect` | `click_effect.tscn` | เอฟเฟกต์วงกลมกระเพื่อม + เสียงตอนคลิก ทำงานทุกซีน |

> 🚨 **เพิ่ม autoload ผ่าน `Project > Project Settings > Globals > Autoload` เท่านั้น**
> ห้ามเติมบรรทัดลง `project.godot` เอง — Godot อ่านไฟล์นี้ตอนเปิดโปรเจกต์ครั้งเดียว
> พอผู้ใช้แตะ Project Settings เรื่องใดก็ตาม มันจะเขียนไฟล์ใหม่จากรายการในหน่วยความจำ
> แล้ว **autoload ที่เติมจากข้างนอกจะถูกลบทิ้งเงียบ ๆ** (เกิดแล้ว 2 ครั้ง — ดู DEVLOG 2026-07-30)

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

### 2. ระบบกล่องคำพูด (ทำงานได้แล้ว)

`Game/dialogue_system.gd` ติดที่ `canvas_layer.tscn` (node ราก `DialogueBox`)

**รูปแบบบทพูด — กำหนดอนิเมชันต่อบรรทัดได้**
```gdscript
{"name": "วาวา",  "text": "อรุณสวัสดิ์จ้า", "anim": "Angry"},
{"name": "น้ำฟ้า", "text": "สวัสดีค่ะ"},      # ไม่ใส่ anim = ใช้ default_anim ("talk")
```

**พฤติกรรมสำคัญ: อารมณ์ค้างไว้**
คนที่ไม่ได้พูดจะ **ย่อลง + มืดลง แต่คงอนิเมชันเดิม** — โกรธค้างจนกว่าจะมีบรรทัดสั่งเปลี่ยน
ทำได้โดย**ไม่เรียก `play()` กับคนที่ไม่ได้พูด** ห้ามใส่ `sprite.play("idle")` กลับเข้าไป

**สลับโหมดมีรูป/ไม่มีรูป**
```gdscript
start_dialogue(lines)               # มีรูปตัวละคร
start_dialogue(lines, null, false)  # ข้อความล้วน (เสียงบรรยาย/ประกาศ)
```

**ตัวละครในกล่องคำพูด 4 คน** — key ต้องตรงกับค่า `"name"` ในบทพูดเป๊ะ

| key | node ใต้ `Root/Portraits` |
|---|---|
| `"น้ำฟ้า"` | `Namfha` |
| `"วาวา"` | `Wawa` |
| `"โชแชง"` | `Chochang` |
| `"คีริน"` | `Kirin` |

⚠️ **ชื่ออนิเมชันแยกตัวพิมพ์เล็กใหญ่** — ตอนนี้วาวาใช้ `Angry` (ตัวใหญ่) ตัวอื่นเป็นตัวเล็ก
พิมพ์ผิดจะขึ้น warning บอกชื่อที่ผิดแล้วเล่น `talk` แทน (ไม่ crash)

⚠️ **ใส่กลุ่ม `dialogue_ui` ที่ `DialogueBox` (CanvasLayer) เท่านั้น** ห้ามใส่ node ลูก
`NPC.gd` หาด้วย `get_first_node_in_group()` ซึ่งอาจคืน node ลูกที่ไม่มีเมธอด `start_dialogue()` แล้ว crash

โครงสร้าง node ทั้งหมด + ค่าที่ต้องตั้ง: ดู [DIALOGUE_UI.md](DIALOGUE_UI.md)

**ทางเข้าบทสนทนา**
- `NPC.gd` — เข้าใกล้ขึ้นบับเบิล กด `interact` (E) แล้ว NPC หันหน้าหาผู้เล่นและเริ่มคุย
- เรียกอัตโนมัติตามเนื้อเรื่องได้ด้วย `start_dialogue()` — รองรับซีนที่ไม่มีผู้เล่น (เช่นบนรถเมล์) แล้ว
- ข้อมูลบทพูดตอนนี้อยู่ใน `DialogData/DialogueData.gd` เป็น **ค่า default ของ `@export`**
  ⚠️ `Game/player/new_resource.tres` ว่างเปล่าและยืมค่า default นั้น — ถ้าแก้ `dialogues` ใน Inspector
  Godot จะบันทึกสำเนาลง `.tres` แล้วบทพูดจะแช่แข็ง แก้สคริปต์ไม่มีผลอีก

### 3. ระบบแชทกรุ๊ปสโม (โค้ดเสร็จ — ยังไม่ถูก instantiate ในฉากไหน)

- `chat_database.gd` (autoload `ChatDatabase`) — ทะเบียนผู้ส่ง 7 คน: ชื่อ, รูป avatar, ฝั่งซ้าย/ขวา
  **เพิ่ม/แก้ตัวละครที่นี่ที่เดียว** บทแชทอ้างด้วย `sender_id` ไม่ใช่ชื่อ
- `phone.gd` (`Phone.tscn`) — โหลดประวัติแชท, ตัวคั่นเวลา, จัดกลุ่มข้อความติดกัน, auto-scroll
- `message_bubble.gd` (`message_bubble.tscn`) — บับเบิลหนึ่งใบ: รูป/ชื่อ/ข้อความ/ซ้ายขวา/ความกว้าง

**API หลัก**
```gdscript
$Phone.load_history(lines)   # ประวัติเก่า ขึ้นครบทันที
$Phone.play_chat(lines)      # ข้อความใหม่ ทยอยขึ้นทีละอัน
await $Phone.show_choices(["ตอบ A", "ตอบ B"])   # ต้องสร้าง node Control/ChoiceContainer ก่อน
```
รายการที่มีคีย์ `"time"` = ตัวคั่นเวลา แทรกได้ทุกจุด · น้ำฟ้า (`namfa`) อยู่ฝั่งขวา ไม่โชว์รูปและชื่อ

**แถบพิมพ์ข้อความเป็นของประดับ** — `LineEdit` ตั้ง `focus_mode = NONE` + `mouse_filter = IGNORE` จากโค้ด
ผู้เล่นพิมพ์เองไม่ได้ ตอนต้องตอบจริงจะใช้ `show_choices()` แทน
⚠️ **ห้ามตั้ง `line_edit.editable = false`** — LineEdit จะสลับไปใช้ StyleBox ชื่อ `read_only` ไม่ใช่ `normal`
สไตล์แคปซูลมนที่ตั้งไว้จะหายตอนรัน แล้วหน้าตาไม่ตรงกับที่เห็นใน editor

โครงสร้าง node ทั้งหมด + ค่าที่ต้องตั้ง: ดู [CHAT_UI.md](CHAT_UI.md)

### 4. เอฟเฟกต์คลิก (ใช้งานได้ทุกซีน)

`click_effect.tscn` เป็น autoload `ClickEffect` → วงกลมกระเพื่อม + เสียงคลิก (สุ่มระดับเสียง ±12%)
ใช้ `_input` ไม่ใช่ `_unhandled_input` เพื่อให้เกิดแม้คลิกโดนปุ่ม และไม่กลืนคลิก (ไม่เรียก `set_input_as_handled()`)

## โครงสร้างโฟลเดอร์ asset

| โฟลเดอร์ | เก็บอะไร |
|---|---|
| `image/` | รูปฉาก พื้นหลัง tileset |
| `image/align_npc/` | สไปรท์ NPC ปริศนาที่นั่ง |
| `image_avatar/` | รูปโปรไฟล์วงกลมสำหรับแชท (256×256) |
| `image_fullAvatar/` | รูปครึ่งตัวสำหรับกล่องคำพูด |
| `image_ui/` | ไอคอน UI |
| `font/` | ฟอนต์ (`2005_iannnnnAMD.ttf` ใช้ทั้งเกม) |
| `soud/` · `soud_effects/` | เพลง · เสียงเอฟเฟกต์ |

> ⚠️ ไฟล์ใน `image_avatar/` นามสกุลเป็น **`.PNG` ตัวใหญ่**
> `res://` ของ Godot เป็น case-sensitive ตอน export แต่ Windows ไม่สน
> เขียน `.png` จะไม่พังตอนทดสอบ **แต่รูปจะหายตอน build จริง**

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
