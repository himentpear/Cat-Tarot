class_name TheatreSet
extends Node3D

const GALLERY := 0
const START := 1
const CONTINUE := 2
const SETTINGS := 3
const QUIT := 4
const MODELS := "res://assets/models/theatre/"
const CurtainCloth := preload("res://scripts/curtain_cloth.gd")
const GalleryCardDisplay := preload("res://scripts/gallery_card_display.gd")
const FOIL := preload("res://shaders/theatre_foil.gdshader")
const BEAM := preload("res://shaders/theatre_beam.gdshader")
const FINISH := preload("res://shaders/theatre_finish.gdshader")
const DECK_SCENE := preload("res://scenes/deck_3d.tscn")
const FADER_TRAVEL := 0.194
const CURTAIN_SETTLE_TIME := 0.48
const GALLERY_LID_OPEN_X := -108.0
const GALLERY_LID_CLOSED_X := 0.0
const GALLERY_DECK_REST := Vector3(0.0, -0.02, 0.06)
const GALLERY_DECK_RISE := 0.09
const GALLERY_RETIRE_POS := Vector3(-9.2, 0.51, 0.55)
const GALLERY_RETIRE_ROT := Vector3(0.0, 26.0, 0.0)
const LOOSE_CARD_RETIRE_POS := Vector3(-1.8, 0.08, 8.2)
const LOOSE_CARD_RETIRE_ROT := Vector3(-86.0, 18.0, -32.0)
const MENU_SUN_ROT := Vector3(-49.0, -28.0, 0.0)
const MENU_SUN_ENERGY := 0.56
const GAMEPLAY_SUN_ROT := Vector3(-58.0, -22.0, 0.0)
const GAMEPLAY_SUN_ENERGY := 0.84
const GAMEPLAY_SUN_BIAS := 0.015
const GAMEPLAY_SUN_NORMAL_BIAS := 0.35
const GAMEPLAY_SUN_MAX_DIST := 28.0
const GAMEPLAY_BEAM_TRANSPARENCY := 0.55

@export var cat_scene: PackedScene
@export var build_menu_props: bool = true
@export var build_menu_hitboxes: bool = true
var props: Array[Node3D] = []
var base_positions: Array[Vector3] = []
var base_rotations: Array[Vector3] = []
var focus_tweens: Dictionary = {}
var curtains: Array[Node3D] = []
var sliders: Array[Node3D] = []
var fader_origins: Array[Vector3] = []
var gears: Array[Node3D] = []
var grips: Array[MeshInstance3D] = []
var grip_materials: Array[StandardMaterial3D] = []
var grip_tweens: Array[Tween] = []
var hot_fader := -1
var pressed_fader := -1
var cover: Node3D
var ticket: Node3D
var flat_ticket: Node3D
var mixer: Node3D
var gallery_chest: Node3D
var gallery_lid: Node3D
var gallery_deck: Node3D
var gallery_preview_cards: Array[MeshInstance3D] = []
var gallery_display: GalleryCardDisplay
var loose_card: MeshInstance3D
var prop_hitboxes: Array[Area3D] = []
var directional_light: DirectionalLight3D
var light_beam: MeshInstance3D
var gallery_glow_light: OmniLight3D
var loose_card_base_pos := Vector3.ZERO
var loose_card_base_rot := Vector3.ZERO
var _gallery_preview_base_pos: Array[Vector3] = []
var _gallery_preview_base_rot: Array[Vector3] = []
var _gallery_openness: float = 0.0
var _gallery_preview_amount: float = 0.0
var _browsing_gallery: bool = false
var _hide_gallery_fan_until_closed: bool = false
var _cover_base_rot := Vector3.ZERO
var _curtain_cloths: Array[CurtainCloth] = []
var _curtain_openness: float = 0.0
var _curtain_goal: float = 0.0
var _curtain_rail_start: float = 0.0
var _curtain_rail_elapsed: float = 0.0
var _curtain_rail_duration: float = 0.0
var _curtain_motion_left: float = 0.0
var _lighting_tween: Tween
var _non_gallery_tween: Tween
var _gallery_tween: Tween
var _return_tween: Tween
var _menu_sun_bias := 0.1
var _menu_sun_normal_bias := 1.0
var _menu_sun_max_dist := 100.0
var _letter_font: SystemFont


func _ready() -> void:
	_letter_font = SystemFont.new()
	_letter_font.font_names = PackedStringArray(["Georgia", "Liberation Serif", "DejaVu Serif", "serif"])
	_letter_font.font_weight = 700
	_room()
	_stage()
	set_physics_process(false)
	if build_menu_props:
		_menu_props()


