class_name TarotTable3D
extends Node3D
## Painted 3D Victorian cat tarot table with normalized play-zone anchors,
## corner elemental clockwork gauges, rear miniature theatre, and hidden drawer.

signal drawer_toggled(open: bool)

const TABLE_SCALE := 13.61
const TABLE_OFFSET := Vector3(0.133, -3.9374, 0.0)
const MINI_THEATRE_SCALE := 0.74
const DRAWER_CLOSED_Z := -0.16
const DRAWER_OPEN_Z := 0.82
const DRAWER_TWEEN_TIME := 0.42

const STAT_SOCKET_ORDER: Array[String] = ["passion", "intuition", "curiosity", "comfort"]

const THEATRE_FINISH_SHADER := preload("res://shaders/theatre_finish.gdshader")
const TABLE_VELVET_SHADER := preload("res://shaders/table_velvet.gdshader")
const THEATRE_VELVET_SHADER := preload("res://shaders/theatre_velvet.gdshader")
const WALNUT_COLOR_TEX := preload("res://assets/models/theatre/table_walnut_color.png")
const WALNUT_NORMAL_TEX := preload("res://assets/models/theatre/table_walnut_normal.png")
const RUNNER_COLOR_TEX := preload("res://assets/models/theatre/table_runner_color.png")
const RUNNER_EMBROIDERY_TEX := preload("res://assets/models/theatre/table_runner_embroidery.png")
const PLAYHOUSE_SCENE := preload("res://assets/models/theatre/playhouse.glb")
const CAT_PLACEHOLDER_SCENE := preload("res://scenes/cat_placeholder.tscn")
const TICKET_SCENE := preload("res://assets/models/theatre/ticket.glb")
const GAUGE_SCENE := preload("res://scenes/elemental_gauge_3d.tscn")

@export var show_miniature_theatre: bool = true

@onready var table_model: Node3D = $TableModel
@onready var rear_ledge_marker: Marker3D = $Anchors/RearLedge
@onready var deck_well_marker: Marker3D = $Anchors/DeckWell
@onready var right_workspace_marker: Marker3D = $Anchors/RightWorkspace
@onready var dimmer_anchor: Marker3D = $Anchors/RightWorkspace/DimmerAnchor
@onready var bell_anchor: Marker3D = $Anchors/RightWorkspace/BellAnchor
@onready var dice_anchor: Marker3D = $Anchors/RightWorkspace/DiceAnchor
@onready var hidden_drawer_marker: Marker3D = $Anchors/HiddenDrawer

var _slot_markers: Array[Marker3D] = []
var _socket_markers: Array[Marker3D] = []
var _gauges: Dictionary = {}
var _miniature_theatre: Node3D = null
var _drawer_body: Node3D = null
var _drawer_area: Area3D = null
var _drawer_open: bool = false
var _drawer_tween: Tween = null
var _letter_font: SystemFont = null


func _ready() -> void:
	_letter_font = SystemFont.new()
	_letter_font.font_names = PackedStringArray(["Georgia", "Liberation Serif", "DejaVu Serif", "serif"])
	_letter_font.font_weight = 700

	_cache_markers()
	_refine_table_materials()
	_setup_elemental_gauges()
	if show_miniature_theatre:
		_mount_miniature_theatre()
	_build_hidden_drawer()


func _cache_markers() -> void:
	_slot_markers = [
		$Anchors/TarotSlots/TarotSlot0 as Marker3D,
		$Anchors/TarotSlots/TarotSlot1 as Marker3D,
		$Anchors/TarotSlots/TarotSlot2 as Marker3D,
	]
	_socket_markers = [
		$Anchors/ElementalSockets/ElementalSocket0 as Marker3D,
		$Anchors/ElementalSockets/ElementalSocket1 as Marker3D,
		$Anchors/ElementalSockets/ElementalSocket2 as Marker3D,
		$Anchors/ElementalSockets/ElementalSocket3 as Marker3D,
	]


