# โครงสร้าง Node ของกล่องคำพูด

สร้าง UI ด้วย node ของ Godot ล้วน (`StyleBoxFlat`) ไม่ใช้ไฟล์ภาพ
สคริปต์: `Game/dialogue_system.gd`

**เป้าหมายด้านขนาด — จุดสำคัญที่สุดของการออกแบบนี้**

| ส่วน | พฤติกรรม | ทำไม |
|---|---|---|
| **กล่องข้อความ** | 🔒 **ขนาดคงที่** | บทสั้น/ยาวไม่เท่ากันทุกบรรทัด ถ้ากล่องหุบ-ขยายตามจะกระโดดทุกครั้งที่กดต่อ กวนสายตามาก |
| **ป้ายชื่อ** | 📐 **ยืดหดตามชื่อ** | ชื่อสั้นยาวไม่เท่ากัน (`"น้ำฟ้า"` vs `"พี่วาวา หัวหน้าสวัสดิการ"`) ถ้าตายตัวจะล้นหรือเหลือที่ว่างเยอะ |

---

## 🌳 ผัง Node

```
DialogueBox                CanvasLayer      ← attach dialogue_system.gd · กลุ่ม "dialogue_ui"
├── Root                   Control          ← Full Rect · mouse_filter: Ignore
│   │
│   ├── Portraits          Control          ← ซ่อนก้อนนี้ = โหมดข้อความล้วน
│   │   ├── Namfha         AnimatedSprite2D
│   │   └── Wawa           AnimatedSprite2D
│   │
│   └── Box                Control          ← 🔒 กรอบตำแหน่ง ขนาดคงที่
│       ├── TextPanel      PanelContainer   ← 🔒 กล่องข้อความ (Full Rect ของ Box)
│       │   └── TextLabel  RichTextLabel
│       └── NamePlate      PanelContainer   ← 📐 ป้ายชื่อ ยืดตามชื่อ
│           └── NameLabel  Label
│
└── ChoiceBox              Control          ← ⚠️ ลูกของ DialogueBox **ไม่ใช่ของ Root**
    ├── LeftBox            VBoxContainer
    │   ├── Choice0        Button           ← ตัวเลือกข้อ 0
    │   └── Choice1        Button           ← ตัวเลือกข้อ **2**
    └── RightBox           VBoxContainer
        ├── Choice2        Button           ← ตัวเลือกข้อ **1**
        └── Choice3        Button           ← ตัวเลือกข้อ 3

   (ที่ไหนก็ได้ในกิ่งนี้)
   Next                    TextureButton    ← ปุ่มไปต่อ · ชื่อต้องเป็น "Next" เป๊ะ ๆ
                                              (Button ก็ได้ — โค้ดรับ BaseButton ทั้งสองสาย)
```

> 🚨 **ชื่อโหนดปุ่มไม่ตรงกับ index ของตัวเลือก** — ตั้งใจให้ 2 ตัวเลือกอยู่คนละฝั่งซ้าย-ขวา
> (`ตอบตกลง | ปฏิเสธ`) ไม่ใช่กองกันฝั่งซ้ายแล้วขวาโล่ง
> ลำดับจริงอยู่ที่ `CHOICE_BUTTON_PATHS` ใน `dialogue_system.gd` — **อยากเปลี่ยนการจัดวางแก้ที่นั่นที่เดียว**
> อย่าเปลี่ยนชื่อโหนดในซีนเพื่อให้ตรง index เพราะจะทำให้ path ในสคริปต์พังทันที

> 🚨 **ปุ่ม `Next` ตอนนี้เป็น `TextureButton` ที่ติ๊ก `Ignore Texture Size`**
> โหมดนั้น **ไม่ยืดตามขนาดรูปให้เอง** — ลืมลากขนาดจะได้กรอบ 0×0 มองไม่เห็นและกดไม่โดน
> ทั้งที่ใส่รูปไว้แล้ว (เกิดจริง 2026-08-16) · โค้ดยืดให้เท่ารูปพร้อมเตือน แต่ควรตั้งขนาดในซีนเอง
> หรือปิด `Ignore Texture Size` ไปเลยถ้าอยากให้เท่ารูปพอดี

> ℹ️ **ปุ่ม `Next` วางไว้ตรงไหนก็ได้** (มุมขวาล่างของ `TextPanel` / ลอยใต้ `Root`) —
> `dialogue_system.gd` หาด้วย `find_child("Next")` ไม่ได้ผูก path ไว้ **แต่ชื่อต้องตรงเป๊ะ**
> ไม่ต้องต่อสัญญาณ `pressed` และไม่ต้องตั้ง `focus_mode` เอง โค้ดจัดการให้แล้วตอน `_ready()`

> ⚠️ **`NamePlate` ต้องอยู่ทีหลัง `TextPanel` ในผัง** เพราะ Godot วาดตามลำดับ node
> ป้ายชื่อจึงทับขอบกล่องข้อความได้สวยแบบที่เห็นในเกมทั่วไป
> ถ้าสลับลำดับ ป้ายจะถูกกล่องทับจนมองไม่เห็น

