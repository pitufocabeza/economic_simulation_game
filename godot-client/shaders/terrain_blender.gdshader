shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// UV Tiling Control
uniform float uv_scale : hint_range(1.0, 16.0) = 4.0;

// Control Map (RGBA = Rock, Snow, Grass, Sand weights)
uniform sampler2D control_map : hint_default_white;

// Grass Textures
uniform sampler2D grass_albedo : hint_default_white;
uniform sampler2D grass_normal : hint_normal;

// Sand Textures
uniform sampler2D sand_albedo : hint_default_white;
uniform sampler2D sand_normal : hint_normal;

// Rock Textures
uniform sampler2D rock_albedo : hint_default_white;
uniform sampler2D rock_normal : hint_normal;

// Snow Textures
uniform sampler2D snow_albedo : hint_default_white;
uniform sampler2D snow_normal : hint_normal;

// ORM Textures (Occlusion-Roughness-Metallic packed)
// R channel = Occlusion, G channel = Roughness, B channel = Metallic
uniform sampler2D grass_orm : hint_default_white;
uniform sampler2D sand_orm : hint_default_white;
uniform sampler2D rock_orm : hint_default_white;

// Material Properties (fallback values, typically overridden by ORM textures)
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// AO Strength Control (0.0 = no AO darkening, 1.0 = full AO, 2.0 = double strength)
uniform float ao_strength : hint_range(0.0, 2.0) = 1.0;

// Helper function: Unpack normal map from [0,1] to [-1,1]
vec3 unpack_normal(vec3 normal_sample) {
	return normal_sample * 2.0 - 1.0;
}

// Helper function: Pack normal map from [-1,1] to [0,1]
vec3 pack_normal(vec3 normal_unpacked) {
	return normal_unpacked * 0.5 + 0.5;
}

// Helper function: Blend normals using weighted average
vec3 blend_normals(
	vec3 rock_norm, vec3 snow_norm, vec3 grass_norm, vec3 sand_norm,
	float rock_weight, float snow_weight, float grass_weight, float sand_weight
) {
	// Unpack all normals from [0,1] to [-1,1]
	rock_norm = unpack_normal(rock_norm);
	snow_norm = unpack_normal(snow_norm);
	grass_norm = unpack_normal(grass_norm);
	sand_norm = unpack_normal(sand_norm);
	
	// Weighted blend
	vec3 blended = (rock_weight * rock_norm) 
	             + (snow_weight * snow_norm) 
	             + (grass_weight * grass_norm) 
	             + (sand_weight * sand_norm);
	
	// Normalize and repack
	return pack_normal(normalize(blended));
}

void fragment() {
	// Scaled UV for texture tiling
	vec2 tiled_uv = UV * uv_scale;
	
	// Sample control map (discrete biome weights)
	// R=Rock, G=Snow, B=Grass, A=Sand
	vec4 control = texture(control_map, UV);
	
	// ============================================
	// ALBEDO SAMPLING AND BLENDING
	// ============================================
	
	// Sample all albedos at tiled UV coordinates
	vec3 rock_albedo_sample = texture(rock_albedo, tiled_uv).rgb;
	vec3 snow_albedo_sample = texture(snow_albedo, tiled_uv).rgb;
	vec3 grass_albedo_sample = texture(grass_albedo, tiled_uv).rgb;
	vec3 sand_albedo_sample = texture(sand_albedo, tiled_uv).rgb;
	
	// Blend albedos using control map weights
	vec3 final_albedo = (control.r * rock_albedo_sample)
	                   + (control.g * snow_albedo_sample)
	                   + (control.b * grass_albedo_sample)
	                   + (control.a * sand_albedo_sample);
	
	// ============================================
	// NORMAL MAP SAMPLING AND BLENDING
	// ============================================
	
	// Sample all normal maps at tiled UV coordinates
	vec3 rock_normal_sample = texture(rock_normal, tiled_uv).rgb;
	vec3 snow_normal_sample = texture(snow_normal, tiled_uv).rgb;
	vec3 grass_normal_sample = texture(grass_normal, tiled_uv).rgb;
	vec3 sand_normal_sample = texture(sand_normal, tiled_uv).rgb;
	
	// Blend normals with proper normal map blending
	vec3 final_normal = blend_normals(
		rock_normal_sample,
		snow_normal_sample,
		grass_normal_sample,
		sand_normal_sample,
		control.r,  // rock weight
		control.g,  // snow weight
		control.b,  // grass weight
		control.a   // sand weight
	);
	
	// ============================================
	// ORM SAMPLING AND BLENDING
	// ============================================
	
	// Sample all ORM maps at tiled UV coordinates
	vec3 rock_orm_sample = texture(rock_orm, tiled_uv).rgb;
	vec3 grass_orm_sample = texture(grass_orm, tiled_uv).rgb;
	vec3 sand_orm_sample = texture(sand_orm, tiled_uv).rgb;
	
	// Blend ORM channels using control map weights (no snow_orm)
	// When snow appears, it uses rock's ORM as fallback
	vec3 final_orm = (control.r * rock_orm_sample)
	               + (control.b * grass_orm_sample)
	               + (control.a * sand_orm_sample);
	
	// If snow is visible (control.g > 0), use rock's ORM
	final_orm += (control.g * rock_orm_sample);
	
	// Extract individual channels
	float final_ao = final_orm.r;         // Occlusion from R channel
	float final_roughness = final_orm.g;  // Roughness from G channel
	float final_metallic = final_orm.b;   // Metallic from B channel
	
	// ============================================
	// FALLBACK HANDLING FOR MISSING ORM TEXTURES
	// ============================================
	
	// If ORM textures are black/missing, use uniform fallbacks
	// This handles cases where ORM map is not available or has black pixels
	if (final_roughness < 0.01) {
		final_roughness = roughness;  // Use uniform fallback
	}
	if (final_metallic < 0.01) {
		final_metallic = metallic;    // Use uniform fallback
	}
	
	// ============================================
	// AO STRENGTH BLENDING
	// ============================================
	
	// Blend AO strength: 0.0 = white (no darkening), 1.0 = full AO, 2.0 = double strength
	final_ao = mix(1.0, final_ao, ao_strength);
	
	// ============================================
	// OUTPUT TO GODOT'S PBR PIPELINE
	// ============================================
	
	ALBEDO = final_albedo;
	NORMAL_MAP = final_normal;
	ROUGHNESS = final_roughness;
	METALLIC = final_metallic;
	AO = final_ao;
}
