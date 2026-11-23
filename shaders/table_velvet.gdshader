shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.227, 0.098, 0.353, 1.0);
uniform bool use_albedo_tex = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform bool use_embroidery_mask = false;
uniform sampler2D embroidery_mask : filter_linear_mipmap_anisotropic;
uniform float nap_scale : hint_range(0.25, 4.0) = 1.0;
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.28;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(112.27, 37.13))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 nw = abs(normalize(world_normal));
	vec2 p = world_pos.xz * nw.y + world_pos.xy * nw.z + world_pos.zy * nw.x;
	p *= nap_scale;

	// Layered royal-velvet pile & woven cloth micro-nap in world space
	float macro_pile = noise2(p * vec2(1.9, 2.7));
	float brush_dir = noise2(p * vec2(7.5, 13.0) + vec2(macro_pile * 0.85, 0.0));
	float micro_nap = noise2(p * vec2(88.0, 74.0));
	float weave = 0.5 + 0.5 * sin(p.x * 165.0) * sin(p.y * 165.0);
	float velvet_grain = 0.80 + 0.14 * macro_pile + 0.11 * brush_dir + 0.08 * micro_nap + 0.03 * weave;

	vec3 sample_rgb = use_albedo_tex ? texture(albedo_tex, UV).rgb : tint.rgb;
	vec2 mask_rg = use_embroidery_mask ? texture(embroidery_mask, UV).rg : vec2(0.0);
	float emb = clamp(mask_rg.r, 0.0, 1.0);
	float trim = clamp(mask_rg.g, 0.0, 1.0);

	// Grazing velvet nap lift (modulated on cloth/crimson trim, suppressed on metallic gold thread)
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float grazing = pow(1.0 - ndv, 2.8) * sheen_strength * (1.0 - emb);

	vec3 ao = clamp(COLOR.rgb, vec3(0.0), vec3(1.0));
	float cloth_mod = mix(velvet_grain, 1.0, emb * 0.85);
	vec3 base_rgb = sample_rgb * cloth_mod;
	vec3 sheen_target = mix(vec3(0.329, 0.173, 0.494), vec3(0.55, 0.14, 0.24), trim);
	vec3 sheen_rgb = mix(sample_rgb, sheen_target, 0.45);

	ALBEDO = (base_rgb + sheen_rgb * grazing * 0.48) * ao;
	METALLIC = mix(0.0, 0.78, emb);
	ROUGHNESS = mix(0.90, 0.36, emb);
	SPECULAR = mix(0.14, 0.48, emb);
	RIM = 0.30 * (1.0 - emb * 0.85);
	RIM_TINT = 0.55;
}
