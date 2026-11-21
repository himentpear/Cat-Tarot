extends Node3D

const HOME := Vector3(0, 3.94, 13.1)
const AIM := Vector3(0, 1.70, 0)
const HOME_FOV := 31.1
const NAMES := ["gallery", "start", "continue", "settings", "quit"]
const CARD_BACK := preload("res://assets/models/theatre/card_back.svg")
const AgentConsole := preload("res://scripts/agent_console.gd")

@onready var stage: TheatreSet = $Set
@onready var camera: Camera3D = $Camera3D
var focused := -1
var mode := ""
var _gallery_requested := 0
var dragging := -1
var grab_offset := 0.0
var dock_dragging := -1
var transitioning := false
var screen := Control.new()
var panel: PanelContainer
var content: VBoxContainer
var hint := Label.new()
var card_title: Label
var card_description: Label
var counter: Label
var volume_controls: Array[HSlider] = []
var volume_readouts: Array[Label] = []
var keyboard_focus := false
var last_mouse := Vector2(-10000,-10000)
var camera_target := AIM
var camera_home := HOME
var pointer := Vector2.ZERO


func _ready() -> void:
	TheatreSession.tracking = false
	TablePreloader.begin_load()
	transitioning = false
	keyboard_focus = false
	_set_focus(-1)
	camera_home = HOME
	camera_target = AIM
	pointer = Vector2.ZERO
	camera.position = HOME
	camera.look_at(AIM)
	camera.fov = HOME_FOV
	var ret := TheatreSession.consume_return_transition()
	if not ret.is_empty():
		camera.global_transform = ret["camera_transform"]
		camera.fov = float(ret["camera_fov"])
		stage.restore_curtains(ret.get("curtains", {}))
		stage.set_curtains_open(false, true, 0.60)
		stage.set_gameplay_lighting(true, false)
		stage.set_gameplay_lighting(false, true, 0.72)
		stage.play_return_props_animation(0.72)
		create_tween().tween_callback(TablePreloader.prepare).set_delay(0.72)
	else:
		TablePreloader.prepare()
	if screen.get_parent() == null:
		_build_interface()
	Audio.start_music()


func _build_interface() -> void:
	stage.gallery_display.card_presented.connect(_show_gallery_description)
	var optics := CameraAttributesPractical.new()
	optics.dof_blur_far_enabled = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	optics.dof_blur_far_distance = HOME.distance_to(AIM) + 2.0
	optics.dof_blur_far_transition = 3.4
	optics.dof_blur_amount = .075
	camera.attributes = optics
	$Interface.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.theme = UiFonts.build_ui_theme(20)
	screen.add_child(hint)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("#fae1ad"))
	hint.add_theme_color_override("font_outline_color", Color("#21141b"))
	hint.add_theme_constant_override("outline_size",5)
	hint.offset_top = -44
	hint.offset_bottom = -15


func _exit_tree() -> void:
	_end_drag()
	if dock_dragging >= 0:
		_end_dock_drag(false,dock_dragging)


func _process(delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	var movement := not mouse.is_equal_approx(last_mouse)
	if movement:
		last_mouse = mouse
		keyboard_focus = false
	if mode.is_empty() and not transitioning and not keyboard_focus and get_viewport().get_visible_rect().has_point(mouse):
		_set_focus(_pick(mouse))
	var desired := mouse / size * 2.0 - Vector2.ONE if mode.is_empty() and not transitioning and not keyboard_focus and get_viewport().get_visible_rect().has_point(mouse) else Vector2.ZERO
	desired = desired.clamp(-Vector2.ONE,Vector2.ONE)
	var blend := 1.0-exp(-delta*6.8)
	pointer = pointer.lerp(desired,blend)
	var offset := Vector3(pointer.x*.17,-pointer.y*.085,0)
	camera.position = camera.position.lerp(camera_home+offset,blend)
	var target_basis := Basis.looking_at((camera_target-camera.position).normalized(), Vector3.UP)
	target_basis = target_basis * Basis.from_euler(Vector3(deg_to_rad(pointer.y*1.2), deg_to_rad(-pointer.x*1.2), 0))
	camera.basis = camera.basis.slerp(target_basis,blend).orthonormalized()
	camera.fov = lerpf(camera.fov, HOME_FOV, blend)
	var optics := camera.attributes as CameraAttributesPractical
	optics.dof_blur_far_distance = lerpf(optics.dof_blur_far_distance,camera.position.distance_to(camera_target)+1.35,blend)
	var tilt := Vector3(-12,4,6)
	if focused == TheatreSet.START and mode.is_empty() and not keyboard_focus:
		var local := _on_plane(stage.ticket, mouse, Vector3.BACK)
		tilt += Vector3(clampf(-local.y*35,-5,5),clampf(local.x*15,-7,7),0)
	stage.ticket.rotation_degrees = stage.ticket.rotation_degrees.lerp(tilt,blend)
	if mode == "settings":
		_update_fader_feedback(mouse)


func _pick(point: Vector2) -> int:
	var origin := camera.project_ray_origin(point)
	var query := PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(point)*80.0,2)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return int(hit.collider.get_meta("menu_id",-1)) if not hit.is_empty() else -1


