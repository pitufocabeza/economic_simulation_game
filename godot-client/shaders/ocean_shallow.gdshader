shader_type spatial;
render_mode blend_mix, cull_back;

// Water texture and animation
uniform sampler2D water_albedo : hint_default_white;
uniform sampler2D water_normal : hint_normal;

// Shallow water: bright turquoise with more transparency to show terrain below
uniform vec4 water_color = vec4(0.2, 1.0, 0.9, 1.0);
uniform float scroll_speed : hint_range(0.0, 2.0) = 0.1;
uniform float scroll_angle : hint_range(0.0, 360.0) = 45.0;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.4;
uniform float roughness_water : hint_range(0.0, 1.0) = 0.3;
uniform float metallic_water : hint_range(0.0, 1.0) = 0.0;
uniform float transparency : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	// Convert scroll angle to direction vector
	float angle_rad = radians(scroll_angle);
	vec2 scroll_dir = vec2(cos(angle_rad), sin(angle_rad));

	// Animated UV: scroll in scroll_dir at scroll_speed
	vec2 uv_animated = UV + scroll_dir * TIME * scroll_speed;

	// Sample water textures at animated UV
	vec3 water_albedo_sample = texture(water_albedo, uv_animated).rgb;
	vec3 water_normal_sample = texture(water_normal, uv_animated).rgb;

	// Unpack normal from [0,1] to [-1,+1]
	vec3 normal_unpacked = water_normal_sample * 2.0 - 1.0;
	
	// Adjust wave strength
	normal_unpacked.xy *= wave_strength;
	
	// Normalize and repack
	vec3 final_normal = normalize(normal_unpacked) * 0.5 + 0.5;

	// Output to Godot PBR
	ALBEDO = water_albedo_sample * water_color.rgb;
	NORMAL_MAP = final_normal;
	ROUGHNESS = roughness_water;
	METALLIC = metallic_water;
	ALPHA = transparency;
}
