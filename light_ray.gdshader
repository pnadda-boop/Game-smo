shader_type canvas_item;
render_mode blend_add;

// ==============================================
// Shader ลำแสงจากหน้าต่าง (Light Ray / God Ray แบบง่าย)
// ==============================================
// วิธีใช้: สร้าง Polygon2D เป็นรูปทรงสี่เหลี่ยมคางหมู (แคบด้านบนที่หน้าต่าง, กว้างด้านล่างที่พื้น/ตัวละคร)
// แล้วเอา shader นี้ใส่ใน Material ของ Polygon2D นั้น
// UV.x = แนวขวางของลำแสง (0 ซ้าย - 1 ขวา), UV.y = แนวยาวของลำแสง (0 = ต้นแสงที่หน้าต่าง, 1 = ปลายแสง)

uniform vec4 light_color : source_color = vec4(1.0, 0.92, 0.72, 1.0); // สีแสงเช้าอมส้ม-เหลืองอ่อน
uniform float intensity : hint_range(0.0, 2.0) = 1.0; // ความสว่างรวม ปรับจาก script ได้ตอน fade in/out
uniform float edge_softness : hint_range(0.0, 1.0) = 0.45; // ความนุ่มของขอบลำแสงซ้าย-ขวา
uniform float length_falloff : hint_range(0.1, 1.0) = 0.95; // จุดที่แสงเริ่มจางลงตามความยาว (ใกล้ 1 = แสงยาวเกือบเต็มเส้น แทบไม่จางกลางทาง)
uniform float shimmer_speed : hint_range(0.0, 3.0) = 0.6; // ความเร็วประกายแสง (ไม่มีผลถ้า shimmer_strength = 0)
uniform float shimmer_strength : hint_range(0.0, 0.3) = 0.0; // 🆕 ปิดไว้เป็นค่าเริ่มต้น (0.0) กันแสงเฟดหายเป็นจังหวะ - อยากได้ประกายกลับมา ค่อยปรับเพิ่มเองทีหลัง

void fragment() {
	// ขอบลำแสงซ้าย-ขวานุ่มๆ ไม่ใช่เส้นตรงคมกริบ
	float edge_fade = smoothstep(0.0, edge_softness, UV.x) * smoothstep(1.0, 1.0 - edge_softness, UV.x);

	// แสงจางลงเมื่อไกลจากหน้าต่าง (ปลายลำแสงที่ตกกระทบพื้น/ตัวละคร)
	float length_fade = smoothstep(1.0, length_falloff, UV.y);

	// ประกายเบาๆ เหมือนฝุ่นลอยในลำแสง (เคลื่อนไหวช้าๆ ตามเวลา)
	float shimmer = sin((UV.y * 12.0) + TIME * shimmer_speed) * shimmer_strength;
	shimmer += sin((UV.x * 20.0) - TIME * shimmer_speed * 0.7) * shimmer_strength * 0.5;

	float alpha = clamp(edge_fade * length_fade + shimmer, 0.0, 1.0) * intensity;
	COLOR = vec4(light_color.rgb, light_color.a * alpha);
}
