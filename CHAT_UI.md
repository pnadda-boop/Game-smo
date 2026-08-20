# โครงสร้าง Node ของระบบแชท

เอกสารอ้างอิงตอนจัด node ใน Godot editor
สคริปต์ที่เกี่ยวข้อง: `phone.gd` · `message_bubble.gd` · `chat_database.gd`

**สัญลักษณ์**
| | ความหมาย |
|---|---|
| ✅ | ถูกต้องแล้ว ไม่ต้องแก้ |
| ✏️ | ต้องเปลี่ยนชื่อ |
| ➕ | ยังไม่มี ต้องเพิ่ม |
| 🎨 | ต้องแต่งหน้าตา |

> ⚠️ **ชื่อ node ต้องตรงเป๊ะ** ตัวพิมพ์เล็ก/ใหญ่มีผล
> `phone.gd` และ `message_bubble.gd` หา node ด้วย path ตรง ๆ ถ้าชื่อไม่ตรงจะหาไม่เจอ
> โค้ดใช้ `get_node_or_null()` ทั้งหมด จึงไม่ crash แต่ฟีเจอร์ตรงนั้นจะเงียบไปเฉย ๆ

---

> 🚨 **เอกสารนี้ล้าสมัยแล้ว (ยังไม่ได้เขียนใหม่)**
> ตอนที่เขียน ระบบแชทยังเป็นซีนเดียวชื่อ `Phone.tscn` — ตอนนี้ถูกแยกเป็น
> `Chat.tscn` (ตัวคุม) + `chat_group.tscn` (ห้องแชท 1 กลุ่ม) และ `Phone.tscn` ถูกลบไปแล้ว
> เครื่องหมาย ✏️ / ➕ ข้างล่างคือ "งานที่ต้องทำ" ซึ่ง **ทำเสร็จไปแล้วทั้งหมด**
> อ่านเป็นประวัติได้ แต่อย่าใช้เป็นคู่มือ — ดูโครงจริงที่หัวข้อ *ระบบแชทหลายกลุ่ม* ใน [CLAUDE.md](CLAUDE.md)

## 1. `Phone.tscn`

```
Phone                        CanvasLayer      ✅  ← attach phone.gd ที่นี่
└── Control                  Control          ✅
    ├── BG                   PanelContainer   ✅  พื้นหลังทั้งจอโทรศัพท์
    │
    ├── BGHeader             PanelContainer   ✅  แถบหัวสีฟ้า
    ├── Header               HBoxContainer    ✅
    │   └── VBoxContainer    VBoxContainer    ✅
    │       ├── Avatar       TextureRect      ✅  โลโก้กลุ่ม SMO
    │       ├── Label        Label            ✅  ชื่อกลุ่ม "SMO"
    │       └── Label2       Label            ✅  "N online"  ← phone.gd เขียนทับทุกครั้ง
    │
    ├── ScrollContainer      ScrollContainer  ✅
    │   └── MessageList      VBoxContainer    ✏️  ตอนนี้ชื่อ "MessageBubble"
    │                                             ต้องว่างเปล่า โค้ดสร้างบับเบิลเอง
    │
    ├── Down                 PanelContainer   🎨  แถบล่าง — ตอนนี้ยังใช้ StyleBox สีฟ้าของ header
    │   └── InputBar         HBoxContainer    ✏️  ตอนนี้ชื่อ "ChoiceContainer"
    │       ├── LineEdit     LineEdit         🎨  ช่องพิมพ์ (ประดับ พิมพ์จริงไม่ได้)
    │       └── SendButton   Button           🎨  ปุ่มส่ง (ประดับ กดไม่ได้)
    │
    └── ChoiceContainer      VBoxContainer    ➕  ปุ่มตัวเลือกคำตอบ — ยังไม่ต้องทำตอนนี้
```

### ทำไม `InputBar` กับ `ChoiceContainer` ต้องแยก node

**อายุการใช้งานต่างกันสิ้นเชิง** — `InputBar` อยู่ตลอดเวลา แต่ `ChoiceContainer` โผล่มาแล้วหายไปเมื่อเลือกเสร็จ

