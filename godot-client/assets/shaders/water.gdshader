shader_type canvas_item;

uniform vec4 water_color : source_color = vec4(0.15, 0.35, 0.55, 1.0);
uniform vec4 deep_water_color : source_color = vec4(0.05, 0.15, 0.35, 1.0);
uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;
uniform float wave_frequency : hint_range(0.0, 20.0) = 5.0;
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;

void fragment() {
	vec2 uv = UV;
	
	// Animated wave distortion
	float time_offset = TIME * wave_speed;
	float wave1 = sin(uv.x * wave_frequency + time_offset) * wave_amplitude;
	float wave2 = cos(uv.y * wave_frequency * 1.3 + time_offset * 1.1) * wave_amplitude;
	
	vec2 distorted_uv = uv + vec2(wave1, wave2);
	
	// Depth variation
	float depth = sin(distorted_uv.x * 3.0) * cos(distorted_uv.y * 3.0) * 0.5 + 0.5;
	
	// Mix colors based on depth
	vec4 final_color = mix(water_color, deep_water_color, depth * 0.3);
	
	// Add shimmer effect
	float shimmer = sin(distorted_uv.x * 20.0 + TIME * 2.0) * 
	                cos(distorted_uv.y * 20.0 + TIME * 1.5) * 0.1 + 0.9;
	
	COLOR = final_color * shimmer;
	COLOR.a = 0.85; // Slight transparency
}
