shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform vec4 brass : source_color = vec4(0.91, 0.69, 0.32, 1.0);
void fragment(){
	vec2 edge = min(UV, 1.0 - UV);
	float line = min(edge.x * 3.35, edge.y);
	float mask = max(1.0-smoothstep(0.007,0.014,abs(line-0.055)),1.0-smoothstep(0.002,0.006,abs(line-0.092)));
	float sweep = pow(max(0.0, cos((UV.x * 0.85 + VIEW.x + VIEW.y * 0.5) * 6.283)), 8.0);
	ALBEDO = brass.rgb;
	METALLIC = 0.87;
	ROUGHNESS = 0.27;
	EMISSION = brass.rgb * (0.08 + 0.9 * sweep);
	ALPHA = mask * 0.92;
}