func _mesh(parent: Node3D, shape: Mesh, at: Vector3, material: Material = null) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = shape
	item.material_override = material
	item.position = at
	parent.add_child(item)
	return item


func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.65) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(parent, shape, at, material)


func _model(parent: Node3D, key: String, at: Vector3, size: Vector3, angles := Vector3.ZERO) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = key.to_pascal_case()
	parent.add_child(pivot)
	pivot.position = at
	pivot.scale = size
	pivot.rotation_degrees = angles
	var packed := load(MODELS + key + ".glb") as PackedScene
	pivot.add_child(packed.instantiate())
	return pivot


func _room() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#191522")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#ffead5")
	environment.ambient_light_energy = 0.37
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.14
	environment.tonemap_exposure = 0.84
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var wall := _mat(Color("#161929"))
	var walnut := _mat(Color("#4e302c"))
	var gold := _mat(Color("#af8150"), 0.55, 0.34)
	_box(self, Vector3(0, 2.4, -5.5), Vector3(26, 10, 0.3), wall)
	for x in range(-10, 11, 2):
		_box(self, Vector3(x, 2.6, -5.22), Vector3(0.095, 7.0, 0.15), walnut)
		_box(self, Vector3(x + 0.75, 2.5, -5.25), Vector3(1.20, 2.7, 0.14), walnut)
		_box(self, Vector3(x + 0.75, 2.5, -5.13), Vector3(1.12, 2.60, 0.10), wall)
	var backdrop := _mat(Color("#bda9b1"))
	backdrop.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	backdrop.cull_mode = BaseMaterial3D.CULL_DISABLED
	backdrop.albedo_texture = preload("res://assets/models/theatre/backstage.jpg")
	for i in range(-3,4):
		var flat := QuadMesh.new()
		flat.size = Vector2(4.01,7.5)
		var scenery := _mesh(self,flat,Vector3(i*4.0,3.00,-4.98),backdrop)
		if posmod(i,2) == 1:
			scenery.scale.x = -1.0
	_box(self, Vector3(0, -0.22, 0.6), Vector3(19, 0.40, 10), walnut)
	var cloth := ShaderMaterial.new()
	cloth.shader = FINISH
	cloth.set_shader_parameter("fabric", true)
	cloth.set_shader_parameter("tint", Color("#51102e"))
	_box(self, Vector3(0, -0.029, 1.35), Vector3(9.72, 0.057, 8.1), cloth)
	for side in [-1, 1]:
		_box(self, Vector3(side * 4.78, 0.002, 1.35), Vector3(.024, .004, 8.1), gold)
		_model(self, "drape", Vector3(side * 7.12, 3.1, -3.2), Vector3(side * 6.5, 7.0, 3.1))
		var stand := _model(self, "small_brass", Vector3(side * 3.67, .63, -.75), Vector3.ONE * 1.30)
		var wax := CylinderMesh.new()
		wax.top_radius = .10
		wax.bottom_radius = .115
		wax.height = .48
		_mesh(stand, wax, Vector3(0, .64, 0), _mat(Color("#e6c59b")))
		var flame := SphereMesh.new()
		flame.radius = .050
		flame.height = .20
		var glow := _mat(Color("#fff0b9"))
		glow.emission_enabled = true
		glow.emission = Color("#ffaf51")
		glow.emission_energy_multiplier = 4.0
		_mesh(stand, flame, Vector3(.008, .947, 0), glow)
		_lamp(Vector3(side * 3.67, 1.98, -.62), Color("#ffae58"), 2.8, 4.0)
	_lamp(Vector3(0, 5.2, 3.3), Color("#ffdfaa"), 2.8, 9.0)
	_lamp(Vector3(-3.3, 3.7, 0.6), Color("#a5c6fc"), 2.0, 6.6)
	_lamp(Vector3(2.3, 3.4, -2.1), Color("#fff3c4"), 3.0, 6.2)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = MENU_SUN_ROT
	sun.light_color = Color("#ffe7c8")
	sun.light_energy = MENU_SUN_ENERGY
	sun.shadow_enabled = true
	directional_light = sun
	_menu_sun_bias = sun.shadow_bias
	_menu_sun_normal_bias = sun.shadow_normal_bias
	_menu_sun_max_dist = sun.directional_shadow_max_distance
	var cone := CylinderMesh.new()
	cone.top_radius = .13
	cone.bottom_radius = 2.0
	cone.height = 6.0
	cone.cap_top = false
	cone.cap_bottom = false
	var beam := ShaderMaterial.new()
	beam.shader = BEAM
	var shaft := _mesh(self, cone, Vector3(0, 3.35, -.58), beam)
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light_beam = shaft
	_dust()


