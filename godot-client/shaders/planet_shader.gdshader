shader_type spatial;

uniform int planet_seed = 12345;
uniform int biome_type = 0;  // 0=Temperate, 1=Ice, 2=Volcanic, 3=Barren, 4=Oceanic
uniform float noise_scale = 10.0;
uniform float height_scale = 90.0;  // Height of terrain features in world units

// Pass object-space position from vertex to fragment
varying vec3 object_pos;

// Better hash function using sin
float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

// Hash with seed - improved to handle large seed values
float hash_seed(vec3 p, int seed) {
	// Hash the seed itself to get better distribution
	float seed_hash = fract(sin(float(seed) * 0.0001) * 43758.5453);
	// Offset position by the hashed seed
	p += vec3(seed_hash * 100.0, seed_hash * 200.0, seed_hash * 150.0);
	return hash(p);
}

// 3D noise with seed support
float noise3d_seed(vec3 p, int seed) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	
	// Quintic interpolation for smoother noise
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	
	return mix(
		mix(mix(hash_seed(i + vec3(0,0,0), seed), hash_seed(i + vec3(1,0,0), seed), u.x),
			mix(hash_seed(i + vec3(0,1,0), seed), hash_seed(i + vec3(1,1,0), seed), u.x), u.y),
		mix(mix(hash_seed(i + vec3(0,0,1), seed), hash_seed(i + vec3(1,0,1), seed), u.x),
			mix(hash_seed(i + vec3(0,1,1), seed), hash_seed(i + vec3(1,1,1), seed), u.x), u.y),
		u.z
	);
}

// Multi-octave noise with seed - 10 octaves for ultra-fine detail
float fbm_seed(vec3 p, int seed) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	
	// 10 octaves for ultra-realistic detail
	for (int i = 0; i < 10; i++) {
		value += amplitude * (noise3d_seed(p * frequency, seed + i) * 2.0 - 1.0);
		amplitude *= 0.5;
		frequency *= 2.0;
	}
	
	return value;
}