func _refine_table_materials() -> void:
	if table_model == null:
		return

	var walnut_mat := _make_walnut_pbr(Color.WHITE)
	var rear_ledge_mat := _make_walnut_pbr(Color.WHITE)
	var drawer_wood_mat := _make_walnut_pbr(Color(0.88, 0.86, 0.84, 1.0))
	var deck_well_wood_mat := _make_walnut_pbr(Color(0.88, 0.86, 0.84, 1.0))

	var table_felt_mat := _make_runner_velvet_material()
	var slot_velvet_mat := _make_velvet_material(Color("#331552"), 1.25, 0.30)
	var deck_velvet_mat := _make_velvet_material(Color("#311245"), 1.30, 0.24)

	var antique_brass_mat := _make_ao_pbr_material(Color("#b59551"), 0.82, 0.34)
	var brass_tassel_mat := _make_ao_pbr_material(Color("#a48645"), 0.35, 0.62)
	var socket_recess_mat := _make_ao_pbr_material(Color("#1b1513"), 0.50, 0.55)

	var material_by_name := {
		"TableWalnutWood": walnut_mat,
		"RearLedgeWood": rear_ledge_mat,
		"HiddenDrawerWood": drawer_wood_mat,
		"DeckWellWood": deck_well_wood_mat,
		"TableFelt": table_felt_mat,
		"SlotVelvet": slot_velvet_mat,
		"DeckWellVelvet": deck_velvet_mat,
		"AntiqueBrass": antique_brass_mat,
		"BrassTassel": brass_tassel_mat,
		"SocketRecess": socket_recess_mat,
	}

	for child: Node in table_model.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := child as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var surface_count := mesh_inst.mesh.get_surface_count()
		for surf_idx in surface_count:
			var original := mesh_inst.get_active_material(surf_idx)
			if original == null:
				original = mesh_inst.mesh.surface_get_material(surf_idx)
			var mat_name := original.resource_name if original != null else ""
			if material_by_name.has(mat_name):
				mesh_inst.set_surface_override_material(surf_idx, material_by_name[mat_name] as Material)


func _make_walnut_pbr(tint: Color, triplanar: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.albedo_texture = WALNUT_COLOR_TEX
	mat.normal_enabled = true
	mat.normal_texture = WALNUT_NORMAL_TEX
	mat.normal_scale = 0.85
	mat.roughness = 0.72
	mat.metallic = 0.0
	mat.vertex_color_use_as_albedo = not triplanar
	if triplanar:
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.45, 0.45, 0.45)
	return mat


func _make_runner_velvet_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TABLE_VELVET_SHADER
	mat.set_shader_parameter("tint", Color(0.92, 0.90, 0.96, 1.0))
	mat.set_shader_parameter("use_albedo_tex", true)
	mat.set_shader_parameter("albedo_tex", RUNNER_COLOR_TEX)
	mat.set_shader_parameter("use_embroidery_mask", true)
	mat.set_shader_parameter("embroidery_mask", RUNNER_EMBROIDERY_TEX)
	mat.set_shader_parameter("nap_scale", 1.0)
	mat.set_shader_parameter("sheen_strength", 0.28)
	return mat


