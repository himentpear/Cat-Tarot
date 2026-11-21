extends Node

const TABLE_GLB_PATH := "res://assets/models/theatre/cat_tarot_table.glb"
const TABLE_SCENE_PATH := "res://scenes/tarot_table_3d.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const EXPECTED_GLB_MATERIALS: Array[String] = [
	"TableWalnutWood",
	"RearLedgeWood",
	"TableFelt",
	"SlotVelvet",
	"DeckWellWood",
	"AntiqueBrass",
	"BrassTassel",
	"SocketRecess",
	"HiddenDrawerWood",
]
const COMPANION_PBR_TEXTURES: Array[String] = [
	"res://assets/models/theatre/table_walnut_color.png",
	"res://assets/models/theatre/table_walnut_normal.png",
	"res://assets/models/theatre/table_runner_color.png",
	"res://assets/models/theatre/table_runner_embroidery.png",
]
const STAT_KEYS: Array[String] = ["passion", "intuition", "curiosity", "comfort"]

var table: TarotTable3D
var passed: int = 0
var failed: int = 0
var _drawer_events: Array[bool] = []


func _ready() -> void:
	await get_tree().process_frame
	_test_glb_materials()
	_test_companion_pbr_textures()
	await _test_main_uses_theatre_set()

	var table_packed := load(TABLE_SCENE_PATH) as PackedScene
	check(table_packed != null, "tarot_table_3d.tscn loads as PackedScene")
	if table_packed != null:
		table = table_packed.instantiate() as TarotTable3D
		check(table != null, "tarot_table_3d.tscn instantiates standalone as TarotTable3D")
		if table != null:
			add_child(table)
			await get_tree().process_frame
			await get_tree().process_frame

			_test_refined_table_materials()
			_test_marker_anchors()
			_test_standalone_table_props()
			await _test_elemental_gauges()
			await _test_hidden_drawer()
			table.queue_free()
			await get_tree().process_frame

	Audio.stop_music()
	TheatreSession.tracking = false
	print("TarotTable test results: %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _test_glb_materials() -> void:
	var packed := load(TABLE_GLB_PATH) as PackedScene
	check(packed != null, "cat_tarot_table.glb loads as PackedScene")
	if packed == null:
		return

	var instance := packed.instantiate()
	var found_materials: Dictionary = {}
	var distinct_colors: Array[Color] = []
	var textured_count: int = 0

	for child: Node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := child as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
		for surf_idx in mesh_inst.mesh.get_surface_count():
			var mat := mesh_inst.mesh.surface_get_material(surf_idx)
			if mat == null:
				continue
			var mat_name := mat.resource_name
			if mat_name != "":
				found_materials[mat_name] = mat
			if mat is BaseMaterial3D:
				var base_mat := mat as BaseMaterial3D
				if base_mat.albedo_texture != null:
					textured_count += 1
				var col := base_mat.albedo_color
				var is_new_color := true
				for existing in distinct_colors:
					if existing.is_equal_approx(col):
						is_new_color = false
						break
				if is_new_color:
					distinct_colors.append(col)

	instance.free()

	check(found_materials.size() >= EXPECTED_GLB_MATERIALS.size(), "cat_tarot_table.glb imports all 9 named materials")
	check(distinct_colors.size() >= 6, "cat_tarot_table.glb imports multiple distinct colored materials")
	check(textured_count >= 5, "cat_tarot_table.glb imports embedded PBR textures on wood and runner")
	for mat_name in EXPECTED_GLB_MATERIALS:
		check(found_materials.has(mat_name), "GLB includes material %s" % mat_name)


func _test_companion_pbr_textures() -> void:
	for tex_path in COMPANION_PBR_TEXTURES:
		check(ResourceLoader.exists(tex_path), "companion PBR texture exists: %s" % tex_path)
		var tex := load(tex_path) as Texture2D
		check(tex != null and tex.get_width() >= 1024 and tex.get_height() >= 1024, "companion PBR texture loads at >=1K: %s" % tex_path)


func _test_main_uses_theatre_set() -> void:
	TheatreSession.tracking = false
	TheatreSession.resume_requested = false
	TheatreSession.consume_enter_transition()
	var main_node := load(MAIN_SCENE_PATH).instantiate() as Node3D
	check(main_node != null, "main.tscn instantiates as Node3D")
	if main_node == null:
		return
	add_child(main_node)
	await get_tree().process_frame
	await get_tree().process_frame

	check(main_node.get_node_or_null("TarotTable") == null, "TarotTable is disabled in main.tscn")
	var theatre := main_node.get_node_or_null("TheatreSet")
	check(theatre != null and theatre is TheatreSet, "main.tscn uses TheatreSet instead of TarotTable")
	check(main_node.get("theatre_set") == theatre, "main.theatre_set points to TheatreSet")

	main_node.queue_free()
	await get_tree().process_frame


func _test_refined_table_materials() -> void:
	var overrides: Dictionary = {}
	for child: Node in table.table_model.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := child as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
		for surf_idx in mesh_inst.mesh.get_surface_count():
			var base_mat := mesh_inst.mesh.surface_get_material(surf_idx)
			if base_mat == null:
				continue
			var override_mat := mesh_inst.get_surface_override_material(surf_idx)
			if override_mat != null:
				overrides[base_mat.resource_name] = override_mat

	for mat_name in EXPECTED_GLB_MATERIALS:
		check(overrides.has(mat_name), "TarotTable3D refines runtime material for %s" % mat_name)

	var felt_mat := overrides.get("TableFelt") as ShaderMaterial
	check(felt_mat != null, "TableFelt uses ShaderMaterial")
	if felt_mat != null:
		check(bool(felt_mat.get_shader_parameter("use_albedo_tex")), "TableFelt enables runner albedo texture")
		check(bool(felt_mat.get_shader_parameter("use_embroidery_mask")), "TableFelt enables embroidery mask")

	var slot_mat := overrides.get("SlotVelvet") as ShaderMaterial
	check(slot_mat != null, "SlotVelvet uses ShaderMaterial")

	for wood_name in ["TableWalnutWood", "DeckWellWood"]:
		var wood_mat := overrides.get(wood_name) as StandardMaterial3D
		check(wood_mat != null and wood_mat.albedo_texture != null and wood_mat.normal_texture != null, "%s binds walnut PBR textures" % wood_name)


func _test_marker_anchors() -> void:
	var rear_ledge := table.get_node_or_null("Anchors/RearLedge")
	check(rear_ledge is Marker3D, "Anchors/RearLedge is a genuine Marker3D")
	check(table.get_rear_ledge_marker() == rear_ledge, "get_rear_ledge_marker returns RearLedge")

	for i in 3:
		var slot := table.get_node_or_null("Anchors/TarotSlots/TarotSlot%d" % i)
		check(slot is Marker3D, "Anchors/TarotSlots/TarotSlot%d is a genuine Marker3D" % i)
		check(table.get_tarot_slot_marker(i) == slot, "get_tarot_slot_marker(%d) matches" % i)

	var deck_well := table.get_node_or_null("Anchors/DeckWell")
	check(deck_well is Marker3D, "Anchors/DeckWell is a genuine Marker3D")
	check(table.get_deck_well_marker() == deck_well, "get_deck_well_marker returns DeckWell")

	var right_ws := table.get_node_or_null("Anchors/RightWorkspace")
	check(right_ws is Marker3D, "Anchors/RightWorkspace is a genuine Marker3D")
	check(table.get_right_workspace_marker() == right_ws, "get_right_workspace_marker returns RightWorkspace")
	for child_name in ["DimmerAnchor", "BellAnchor", "DiceAnchor"]:
		var sub_anchor := table.get_node_or_null("Anchors/RightWorkspace/%s" % child_name)
		check(sub_anchor is Marker3D, "RightWorkspace/%s is a genuine Marker3D" % child_name)

	for i in 4:
		var socket := table.get_node_or_null("Anchors/ElementalSockets/ElementalSocket%d" % i)
		check(socket is Marker3D, "Anchors/ElementalSockets/ElementalSocket%d is a genuine Marker3D" % i)
		check(table.get_elemental_socket_marker(i) == socket, "get_elemental_socket_marker(%d) matches" % i)

	var hidden_drawer := table.get_node_or_null("Anchors/HiddenDrawer")
	check(hidden_drawer is Marker3D, "Anchors/HiddenDrawer is a genuine Marker3D")
	check(table.get_hidden_drawer_marker() == hidden_drawer, "get_hidden_drawer_marker returns HiddenDrawer")


func _test_standalone_table_props() -> void:
	var rear_ledge := table.get_rear_ledge_marker()
	var mini_theatre := rear_ledge.get_node_or_null("MiniatureTheatre") as Node3D if rear_ledge != null else null
	check(mini_theatre != null, "MiniatureTheatre is mounted on RearLedge")
	if mini_theatre != null:
		var cat_anchor := mini_theatre.find_child("CatAnchor", true, false)
		check(cat_anchor != null and cat_anchor.get_child_count() >= 1, "MiniatureTheatre has CatAnchor with cat prop")
		var meshes := mini_theatre.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() > 0, "MiniatureTheatre contains rendered meshes")

	check(table.get_deck_well_position().x < -4.0, "DeckWell sits on left side of table")
	check(table.get_dice_anchor_position().x > 4.0, "DiceAnchor sits in RightWorkspace")
	check(table.get_restart_anchor_position().x > 4.0, "BellAnchor sits in RightWorkspace")
	check_approx(table.get_tarot_slot_position(1).x, 0.0, 0.02, "TarotSlot1 is centered on X")
	check_approx(
		table.get_tarot_slot_position(2).x - table.get_tarot_slot_position(0).x,
		3.90,
		0.05,
		"TarotSlots span 3.90 units across X"
	)


