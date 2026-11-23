class_name ElementalGauge3D
extends Node3D
## Reusable 3D Victorian brass clockwork dial gauge for an elemental stat socket.

const MIN_VALUE := 0
const MAX_VALUE := 10
const MIN_ANGLE_DEG := -125.0
const MAX_ANGLE_DEG := 125.0
const DANGER_LOW := 1
const DANGER_HIGH := 9
const NEEDLE_TWEEN_DURATION := 0.36
const DIAL_RESOLUTION := 384
const DIAL_RADIUS := 0.46
const BEZEL_INNER_RADIUS := 0.45
const BEZEL_OUTER_RADIUS := 0.57

const STAT_ICONS := {
	"passion": "res://assets/icons/fire_color.png",
	"intuition": "res://assets/icons/eye_color.png",
	"curiosity": "res://assets/icons/star_color.png",
	"comfort": "res://assets/icons/leaves_color.png",
}

const STAT_LABELS := {
	"zh": {
		"passion": "戏魂",
		"intuition": "喵缘",
		"curiosity": "台本",
		"comfort": "幕布",
	},
	"en": {
		"passion": "Passion",
		"intuition": "Intuition",
		"curiosity": "Curiosity",
		"comfort": "Comfort",
	},
}

const STAT_ACCENT_COLORS := {
	"passion": Color("#e04850"),
	"intuition": Color("#5584e0"),
	"curiosity": Color("#d4a234"),
	"comfort": Color("#46a87b"),
}

const COLOR_BRASS := Color("#c89954")
const COLOR_BRASS_CAP := Color("#d4a45a")
const COLOR_BRASS_NEEDLE := Color("#f5cf76")
const COLOR_BRONZE_CUP := Color("#2a1e1a")
const COLOR_DIAL_PLATE := Color("#160e1c")
const COLOR_DANGER_RING_IDLE := Color("#3b2321")
const COLOR_DANGER_RING_HOT := Color("#a82430")
const COLOR_DANGER_EMISSION := Color("#e02b3a")

@export var stat_key: String = "passion"
@export var initial_value: int = 4

var _stat_key: String = "passion"
var _value: int = 4
var _configured: bool = false
var _has_applied_value: bool = false
var _built: bool = false
var _danger_pulse_time: float = 0.0

var _needle_pivot: Node3D
var _danger_material: StandardMaterial3D
var _dial_viewport: SubViewport
var _dial_canvas: _DialCanvas
var _needle_tween: Tween
var _icon_cache: Dictionary = {}


func _ready() -> void:
	_ensure_built()
	_connect_language_signal()
	if not _configured:
		setup(stat_key, initial_value)
	else:
		_refresh_dial_face()
		_update_needle_rotation(false, true)


func _exit_tree() -> void:
	var loc_node := _get_loc_node()
	if loc_node != null and loc_node.is_connected("language_changed", _on_language_changed):
		loc_node.disconnect("language_changed", _on_language_changed)


func _process(delta: float) -> void:
	if _danger_material == null:
		return
	if is_danger():
		_danger_pulse_time += delta
		var pulse := 0.5 + 0.5 * sin(_danger_pulse_time * 4.2)
		_danger_material.emission_energy_multiplier = 0.55 + 1.25 * pulse
		_danger_material.albedo_color = COLOR_DANGER_RING_IDLE.lerp(COLOR_DANGER_RING_HOT, pulse)
	elif _danger_material.emission_energy_multiplier > 0.0:
		_danger_pulse_time = 0.0
		_danger_material.emission_energy_multiplier = 0.0
		_danger_material.albedo_color = COLOR_DANGER_RING_IDLE


## Configures which elemental stat the gauge displays and snaps to initial_value.
func setup(next_stat_key: String, next_initial_value: int = 4) -> void:
	var normalized := next_stat_key.strip_edges().to_lower()
	if not STAT_ICONS.has(normalized):
		push_warning("ElementalGauge3D: unknown stat_key '%s', defaulting to 'passion'" % next_stat_key)
		normalized = "passion"
	_stat_key = normalized
	_configured = true
	_ensure_built()
	_value = clampi(next_initial_value, MIN_VALUE, MAX_VALUE)
	_has_applied_value = true
	_reset_danger_if_safe()
	_refresh_dial_face()
	_update_needle_rotation(false, true)


