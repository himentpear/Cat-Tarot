shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_add;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
varying float height_fraction;
void vertex(){height_fraction=UV.y;}
void fragment(){
	float sample_depth = texture(scene_depth, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, sample_depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, sample_depth);
#endif
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc,1.0);
	float soft = clamp((VERTEX.z-view_pos.z/view_pos.w)*2.0,0.0,1.0);
	float edge = smoothstep(0.0,0.65,abs(dot(normalize(NORMAL), normalize(VIEW))));
	ALBEDO = vec3(1.0,0.71,0.39);
	ALPHA = 0.034 * edge * sin(clamp(height_fraction, 0.0, 1.0)*3.14159) * soft;
}
