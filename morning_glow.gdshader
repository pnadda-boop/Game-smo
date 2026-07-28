shader_type canvas_item;
render_mode blend_add;

// ==============================================
// Shader โทนแสงเช้าอบอุ่น (Morning Ambient Glow)
// ==============================================
// วิธีใช้: สร้าง ColorRect คลุมเต็มจอ (Full Rect) วางไว้บนสุดของฉาก (เหนือพื้นหลัง เหนือตัวละคร)
// แล้วเอา shader นี้ใส่ใน Material ของ ColorRect นั้น
// ทำให้ทั้งซีนดูอมส้ม-เหลืองอ่อนแบบแสงเช้า โดยเข้มสุดตรงตำแหน่งหน้าต่างแล้วจางออกไป

uniform vec4 warm_color : source_color = vec4(1.0, 0.85, 0.6, 1.0); // สีโทนอบอุ่น
uniform float intensity : hint_range(0.0, 1.0) = 0.15; // ความเข้มรวม (ใส่น้อยๆ ไว้ก่อน ค่อยปรับเพิ่ม)
uniform vec2 light_origin = vec2(0.15, 0.35); // ตำแหน่งหน้าต่างบนจอ (0-1, 0,0=บนซ้าย)
uniform float falloff : hint_range(0.1, 3.0) = 1.2; // ยิ่งมาก ยิ่งจางเร็วเมื่อห่างจากหน้าต่าง

void fragment() {
	float dist = distance(UV, light_origin);
	float glow = clamp(1.0 - dist * falloff, 0.0, 1.0);
	COLOR = vec4(warm_color.rgb, warm_color.a * glow * intensity);
}