## Updates the gauge numeric value and rotates the 3D pointer needle.
func set_value(value: int, animate: bool = true) -> void:
	_ensure_built()
	var clamped := clampi(value, MIN_VALUE, MAX_VALUE)
	var changed := (clamped != _value) or not _has_applied_value
	_value = clamped
	_has_applied_value = true
	if changed:
		_reset_danger_if_safe()
		_refresh_dial_face()
	_update_needle_rotation(animate and is_inside_tree(), changed)


## Returns the current clamped stat value (0..10).
func get_value() -> int:
	return _value


## Returns true when the stat value is in the critical danger threshold (<= 1 or >= 9).
func is_danger() -> bool:
	return _value <= DANGER_LOW or _value >= DANGER_HIGH


## Returns the logical dial angle in [-125.0, +125.0] degrees (0 -> -125, 5 -> 0, 10 -> +125).
func get_pointer_angle_deg() -> float:
	var t := float(_value - MIN_VALUE) / float(MAX_VALUE - MIN_VALUE)
	return lerpf(MIN_ANGLE_DEG, MAX_ANGLE_DEG, t)


func _ensure_built() -> void:
	if _built:
		return
	_built = true

	_needle_pivot = get_node_or_null("NeedlePivot") as Node3D
	if _needle_pivot == null:
		_needle_pivot = Node3D.new()
		_needle_pivot.name = "NeedlePivot"
		_needle_pivot.position = Vector3(0.0, 0.064, 0.0)
		add_child(_needle_pivot)

	_build_housing()
	_build_dial_surface()
	_build_needle_and_cap()


func _build_housing() -> void:
	var cup_mesh := CylinderMesh.new()
	cup_mesh.top_radius = BEZEL_OUTER_RADIUS
	cup_mesh.bottom_radius = BEZEL_OUTER_RADIUS - 0.018
	cup_mesh.height = 0.036
	cup_mesh.radial_segments = 64
	var cup_mat := _pbr_material(COLOR_BRONZE_CUP, 0.62, 0.44)
	var cup := _add_mesh("CupRim", cup_mesh, Vector3(0.0, 0.018, 0.0), cup_mat)
	cup.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var plate_mesh := CylinderMesh.new()
	plate_mesh.top_radius = DIAL_RADIUS
	plate_mesh.bottom_radius = DIAL_RADIUS
	plate_mesh.height = 0.028
	plate_mesh.radial_segments = 64
	var plate_mat := _pbr_material(COLOR_DIAL_PLATE, 0.06, 0.84)
	_add_mesh("DialPlate", plate_mesh, Vector3(0.0, 0.033, 0.0), plate_mat)

	var bezel_mesh := TorusMesh.new()
	bezel_mesh.inner_radius = BEZEL_INNER_RADIUS
	bezel_mesh.outer_radius = BEZEL_OUTER_RADIUS
	bezel_mesh.rings = 64
	bezel_mesh.ring_segments = 24
	var bezel_mat := _pbr_material(COLOR_BRASS, 0.86, 0.26)
	var bezel := _add_mesh("OuterBezel", bezel_mesh, Vector3(0.0, 0.044, 0.0), bezel_mat)
	bezel.scale = Vector3(1.0, 0.72, 1.0)
	bezel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var danger_mesh := TorusMesh.new()
	danger_mesh.inner_radius = 0.438
	danger_mesh.outer_radius = 0.458
	danger_mesh.rings = 64
	danger_mesh.ring_segments = 16
	_danger_material = _pbr_material(COLOR_DANGER_RING_IDLE, 0.50, 0.34)
	_danger_material.emission_enabled = true
	_danger_material.emission = COLOR_DANGER_EMISSION
	_danger_material.emission_energy_multiplier = 0.0
	var danger_ring := _add_mesh("DangerRing", danger_mesh, Vector3(0.0, 0.054, 0.0), _danger_material)
	danger_ring.scale = Vector3(1.0, 0.55, 1.0)

	var rivet_root := Node3D.new()
	rivet_root.name = "BezelRivets"
	add_child(rivet_root)
	var rivet_mesh := SphereMesh.new()
	rivet_mesh.radius = 0.014
	rivet_mesh.height = 0.028
	rivet_mesh.radial_segments = 12
	rivet_mesh.rings = 6
	var rivet_mat := _pbr_material(COLOR_BRASS_CAP, 0.90, 0.22)
	for i in 8:
		var angle := float(i) * (TAU / 8.0) + (TAU / 16.0)
		var rivet := MeshInstance3D.new()
		rivet.name = "Rivet%d" % i
		rivet.mesh = rivet_mesh
		rivet.material_override = rivet_mat
		rivet.position = Vector3(cos(angle) * 0.51, 0.084, sin(angle) * 0.51)
		rivet.scale = Vector3(1.0, 0.5, 1.0)
		rivet_root.add_child(rivet)