func _lamp(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	add_child(lamp)


func _dust() -> void:
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(2.45, 1.4, .85)
	process.gravity = Vector3(.006, .018, 0)
	process.scale_min = .42
	process.scale_max = 1.0
	process.turbulence_enabled = true
	process.turbulence_noise_strength = .11
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1,.86,.51,.68), Color(1,.78,.4,0)])
	var sprite := GradientTexture2D.new()
	sprite.gradient = gradient
	sprite.fill = GradientTexture2D.FILL_RADIAL
	sprite.fill_from = Vector2(.5,.5)
	sprite.fill_to = Vector2(.98,.5)
	var m := _mat(Color.WHITE)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = sprite
	var q := QuadMesh.new()
	q.size = Vector2(.020,.020)
	q.material = m
	particles.amount = 52
	particles.lifetime = 9
	particles.preprocess = 9
	particles.process_material = process
	particles.draw_pass_1 = q
	particles.position = Vector3(0, 2.4, .4)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)


func _stage() -> void:
	var stage := _model(self, "playhouse", Vector3(0, 0, -.82), Vector3.ONE * 1.06)
	var timber := ShaderMaterial.new()
	timber.shader = FINISH
	timber.set_shader_parameter("tint", Color("#663820"))
	for part: Node in stage.find_children("*","MeshInstance3D",true,false):
		var surface := part as MeshInstance3D
		var original := surface.get_active_material(0)
		if original and "walnut" in original.resource_name.to_lower():
			surface.material_override = timber
	for key in ["CurtainLeft", "CurtainRight"]:
		var panel := stage.find_child(key, true, false) as MeshInstance3D
		if panel == null or panel.mesh == null:
			continue
		curtains.append(panel)
		_curtain_cloths.append(CurtainCloth.new(panel, 1.0 if key == "CurtainLeft" else -1.0))
	for side in [-1, 1]:
		_model(stage, "drape", Vector3(side * 1.42, 2.12, .12), Vector3(side * 2.1, 2.59, 1.5))
	_letter(stage, "THE 22 ACTS OF THE", Vector3(0, 4.055, .343), Vector2(2.53, .245), Color("#ffda87"))
	_letter(stage, "BLACK CAT", Vector3(0, 3.72, .343), Vector2(2.96, .50), Color("#ffe5a2"))
	var anchor := Node3D.new()
	anchor.name = "CatAnchor"
	anchor.position = Vector3(1.70, .93, .96)
	stage.add_child(anchor)
	if cat_scene:
		anchor.add_child(cat_scene.instantiate())