func _make_finish_material(tint: Color, fabric: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = THEATRE_FINISH_SHADER
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("fabric", fabric)
	return mat


func _make_velvet_material(tint: Color, nap_scale: float, sheen_strength: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TABLE_VELVET_SHADER
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("use_albedo_tex", false)
	mat.set_shader_parameter("use_embroidery_mask", false)
	mat.set_shader_parameter("nap_scale", nap_scale)
	mat.set_shader_parameter("sheen_strength", sheen_strength)
	return mat


func _make_ao_pbr_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	mat.vertex_color_use_as_albedo = true
	return mat


func _setup_elemental_gauges() -> void:
	_gauges.clear()
	for i in mini(_socket_markers.size(), STAT_SOCKET_ORDER.size()):
		var socket := _socket_markers[i]
		var stat_key := STAT_SOCKET_ORDER[i]
		var gauge := _find_child_gauge(socket)
		if gauge == null:
			gauge = GAUGE_SCENE.instantiate() as ElementalGauge3D
			gauge.name = "ElementalGauge%d" % i
			gauge.position = Vector3(0.0, 0.012, 0.0)
			socket.add_child(gauge)
		gauge.setup(stat_key, 4)
		_gauges[stat_key] = gauge


func _find_child_gauge(socket: Node) -> ElementalGauge3D:
	if socket == null:
		return null
	for child: Node in socket.get_children():
		if child is ElementalGauge3D:
			return child as ElementalGauge3D
	return null


func _mount_miniature_theatre() -> void:
	if rear_ledge_marker == null:
		return
	var existing := rear_ledge_marker.get_node_or_null("MiniatureTheatre")
	if existing != null:
		existing.queue_free()

	var stage := PLAYHOUSE_SCENE.instantiate() as Node3D
	stage.name = "MiniatureTheatre"
	stage.position = Vector3(0.0, 0.0, -0.02)
	stage.scale = Vector3.ONE * MINI_THEATRE_SCALE
	rear_ledge_marker.add_child(stage)
	_miniature_theatre = stage

	var timber := _make_finish_material(Color("#4e3a2c"), false)
	for part: Node in stage.find_children("*", "MeshInstance3D", true, false):
		var surface := part as MeshInstance3D
		if surface == null:
			continue
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var original := surface.get_active_material(0)
		if original != null and "walnut" in original.resource_name.to_lower():
			surface.material_override = timber

	var curtain_mat := ShaderMaterial.new()
	curtain_mat.shader = THEATRE_VELVET_SHADER
	curtain_mat.set_shader_parameter("dye", Color("#580818"))
	curtain_mat.set_shader_parameter("sway", 0.004)
	for key in ["CurtainLeft", "CurtainRight"]:
		var panel := stage.find_child(key, true, false) as MeshInstance3D
		if panel != null:
			panel.material_override = curtain_mat
			panel.scale.x = 0.16

	_add_marquee_letter(stage, "THE 22 ACTS OF THE", Vector3(0.0, 4.055, 0.343), Vector2(2.53, 0.245), Color("#ffda87"))
	_add_marquee_letter(stage, "BLACK CAT", Vector3(0.0, 3.72, 0.343), Vector2(2.96, 0.50), Color("#ffe5a2"))

	var cat_anchor := stage.find_child("CatAnchor", true, false) as Node3D
	if cat_anchor == null:
		cat_anchor = Node3D.new()
		cat_anchor.name = "CatAnchor"
		cat_anchor.position = Vector3(1.70, 0.93, 0.96)
		stage.add_child(cat_anchor)
	if cat_anchor.get_child_count() == 0:
		cat_anchor.add_child(CAT_PLACEHOLDER_SCENE.instantiate())

	var stage_light := OmniLight3D.new()
	stage_light.name = "MiniatureStageFootlight"
	stage_light.position = Vector3(0.0, 1.55, 0.72)
	stage_light.light_color = Color("#ffcf87")
	stage_light.light_energy = 1.6
	stage_light.omni_range = 4.6
	stage_light.shadow_enabled = false
	stage.add_child(stage_light)

	var balcony_light := OmniLight3D.new()
	balcony_light.name = "MiniatureFootlightGlow"
	balcony_light.position = Vector3(0.0, 0.52, 1.05)
	balcony_light.light_color = Color("#ffba63")
	balcony_light.light_energy = 0.85
	balcony_light.omni_range = 3.4
	balcony_light.shadow_enabled = false
	stage.add_child(balcony_light)


func _add_marquee_letter(
	parent: Node3D,
	words: String,
	at: Vector3,
	size: Vector2,
	color: Color,
	angles: Vector3 = Vector3.ZERO,
) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(720, maxi(54, roundi(720.0 * size.y / size.x)))
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	parent.add_child(vp)

	var label := Label.new()
	label.size = Vector2(vp.size)
	label.text = words
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _letter_font)
	var str_w := _letter_font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x
	var fit := minf(vp.size.y * 0.82, vp.size.x * 100.0 / maxf(1.0, str_w) * 0.96)
	label.add_theme_font_size_override("font_size", maxi(12, int(fit)))
	label.add_theme_color_override("font_color", color)
	vp.add_child(label)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = vp.get_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = size
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = quad
	mesh_inst.material_override = mat
	mesh_inst.position = at
	mesh_inst.rotation_degrees = angles
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_inst)


