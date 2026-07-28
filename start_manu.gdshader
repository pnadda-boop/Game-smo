shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 resolution = vec2(640.0, 360.0);

float bayer4x4(ivec2 p){
	int x = p.x & 3;
	int y = p.y & 3;
	int index = x + y * 4;
	float table[16] = float[](
		 0.0,  8.0,  2.0, 10.0,
		12.0,  4.0, 14.0,  6.0,
		 3.0, 11.0,  1.0,  9.0,
		15.0,  7.0, 13.0,  5.0
	);
	return table[index] / 16.0;
}

void fragment()
{
	vec2 pixel = floor(UV * resolution);
	float threshold = bayer4x4(ivec2(pixel));
	if(progress >= threshold){
		COLOR = vec4(0.0,0.0,0.0,1.0);
	}else{
		COLOR = vec4(0.0,0.0,0.0,0.0);
	}
}