func _menu_props() -> void:
	for i in 5:
		var root := Node3D.new()
		root.name = ["Gallery", "Start", "Continue", "Settings", "Quit"][i]
		add_child(root)
		props.append(root)
	var chest := _model(props[GALLERY], "card_box", Vector3.ZERO, Vector3.ONE * 2.02)
	gallery_chest = chest
	props[GALLERY].position = Vector3(-3.85,.51,1.70)
	props[GALLERY].rotation_degrees.y = 13
	_hit(props[GALLERY], GALLERY, Vector3(0,.46,-.05), Vector3(2.03,1.78,1.56))
	var lid := chest.find_child("Lid",true,false) as Node3D
	gallery_lid = lid
	_letter(chest, "GALLERY", Vector3(0,-.134,.351), Vector2(.66,.105), Color("#e5c88f"))
	gallery_deck = DECK_SCENE.instantiate() as Node3D
	gallery_deck.name = "GalleryDeck"
	gallery_deck.position = GALLERY_DECK_REST
	gallery_deck.rotation_degrees.y = 90.0
	gallery_deck.scale = Vector3.ONE * 0.48
	props[GALLERY].add_child(gallery_deck)
	gallery_glow_light = OmniLight3D.new()
	gallery_glow_light.position = Vector3(0.0, 0.06, 0.02)
	gallery_glow_light.light_color = Color("#ffcf75")
	gallery_glow_light.light_energy = 0.0
	gallery_glow_light.omni_range = 2.6
	chest.add_child(gallery_glow_light)
	for i in 3:
		var card := QuadMesh.new()
		card.size = Vector2(.295,.432)
		var m := _mat(Color.WHITE)
		m.albedo_texture = load(CardDatabase.texture_path([1,11,0][i]))
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var face := _mesh(chest, card, Vector3((i-1)*.210,.275,-.050+.018*i), m)
		face.rotation_degrees = Vector3(-24, 0, 8.0-i*6.0)
		gallery_preview_cards.append(face)
		_gallery_preview_base_pos.append(face.position)
		_gallery_preview_base_rot.append(face.rotation_degrees)
	if build_menu_hitboxes:
		gallery_display = GalleryCardDisplay.new()
		gallery_display.name = "GalleryCardDisplay"
		chest.add_child(gallery_display)
	set_gallery_open(false, false)
	props[START].position = Vector3(-1.73,.43,2.76)
	ticket = _ticket(props[START], Vector3(0,.13,0), Vector3(-12,4,6))
	flat_ticket = _ticket(props[START], Vector3(-.09,-.32,.58), Vector3(-76,1,6))
	_hit(props[START], START, ticket.position, Vector3(1.98,.67,.11), ticket.rotation)
	_hit(props[START], START, flat_ticket.position, Vector3(1.98,.67,.11), flat_ticket.rotation)
	props[CONTINUE].position = Vector3(.94,.39,2.62)
	props[CONTINUE].rotation_degrees = Vector3(12,-9,0)
	var book := _model(props[CONTINUE], "libretto", Vector3.ZERO, Vector3(2.34,2.10,2.60))
	cover = book.find_child("Cover",true,false)
	_cover_base_rot = cover.rotation_degrees
	var bookmark := _mat(Color("#8d7753") if TheatreSession.checkpoint.is_empty() else Color("#ffcd72"),.72,.26)
	if not TheatreSession.checkpoint.is_empty():
		bookmark.emission_enabled = true
		bookmark.emission = Color("#926529")
	for toe: Node in cover.find_children("Bookmark*","MeshInstance3D",true,false):
		(toe as MeshInstance3D).material_override = bookmark
	_letter(cover, "CONTINUE", Vector3(0,.064,.35), Vector2(.78,.195), Color("#ffdb8b"), Vector3(-90,0,0))
	_hit(props[CONTINUE], CONTINUE, Vector3.ZERO, Vector3(2.26,.61,2.00))
	props[SETTINGS].position = Vector3(3.01,.56,1.58)
	props[SETTINGS].rotation_degrees.y = -11
	mixer = _model(props[SETTINGS], "mixer", Vector3.ZERO, Vector3.ONE * 1.78)
	_hit(props[SETTINGS], SETTINGS, Vector3.ZERO, Vector3(1.70,1.13,.81))
	for i in 2:
		var fader := mixer.find_child("Fader%d" % i,true,false) as Node3D
		sliders.append(fader)
		fader_origins.append(fader.position)
		var grip := fader.get_node("Grip%d" % i) as MeshInstance3D
		var finish := grip.get_active_material(0).duplicate() as StandardMaterial3D
		finish.emission_enabled = true
		finish.emission = Color("#ffc56f")
		finish.emission_texture = finish.albedo_texture
		finish.emission_energy_multiplier = 0.0
		grip.material_override = finish
		grips.append(grip)
		grip_materials.append(finish)
		grip_tweens.append(null)
	for part in ["GearTop", "GearLower", "GearPinion"]:
		gears.append(mixer.find_child(part,true,false))
	update_mixer()
	props[QUIT].position = Vector3(4.40,.62,2.14)
	var bell := _model(props[QUIT], "desk_brass", Vector3.ZERO, Vector3.ONE * 1.29)
	_hit(props[QUIT], QUIT, Vector3.ZERO, Vector3(.95,1.32,.95))
	_letter(bell, "QUIT", Vector3(0,-.435,.47), Vector2(.53,.16), Color("#edcf8f"), Vector3(-34,0,0))
	for prop in props:
		base_positions.append(prop.position)
		base_rotations.append(prop.rotation_degrees)
	var loose := QuadMesh.new()
	loose.size = Vector2(.66,.91)
	var illustrated := _mat(Color.WHITE)
	illustrated.albedo_texture = load(CardDatabase.texture_path(0))
	loose_card = _mesh(self,loose,Vector3(-.61,.025,3.24),illustrated)
	loose_card.rotation_degrees = Vector3(-89,0,-13)
	loose_card_base_pos = loose_card.position
	loose_card_base_rot = loose_card.rotation_degrees


func _ticket(parent: Node3D, at: Vector3, angles: Vector3) -> Node3D:
	var stub := _model(parent, "ticket", at, Vector3(2.10,2.42,2.1), angles)
	_letter(stub, "START PLAY", Vector3(0,0,.008), Vector2(.71,.165), Color("#593819"))
	var q := QuadMesh.new()
	q.size = Vector2(.939,.273)
	var foil := ShaderMaterial.new()
	foil.shader = FOIL
	_mesh(stub,q,Vector3(0,0,.007),foil)
	return stub


