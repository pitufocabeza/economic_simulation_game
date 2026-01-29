shader_type canvas_item;

// Varying to pass vertex position to fragment shader
varying vec2 vertex_position;

// Terrain textures for blending
uniform sampler2D terrain_1 : filter_linear_mipmap, repeat_enable; // Lowest elevation (water/ice sea)
uniform sampler2D terrain_2 : filter_linear_mipmap, repeat_enable; // Low elevation (plains)
uniform sampler2D terrain_3 : filter_linear_mipmap, repeat_enable; // Mid elevation (glacier/forest)
uniform sampler2D terrain_4 : filter_linear_mipmap, repeat_enable; // High elevation (mountain)

// Noise parameters
uniform int noise_seed = 12345;
uniform float noise_frequency = 0.08;
uniform int noise_octaves = 4;
uniform float blend_sharpness = 3.0; // Higher = sharper transitions

// Simple hash function for noise
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// 2D noise function
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	
	// Quintic interpolation
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	
	// Sample corners
	float a = hash(i + vec2(0.0, 0.0));
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	// Bilinear interpolation
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractal Brownian Motion (multiple octaves of noise)
float fbm(vec2 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	
	for (int i = 0; i < octaves; i++) {
		value += amplitude * (noise(p * frequency) * 2.0 - 1.0);
		frequency *= 2.0;
		amplitude *= 0.5;
	}
	
	return value;
}

// Smooth blend function (smoother than smoothstep)
float smooth_blend(float edge0, float edge1, float x) {
	x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
	return x * x * (3.0 - 2.0 * x);
}

void vertex() {
	vertex_position = VERTEX;
}

void fragment() {
	// Use vertex position for world-space noise sampling
	vec2 noise_pos = vertex_position / 256.0; // One noise sample per tile
	noise_pos += vec2(float(noise_seed) * 0.1);
	
	// Sample noise at this world position
	float elevation = fbm(noise_pos * noise_frequency, noise_octaves);
	
	// Normalize to 0-1 range
	elevation = (elevation + 1.0) * 0.5;
	
	// For texture sampling, use vertex position to create seamless tiling
	vec2 texture_uv = vertex_position / 256.0;
	
	// Sample all terrain textures
	vec4 color_1 = texture(terrain_1, texture_uv);
	vec4 color_2 = texture(terrain_2, texture_uv);
	vec4 color_3 = texture(terrain_3, texture_uv);
	vec4 color_4 = texture(terrain_4, texture_uv);
	
	// Define elevation thresholds (adjust these to match your biome logic)
	float threshold_1 = 0.25;  // Water/Ice Sea cutoff
	float threshold_2 = 0.45;  // Plains cutoff
	float threshold_3 = 0.70;  // Glacier/Forest cutoff
	
	// Blend width for smooth transitions
	float blend_width = 0.1 / blend_sharpness;
	
	// Calculate blend weights
	float weight_1 = 1.0 - smooth_blend(threshold_1 - blend_width, threshold_1 + blend_width, elevation);
	float weight_2 = smooth_blend(threshold_1 - blend_width, threshold_1 + blend_width, elevation) 
	                * (1.0 - smooth_blend(threshold_2 - blend_width, threshold_2 + blend_width, elevation));
	float weight_3 = smooth_blend(threshold_2 - blend_width, threshold_2 + blend_width, elevation)
	                * (1.0 - smooth_blend(threshold_3 - blend_width, threshold_3 + blend_width, elevation));
	float weight_4 = smooth_blend(threshold_3 - blend_width, threshold_3 + blend_width, elevation);
	
	// Normalize weights
	float total_weight = weight_1 + weight_2 + weight_3 + weight_4;
	weight_1 /= total_weight;
	weight_2 /= total_weight;
	weight_3 /= total_weight;
	weight_4 /= total_weight;
	
	// Blend colors
	vec4 final_color = color_1 * weight_1 + color_2 * weight_2 + color_3 * weight_3 + color_4 * weight_4;
	
	COLOR = final_color;
}