`phone.gd` จัดการ `ChoiceContainer` แบบนี้:
```gdscript
choice_container.hide()   # ซ่อนตอนเริ่ม
clear_choices()           # ลบลูกทุกตัวทิ้ง
```
ถ้า `LineEdit` กับ `SendButton` อยู่ในนั้น จะโดนซ่อนและโดนลบไปด้วย

### path ที่ `phone.gd` มองหา

| ตัวแปรในโค้ด | path |
|---|---|
| `scroll` | `Control/ScrollContainer` |
| `message_list` | `Control/ScrollContainer/MessageList` * |
| `online_label` | `Control/Header/VBoxContainer/Label2` |
| `input_bar` | `Control/Down/InputBar` |
| `line_edit` | `Control/Down/InputBar/LineEdit` |
| `send_button` | `Control/Down/InputBar/SendButton` |
| `choice_container` | `Control/ChoiceContainer` |

\* หาไม่เจอจะ fallback ไปใช้ VBoxContainer ตัวแรกใต้ `ScrollContainer` พร้อม push_warning

---

## 2. `message_bubble.tscn`

```
MessageBubble                HBoxContainer    ✅  ← attach message_bubble.gd ที่นี่
├── TextureRect              TextureRect      ✅  รูปโปรไฟล์ผู้ส่ง (นอกบับเบิล)
└── Column                   VBoxContainer    ✅
    ├── SenderName           Label            ✅  ชื่อผู้ส่ง
    └── PanelContainer       PanelContainer   ✅  ตัวบับเบิล (พื้นหลังมน)
        └── MarginContainer  MarginContainer  ✅  ระยะขอบในบับเบิล
            └── Content      VBoxContainer    ✅
                ├── TextureRect  TextureRect  ➕  รูปแนบในข้อความ — ถูกลบไปแล้ว
                └── Text         RichTextLabel ✅  เนื้อข้อความ
```

### path ที่ `message_bubble.gd` มองหา

| ตัวแปรในโค้ด | path |
|---|---|
| `avatar` | `TextureRect` |
| `column` | `Column` |
| `sender_name` | `Column/SenderName` |
| `attach_image` | `Column/PanelContainer/MarginContainer/Content/TextureRect` |
| `text_label` | `Column/PanelContainer/MarginContainer/Content/Text` |

### เรื่อง `Content/TextureRect` (รูปแนบในข้อความ)

ตอนนี้**ไม่มี** node นี้แล้ว ระบบยังทำงานปกติเพราะโค้ดเช็ค null ไว้
แต่พารามิเตอร์ `image` ใน `add_message()` / `load_history()` จะไม่มีผล

อยากให้ใช้ได้ → เพิ่ม `TextureRect` ชื่อ `TextureRect` เป็นลูกของ `Content` วาง**เหนือ** `Text`
โค้ดจะซ่อนมันเองอัตโนมัติเมื่อข้อความไม่มีรูปแนบ

---

## 3. ค่าที่ต้องตั้งใน Editor

### `Down` (แถบล่าง) 🎨
| property | ค่า |
|---|---|
| `theme_override_styles/panel` | StyleBoxFlat **ใหม่** สีเข้ม `#0F0F14` (อย่าใช้ตัวเดียวกับ header ที่เป็นสีฟ้า) |

### `LineEdit` 🎨
| property | ค่า | ทำไม |
|---|---|---|
| `theme_override_styles/normal` | StyleBoxFlat ใหม่ | |
| ↳ `bg_color` | `#08080C` (เข้มกว่าพื้น `Down`) | ให้เห็นว่าเป็นช่องแยก |
| ↳ `corner_radius` ทั้ง 4 มุม | **40** | Godot ตัดรัศมีไม่ให้เกินครึ่งความสูงอยู่แล้ว ใส่เกินไว้ = มนพอดีเสมอแม้เปลี่ยนความสูงทีหลัง |
| ↳ `border_width` ทุกด้าน | 1 | |
| ↳ `border_color` | ขาว alpha ≈ 0.12 | เส้นขอบจาง ๆ |
| ↳ `content_margin_left` | 24 | กันข้อความชิดขอบโค้ง |
| `placeholder_text` | เช่น `"พิมพ์ข้อความ..."` | **สำคัญ** — ช่องเปล่าที่พิมพ์ไม่ได้ดูเหมือนบั๊ก มีข้อความจาง ๆ จะดูเป็นแอปที่สมบูรณ์ |
| `theme_override_fonts/font` | `2005_iannnnnAMD.ttf` | ให้เข้ากับทั้งจอ |