func _hit(parent: Node3D, id: int, at: Vector3, size: Vector3, angles := Vector3.ZERO) -> void:
	if not build_menu_hitboxes:
		return
	var area := Area3D.new()
	area.position = at
	area.rotation = angles
	area.collision_layer = 2
	area.collision_mask = 0
	area.set_meta("menu_id", id)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	area.add_child(col)
	# The picking volume stays at rest while the model moves.
	add_child(area)
	area.global_transform = parent.global_transform * Transform3D(Basis.from_euler(angles), at)
	prop_hitboxes.append(area)


func _letter(parent: Node3D, words: String, at: Vector3, size: Vector2, color: Color, angles := Vector3.ZERO) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(960, maxi(72,roundi(960.0*size.y/size.x)))
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
	var fit := minf(vp.size.y*.82, vp.size.x*100.0/_letter_font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,100).x*.96)
	label.add_theme_font_size_override("font_size",maxi(12,int(fit)))
	label.add_theme_color_override("font_color",color)
	vp.add_child(label)
	var m := _mat(Color.WHITE)
	m.albedo_texture = vp.get_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	q.size = size
	var sign_mesh := _mesh(parent,q,at,m)
	sign_mesh.rotation_degrees = angles
	sign_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func focus_prop(index: int, active: bool) -> void:
	if index < 0 or index >= props.size() or not props[index].visible:
		return
	if index == GALLERY:
		set_gallery_open(active)
		return
	var prop := props[index]
	if focus_tweens.has(index):
		_kill_tween(focus_tweens[index] as Tween)
	var tween := create_tween().set_parallel(true)
	focus_tweens[index] = tween
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(prop,"position",base_positions[index]+Vector3.UP*(.073 if active else 0.0),.23)
	tween.tween_property(prop,"scale",Vector3.ONE*(1.038 if active else 1.0),.23)


func update_mixer() -> void:
	if sliders.size() < 2 or gears.size() < 3:
		return
	for i in sliders.size():
		var level := TheatreSession.levels[i]
		sliders[i].position = fader_origins[i] + sliders[i].basis.y * ((level - 0.5) * FADER_TRAVEL)
	# Zero rotation corresponds to the meshed teeth in the authored pose.
	var angle := (TheatreSession.levels[0] - 0.5) * 1.9 + (TheatreSession.levels[1] - 0.5) * 2.2
	gears[0].rotation.z = angle
	gears[1].rotation.z = -angle * 1.16
	gears[2].rotation.z = -angle * 2.0


func set_fader_feedback(hot: int, pressed: int) -> void:
	if hot == hot_fader and pressed == pressed_fader:
		return
	hot_fader = hot
	pressed_fader = pressed
	for i in grips.size():
		if grip_tweens[i] != null:
			grip_tweens[i].kill()
		var light := 0.0
		var depth := 0.0
		if i == pressed:
			light = 0.42
			depth = -0.010
		elif i == hot:
			light = 0.20
		var tween := create_tween().set_parallel(true)
		grip_tweens[i] = tween
		tween.tween_property(grip_materials[i], "emission_energy_multiplier", light, 0.10)
		tween.tween_property(grips[i], "position:z", depth, 0.09)


func set_curtains_open(open: bool, animate: bool = false, duration: float = 0.55) -> void:
	var target := 1.0 if open else 0.0
	if is_equal_approx(_curtain_openness, target) and is_equal_approx(_curtain_goal, target):
		return
	_curtain_goal = target
	_curtain_rail_start = _curtain_openness
	_curtain_rail_elapsed = 0.0
	_curtain_rail_duration = duration if animate else 0.0
	if not animate or duration <= 0.0:
		_curtain_openness = target
		_curtain_motion_left = 0.0
		for cloth in _curtain_cloths:
			cloth.snap(target)
		set_physics_process(false)
		return
	_curtain_motion_left = duration + CURTAIN_SETTLE_TIME
	set_physics_process(true)


func get_curtain_openness() -> float:
	return _curtain_openness


func capture_curtains() -> Dictionary:
	var panels: Array[Dictionary] = []
	for cloth in _curtain_cloths:
		panels.append(cloth.capture())
	return {
		"panels": panels, "openness": _curtain_openness, "goal": _curtain_goal,
		"rail_start": _curtain_rail_start, "rail_elapsed": _curtain_rail_elapsed,
		"rail_duration": _curtain_rail_duration, "motion_left": _curtain_motion_left,
	}


