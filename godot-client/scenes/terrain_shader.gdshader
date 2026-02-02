shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Terrain textures
uniform sampler2D grass_texture : hint_default_white;
uniform sampler2D sand_texture : hint_default_white;
uniform sampler2D ocean_texture : hint_default_white;

// Tiling scales
uniform float grass_scale : hint_range(0.1, 10.0) = 2.0;
uniform float sand_scale : hint_range(0.1, 10.0) = 4.0;
uniform float ocean_scale : hint_range(0.1, 10.0) = 1.0;

void fragment() {
	// Vertex color encodes terrain type:
	// Blue (0.1, 0.3, 0.8) = WATER / OCEAN
	// Sand (0.85, 0.8, 0.55) = BEACH
	// Green (0.2, 0.7, 0.3) = BUILDABLE LAND
	// Grey (0.5, 0.5, 0.5) = UNBUILDABLE
	
	vec3 vertex_color = COLOR.rgb;
	vec3 albedo = vec3(1.0);
	
	// Determine terrain type by vertex color
	// Use world position for texture tiling
	vec2 uv_base = WORLD_POSITION.xz;
	
	// Check for WATER (blue-ish)
	if (vertex_color.b > vertex_color.r && vertex_color.b > vertex_color.g) {
		// WATER: Use ocean texture
		uv_base *= ocean_scale;
		albedo = texture(ocean_texture, uv_base).rgb;
	}
	// Check for BEACH (sandy beige)
	else if (vertex_color.r > 0.7 && vertex_color.g > 0.7 && vertex_color.b < 0.6) {
		// BEACH: Use sand texture
		uv_base *= sand_scale;
		albedo = texture(sand_texture, uv_base).rgb;
	}
	// Check for UNBUILDABLE (grey)
	else if (abs(vertex_color.r - vertex_color.g) < 0.05 && abs(vertex_color.r - vertex_color.b) < 0.05) {
		// UNBUILDABLE: Use grey (keep as-is for now)
		albedo = vertex_color;
	}
	// Otherwise BUILDABLE LAND (green-ish)
	else {
		// BUILDABLE: Use grass texture
		uv_base *= grass_scale;
		albedo = texture(grass_texture, uv_base).rgb;
	}
	
	ALBEDO = albedo;
	ROUGHNESS = 0.8;
}