---

## 1. `Box` — กรอบตำแหน่ง (ขนาดคงที่)

Control เปล่า ๆ ทำหน้าที่กำหนดว่ากล่องคำพูดอยู่ตรงไหนและใหญ่เท่าไหร่

| property | ค่า |
|---|---|
| `anchors_preset` | **Bottom Wide** (12) |
| `offset_left` | 60 |
| `offset_right` | −60 |
| `offset_top` | **−300** ← ความสูงกล่อง ปรับตัวนี้ |
| `offset_bottom` | −24 ← ระยะห่างจากขอบล่างจอ |
| `mouse_filter` | Ignore |

**ทำไมต้องมี Control ชั้นนี้:** เพื่อให้ `TextPanel` และ `NamePlate` อ้างอิงกรอบเดียวกัน
ป้ายชื่อจะเกาะมุมซ้ายบนของกรอบนี้ ขยับกล่องทีเดียวป้ายตามไปด้วยเสมอ

---

## 2. `TextPanel` — กล่องข้อความ 🔒 คงที่

| property | ค่า | เหตุผล |
|---|---|---|
| `anchors_preset` | **Full Rect** | เต็มกรอบ `Box` → ขนาดมาจาก Box ที่คงที่ ไม่หุบตามข้อความ |
| `theme_override_styles/panel` | **StyleBoxFlat** (ดูค่าด้านล่าง) | |

### StyleBoxFlat ของ `TextPanel`

| property | ค่าแนะนำ |
|---|---|
| `bg_color` | `#12131A` เข้ม + alpha ~0.92 (ทึบพอให้อ่านข้อความออก แต่ยังเห็นฉากหลังจาง ๆ) |
| `corner_radius` ทั้ง 4 มุม | 14 |
| `border_width` ทุกด้าน | 2 |
| `border_color` | ขาว alpha ~0.18 |
| `content_margin_left / right` | **28** |
| `content_margin_top / bottom` | **22** |

> 💡 **ใช้ `content_margin_*` แทนการเพิ่ม `MarginContainer`**
> `PanelContainer` จะเว้นระยะขอบให้ลูกตามค่านี้เอง — ลด node ไปหนึ่งชั้นโดยได้ผลเหมือนกัน

---

## 3. `TextLabel` — เนื้อข้อความ

**ต้องเป็น `RichTextLabel` ไม่ใช่ `Label`** เพราะเอฟเฟกต์พิมพ์ทีละตัวอักษรใช้ `visible_ratio` ซึ่ง `Label` ไม่มี

| property | ค่า | เหตุผล |
|---|---|---|
| `bbcode_enabled` | ✔ | สคริปต์ตั้งให้แล้วตอน `_ready()` แต่ติ๊กไว้จะเห็นผลใน editor ด้วย |
| `fit_content` | **✘ ปิด** | ถ้าเปิด กล่องจะขยายตามข้อความ = ขัดกับที่ต้องการให้คงที่ |
| `scroll_active` | **✘ ปิด** | กันแถบเลื่อนโผล่ในกล่องบทพูด |
| `autowrap_mode` | Word Smart | ตัดบรรทัดตามคำ |
| `custom_minimum_size` | **ไม่ต้องตั้ง** | ปล่อยว่าง ขนาดมาจาก `TextPanel` |

---

## 4. `NamePlate` — ป้ายชื่อ 📐 ยืดหดตามชื่อ

**นี่คือส่วนที่กลไกน่าสนใจที่สุด** — ทำให้ป้ายกว้างเท่าชื่อพอดีทุกตัวละคร โดยไม่ต้องเขียนโค้ดคำนวณ

| property | ค่า | เหตุผล |
|---|---|---|
| `anchors_preset` | **Top Left** (0) | เกาะมุมซ้ายบนของ `Box` |
| `offset_left` | 28 | เยื้องเข้ามาจากขอบกล่อง |
| `offset_right` | **28** ← เท่ากับ `offset_left` | ⭐ ทำให้ความกว้างตั้งต้นเป็น **0** |
| `offset_top` | 0 | อยู่ที่ขอบบนของกล่อง |
| `offset_bottom` | **0** ← เท่ากับ `offset_top` | ⭐ ทำให้ความสูงตั้งต้นเป็น **0** |
| `grow_horizontal` | **End** | ขยายไปทางขวา |
| `grow_vertical` | **Begin** | ⭐ ขยาย **ขึ้นด้านบน** → ป้ายไปนั่งเหนือกล่องพอดี |

### กลไกทำงานยังไง

Godot มีกฎว่า **Control จะเล็กกว่า `get_combined_minimum_size()` ไม่ได้**