func restore_curtains(state: Dictionary) -> void:
	if state.is_empty() or state["panels"].size() != _curtain_cloths.size():
		set_curtains_open(true)
		return
	_curtain_openness = state["openness"]
	_curtain_goal = state["goal"]
	_curtain_rail_start = state["rail_start"]
	_curtain_rail_elapsed = state["rail_elapsed"]
	_curtain_rail_duration = state["rail_duration"]
	_curtain_motion_left = state["motion_left"]
	for i in _curtain_cloths.size():
		_curtain_cloths[i].restore(state["panels"][i], _curtain_openness)
	set_physics_process(_curtain_motion_left > 0.0)


func _physics_process(delta: float) -> void:
	if _curtain_rail_elapsed < _curtain_rail_duration:
		_curtain_rail_elapsed = minf(_curtain_rail_duration, _curtain_rail_elapsed + delta)
		var progress := _curtain_rail_elapsed / _curtain_rail_duration
		_curtain_openness = lerpf(_curtain_rail_start, _curtain_goal, (1.0 - cos(PI * progress)) * 0.5)
	for cloth in _curtain_cloths:
		cloth.advance(_curtain_openness, delta)
	_curtain_motion_left = maxf(0.0, _curtain_motion_left - delta)
	if _curtain_motion_left <= 0.0:
		if is_zero_approx(_curtain_goal):
			for cloth in _curtain_cloths:
				cloth.snap(0.0)
		set_physics_process(false)


func set_gameplay_lighting(active: bool, animate: bool = true, duration: float = 1.1) -> void:
	_kill_tween(_lighting_tween)
	var target_rot := GAMEPLAY_SUN_ROT if active else MENU_SUN_ROT
	var target_energy := GAMEPLAY_SUN_ENERGY if active else MENU_SUN_ENERGY
	var target_bias := GAMEPLAY_SUN_BIAS if active else _menu_sun_bias
	var target_normal_bias := GAMEPLAY_SUN_NORMAL_BIAS if active else _menu_sun_normal_bias
	var target_max_dist := GAMEPLAY_SUN_MAX_DIST if active else _menu_sun_max_dist
	var target_beam_transp := GAMEPLAY_BEAM_TRANSPARENCY if active else 0.0
	if is_instance_valid(directional_light):
		directional_light.directional_shadow_max_distance = target_max_dist
	if not animate or duration <= 0.0:
		if is_instance_valid(directional_light):
			directional_light.rotation_degrees = target_rot
			directional_light.light_energy = target_energy
			directional_light.shadow_bias = target_bias
			directional_light.shadow_normal_bias = target_normal_bias
		if is_instance_valid(light_beam):
			light_beam.transparency = target_beam_transp
		return
	_lighting_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(directional_light):
		_lighting_tween.tween_property(directional_light, "rotation_degrees", target_rot, duration)
		_lighting_tween.tween_property(directional_light, "light_energy", target_energy, duration)
		_lighting_tween.tween_property(directional_light, "shadow_bias", target_bias, duration)
		_lighting_tween.tween_property(directional_light, "shadow_normal_bias", target_normal_bias, duration)
	if is_instance_valid(light_beam):
		_lighting_tween.tween_property(light_beam, "transparency", target_beam_transp, duration)


func disable_menu_hitboxes() -> void:
	_set_menu_hitboxes_enabled(false)


func get_gallery_deck_spawn_position() -> Vector3:
	if not is_instance_valid(gallery_deck):
		return Vector3(-3.85, 0.49, 1.70)
	return gallery_deck.global_position


func replace_gallery_deck(table_deck: Node3D) -> void:
	if is_instance_valid(gallery_deck):
		table_deck.global_transform = gallery_deck.global_transform
		gallery_deck.hide()