func _test_elemental_gauges() -> void:
	for i in 4:
		var socket := table.get_elemental_socket_marker(i)
		var key := STAT_KEYS[i]
		var gauge := table.get_elemental_gauge(key)
		check(gauge != null, "ElementalGauge3D exists for %s" % key)
		if gauge != null and socket != null:
			check(gauge.get_parent() == socket, "ElementalGauge3D for %s is mounted on ElementalSocket%d" % [key, i])
			check(gauge.get_value() == 4, "initial gauge %s reads 4" % key)
			check(not gauge.is_danger(), "initial gauge %s is not in danger" % key)

	table.sync_stats({"passion": 1, "intuition": 9, "curiosity": 2, "comfort": 8}, true)
	await get_tree().create_timer(0.55).timeout

	var g_passion := table.get_elemental_gauge("passion")
	var g_intuition := table.get_elemental_gauge("intuition")
	var g_curiosity := table.get_elemental_gauge("curiosity")
	var g_comfort := table.get_elemental_gauge("comfort")

	check_eq(g_passion.get_value(), 1, "passion gauge updates to 1")
	check_eq(g_intuition.get_value(), 9, "intuition gauge updates to 9")
	check_eq(g_curiosity.get_value(), 2, "curiosity gauge updates to 2")
	check_eq(g_comfort.get_value(), 8, "comfort gauge updates to 8")

	check(g_passion.is_danger(), "gauge enters danger state at value 1")
	check(g_intuition.is_danger(), "gauge enters danger state at value 9")
	check(not g_curiosity.is_danger(), "gauge stays safe at value 2")
	check(not g_comfort.is_danger(), "gauge stays safe at value 8")

	await get_tree().process_frame
	var passion_ring := g_passion.get_node_or_null("DangerRing") as MeshInstance3D
	var passion_mat := passion_ring.material_override as StandardMaterial3D if passion_ring != null else null
	check(passion_mat != null and passion_mat.emission_energy_multiplier > 0.0, "danger ring pulses emission at 1")

	var intuition_ring := g_intuition.get_node_or_null("DangerRing") as MeshInstance3D
	var intuition_mat := intuition_ring.material_override as StandardMaterial3D if intuition_ring != null else null
	check(intuition_mat != null and intuition_mat.emission_energy_multiplier > 0.0, "danger ring pulses emission at 9")

	for pair in [
		[g_passion, -100.0, "passion=1"],
		[g_intuition, 100.0, "intuition=9"],
		[g_curiosity, -75.0, "curiosity=2"],
		[g_comfort, 75.0, "comfort=8"],
	]:
		var g := pair[0] as ElementalGauge3D
		var expected_angle := float(pair[1])
		var tag := str(pair[2])
		var needle := g.get_node_or_null("NeedlePivot") as Node3D
		check_approx(g.get_pointer_angle_deg(), expected_angle, 0.5, "logical angle for %s" % tag)
		check(needle != null, "NeedlePivot exists on %s" % tag)
		if needle != null:
			check_approx(needle.rotation_degrees.y, -expected_angle, 1.5, "needle Y rotation for %s" % tag)

	table.sync_stats({"passion": 0, "intuition": 10, "curiosity": 5, "comfort": 4}, true)
	await get_tree().create_timer(0.55).timeout
	check(g_passion.is_danger() and g_intuition.is_danger(), "gauges stay in danger at 0 and 10")
	check(not g_curiosity.is_danger() and not g_comfort.is_danger(), "gauges exit danger at 5 and 4")
	check_approx(
		(g_passion.get_node("NeedlePivot") as Node3D).rotation_degrees.y,
		125.0,
		1.5,
		"needle rotates to +125 deg at value 0"
	)
	check_approx(
		(g_intuition.get_node("NeedlePivot") as Node3D).rotation_degrees.y,
		-125.0,
		1.5,
		"needle rotates to -125 deg at value 10"
	)
	check_approx(
		(g_curiosity.get_node("NeedlePivot") as Node3D).rotation_degrees.y,
		0.0,
		1.5,
		"needle centers at 0 deg at value 5"
	)

	table.sync_stats({"passion": 4, "intuition": 4, "curiosity": 4, "comfort": 4}, true)
	await get_tree().create_timer(0.55).timeout


