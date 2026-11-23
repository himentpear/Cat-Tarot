shader_type spatial;
render_mode cull_disabled;

// The die's black pips are baked into the model's vertex colors. The glTF
// importer leaves vertex_color_use_as_albedo off, which renders the die solid
// white. Use the vertex color as the albedo directly so the pips show on every
// rendering backend (Forward+ and Compatibility).
void fragment() {
	ALBEDO = COLOR.rgb;
	METALLIC = 0.043636;
	ROUGHNESS = 0.412727;
}