func _build_hidden_drawer() -> void:
	if hidden_drawer_marker == null:
		return
	var existing := hidden_drawer_marker.get_node_or_null("DrawerBody")
	if existing != null:
		existing.queue_free()

	_drawer_body = Node3D.new()
	_drawer_body.name = "DrawerBody"
	_drawer_body.position = Vector3(0.0, 0.0, DRAWER_CLOSED_Z)
	hidden_drawer_marker.add_child(_drawer_body)

	var walnut_drawer := _make_walnut_pbr(Color(0.88, 0.86, 0.84, 1.0), true)
	var trim_brass := _make_pbr(Color("#b59551"), 0.82, 0.34)
	var velvet_lining := _make_velvet_material(Color("#341552"), 1.4, 0.28)

	# Drawer box walls (kept strictly below y_local = +0.01 so it clears the cat head relief above).
	_add_box(_drawer_body, "DrawerFloor", Vector3(0.0, -0.25, -0.45), Vector3(2.08, 0.035, 1.06), walnut_drawer)
	_add_box(_drawer_body, "DrawerBackWall", Vector3(0.0, -0.145, -0.955), Vector3(2.08, 0.22, 0.05), walnut_drawer)
	_add_box(_drawer_body, "DrawerLeftWall", Vector3(-1.015, -0.145, -0.45), Vector3(0.05, 0.22, 1.06), walnut_drawer)
	_add_box(_drawer_body, "DrawerRightWall", Vector3(1.015, -0.145, -0.45), Vector3(0.05, 0.22, 1.06), walnut_drawer)
	_add_box(_drawer_body, "DrawerFrontPanel", Vector3(0.0, -0.135, 0.075), Vector3(2.16, 0.26, 0.06), walnut_drawer)
	_add_box(_drawer_body, "DrawerFrontTrim", Vector3(0.0, -0.01, 0.085), Vector3(2.18, 0.025, 0.065), trim_brass)
	_add_box(_drawer_body, "DrawerVelvetLiner", Vector3(0.0, -0.222, -0.45), Vector3(1.94, 0.022, 0.94), velvet_lining)

	# Miniature brass cat-ring pull handle on front panel.
	var pull_root := Node3D.new()
	pull_root.name = "DrawerPullHandle"
	pull_root.position = Vector3(0.0, -0.135, 0.115)
	_drawer_body.add_child(pull_root)

	var escutcheon_mesh := CylinderMesh.new()
	escutcheon_mesh.top_radius = 0.095
	escutcheon_mesh.bottom_radius = 0.105
	escutcheon_mesh.height = 0.022
	escutcheon_mesh.radial_segments = 24
	var escutcheon := MeshInstance3D.new()
	escutcheon.name = "PullPlate"
	escutcheon.mesh = escutcheon_mesh
	escutcheon.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	escutcheon.material_override = trim_brass
	pull_root.add_child(escutcheon)

	for side in [-1.0, 1.0]:
		var ear := _add_box(pull_root, "PullEar", Vector3(side * 0.055, 0.075, 0.0), Vector3(0.045, 0.055, 0.02), trim_brass)
		ear.rotation_degrees = Vector3(0.0, 0.0, -side * 20.0)

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.058
	ring_mesh.outer_radius = 0.082
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 12
	var pull_ring := MeshInstance3D.new()
	pull_ring.name = "PullRing"
	pull_ring.mesh = ring_mesh
	pull_ring.position = Vector3(0.0, -0.055, 0.025)
	pull_ring.rotation_degrees = Vector3(78.0, 0.0, 0.0)
	pull_ring.material_override = trim_brass
	pull_root.add_child(pull_ring)

	# Velvet-lined compartment prop 1: miniature admission ticket stub.
	var ticket_stub := TICKET_SCENE.instantiate() as Node3D
	ticket_stub.name = "DrawerTicketStub"
	ticket_stub.position = Vector3(-0.42, -0.195, -0.40)
	ticket_stub.rotation_degrees = Vector3(-90.0, 14.0, 0.0)
	ticket_stub.scale = Vector3.ONE * 0.68
	_drawer_body.add_child(ticket_stub)

	# Velvet-lined compartment prop 2: sculpted brass catnip emblem.
	var emblem := Node3D.new()
	emblem.name = "BrassCatnipEmblem"
	emblem.position = Vector3(0.45, -0.195, -0.38)
	_drawer_body.add_child(emblem)

	var coin_mesh := CylinderMesh.new()
	coin_mesh.top_radius = 0.19
	coin_mesh.bottom_radius = 0.20
	coin_mesh.height = 0.024
	coin_mesh.radial_segments = 32
	var coin := MeshInstance3D.new()
	coin.name = "EmblemBase"
	coin.mesh = coin_mesh
	coin.material_override = trim_brass
	emblem.add_child(coin)

	var leaf_mat := _make_pbr(Color("#c4a35d"), 0.84, 0.28)
	for leaf_cfg in [
		[Vector3(0.0, 0.018, -0.03), 0.0, Vector3(0.055, 0.014, 0.13)],
		[Vector3(-0.055, 0.018, 0.01), 36.0, Vector3(0.048, 0.014, 0.105)],
		[Vector3(0.055, 0.018, 0.01), -36.0, Vector3(0.048, 0.014, 0.105)],
	]:
		var leaf := _add_box(emblem, "CatnipLeaf", leaf_cfg[0] as Vector3, leaf_cfg[2] as Vector3, leaf_mat)
		leaf.rotation_degrees.y = float(leaf_cfg[1])

	_drawer_area = Area3D.new()
	_drawer_area.name = "DrawerClickArea"
	_drawer_area.input_ray_pickable = true
	_drawer_body.add_child(_drawer_area)

	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(2.22, 0.34, 1.24)
	col.shape = box_shape
	col.position = Vector3(0.0, -0.14, -0.38)
	_drawer_area.add_child(col)
	_drawer_area.input_event.connect(_on_drawer_area_input)