func _build_dial_surface() -> void:
	_dial_viewport = SubViewport.new()
	_dial_viewport.name = "DialViewport"
	_dial_viewport.size = Vector2i(DIAL_RESOLUTION, DIAL_RESOLUTION)
	_dial_viewport.transparent_bg = true
	_dial_viewport.disable_3d = true
	_dial_viewport.gui_disable_input = true
	_dial_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_dial_viewport)

	_dial_canvas = _DialCanvas.new()
	_dial_canvas.name = "DialCanvas"
	_dial_canvas.size = Vector2(DIAL_RESOLUTION, DIAL_RESOLUTION)
	_dial_canvas.custom_minimum_size = Vector2(DIAL_RESOLUTION, DIAL_RESOLUTION)
	_dial_viewport.add_child(_dial_canvas)

	var dial_quad := QuadMesh.new()
	dial_quad.size = Vector2(DIAL_RADIUS * 2.0, DIAL_RADIUS * 2.0)
	var dial_mat := StandardMaterial3D.new()
	dial_mat.albedo_texture = _dial_viewport.get_texture()
	dial_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	dial_mat.alpha_scissor_threshold = 0.5
	dial_mat.roughness = 0.88
	dial_mat.metallic = 0.0
	dial_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var dial_face := _add_mesh("DialFace", dial_quad, Vector3(0.0, 0.048, 0.0), dial_mat)
	dial_face.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	dial_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_needle_and_cap() -> void:
	if _needle_pivot.get_node_or_null("NeedleBlade") == null:
		var needle := MeshInstance3D.new()
		needle.name = "NeedleBlade"
		needle.mesh = _create_needle_mesh()
		needle.material_override = _pbr_material(COLOR_BRASS_NEEDLE, 0.84, 0.24)
		needle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_needle_pivot.add_child(needle)

	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = 0.056
	collar_mesh.bottom_radius = 0.062
	collar_mesh.height = 0.016
	collar_mesh.radial_segments = 32
	var collar_mat := _pbr_material(COLOR_BRASS, 0.86, 0.28)
	var collar := _add_mesh("CenterCollar", collar_mesh, Vector3(0.0, 0.068, 0.0), collar_mat)
	collar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.044
	cap_mesh.height = 0.088
	cap_mesh.radial_segments = 32
	cap_mesh.rings = 16
	var cap_mat := _pbr_material(COLOR_BRASS_CAP, 0.90, 0.20)
	var cap := _add_mesh("CenterRivet", cap_mesh, Vector3(0.0, 0.077, 0.0), cap_mat)
	cap.scale = Vector3(1.0, 0.44, 1.0)
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _create_needle_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)

	var tip := Vector3(0.0, 0.002, -0.372)
	var sh_l := Vector3(-0.022, 0.001, -0.048)
	var sh_r := Vector3(0.022, 0.001, -0.048)
	var sh_top := Vector3(0.0, 0.013, -0.048)
	var hub_l := Vector3(-0.026, 0.001, 0.0)
	var hub_r := Vector3(0.026, 0.001, 0.0)
	var hub_top := Vector3(0.0, 0.014, 0.0)
	var tail_l := Vector3(-0.020, 0.001, 0.068)
	var tail_r := Vector3(0.020, 0.001, 0.068)
	var tail_top := Vector3(0.0, 0.011, 0.068)
	var tail_tip := Vector3(0.0, 0.002, 0.102)
	var hub_bot := Vector3(0.0, -0.003, 0.0)

	# Clockwise winding when viewed from outside (+Y up) for outward Godot normals.
	_tri(st, tip, sh_r, sh_top)
	_tri(st, tip, sh_top, sh_l)
	_quad(st, sh_top, sh_r, hub_r, hub_top)
	_quad(st, sh_l, sh_top, hub_top, hub_l)
	_quad(st, hub_top, hub_r, tail_r, tail_top)
	_quad(st, hub_l, hub_top, tail_top, tail_l)
	_tri(st, tail_top, tail_r, tail_tip)
	_tri(st, tail_l, tail_top, tail_tip)

	# Underside facets so the blade is a closed solid prism.
	_tri(st, tip, hub_bot, sh_r)
	_tri(st, tip, sh_l, hub_bot)
	_tri(st, sh_r, hub_bot, hub_r)
	_tri(st, sh_l, hub_l, hub_bot)
	_tri(st, hub_r, hub_bot, tail_r)
	_tri(st, hub_l, tail_l, hub_bot)
	_tri(st, tail_r, hub_bot, tail_tip)
	_tri(st, tail_l, tail_tip, hub_bot)

	st.generate_normals()
	return st.commit()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)