// Get color based on biome and elevation
vec3 get_biome_color(float elevation, int biome) {
	vec3 color;
	
	if (biome == 0) {  // Temperate - lush and green
		if (elevation > 0.70) {
			color = vec3(0.65, 0.65, 0.67);  // Snow peaks
		} else if (elevation > 0.65) {
			float t = (elevation - 0.65) / 0.05;
			color = mix(vec3(0.28, 0.25, 0.22), vec3(0.65, 0.65, 0.67), t);
		} else if (elevation > 0.58) {
			color = vec3(0.28, 0.25, 0.22);  // Rocky mountains
		} else if (elevation > 0.52) {
			float t = (elevation - 0.52) / 0.06;
			color = mix(vec3(0.12, 0.28, 0.12), vec3(0.28, 0.25, 0.22), t);
		} else if (elevation > 0.48) {
			color = vec3(0.12, 0.28, 0.12);  // Dense forest - darker green
		} else if (elevation > 0.45) {
			float t = (elevation - 0.45) / 0.03;
			color = mix(vec3(0.18, 0.35, 0.15), vec3(0.12, 0.28, 0.12), t);
		} else if (elevation > 0.43) {
			color = vec3(0.18, 0.35, 0.15);  // Forest - vibrant green
		} else if (elevation > 0.425) {
			float t = (elevation - 0.425) / 0.005;
			color = mix(vec3(0.25, 0.38, 0.18), vec3(0.18, 0.35, 0.15), t);
		} else if (elevation > 0.42) {
			color = vec3(0.25, 0.38, 0.18);  // Grasslands - lush
		} else if (elevation > 0.40) {
			float t = (elevation - 0.40) / 0.02;
			color = mix(vec3(0.08, 0.18, 0.28), vec3(0.12, 0.25, 0.35), t);
		} else if (elevation > 0.35) {
			color = vec3(0.08, 0.18, 0.28);  // Continental shelf
		} else {
			float depth = (0.30 - elevation) / 0.30;
			color = mix(vec3(0.04, 0.10, 0.18), vec3(0.01, 0.04, 0.10), depth);
		}
	} else if (biome == 1) {  // Ice - darker and more realistic
		if (elevation > 0.58) {
			color = vec3(0.70, 0.72, 0.75);  // Ice peaks - much darker
		} else if (elevation > 0.48) {
			float t = (elevation - 0.48) / 0.1;
			color = mix(vec3(0.55, 0.58, 0.62), vec3(0.70, 0.72, 0.75), t);
		} else if (elevation > 0.38) {
			color = vec3(0.55, 0.58, 0.62);  // Glaciers
		} else {
			float t = max(0.0, (elevation - 0.3) / 0.08);
			color = mix(vec3(0.30, 0.38, 0.45), vec3(0.55, 0.58, 0.62), t);
		}
	} else if (biome == 2) {  // Volcanic - darker tones
		if (elevation > 0.55) {
			color = vec3(0.08, 0.06, 0.05);  // Very dark volcanic rock
		} else if (elevation > 0.45) {
			float t = (elevation - 0.45) / 0.1;
			color = mix(vec3(0.18, 0.12, 0.08), vec3(0.08, 0.06, 0.05), t);
		} else if (elevation > 0.38) {
			color = vec3(0.18, 0.12, 0.08);  // Ash plains - darker
		} else if (elevation > 0.35) {
			// Transition to lava
			float t = (elevation - 0.35) / 0.03;
			color = mix(vec3(0.6, 0.18, 0.04), vec3(0.18, 0.12, 0.08), t);
		} else {
			// Lava - less bright
			color = vec3(0.6, 0.18, 0.04);
		}
	} else if (biome == 3) {  // Barren - more Mars-like
		if (elevation > 0.5) {
			color = vec3(0.25, 0.22, 0.18);  // Rocky mountains - darker
		} else if (elevation > 0.3) {
			color = vec3(0.32, 0.28, 0.22);  // Rocky plains
		} else {
			color = vec3(0.38, 0.32, 0.24);  // Sand/dust - desaturated
		}
	} else if (biome == 4) {  // Oceanic - mostly water
		if (elevation > 0.56) {
			color = vec3(0.30, 0.28, 0.20);  // Island peaks - darker
		} else if (elevation > 0.54) {
			float t = (elevation - 0.54) / 0.02;
			color = mix(vec3(0.10, 0.25, 0.35), vec3(0.30, 0.28, 0.20), t);
		} else if (elevation > 0.45) {
			color = vec3(0.10, 0.25, 0.35);  // Shallow water - darker
		} else if (elevation > 0.38) {
			float t = (elevation - 0.38) / 0.07;
			color = mix(vec3(0.01, 0.04, 0.15), vec3(0.10, 0.25, 0.35), t);
		} else {
			color = vec3(0.01, 0.04, 0.15);  // Deep ocean - very dark
		}
	} else {
		color = vec3(0.5, 0.5, 0.5);  // Default gray
	}
	
	return color;
}

void vertex() {
	// Calculate terrain height at this vertex
	vec3 normalized_pos = normalize(VERTEX);
	float terrain_height = fbm_seed(normalized_pos * noise_scale, planet_seed);
	
	// Displace vertex outward based on terrain height
	// Add some height variation - positive for mountains, negative for valleys
	VERTEX += normalized_pos * terrain_height * height_scale;
	
	// Pass normalized object-space vertex position to fragment shader
	object_pos = normalized_pos;
}