func _add_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.position = pos
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh_inst)
	return mesh_inst


func _make_pbr(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


func _on_drawer_area_input(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int,
) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			toggle_drawer()


## Opens or closes the hidden front apron drawer.
func set_drawer_open(open: bool, animate: bool = true) -> void:
	var changed := _drawer_open != open
	_drawer_open = open
	if _drawer_body != null:
		var target_z := DRAWER_OPEN_Z if open else DRAWER_CLOSED_Z
		if _drawer_tween != null and _drawer_tween.is_valid():
			_drawer_tween.kill()
		if animate and is_inside_tree():
			_drawer_tween = create_tween()
			_drawer_tween.set_trans(Tween.TRANS_CUBIC)
			_drawer_tween.set_ease(Tween.EASE_OUT)
			_drawer_tween.tween_property(_drawer_body, "position:z", target_z, DRAWER_TWEEN_TIME)
		else:
			_drawer_body.position.z = target_z
	if changed:
		drawer_toggled.emit(_drawer_open)


## Toggles the hidden drawer between open and closed states.
func toggle_drawer() -> void:
	set_drawer_open(not _drawer_open, true)


## Returns true if the hidden drawer is currently open.
func is_drawer_open() -> bool:
	return _drawer_open


## Synchronizes all four corner elemental gauges from a stats dictionary.
func sync_stats(stats: Dictionary, animate: bool = true) -> void:
	for stat_key: String in STAT_SOCKET_ORDER:
		if not stats.has(stat_key):
			continue
		var gauge := get_elemental_gauge(stat_key)
		if gauge != null:
			gauge.set_value(int(stats[stat_key]), animate)


## Returns the mounted ElementalGauge3D for a stat key ("passion", "intuition", "curiosity", "comfort").
func get_elemental_gauge(stat_key: String) -> ElementalGauge3D:
	var normalized := stat_key.strip_edges().to_lower()
	return _gauges.get(normalized, null) as ElementalGauge3D


func get_rear_ledge_marker() -> Marker3D:
	return rear_ledge_marker if rear_ledge_marker != null else get_node_or_null("Anchors/RearLedge") as Marker3D


func get_tarot_slot_marker(index: int) -> Marker3D:
	if index < 0 or index > 2:
		return null
	if _slot_markers.size() == 3:
		return _slot_markers[index]
	return get_node_or_null("Anchors/TarotSlots/TarotSlot%d" % index) as Marker3D


func get_tarot_slot_position(index: int) -> Vector3:
	var marker := get_tarot_slot_marker(index)
	return _marker_world_position(marker)


func get_deck_well_marker() -> Marker3D:
	return deck_well_marker if deck_well_marker != null else get_node_or_null("Anchors/DeckWell") as Marker3D


func get_deck_well_position() -> Vector3:
	return _marker_world_position(get_deck_well_marker())


func get_right_workspace_marker() -> Marker3D:
	return right_workspace_marker if right_workspace_marker != null else get_node_or_null("Anchors/RightWorkspace") as Marker3D


func get_dice_anchor_position() -> Vector3:
	var marker := dice_anchor if dice_anchor != null else get_node_or_null("Anchors/RightWorkspace/DiceAnchor") as Marker3D
	return _marker_world_position(marker)


func get_restart_anchor_position() -> Vector3:
	var marker := bell_anchor if bell_anchor != null else get_node_or_null("Anchors/RightWorkspace/BellAnchor") as Marker3D
	return _marker_world_position(marker)


func get_elemental_socket_marker(index: int) -> Marker3D:
	if index < 0 or index > 3:
		return null
	if _socket_markers.size() == 4:
		return _socket_markers[index]
	return get_node_or_null("Anchors/ElementalSockets/ElementalSocket%d" % index) as Marker3D


func get_hidden_drawer_marker() -> Marker3D:
	return hidden_drawer_marker if hidden_drawer_marker != null else get_node_or_null("Anchors/HiddenDrawer") as Marker3D


func _marker_world_position(marker: Marker3D) -> Vector3:
	if marker == null:
		return Vector3.ZERO
	if marker.is_inside_tree():
		return marker.global_position
	var pos := marker.position
	var current: Node = marker.get_parent()
	while current is Node3D and current != self:
		pos = (current as Node3D).transform * pos
		current = current.get_parent()
	if current == self:
		pos = transform * pos
	return pos