func _test_hidden_drawer() -> void:
	_drawer_events.clear()
	table.drawer_toggled.connect(_on_drawer_toggled)

	var drawer_marker := table.get_hidden_drawer_marker()
	var drawer_body := drawer_marker.get_node_or_null("DrawerBody") as Node3D if drawer_marker != null else null
	check(drawer_body != null, "HiddenDrawer/DrawerBody exists")
	check(not table.is_drawer_open(), "HiddenDrawer starts closed")
	if drawer_body != null:
		check_approx(drawer_body.position.z, TarotTable3D.DRAWER_CLOSED_Z, 0.02, "DrawerBody starts at closed Z")

	table.toggle_drawer()
	check(table.is_drawer_open(), "toggle_drawer() marks HiddenDrawer open")
	check(_drawer_events.size() == 1 and _drawer_events[0] == true, "drawer_toggled(true) emitted on open")
	await get_tree().create_timer(0.55).timeout
	if drawer_body != null:
		check_approx(drawer_body.position.z, TarotTable3D.DRAWER_OPEN_Z, 0.02, "DrawerBody slides to open Z")

	table.toggle_drawer()
	check(not table.is_drawer_open(), "toggle_drawer() marks HiddenDrawer closed")
	check(_drawer_events.size() == 2 and _drawer_events[1] == false, "drawer_toggled(false) emitted on close")
	await get_tree().create_timer(0.55).timeout
	if drawer_body != null:
		check_approx(drawer_body.position.z, TarotTable3D.DRAWER_CLOSED_Z, 0.02, "DrawerBody slides back to closed Z")

	table.set_drawer_open(true, false)
	check(table.is_drawer_open(), "set_drawer_open(true, false) opens immediately")
	if drawer_body != null:
		check_approx(drawer_body.position.z, TarotTable3D.DRAWER_OPEN_Z, 0.02, "DrawerBody snaps to open Z")
	table.set_drawer_open(false, false)
	check(not table.is_drawer_open(), "set_drawer_open(false, false) closes immediately")
	if drawer_body != null:
		check_approx(drawer_body.position.z, TarotTable3D.DRAWER_CLOSED_Z, 0.02, "DrawerBody snaps to closed Z")

	table.drawer_toggled.disconnect(_on_drawer_toggled)


func _on_drawer_toggled(open: bool) -> void:
	_drawer_events.append(open)


func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL " + label)


func check_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		passed += 1
		return
	failed += 1
	push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])


func check_approx(actual: float, expected: float, tolerance: float, label: String) -> void:
	if absf(actual - expected) <= tolerance:
		passed += 1
		return
	failed += 1
	push_error("FAIL %s: expected %.3f +- %.3f, got %.3f" % [label, expected, tolerance, actual])