func _on_plane(node: Node3D, point: Vector2, normal: Vector3) -> Vector3:
	var origin := node.to_local(camera.project_ray_origin(point))
	var direction := node.global_transform.basis.inverse() * camera.project_ray_normal(point)
	var hit: Variant = Plane(normal.normalized(),0).intersects_ray(origin,direction)
	return hit if hit is Vector3 else Vector3.INF


func _set_focus(id: int) -> void:
	if id == focused:
		return
	if focused >= 0:
		stage.focus_prop(focused,false)
	focused = id
	hint.text = ""
	if id >= 0 and mode.is_empty():
		stage.focus_prop(id,true)
		hint.text = Loc.t("theatre."+NAMES[id])
		if id == TheatreSet.CONTINUE and TheatreSession.checkpoint.is_empty():
			hint.text = Loc.t("theatre.no_run")


func _input(event: InputEvent) -> void:
	if mode == "gallery" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_RIGHT]:
			_turn_card(-1 if event.keycode == KEY_LEFT else 1)
			get_viewport().set_input_as_handled()
			return
	if mode == "settings" and event is InputEventKey and event.pressed:
		keyboard_focus = true
	if dragging < 0:
		return
	if event is InputEventMouseMotion:
		_drag(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_end_drag()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if transitioning:
		return
	if event.is_action_pressed("ui_cancel"):
		if mode.is_empty():
			_activate(TheatreSet.QUIT)
		elif mode == "agent":
			_open_settings()
		else:
			_close_panel()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mode == "settings":
			_start_drag(event.position)
		elif mode.is_empty():
			_activate(_pick(event.position))
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if mode.is_empty():
		var step := 0
		match event.keycode:
			KEY_LEFT, KEY_UP: step = -1
			KEY_RIGHT, KEY_DOWN: step = 1
			KEY_TAB: step = -1 if event.shift_pressed else 1
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_activate(focused if focused >= 0 else TheatreSet.START)
				get_viewport().set_input_as_handled()
		if step != 0:
			keyboard_focus = true
			_set_focus(posmod(focused+step,5) if focused >= 0 else TheatreSet.START)
			get_viewport().set_input_as_handled()


func _activate(id: int) -> void:
	if id < 0 or transitioning:
		return
	match id:
		TheatreSet.START:
			if TheatreSession.checkpoint.is_empty():
				_enter_game(false)
			else:
				_confirmation("overwrite")
		TheatreSet.CONTINUE:
			if TheatreSession.checkpoint.is_empty():
				_set_focus(id)
			else:
				_enter_game(true)
		TheatreSet.GALLERY: _open_gallery()
		TheatreSet.SETTINGS: _open_settings()
		TheatreSet.QUIT:
			Audio.play_sfx("theatre_bell",-6.0)
			var ring := create_tween()
			ring.tween_property(stage.props[id],"rotation:z",.15,.09)
			ring.tween_property(stage.props[id],"rotation:z",-.12,.14)
			ring.tween_property(stage.props[id],"rotation:z",0.0,.14)
			_confirmation("quit")


func _enter_game(resume: bool, question: String = "") -> void:
	if transitioning:
		return
	if not resume and AgentSettings.enabled and question.is_empty():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--question="):
				question = arg.trim_prefix("--question=").strip_edges()
				break
		if question.is_empty():
			_open_question()
			return
	transitioning = true
	_close_panel()
	stage.set_gallery_open(true)
	TheatreSession.resume_requested = resume
	TheatreSession.tracking = true
	if resume:
		var flip := create_tween()
		flip.tween_property(stage.cover,"rotation:x",deg_to_rad(-34),.25)
	var lift := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lift.tween_property(self, "camera_home", HOME + Vector3(0.0, 0.20, -0.35), 0.42)
	lift.tween_property(self, "camera_target", AIM + Vector3(0.0, -0.15, 0.35), 0.42)
	stage.set_curtains_open(true, true, 0.65)
	var tree := get_tree()
	await tree.create_timer(.44).timeout
	if not is_inside_tree():
		return
	if not TablePreloader.finished:
		TablePreloader.prepare()
		await TablePreloader.preparation_finished
	await tree.process_frame
	var table := TablePreloader.take_table()
	if table == null:
		_restore_menu_after_failed_entry()
		return

	stage.set_gallery_open(true, false)
	TheatreSession.begin_enter_transition("continue" if resume else "start", camera.global_transform, camera.fov, stage.capture_curtains(), question)
	TablePreloader.keep_menu(self)
	if tree.change_scene_to_node(table) != OK:
		table.queue_free()
		TheatreSession.consume_enter_transition()
		var menu := TablePreloader.take_menu()
		tree.root.add_child(menu)
		tree.current_scene = menu
		_restore_menu_after_failed_entry()


func _restore_menu_after_failed_entry() -> void:
	TheatreSession.resume_requested = false
	TheatreSession.tracking = false
	transitioning = false
	camera_home = HOME
	camera_target = AIM
	stage.set_gallery_open(false)
	stage.set_curtains_open(false, true)
	push_error("Could not open the tarot table")


func _open_panel(kind: String, at_right: bool = false) -> void:
	_close_panel()
	mode = kind
	_set_focus(-1)
	panel = PanelContainer.new()
	screen.add_child(panel)
	panel.theme = UiFonts.build_ui_theme(20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#241b21f5")
	style.border_color = Color("#9d7951")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel",style)
	if at_right:
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		panel.offset_right = -52
		panel.offset_left = -420
	else:
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.offset_bottom = -28
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH if at_right else Control.GROW_DIRECTION_BEGIN
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation",9)
	panel.add_child(content)


func _close_panel() -> void:
	if mode == "gallery":
		stage.set_gallery_browsing(false)
	_end_drag()
	if dock_dragging >= 0:
		_end_dock_drag(false,dock_dragging)
	stage.set_fader_feedback(-1,-1)
	mode = ""
	volume_controls.clear()
	volume_readouts.clear()
	if is_instance_valid(panel):
		panel.hide()
		panel.queue_free()
		panel = null
	camera_home = HOME
	camera_target = AIM


func _label(parent: Control, words: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = words
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("#f6e0b6"))
	parent.add_child(label)
	return label


func _button(parent: Control, key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = Loc.t("theatre."+key)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _confirmation(kind: String) -> void:
	_open_panel(kind)
	_label(content,Loc.t("theatre."+kind+"_prompt"),23)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(row)
	_button(row,"back",_close_panel).grab_focus()
	if kind == "quit":
		_button(row,"quit",_leave_theatre)
	else:
		_button(row,"start",_enter_game.bind(false))


func _leave_theatre() -> void:
	if transitioning:
		return
	transitioning = true
	Audio.stop_music()
	await get_tree().create_timer(.18).timeout
	get_tree().quit()


func _open_gallery() -> void:
	_open_panel("gallery",true)
	stage.set_gallery_browsing(true)
	var chest := stage.props[TheatreSet.GALLERY].position
	camera_target = chest + Vector3(.60,.47,.0)
	camera_home = camera_target + Vector3(0.0, 1.62, 4.90)
	_label(content,Loc.t("theatre.gallery"),27)
	card_title = _label(content,"",23)
	card_description = _label(content,"",17)
	card_description.custom_minimum_size.x = 306
	card_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	counter = _label(content,"",16)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(row)
	_button(row,"prev",_turn_card.bind(-1))
	_button(row,"back",_close_panel).grab_focus()
	_button(row,"next",_turn_card.bind(1))
	_gallery_requested = 0 if TheatreSession.collected.is_empty() else TheatreSession.collected[0]
	_show_gallery_description(_gallery_requested)
	_turn_card(0)


func _turn_card(amount: int) -> void:
	_gallery_requested = posmod(_gallery_requested + amount, GameManager.WORLD_ID + 1)
	var texture := CARD_BACK as Texture2D
	if TheatreSession.collected.has(_gallery_requested):
		texture = load(CardDatabase.texture_path(_gallery_requested)) as Texture2D
	stage.gallery_display.show_card(_gallery_requested, texture, amount)


func _show_gallery_description(card_id: int) -> void:
	if mode != "gallery":
		return
	var unlocked := TheatreSession.collected.has(card_id)
	card_title.text = Loc.card_name(card_id) if unlocked else Loc.t("theatre.unseen")
	card_description.text = Loc.card_desc(card_id) if unlocked else Loc.t("theatre.discover")
	card_description.visible = not card_description.text.is_empty()
	counter.text = "%02d / 22    ·    %s %d / 22" % [card_id + 1, Loc.t("theatre.collected"), TheatreSession.collected.size()]


func _open_settings() -> void:
	_open_panel("settings")
	camera_target = stage.props[TheatreSet.SETTINGS].position - Vector3(0,.065,0)
	camera_home = camera_target + Vector3(-.27,1.37,3.30)
	var row := HBoxContainer.new()
	row.theme = preload("res://scenes/settings_controls.tres")
	row.add_theme_constant_override("separation",22)
	content.add_child(row)
	for i in 2:
		var channel := VBoxContainer.new()
		channel.add_theme_constant_override("separation",2)
		row.add_child(channel)
		var caption := HBoxContainer.new()
		channel.add_child(caption)
		var title := _label(caption,Loc.t(["theatre.music","theatre.sfx"][i]),19)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var readout := _label(caption,"",18)
		readout.custom_minimum_size.x = 52
		readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		volume_readouts.append(readout)
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(160,24)
		slider.max_value = 1.0
		slider.step = .01
		slider.value = TheatreSession.levels[i]
		channel.add_child(slider)
		volume_controls.append(slider)
		_show_level(i,slider.value)
		slider.value_changed.connect(_set_volume.bind(i))
		slider.drag_started.connect(_begin_dock_drag.bind(i))
		slider.drag_ended.connect(_end_dock_drag.bind(i))
		if i == 0:
			slider.grab_focus()
	var back := _button(row,"back",_close_panel)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_button(content, "agent_console", _open_agent_console)


func _open_agent_console() -> void:
	_close_panel()
	mode = "agent"
	_set_focus(-1)
	panel = AgentConsole.new()
	screen.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 54.0
	panel.offset_right = -54.0
	panel.offset_top = 32.0
	panel.offset_bottom = -32.0
	panel.close_requested.connect(_open_settings)


func _open_question() -> void:
	_open_panel("question")
	_label(content, Loc.t("theatre.ask_question"), 23)
	var input := LineEdit.new()
	input.custom_minimum_size.x = 440
	input.max_length = 240
	content.add_child(input)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(actions)
	_button(actions, "back", _close_panel)
	var start := _button(actions, "start", func() -> void:
		if not input.text.strip_edges().is_empty():
			_enter_game(false, input.text.strip_edges())
	)
	start.disabled = true
	input.text_changed.connect(func(value: String) -> void: start.disabled = value.strip_edges().is_empty())
	input.text_submitted.connect(func(value: String) -> void:
		if not value.strip_edges().is_empty():
			_enter_game(false, value.strip_edges())
	)
	input.grab_focus()


func _show_level(id: int, value: float) -> void:
	volume_readouts[id].text = "%d%%" % roundi(value*100.0)


func _begin_dock_drag(id: int) -> void:
	dock_dragging = id


func _end_dock_drag(_changed: bool, id: int) -> void:
	if id != dock_dragging:
		return
	dock_dragging = -1
	TheatreSession.write_profile()
	if id == 1:
		Audio.play_sfx("card_tap",-5)


func _set_volume(value: float, id: int) -> void:
	TheatreSession.set_level(id,value)
	stage.update_mixer()
	_show_level(id,value)
	if dragging < 0 and dock_dragging < 0:
		TheatreSession.write_profile()
		if id == 1:
			Audio.play_sfx("card_tap",-5)


func _fader_at(at: Vector2) -> int:
	for i in stage.sliders.size():
		var local := _on_plane(stage.sliders[i],at,Vector3.BACK)
		var from_center := local.y + (TheatreSession.levels[i] - .5) * TheatreSet.FADER_TRAVEL
		if absf(local.x) <= .062 and absf(from_center) <= TheatreSet.FADER_TRAVEL*.5 + .033:
			return i
	return -1


func _update_fader_feedback(mouse: Vector2) -> void:
	var pressed := maxi(dragging,dock_dragging)
	var hot := -1
	if keyboard_focus:
		var control := get_viewport().gui_get_focus_owner() as HSlider
		if control:
			hot = volume_controls.find(control)
	elif panel.get_global_rect().has_point(mouse):
		var control := get_viewport().gui_get_hovered_control() as HSlider
		if control:
			hot = volume_controls.find(control)
	elif get_viewport().get_visible_rect().has_point(mouse):
		hot = _fader_at(mouse)
	if keyboard_focus and hot >= 0 and (Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")):
		pressed = hot
	stage.set_fader_feedback(hot, pressed)


func _start_drag(at: Vector2) -> void:
	dragging = _fader_at(at)
	if dragging < 0:
		return
	var local := _on_plane(stage.sliders[dragging],at,Vector3.BACK)
	# Grabbing the handle preserves its position. Clicking the slot jumps to it.
	grab_offset = local.y if absf(local.y) <= .035 else 0.0
	_drag(at)
	stage.set_fader_feedback(dragging,dragging)
	get_viewport().set_input_as_handled()


func _drag(at: Vector2) -> void:
	var slider := stage.sliders[dragging]
	var local := _on_plane(slider,at,Vector3.BACK)
	if not local.is_finite():
		return
	var value := clampf(TheatreSession.levels[dragging]+(local.y-grab_offset)/TheatreSet.FADER_TRAVEL,0,1)
	_set_volume(value,dragging)
	volume_controls[dragging].set_value_no_signal(value)


func _end_drag() -> void:
	if dragging >= 0:
		TheatreSession.write_profile()
		if dragging == 1:
			Audio.play_sfx("card_tap",-5)
		dragging = -1