func _add_mesh(
	node_name: String,
	mesh_shape: Mesh,
	pos: Vector3,
	material: Material,
) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = node_name
	item.mesh = mesh_shape
	item.position = pos
	item.material_override = material
	add_child(item)
	return item


func _pbr_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


func _update_needle_rotation(should_animate: bool, value_changed: bool) -> void:
	if _needle_pivot == null:
		return
	# +Y rotation is CCW from above; pointer points -Z, so -logical_angle sweeps clockwise left->right.
	var target_y_deg := -get_pointer_angle_deg()
	if not should_animate:
		if _needle_tween != null and _needle_tween.is_valid():
			_needle_tween.kill()
		_needle_pivot.rotation_degrees.y = target_y_deg
		return
	if not value_changed:
		if _needle_tween != null and _needle_tween.is_valid():
			return
		if is_equal_approx(_needle_pivot.rotation_degrees.y, target_y_deg):
			return
	if _needle_tween != null and _needle_tween.is_valid():
		_needle_tween.kill()
	_needle_tween = create_tween()
	_needle_tween.set_trans(Tween.TRANS_BACK)
	_needle_tween.set_ease(Tween.EASE_OUT)
	_needle_tween.tween_property(
		_needle_pivot,
		"rotation_degrees:y",
		target_y_deg,
		NEEDLE_TWEEN_DURATION,
	)


func _reset_danger_if_safe() -> void:
	if _danger_material == null or is_danger():
		return
	_danger_pulse_time = 0.0
	_danger_material.emission_energy_multiplier = 0.0
	_danger_material.albedo_color = COLOR_DANGER_RING_IDLE


func _refresh_dial_face() -> void:
	if _dial_canvas == null or _dial_viewport == null:
		return
	var lang := _current_language()
	var lang_table: Dictionary = STAT_LABELS.get(lang, STAT_LABELS["en"])
	var emblem_label := str(lang_table.get(_stat_key, _stat_key.capitalize()))
	var accent: Color = STAT_ACCENT_COLORS.get(_stat_key, COLOR_BRASS)
	_dial_canvas.configure(_value, is_danger(), emblem_label, _load_icon(_stat_key), accent)
	_dial_canvas.queue_redraw()
	_dial_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _load_icon(key: String) -> Texture2D:
	if _icon_cache.has(key):
		return _icon_cache[key] as Texture2D
	var path := str(STAT_ICONS.get(key, STAT_ICONS["passion"]))
	var tex := load(path) as Texture2D
	_icon_cache[key] = tex
	return tex


func _current_language() -> String:
	var loc_node := _get_loc_node()
	if loc_node != null:
		var lang := str(loc_node.get("language"))
		if STAT_LABELS.has(lang):
			return lang
	return "zh"


func _get_loc_node() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Loc")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null("Loc")
	return null


func _connect_language_signal() -> void:
	var loc_node := _get_loc_node()
	if loc_node != null and loc_node.has_signal("language_changed"):
		if not loc_node.is_connected("language_changed", _on_language_changed):
			loc_node.connect("language_changed", _on_language_changed)


func _on_language_changed() -> void:
	_refresh_dial_face()