### `SendButton` 🎨
| property | ค่า | ทำไม |
|---|---|---|
| `custom_minimum_size` | **56 × 56** | 30×30 เล็กไปสำหรับแถบสูง 84px |
| `flat` | ✔ ติ๊ก | เอาพื้นหลังปุ่มออก เหลือแต่ลูกศรลอย |
| `icon` | ลูกศรที่มีอยู่แล้ว | |

### `InputBar` 🎨
| property | ค่า |
|---|---|
| `theme_override_constants/separation` | ≈ 12 (กันลูกศรชิดช่องพิมพ์) |

### `LineEdit` size flag
`size_flags_horizontal = Fill, Expand` (ค่า 3) — ตั้งไว้แล้ว ✅ ทำให้ช่องพิมพ์ยืดเต็ม ปุ่มส่งเกาะขวา

---

## 4. ค่าที่ปรับได้จาก Inspector (ไม่ต้องแก้โค้ด)

### node `Phone` — จาก `phone.gd`
| property | ค่าปัจจุบัน | หน้าที่ |
|---|---|---|
| `message_spacing` | 28 | ระยะห่างระหว่างข้อความ |
| `divider_font_size` | 38 | ขนาดฟอนต์ตัวคั่นเวลา |
| `divider_color` | ขาว alpha 0.45 | สีตัวคั่นเวลา |
| `delay_base` / `delay_per_char` / `delay_max` | 0.6 / 0.02 / 2.5 | จังหวะข้อความใน `play_chat()` |
| `autoplay_test` | เปิด | เล่นบททดสอบเองตอนเปิดฉาก — **ปิดตอนเอาไปใช้จริงในเกม** |

### node `MessageBubble` — จาก `message_bubble.gd`
| property | ค่าปัจจุบัน | หน้าที่ |
|---|---|---|
| `avatar_size` | 56 | ขนาดรูปโปรไฟล์ |
| `max_width` | 420 | ความกว้างสูงสุดของบับเบิล เกินแล้วตัดบรรทัด |

---

## 5. ค่าที่ตั้งจากโค้ด — อย่าไปตั้งใน editor ให้ขัดกัน

`phone.gd` และ `message_bubble.gd` เขียนทับค่าเหล่านี้ทุกครั้งที่รัน
ตั้งใน editor ไปก็ไม่มีผล (และจะทำให้สับสนว่าทำไมแก้แล้วไม่เปลี่ยน)

| node | property | ตั้งโดย |
|---|---|---|
| `Label2` | `text` | `phone.gd` → `"N online"` จาก `ChatDatabase.online_count()` |
| `ScrollContainer` | `horizontal_scroll_mode` | `phone.gd` → ปิด |
| `MessageList` | `size_flags_horizontal` · `separation` | `phone.gd` |
| `LineEdit` | `editable` · `focus_mode` · `mouse_filter` | `phone.gd` → ทำให้เป็นของประดับ |
| `SendButton` | `focus_mode` · `mouse_filter` | `phone.gd` → ทำให้เป็นของประดับ |
| `MessageBubble` | `alignment` | `message_bubble.gd` → ซ้าย/ขวาตามผู้ส่ง |
| `TextureRect` (avatar) | `custom_minimum_size` · `expand_mode` · `stretch_mode` · `size_flags_vertical` | `message_bubble.gd` |
| `Text` | `custom_minimum_size` · `fit_content` · `scroll_active` | `message_bubble.gd` |

> ⚠️ **ห้ามตั้ง `custom_minimum_size` ที่ `Text` หรือ `PanelContainer` ใน editor**
> `message_bubble.gd` คำนวณความกว้างจากข้อความจริงทุกครั้ง ถ้าไปปักค่าไว้จะทำให้บับเบิลสั้นกลายเป็นแท่งยาว