func clear_non_gallery_props(animate: bool = true) -> void:
	disable_menu_hitboxes()
	_kill_focus_tweens([START, CONTINUE, SETTINGS, QUIT])
	_kill_tween(_non_gallery_tween)
	if props.size() < 5:
		return
	if not animate:
		for idx in [START, CONTINUE, SETTINGS, QUIT]:
			if is_instance_valid(props[idx]):
				props[idx].visible = false
		if is_instance_valid(loose_card):
			loose_card.visible = false
		return
	_non_gallery_tween = create_tween().set_parallel(true)
	for idx in [QUIT, SETTINGS, START, CONTINUE]:
		var prop := props[idx]
		if not is_instance_valid(prop):
			continue
		var pose := _retire_pose(idx)
		var delay := float(pose["delay"])
		var dur := float(pose["dur"])
		_non_gallery_tween.tween_property(prop, "position", pose["pos"], dur).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_non_gallery_tween.tween_property(prop, "rotation_degrees", pose["rot"], dur).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_non_gallery_tween.tween_property(prop, "scale", Vector3.ONE, 0.16).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_non_gallery_tween.tween_callback(prop.hide).set_delay(delay + dur)
	if is_instance_valid(loose_card):
		_non_gallery_tween.tween_property(loose_card, "position", LOOSE_CARD_RETIRE_POS, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_non_gallery_tween.tween_property(loose_card, "rotation_degrees", LOOSE_CARD_RETIRE_ROT, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_non_gallery_tween.tween_callback(loose_card.hide).set_delay(0.38)


func set_gallery_open(open: bool, animate: bool = true) -> void:
	_kill_tween(_gallery_tween)
	if open:
		_hide_gallery_fan_until_closed = false
	var target := 1.0 if open else 0.0
	if not animate:
		_apply_gallery_lid(target)
		return
	_gallery_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_gallery_tween.tween_method(_apply_gallery_lid, _gallery_openness, target, 0.32)


func set_gallery_browsing(active: bool) -> void:
	_browsing_gallery = active
	_hide_gallery_fan_until_closed = not active
	if not active:
		gallery_display.clear()
	_apply_gallery_preview(_gallery_preview_amount)
	set_gallery_open(active)


func _apply_gallery_lid(amount: float) -> void:
	_gallery_openness = amount
	if is_instance_valid(gallery_lid):
		gallery_lid.rotation_degrees.x = lerpf(GALLERY_LID_CLOSED_X, GALLERY_LID_OPEN_X, amount)
	if is_instance_valid(gallery_glow_light):
		gallery_glow_light.light_energy = 2.4 * amount
	var reveal := smoothstep(0.40, 1.0, amount)
	if is_instance_valid(gallery_deck):
		gallery_deck.position = GALLERY_DECK_REST + Vector3.UP * (GALLERY_DECK_RISE * reveal)
	_apply_gallery_preview(reveal)


func _apply_gallery_preview(amount: float) -> void:
	_gallery_preview_amount = amount
	if is_zero_approx(amount):
		_hide_gallery_fan_until_closed = false
	for i in gallery_preview_cards.size():
		var face := gallery_preview_cards[i]
		var stacked := Vector3(0.0, 0.080 + i * 0.003, 0.030)
		face.position = stacked.lerp(_gallery_preview_base_pos[i], amount)
		face.rotation_degrees = Vector3(-90.0, 0.0, 0.0).lerp(_gallery_preview_base_rot[i], amount)
		face.scale = Vector3.ONE * lerpf(0.8, 1.0, amount)
		face.visible = amount > 0.001 and not _browsing_gallery and not _hide_gallery_fan_until_closed


func stack_gallery_preview() -> void:
	_kill_tween(_gallery_tween)
	_gallery_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_gallery_tween.tween_method(_apply_gallery_preview, _gallery_preview_amount, 0.0, 0.20)


func close_and_retire_gallery_chest(animate: bool = true) -> void:
	_kill_focus_tweens([GALLERY])
	_kill_tween(_gallery_tween)
	_apply_gallery_preview(0.0)
	if props.size() <= GALLERY or not is_instance_valid(props[GALLERY]):
		return
	if not animate:
		if is_instance_valid(gallery_glow_light):
			gallery_glow_light.light_energy = 0.0
		if is_instance_valid(gallery_lid):
			gallery_lid.rotation_degrees.x = GALLERY_LID_CLOSED_X
		props[GALLERY].position = GALLERY_RETIRE_POS
		props[GALLERY].rotation_degrees = GALLERY_RETIRE_ROT
		props[GALLERY].visible = false
		return
	_gallery_tween = create_tween().set_parallel(true)
	if is_instance_valid(gallery_glow_light):
		_gallery_tween.tween_property(gallery_glow_light, "light_energy", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(gallery_lid):
		_gallery_tween.tween_property(gallery_lid, "rotation_degrees:x", GALLERY_LID_CLOSED_X, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_gallery_tween.tween_property(props[GALLERY], "position", GALLERY_RETIRE_POS, 0.44).set_delay(0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_gallery_tween.tween_property(props[GALLERY], "rotation_degrees", GALLERY_RETIRE_ROT, 0.44).set_delay(0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_gallery_tween.tween_callback(props[GALLERY].hide).set_delay(0.60)


func hide_all_menu_props_immediately() -> void:
	disable_menu_hitboxes()
	_kill_focus_tweens()
	_kill_tween(_non_gallery_tween)
	_kill_tween(_gallery_tween)
	_kill_tween(_return_tween)
	for prop in props:
		if is_instance_valid(prop):
			prop.visible = false
	if is_instance_valid(loose_card):
		loose_card.visible = false
	set_gallery_open(false, false)


func play_return_props_animation(duration: float = 0.72) -> void:
	_kill_focus_tweens()
	_kill_tween(_non_gallery_tween)
	_kill_tween(_gallery_tween)
	_kill_tween(_return_tween)
	_set_menu_hitboxes_enabled(true)
	if props.size() < 5:
		return
	set_gallery_open(false, false)
	gallery_deck.show()
	if is_instance_valid(cover):
		cover.rotation_degrees = _cover_base_rot
	if duration <= 0.0:
		for i in props.size():
			if is_instance_valid(props[i]):
				props[i].position = base_positions[i]
				props[i].rotation_degrees = base_rotations[i]
				props[i].scale = Vector3.ONE
				props[i].visible = true
		if is_instance_valid(loose_card):
			loose_card.position = loose_card_base_pos
			loose_card.rotation_degrees = loose_card_base_rot
			loose_card.scale = Vector3.ONE
			loose_card.visible = true
		return
	props[GALLERY].position = GALLERY_RETIRE_POS
	props[GALLERY].rotation_degrees = GALLERY_RETIRE_ROT
	props[GALLERY].scale = Vector3.ONE
	props[GALLERY].visible = true
	for idx in [START, CONTINUE, SETTINGS, QUIT]:
		var pose := _retire_pose(idx)
		props[idx].position = pose["pos"]
		props[idx].rotation_degrees = pose["rot"]
		props[idx].scale = Vector3.ONE
		props[idx].visible = true
	if is_instance_valid(loose_card):
		loose_card.position = LOOSE_CARD_RETIRE_POS
		loose_card.rotation_degrees = LOOSE_CARD_RETIRE_ROT
		loose_card.scale = Vector3.ONE
		loose_card.visible = true
	_return_tween = create_tween().set_parallel(true)
	var gallery_dur := duration * 0.85
	_return_tween.tween_property(props[GALLERY], "position", base_positions[GALLERY], gallery_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_return_tween.tween_property(props[GALLERY], "rotation_degrees", base_rotations[GALLERY], gallery_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for idx in [START, CONTINUE, SETTINGS, QUIT]:
		var delay := 0.025 * float(idx)
		var move_dur := maxf(0.1, duration - delay)
		_return_tween.tween_property(props[idx], "position", base_positions[idx], move_dur).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_return_tween.tween_property(props[idx], "rotation_degrees", base_rotations[idx], move_dur).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(loose_card):
		var card_delay := 0.06
		_return_tween.tween_property(loose_card, "position", loose_card_base_pos, maxf(0.1, duration - card_delay)).set_delay(card_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_return_tween.tween_property(loose_card, "rotation_degrees", loose_card_base_rot, maxf(0.1, duration - card_delay)).set_delay(card_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _retire_pose(index: int) -> Dictionary:
	match index:
		START:
			return {"pos": Vector3(-1.85, 0.48, 8.2), "rot": Vector3(0.0, 10.0, 6.0), "delay": 0.04, "dur": 0.40}
		CONTINUE:
			return {"pos": Vector3(8.4, 0.42, 3.65), "rot": Vector3(12.0, -24.0, -8.0), "delay": 0.06, "dur": 0.42}
		SETTINGS:
			return {"pos": Vector3(8.8, 0.56, 1.65), "rot": Vector3(0.0, -24.0, -8.0), "delay": 0.03, "dur": 0.42}
		QUIT:
			return {"pos": Vector3(8.9, 0.62, 2.45), "rot": Vector3(0.0, 0.0, -14.0), "delay": 0.00, "dur": 0.38}
	return {"pos": GALLERY_RETIRE_POS, "rot": GALLERY_RETIRE_ROT, "delay": 0.0, "dur": 0.42}


func _set_menu_hitboxes_enabled(enabled: bool) -> void:
	for area in prop_hitboxes:
		if not is_instance_valid(area):
			continue
		area.input_ray_pickable = enabled
		area.monitoring = enabled
		area.monitorable = enabled
		area.collision_layer = 2 if enabled else 0


func _kill_tween(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()


func _kill_focus_tweens(indices: Array[int] = []) -> void:
	if indices.is_empty():
		for key: Variant in focus_tweens.keys():
			_kill_tween(focus_tweens[key] as Tween)
		focus_tweens.clear()
		return
	for idx in indices:
		if focus_tweens.has(idx):
			_kill_tween(focus_tweens[idx] as Tween)
			focus_tweens.erase(idx)