void fragment() {
	// Use the object-space position that was passed from vertex shader
	vec3 obj_normal = object_pos;
	
	// Generate terrain using multi-octave noise
	float terrain = fbm_seed(obj_normal * noise_scale, planet_seed);
	
	// Normalize to 0-1 range
	float elevation = terrain * 0.5 + 0.5;
	elevation = clamp(elevation, 0.0, 1.0);
	
	// Get color based on biome and elevation
	vec3 base_color = get_biome_color(elevation, biome_type);
	
	// Generate enhanced normal map for surface detail - calculate height samples first
	float bump_strength = 1.2;
	vec3 offset = vec3(0.005, 0.0, 0.0);
	float h_center = fbm_seed(obj_normal * noise_scale, planet_seed);
	float h_right = fbm_seed((obj_normal + offset.xyy) * noise_scale, planet_seed);
	float h_up = fbm_seed((obj_normal + offset.yxy) * noise_scale, planet_seed);
	
	// Add multiple layers of fine detail at different scales for HD appearance
	float detail1 = noise3d_seed(obj_normal * noise_scale * 8.0, planet_seed + 100);
	detail1 = detail1 * 0.5 + 0.5;
	
	float detail2 = noise3d_seed(obj_normal * noise_scale * 24.0, planet_seed + 200);
	detail2 = detail2 * 0.5 + 0.5;
	
	float detail3 = noise3d_seed(obj_normal * noise_scale * 64.0, planet_seed + 300);
	detail3 = detail3 * 0.5 + 0.5;
	
	float detail4 = noise3d_seed(obj_normal * noise_scale * 128.0, planet_seed + 400);
	detail4 = detail4 * 0.5 + 0.5;
	
	// Combine detail layers with decreasing influence for photorealistic micro-detail
	// Add color variation based on slope for more realism
	float slope = abs(h_center - h_right) + abs(h_center - h_up);
	
	base_color = mix(base_color * 0.88, base_color * 1.08, detail1);
	base_color = mix(base_color * 0.93, base_color * 1.04, detail2 * 0.6);
	base_color = mix(base_color * 0.96, base_color * 1.02, detail3 * 0.4);
	base_color = mix(base_color * 0.98, base_color * 1.01, detail4 * 0.2);
	
	// Darken steep slopes slightly for more depth
	base_color *= mix(1.0, 0.85, clamp(slope * 2.0, 0.0, 1.0));
	
	// Add subtle atmospheric scattering (blue tint at edges)
	float edge_factor = dot(normalize(VIEW), normalize(NORMAL));
	edge_factor = pow(max(0.0, edge_factor), 1.2);
	
	// Atmospheric rim lighting
	vec3 atmosphere_color = vec3(0.3, 0.5, 0.8) * 0.15;
	float atmosphere = pow(1.0 - edge_factor, 3.0);
	base_color = mix(base_color, atmosphere_color, atmosphere * 0.3);
	
	// Add edge darkening (limb darkening)
	base_color *= mix(0.1, 1.0, edge_factor);
	
	// Add micro-detail to normals
	float micro_right = noise3d_seed((obj_normal + offset.xyy) * noise_scale * 32.0, planet_seed + 500);
	float micro_up = noise3d_seed((obj_normal + offset.yxy) * noise_scale * 32.0, planet_seed + 500);
	
	vec3 normal_detail = normalize(vec3(
		(h_center - h_right) + (terrain - micro_right) * 0.3,
		(h_center - h_up) + (terrain - micro_up) * 0.3,
		bump_strength
	));
	
	// Apply normal in tangent space - reduced strength to prevent line artifacts
	NORMAL = normalize(NORMAL + normal_detail * 0.2);
	
	// Calculate Fresnel effect for realistic reflections
	float fresnel = pow(1.0 - max(0.0, dot(normalize(VIEW), normalize(NORMAL))), 3.0);
	
	// Material properties based on terrain type
	float roughness = 0.85;
	float metallic = 0.0;
	float specular = 0.1;
	float anisotropy = 0.0;
	
	// Water and ice use Fresnel - more reflective at grazing angles
	if (biome_type == 0 && elevation < 0.42) {  // Temperate water
		roughness = 0.35;
		specular = mix(0.08, 0.25, fresnel);
		anisotropy = 0.05;  // Slight directional reflection
		// Add subsurface scattering effect for water
		base_color = mix(base_color, base_color * vec3(0.8, 0.95, 1.0), 0.15);
	} else if (biome_type == 1) {  // Ice world
		roughness = 0.45;
		specular = mix(0.1, 0.3, fresnel);
		// Ice subsurface scattering
		base_color = mix(base_color, base_color * vec3(0.9, 0.95, 1.0), 0.1);
	} else if (biome_type == 2 && elevation < 0.38) {  // Volcanic lava
		roughness = 0.35;
		specular = 0.2;
		// Enhanced lava glow with pulsing effect
		float glow_variation = noise3d_seed(obj_normal * 4.0, planet_seed + 999) * 0.5 + 0.5;
		EMISSION = base_color * (0.6 + glow_variation * 0.4);
	} else if (biome_type == 4 && elevation < 0.54) {  // Oceanic water
		roughness = 0.35;
		specular = mix(0.08, 0.25, fresnel);
		anisotropy = 0.05;
		base_color = mix(base_color, base_color * vec3(0.8, 0.95, 1.0), 0.15);
	}
	
	ALBEDO = base_color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
	ANISOTROPY = anisotropy;
}
