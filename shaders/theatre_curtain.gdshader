shader_type spatial;
render_mode cull_disabled;

uniform vec4 dye : source_color = vec4(0.35, 0.023, 0.067, 1.0);
uniform float panel_width = 1.72;
uniform float panel_height = 2.425;
uniform float direction = 1.0;
uniform float openness = 0.0;
// 13 rail points by 8 rows. The existing mesh supplies the fine folds and hem.
uniform vec4 cloth_offsets[104];

void vertex() {
	vec2 grid = clamp(UV, vec2(0.0), vec2(1.0)) * vec2(12.0, 7.0);
	ivec2 cell = min(ivec2(grid), ivec2(11, 6));
	vec2 weight = grid - vec2(cell);
	int i = cell.y * 13 + cell.x;
	vec3 a = cloth_offsets[i].xyz;
	vec3 b = cloth_offsets[i + 1].xyz;
	vec3 c = cloth_offsets[i + 13].xyz;
	vec3 d = cloth_offsets[i + 14].xyz;
	VERTEX.z *= mix(1.0, 0.22, openness);
	VERTEX += mix(mix(a, b, weight.x), mix(c, d, weight.x), weight.y);

	vec3 along_rail = vec3(panel_width * direction, 0.0, 0.0) + mix(b - a, d - c, weight.y) * 12.0;
	vec3 down_cloth = vec3(0.0, -panel_height, 0.0) + mix(c - a, d - b, weight.x) * 7.0;
	vec3 cloth_normal = cross(down_cloth, along_rail) * direction;
	if (length(cloth_normal) > 0.001) {
		NORMAL = normalize(mix(NORMAL, normalize(cloth_normal), openness * 0.88));
	}
}

void fragment() {
	float grazing = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.8);
	ALBEDO = dye.rgb * (0.94 + 0.06 * sin(UV.x * 160.0)) + vec3(0.10, 0.018, 0.026) * grazing;
	ROUGHNESS = 0.87;
	SPECULAR = 0.27;
	RIM = 0.17;
}
