shader_type canvas_item;

uniform vec2 scroll_speed = vec2(1.0, 0.0);
uniform float intensity = 1.0;

void fragment() {
	vec2 uv = UV;
	// COLOR.rgb = vec3(fract(TIME));

	// Scroll UVs over time
	uv += scroll_speed * TIME;

	// Wrap UVs infinitely
	uv = fract(uv);

	vec4 nebula = texture(TEXTURE, uv);

	// Final color
	COLOR = vec4(nebula.rgb * intensity, nebula.a);
}
