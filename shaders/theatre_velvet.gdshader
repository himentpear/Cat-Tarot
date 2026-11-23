shader_type spatial;
render_mode cull_disabled;
uniform vec4 dye : source_color = vec4(0.35, 0.023, 0.067, 1.0);
uniform float sway = 0.009;
void vertex() {
	VERTEX.z += sway * (1.0 - UV.y) * sin(TIME * 0.65 + VERTEX.x * 4.3 + UV.y * 3.0);
}
void fragment() {
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.8);
	ALBEDO = dye.rgb * (0.94 + 0.06 * sin(UV.x * 160.0)) + vec3(0.16, 0.028, 0.04) * rim;
	ROUGHNESS = 0.82;
	RIM = 0.24;
}