class _DialCanvas extends Control:
	const CENTER := Vector2(192.0, 192.0)
	const PLATE_RADIUS := 188.0
	const ARC_RADIUS := 148.0
	const C_BG_OUTER := Color("#140c1a")
	const C_BG_INNER := Color("#1f1429")
	const C_GOLD_RING := Color(0.75, 0.56, 0.30, 0.72)
	const C_GOLD_TICK := Color("#f0c46c")
	const C_GOLD_MINOR := Color(0.68, 0.52, 0.28, 0.85)
	const C_IVORY_SAFE := Color("#f0e3c6")
	const C_BRIDGE_AMBER := Color("#9e743b")
	const C_CRIMSON := Color("#db2736")
	const C_CRIMSON_BRIGHT := Color("#ff3b4a")
	const C_TEXT_SAFE := Color("#fff3d6")
	const C_TEXT_LABEL := Color("#edd9b2")
	const C_OUTLINE := Color(0.05, 0.02, 0.06, 0.96)

	var _draw_value: int = 4
	var _draw_danger: bool = false
	var _emblem_text: String = "戏魂"
	var _icon_texture: Texture2D
	var _accent_color: Color = Color("#e04850")
	var _font: Font

	func configure(
		value: int,
		danger: bool,
		emblem_text: String,
		icon_texture: Texture2D,
		accent_color: Color,
	) -> void:
		_draw_value = value
		_draw_danger = danger
		_emblem_text = emblem_text
		_icon_texture = icon_texture
		_accent_color = accent_color

	func _draw() -> void:
		if _font == null:
			_font = UiFonts.get_font()

		# Opaque circular enamel face tucked beneath the brass bezel lip.
		draw_circle(CENTER, PLATE_RADIUS, C_BG_OUTER)
		draw_circle(CENTER, 166.0, C_BG_INNER)
		draw_circle(CENTER, 122.0, Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.08))
		if _draw_danger:
			draw_arc(CENTER, 170.0, 0.0, TAU, 72, Color(0.88, 0.16, 0.22, 0.28), 8.0, true)

		draw_arc(CENTER, 176.0, 0.0, TAU, 72, C_GOLD_RING, 2.0, true)
		draw_arc(
			CENTER,
			126.0,
			_dial_rad(-125.0),
			_dial_rad(125.0),
			64,
			Color(0.54, 0.39, 0.21, 0.65),
			1.5,
			true,
		)

		_draw_scale_arcs()
		_draw_ticks_and_scale_numbers()
		_draw_emblem_icon()
		_draw_readout_and_label()

	func _draw_scale_arcs() -> void:
		draw_arc(
			CENTER,
			ARC_RADIUS,
			_dial_rad(-127.0),
			_dial_rad(127.0),
			64,
			Color(0.05, 0.03, 0.06, 0.90),
			18.0,
			true,
		)
		draw_arc(CENTER, ARC_RADIUS, _dial_rad(-125.0), _dial_rad(-100.0), 16, C_CRIMSON, 12.5, true)
		draw_arc(CENTER, ARC_RADIUS, _dial_rad(-100.0), _dial_rad(-75.0), 16, C_BRIDGE_AMBER, 10.5, true)
		draw_arc(CENTER, ARC_RADIUS, _dial_rad(-75.0), _dial_rad(75.0), 48, C_IVORY_SAFE, 11.0, true)
		draw_arc(CENTER, ARC_RADIUS, _dial_rad(75.0), _dial_rad(100.0), 16, C_BRIDGE_AMBER, 10.5, true)
		draw_arc(CENTER, ARC_RADIUS, _dial_rad(100.0), _dial_rad(125.0), 16, C_CRIMSON, 12.5, true)

		if _draw_danger:
			var low_end := _draw_value <= 1
			var glow_from := _dial_rad(-125.0) if low_end else _dial_rad(100.0)
			var glow_to := _dial_rad(-100.0) if low_end else _dial_rad(125.0)
			draw_arc(
				CENTER,
				ARC_RADIUS,
				glow_from,
				glow_to,
				18,
				Color(1.0, 0.25, 0.30, 0.38),
				20.0,
				true,
			)

	func _draw_ticks_and_scale_numbers() -> void:
		for i in 10:
			var mid_deg := -125.0 + (float(i) + 0.5) * 25.0
			var mid_rad := _dial_rad(mid_deg)
			var mid_dir := Vector2(cos(mid_rad), sin(mid_rad))
			var minor_color := C_CRIMSON if (i == 0 or i == 9) else C_GOLD_MINOR
			draw_line(CENTER + mid_dir * 139.0, CENTER + mid_dir * 156.0, minor_color, 2.0, true)

		for i in 11:
			var deg := -125.0 + float(i) * 25.0
			var rad := _dial_rad(deg)
			var dir := Vector2(cos(rad), sin(rad))
			var is_danger_tick := i <= 1 or i >= 9
			var tick_color := C_CRIMSON_BRIGHT if is_danger_tick else C_GOLD_TICK
			if i == 5:
				tick_color = Color("#ffe59e")
			var inner_r := 130.0 if (i == 0 or i == 5 or i == 10) else 133.0
			var width := 4.2 if (i == 0 or i == 5 or i == 10) else 3.2
			draw_line(CENTER + dir * inner_r, CENTER + dir * 162.0, tick_color, width, true)

		var marker_indices: Array[int] = [0, 1, 5, 9, 10]
		for idx in marker_indices:
			var deg := -125.0 + float(idx) * 25.0
			var rad := _dial_rad(deg)
			var pos := CENTER + Vector2(cos(rad), sin(rad)) * 116.0
			var num_color := C_CRIMSON_BRIGHT if (idx <= 1 or idx >= 9) else Color("#ffe59e")
			_draw_centered_text(pos, str(idx), 20, num_color, 40.0, 3)

	func _draw_emblem_icon() -> void:
		var icon_center := Vector2(192.0, 130.0)
		draw_circle(icon_center, 31.0, Color(0.08, 0.05, 0.10, 0.72))
		draw_arc(icon_center, 31.0, 0.0, TAU, 36, Color(0.82, 0.64, 0.34, 0.55), 1.6, true)
		if _icon_texture != null:
			var rect := Rect2(icon_center - Vector2(23.0, 23.0), Vector2(46.0, 46.0))
			draw_texture_rect(_icon_texture, rect, false)

	func _draw_readout_and_label() -> void:
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(0.32, 0.05, 0.08, 0.68) if _draw_danger else Color(0.07, 0.04, 0.09, 0.75)
		badge_style.border_color = Color(0.95, 0.25, 0.32, 0.90) if _draw_danger else Color(0.78, 0.58, 0.31, 0.56)
		badge_style.set_border_width_all(2)
		badge_style.set_corner_radius_all(14)
		draw_style_box(badge_style, Rect2(Vector2(140.0, 237.0), Vector2(104.0, 62.0)))

		var value_color := C_CRIMSON_BRIGHT if _draw_danger else C_TEXT_SAFE
		_draw_centered_text(Vector2(192.0, 268.0), str(_draw_value), 70, value_color, 108.0, 7, 2)

		var fitted_size := _fit_font_size(_emblem_text, 34, 176.0)
		_draw_centered_text(Vector2(192.0, 329.0), _emblem_text, fitted_size, C_TEXT_LABEL, 192.0, 5, 1)

	func _dial_rad(logical_deg: float) -> float:
		return deg_to_rad(-90.0 + logical_deg)

	func _fit_font_size(text: String, max_size: int, max_width: float) -> int:
		if _font == null or text.is_empty():
			return max_size
		var measured := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, max_size).x
		if measured <= max_width or measured <= 0.0:
			return max_size
		return maxi(16, int(floor(float(max_size) * (max_width / measured))))

	func _draw_centered_text(
		center_pos: Vector2,
		text: String,
		font_size: int,
		color: Color,
		box_width: float,
		outline_size: int,
		bold_stroke: int = 0,
	) -> void:
		if _font == null or text.is_empty():
			return
		var ascent := _font.get_ascent(font_size)
		var descent := _font.get_descent(font_size)
		var baseline_y := center_pos.y + (ascent - descent) * 0.5
		var draw_pos := Vector2(center_pos.x - box_width * 0.5, baseline_y)
		if outline_size > 0:
			draw_string_outline(
				_font,
				draw_pos,
				text,
				HORIZONTAL_ALIGNMENT_CENTER,
				box_width,
				font_size,
				outline_size,
				C_OUTLINE,
			)
		if bold_stroke > 0:
			draw_string_outline(
				_font,
				draw_pos,
				text,
				HORIZONTAL_ALIGNMENT_CENTER,
				box_width,
				font_size,
				bold_stroke,
				color,
			)
		draw_string(
			_font,
			draw_pos,
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			box_width,
			font_size,
			color,
		)