- ตั้ง offset ให้ขนาดตั้งต้นเป็น **0×0**
- `PanelContainer` คำนวณขนาดต่ำสุดจาก `NameLabel` ข้างใน + `content_margin`
- Godot จึงขยายป้ายจาก 0 ไปเท่าขนาดต่ำสุดนั้น = **พอดีกับชื่อเป๊ะ**
- `grow_vertical = Begin` กำหนดว่าให้ขยายขึ้น ไม่ใช่ลง → ป้ายอยู่เหนือกล่อง ไม่ทับข้อความ

**ผลลัพธ์:** ชื่อ `"น้ำฟ้า"` ได้ป้ายแคบ · `"พี่วาวา หัวหน้าสวัสดิการ"` ได้ป้ายกว้าง — อัตโนมัติทั้งคู่

### StyleBoxFlat ของ `NamePlate`

| property | ค่าแนะนำ |
|---|---|
| `bg_color` | สีเน้น ต่างจากกล่องข้อความ เช่น `#4A56E8` (ฟ้าเข้าชุดกับ UI แชท) |
| `corner_radius_top_left / top_right` | 12 |
| `corner_radius_bottom_left / bottom_right` | **0** ← มุมล่างเหลี่ยม ให้เชื่อมกับกล่องข้อความเนียน |
| `content_margin_left / right` | 20 |
| `content_margin_top / bottom` | 8 |

---

## 5. `Portraits` — รูปตัวละคร

| property | ค่า |
|---|---|
| `anchors_preset` | Full Rect |
| `mouse_filter` | Ignore |

**สลับโหมดจากโค้ด:**
```gdscript
portraits.show()   # โหมดมีรูปตัวละคร
portraits.hide()   # โหมดข้อความล้วน
```

⭐ **`Portraits` กับ `Box` ต้องเป็นพี่น้อง anchor แยกกันเอง**
ห้ามเอาไปใส่ `VBoxContainer` เดียวกัน ไม่งั้นซ่อนรูปแล้วกล่องข้อความจะกระโดดขึ้นไปแทนที่รูป
เป็นพี่น้องแล้วซ่อนรูป กล่องอยู่ที่เดิมเป๊ะ

`AnimatedSprite2D` เป็น Node2D ไม่เข้าระบบ anchor → กำหนดตำแหน่งและ `scale` ด้วยมือ
ไม่ใช่ปัญหาเพราะอยู่ใต้ `CanvasLayer` กล้องซูม/เลื่อน/สั่นไม่มีผล วางครั้งเดียวอยู่ตลอด

---

## ❌ สิ่งที่ห้ามทำ

| ห้าม | เพราะ |
|---|---|
| ใส่กลุ่ม `dialogue_ui` ให้ node ลูก | `NPC.gd` ใช้ `get_first_node_in_group()` อาจได้ node ที่ไม่มีเมธอด `start_dialogue()` → crash · ใส่ที่ `DialogueBox` (CanvasLayer) เท่านั้น |
| ตั้ง `custom_minimum_size` ที่ `TextLabel` | ขนาดต้องมาจาก `TextPanel` — ปักไว้จะทำให้กล่องเพี้ยน |
| เปิด `fit_content` ที่ `TextLabel` | กล่องจะขยายตามข้อความ ขัดกับที่ต้องการให้คงที่ |
| ตั้ง `offset_right`/`offset_bottom` ของ `NamePlate` ให้ต่างจาก left/top | ป้ายจะมีขนาดตายตัว ไม่ยืดตามชื่อ |
| ใส่ `MarginContainer` เพิ่มเพื่อเว้นขอบ | ใช้ `content_margin_*` ใน StyleBoxFlat ได้ผลเหมือนกันโดยไม่เพิ่ม node |

---

## ค่าที่โค้ดตั้งเอง — อย่าตั้งใน editor ให้ขัดกัน

`dialogue_system.gd` เขียนทับค่าเหล่านี้ทุกครั้งที่รัน

| node | property |
|---|---|
| `DialogueBox` | `visible` (ซ่อนตอนเริ่ม เปิดเมื่อคุย) |
| `NameLabel` | `text` |
| `TextLabel` | `text` · `visible_ratio` · `bbcode_enabled` |
| `Namfha` / `Wawa` | `modulate` · `scale` · อนิเมชันที่เล่น |

## ค่าที่ปรับได้จาก Inspector ของ `DialogueBox`

| property | ค่าเริ่มต้น | หน้าที่ |
|---|---|---|
| `typing_speed` | 0.05 | วินาทีต่อตัวอักษร |
| `default_anim` | `"talk"` | อนิเมชันเมื่อบรรทัดนั้นไม่ระบุ `anim` |
| `color_active` / `color_idle` | ขาว / 0.35 | สีคนพูด / คนไม่พูด |
| `base_scale` | 2.5 | ขนาดพื้นฐานรูปตัวละคร |
| `scale_active` / `scale_idle` | 1.05 / 0.9 | ขยายคนพูด / ย่อคนไม่พูด |
| `focus_time` | 0.2 | เวลาเปลี่ยนสี-ขนาด |
