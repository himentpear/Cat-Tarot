extends Node3D

const CARD_SCENE := preload("res://scenes/card_3d.tscn")
const NarrativeCoordinator := preload("res://scripts/narrative_coordinator.gd")
const NarrativeStage := preload("res://scripts/narrative_stage.gd")
const NarrativeSkills := preload("res://scripts/narrative_skills.gd")
const AgentClient := preload("res://scripts/agent_client.gd")
const CARD_SPACING := 1.95
const CARD_Y := 0.065
const CARD_Z := 0.0
const WORLD_ID := 21
const GAMEPLAY_CAM_POS := Vector3(0.0, 8.8, 8.6)
const GAMEPLAY_CAM_AIM := Vector3(0.0, 0.30, 1.90)
const GAMEPLAY_CAM_FOV := 41.0
const DECK_REST_POS := Vector3(-3.95, 0.025, 2.85)
const DICE_REST_POS := Vector3(3.80, 0.375, 4.65)
const RESTART_REST_POS := Vector3(4.05, 0.025, 1.15)
const HAND_Z := 2.45
const HAND_SCALE := 0.8
const HAND_SPACING := 0.9
const HAND_FAN_DEGREES := 8.0
const HAND_STACK_STEP := 0.01
const HAND_HOLD_POS := Vector3(0.0, 0.6, 1.85)
const HAND_HOLD_SCALE := 0.92
const DISCARD_POS := Vector3(5.4, 1.2, 0.60)
const CARD_MOVE_TIME := 0.90

@onready var theatre_set: TheatreSet = $TheatreSet
@onready var card_root: Node3D = $CardRoot
@onready var camera: Camera3D = $Camera3D
@onready var dice: Dice3D = $Dice3D
@onready var deck: Node3D = $Deck3D
@onready var restart_button: RestartButton3D = $RestartButton3D
@onready var ui: CanvasLayer = $UI

@export var opening_question: String = ""

var preparing_offscreen: bool = false
var _visuals_prepared: bool = false
var _returning_to_menu: bool = false
var _slot_cards: Array = [null, null, null]
var _hand_root: Node3D
var _hand_cards: Array[Card3D] = []
var _hand_holders: Array[Node3D] = []
var _textures: Dictionary = {}
var _world_shown: bool = false
var _world_card: Card3D = null
var _seed: int = 0
var _choice_animating: bool = false
var _defer_hand_rebuild: bool = false
var _field_update_pending: bool = false
var _pending_field_cards: Array = []
var _field_deal_id: int = 0
var _pending_hold_card: Card3D = null
var _hold_slot: int = -1
var _hand_discarding: bool = false
var _hand_lift_tween: Tween
var _roll_pending: bool = false
var _table_generation: int = 0
var _narrative: NarrativeCoordinator
var _narrative_stage: NarrativeStage
var _intro_active: bool = false
var _intro_tweens: Array[Tween] = []
var _setting_up_intro_game: bool = false


func is_intro_active() -> bool:
	return _intro_active


func _ready() -> void:
	# The parked table re-enters with its visuals built and starts gameplay here.
	if not _visuals_prepared:
		_prepare_visuals()
	if not preparing_offscreen:
		_activate_gameplay()


func _prepare_visuals() -> void:
	_visuals_prepared = true
	card_root.position = Vector3(0.0, 0.0, 2.25)
	_hand_root = Node3D.new()
	_hand_root.name = "HandRoot"
	_hand_root.position = Vector3(0.0, 0.0, 2.25)
	add_child(_hand_root)
	_style_dice_cost()
	if preparing_offscreen:
		camera.global_transform = _gameplay_camera_transform()
		camera.fov = GAMEPLAY_CAM_FOV


func _activate_gameplay() -> void:
	_narrative = NarrativeCoordinator.new()
	add_child(_narrative)
	if AgentSettings.enabled:
		var client := AgentClient.new()
		add_child(client)
		var profile := AgentSettings.with_environment_key(AgentSettings.get_profile(AgentSettings.active_provider))
		_narrative.provider = _request_agent_plan.bind(client, profile)
		_narrative.provider_cancel = client.cancel
		_narrative.provider_timeout = AgentClient.TIMEOUT + 1.0
	_narrative.beat_requested.connect(_play_narrative_beat)
	_narrative.plan_ready.connect(_refresh_narrative_preview)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--question="):
			opening_question = arg.trim_prefix("--question=")
			break
	GameManager.field_cards_changed.connect(_on_field_cards_changed)
	GameManager.selected_card_changed.connect(_on_selected_card_changed)
	GameManager.choice_committed.connect(_on_choice_committed)
	GameManager.turn_resolved.connect(_on_turn_resolved)
	GameManager.orientation_rolled.connect(_on_orientation_rolled)
	GameManager.marks_changed.connect(_on_marks_changed)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.game_started.connect(_on_game_started)
	GameManager.game_started.connect(_on_narrative_started)
	dice.clicked.connect(_on_die_clicked)
	dice.roll_finished.connect(_on_die_roll_finished)
	restart_button.pressed.connect(_on_restart_pressed)
	Loc.language_changed.connect(_on_language_changed)
	_seed = _read_seed()
	var handoff := TheatreSession.consume_enter_transition()
	if not str(handoff.get("question", "")).is_empty():
		opening_question = handoff["question"]
	var has_handoff := not handoff.is_empty()
	var is_resume := TheatreSession.resume_requested
	if has_handoff:
		_intro_active = true
	else:
		_snap_to_gameplay_state()
	if is_resume:
		_setting_up_intro_game = true
		var restored := TheatreSession.restore_game()
		if restored:
			opening_question = str(TheatreSession.narrative.get("question", opening_question))
			_restore_table()
			_narrative.resume()
		_setting_up_intro_game = false
		if not restored:
			_intro_active = false
			TheatreSession.read_profile()
			get_tree().change_scene_to_file.call_deferred("res://scenes/theatre_menu.tscn")
			return
	else:
		_setting_up_intro_game = true
		GameManager.new_game(_seed, not opening_question.strip_edges().is_empty())
		_setting_up_intro_game = false
	if has_handoff:
		_play_enter_transition(handoff, is_resume)


func _request_agent_plan(context: Dictionary, complete: Callable, client: AgentClient, profile: Dictionary) -> void:
	client.send(context, profile, func(reply: Dictionary) -> void: complete.call(reply["plan"]))


func _gameplay_camera_transform() -> Transform3D:
	var basis := Basis.looking_at((GAMEPLAY_CAM_AIM - GAMEPLAY_CAM_POS).normalized(), Vector3.UP)
	return Transform3D(basis, GAMEPLAY_CAM_POS)


func _snap_to_gameplay_state() -> void:
	camera.global_transform = _gameplay_camera_transform()
	camera.fov = GAMEPLAY_CAM_FOV
	deck.visible = true
	deck.position = DECK_REST_POS
	deck.rotation = Vector3.ZERO
	deck.scale = Vector3.ONE
	dice.visible = true
	dice.position = DICE_REST_POS
	dice.scale = Vector3.ONE
	restart_button.visible = true
	restart_button.position = RESTART_REST_POS
	restart_button.scale = Vector3.ONE
	if ui != null and ui.root != null:
		ui.root.modulate.a = 1.0
	if theatre_set != null:
		theatre_set.hide_all_menu_props_immediately()
		theatre_set.set_curtains_open(true, false)
		theatre_set.set_gameplay_lighting(true, false)


func _make_intro_tween() -> Tween:
	var t := create_tween()
	_intro_tweens.append(t)
	return t


func _cancel_intro_immediately() -> void:
	_stop_intro_tweens()
	if not _intro_active:
		return
	_intro_active = false
	_snap_to_gameplay_state()


func _exit_tree() -> void:
	_stop_intro_tweens()


func _stop_intro_tweens() -> void:
	for t in _intro_tweens:
		if t != null and t.is_valid():
			t.kill()
	_intro_tweens.clear()


func _play_enter_transition(handoff: Dictionary, is_resume: bool) -> void:
	var start_xform: Transform3D = handoff.get("camera_transform", _gameplay_camera_transform())
	var start_fov: float = float(handoff.get("camera_fov", GAMEPLAY_CAM_FOV))
	var end_xform := _gameplay_camera_transform()
	var start_pos := start_xform.origin
	var end_pos := end_xform.origin
	var start_quat := start_xform.basis.get_rotation_quaternion().normalized()
	var end_quat := end_xform.basis.get_rotation_quaternion().normalized()

	camera.global_transform = start_xform
	camera.fov = start_fov
	if theatre_set != null:
		theatre_set.restore_curtains(handoff.get("curtains", {}))
		theatre_set.set_gameplay_lighting(false, false)
		theatre_set.disable_menu_hitboxes()
	if ui != null and ui.root != null:
		ui.root.modulate.a = 0.0
	dice.visible = false
	dice.position = DICE_REST_POS + Vector3(1.5, 0.85, 0.35)
	dice.scale = Vector3.ONE * 0.45
	restart_button.visible = false
	restart_button.position = RESTART_REST_POS + Vector3(1.8, 0.0, 0.0)
	restart_button.scale = Vector3.ONE * 0.6

	if theatre_set != null:
		theatre_set.set_gallery_open(true, false)
	var spawn_pos := theatre_set.get_gallery_deck_spawn_position() if theatre_set != null else Vector3(-3.85, 0.49, 1.70)
	deck.visible = true
	deck.global_position = spawn_pos
	deck.scale = Vector3.ONE * 0.48
	deck.rotation_degrees = Vector3(0.0, 103.0, 0.0)
	if theatre_set != null:
		theatre_set.replace_gallery_deck(deck)

	# Beat 1 (0.00s): Crane camera smoothly into gameplay pose, warm gameplay light, sweep menu props.
	var cam_tween := _make_intro_tween()
	var move_camera := _move_intro_camera.bind(start_pos, end_pos, start_quat, end_quat, start_fov)
	cam_tween.tween_method(move_camera, 0.0, 1.0, 1.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if theatre_set != null:
		theatre_set.set_gameplay_lighting(true, true, 1.15)
		theatre_set.clear_non_gallery_props(true)

	var timeline := _make_intro_tween().set_parallel(true)
	if theatre_set != null:
		timeline.tween_callback(theatre_set.stack_gallery_preview).set_delay(0.12)
		timeline.tween_callback(theatre_set.close_and_retire_gallery_chest).set_delay(0.70)
	timeline.tween_callback(_lift_intro_deck.bind(spawn_pos)).set_delay(0.34)
	timeline.tween_callback(_slide_intro_deck).set_delay(0.76)
	timeline.tween_callback(_bring_in_table_props).set_delay(0.98)
	timeline.tween_callback(Audio.play_sfx.bind("card_tap", -4.0)).set_delay(1.22)
	timeline.tween_callback(_finish_intro.bind(is_resume)).set_delay(1.40)


func _move_intro_camera(t: float, start_pos: Vector3, end_pos: Vector3, start_quat: Quaternion, end_quat: Quaternion, start_fov: float) -> void:
	camera.global_position = start_pos.lerp(end_pos, t)
	camera.global_basis = Basis(start_quat.slerp(end_quat, t)).orthonormalized()
	camera.fov = lerpf(start_fov, GAMEPLAY_CAM_FOV, t)


func _lift_intro_deck(spawn_pos: Vector3) -> void:
	Audio.play_sfx("card_fan_open", -4.0)
	var lift_pos := spawn_pos + Vector3(0.0, 1.15, 0.02)
	var lift_tween := _make_intro_tween()
	lift_tween.set_parallel(true)
	lift_tween.tween_property(deck, "position", lift_pos, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lift_tween.tween_property(deck, "scale", Vector3.ONE * 0.86, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	lift_tween.tween_property(deck, "rotation_degrees:y", 28.0, 0.28).set_delay(0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _slide_intro_deck() -> void:
	var deck_height: float = deck.position.y
	var arc_tween := _make_intro_tween()
	arc_tween.set_parallel(true)
	arc_tween.tween_property(deck, "position:x", DECK_REST_POS.x, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	arc_tween.tween_property(deck, "position:z", DECK_REST_POS.z, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	arc_tween.tween_property(deck, "scale", Vector3.ONE, 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arc_tween.tween_property(deck, "rotation_degrees:y", 0.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var arc_y := _make_intro_tween()
	arc_y.tween_property(deck, "position:y", deck_height + 0.16, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arc_y.tween_property(deck, "position:y", DECK_REST_POS.y, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _bring_in_table_props() -> void:
	dice.visible = true
	restart_button.visible = true
	var props_tween := _make_intro_tween()
	props_tween.set_parallel(true)
	props_tween.tween_property(dice, "position", DICE_REST_POS, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	props_tween.tween_property(dice, "scale", Vector3.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	props_tween.tween_property(restart_button, "position", RESTART_REST_POS, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	props_tween.tween_property(restart_button, "scale", Vector3.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if ui != null and ui.root != null:
		props_tween.tween_property(ui.root, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _finish_intro(is_resume: bool) -> void:
	_intro_active = false
	_intro_tweens.clear()
	_snap_to_gameplay_state()
	if is_resume:
		_restore_visual_cards()
		_on_state_changed()
	else:
		_apply_field_cards(GameManager.field_cards.duplicate())
	_refresh_narrative_preview()


func _style_dice_cost() -> void:
	if dice == null:
		return
	if dice._cost_sprite != null:
		dice._cost_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		dice._cost_sprite.pixel_size = 0.0033
	if dice._cost_label != null:
		dice._cost_label.add_theme_font_size_override("normal_font_size", 56)
		dice._cost_label.add_theme_color_override("font_outline_color", Color("#f8eedb"))
		dice._cost_label.add_theme_constant_override("outline_size", 6)


func _unhandled_key_input(event: InputEvent) -> void:
	if preparing_offscreen or _returning_to_menu:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			_return_to_menu()
			return
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
			_restart(_seed)
			return


func _return_to_menu() -> void:
	if _returning_to_menu:
		return
	_returning_to_menu = true
	var curtains := theatre_set.capture_curtains() if theatre_set != null else {}
	_cancel_intro_immediately()
	TheatreSession.tracking = false
	TheatreSession.begin_return_transition(camera.global_transform, camera.fov, curtains)
	var tree := get_tree()
	await tree.process_frame
	var menu := TablePreloader.take_menu()
	if menu != null:
		if tree.change_scene_to_node(menu) == OK:
			return
		menu.queue_free()
	if tree.change_scene_to_file("res://scenes/theatre_menu.tscn") != OK:
		TheatreSession.consume_return_transition()
		TheatreSession.tracking = true
		_returning_to_menu = false


func _read_seed() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			var value := arg.trim_prefix("--seed=")
			if value.is_valid_int():
				return int(value)
	return 0


func _slot_position(index: int) -> Vector3:
	return Vector3((index - 1) * CARD_SPACING, CARD_Y, CARD_Z)


func _on_field_cards_changed(cards: Array) -> void:
	if _intro_active or _roll_pending:
		return
	if _choice_animating:
		_pending_field_cards = cards.duplicate()
		_field_update_pending = true
		return
	_apply_field_cards(cards)


func _apply_field_cards(cards: Array) -> void:
	_field_deal_id += 1
	var deal_id := _field_deal_id
	var incoming: Array[Dictionary] = []
	for i in 3:
		var runtime: Dictionary = {}
		if i < cards.size() and cards[i] != null:
			runtime = cards[i]
		var node: Card3D = _slot_cards[i]
		if runtime.is_empty():
			if node != null and is_instance_valid(node):
				node.queue_free()
			_slot_cards[i] = null
			continue
		var target := _slot_position(i)
		var card_id := int(runtime["card_id"])
		if node != null and is_instance_valid(node) and node.card_id == card_id:
			node.base_position = target
			if not _roll_pending:
				node.set_state(str(runtime["orientation"]))
				node.set_effect_text(_effect_text(card_id, str(runtime["orientation"])))
				_style_card_labels(node)
			continue
		if node != null and is_instance_valid(node):
			node.queue_free()
		_slot_cards[i] = null
		incoming.append({
			"slot": i,
			"runtime": runtime,
			"target": target,
		})
	_apply_selection_visual()
	_deal_next(incoming, deal_id)


func _deal_next(incoming: Array[Dictionary], deal_id: int) -> void:
	if incoming.is_empty() or deal_id != _field_deal_id:
		return
	var request: Dictionary = incoming.pop_front()
	var slot := int(request["slot"])
	var runtime: Dictionary = request["runtime"]
	var target: Vector3 = request["target"]
	var orientation := str(runtime["orientation"])
	var card_id := int(runtime["card_id"])
	var pivot := Node3D.new()
	pivot.position = card_root.to_local(deck.top_card_position())
	card_root.add_child(pivot)
	var card := _make_field_card(pivot, card_id, target, orientation)
	card.scale = Vector3.ONE * 0.9
	card.animation_locked = true
	card.area.input_ray_pickable = false
	_slot_cards[slot] = card
	Audio.play_sfx("card_draw", -4.0)
	deck.draw_cards(1)
	_animate_card_draw(pivot, card, _animate_card_entry.bind(card, target, orientation, _deal_next.bind(incoming, deal_id), slot))


func _make_field_card(parent: Node3D, id: int, target: Vector3, orientation: String) -> Card3D:
	var card: Card3D = CARD_SCENE.instantiate()
	parent.add_child(card)
	card.setup(id, _texture_for(id))
	card.front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	card.back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	card.base_position = target
	card.set_effect_text(_effect_text(id, orientation))
	_style_card_labels(card)
	card.clicked.connect(_on_card_clicked)
	card.accept_pressed.connect(_on_card_accept)
	card.refuse_pressed.connect(_on_card_refuse)
	return card


func _style_card_labels(card: Card3D) -> void:
	if card == null or not is_instance_valid(card):
		return
	if card._effect_viewport != null:
		card._effect_viewport.size.y = 216
	if card._effect_sprite != null:
		card._effect_sprite.pixel_size = 0.0030
		card._effect_sprite.position.y = 1.56
	if card._effect_label != null:
		card._effect_label.add_theme_font_size_override("normal_font_size", 46)
		card._effect_label.add_theme_color_override("default_color", Color("#fff3d6"))
		card._effect_label.add_theme_color_override("font_outline_color", Color("#12061b"))
		card._effect_label.add_theme_constant_override("outline_size", 8)
	for action_label in [card._accept_label, card._reject_label]:
		if action_label != null:
			action_label.add_theme_color_override("font_outline_color", Color("#f6ebd5"))
			action_label.add_theme_constant_override("outline_size", 6)


func _restore_table() -> void:
	_on_game_started(GameManager.rng_seed)
	deck.draw_cards(GameManager.TOTAL_CARDS - GameManager.deck.size())
	if not _intro_active:
		_restore_visual_cards()
	_on_state_changed()
	GameManager.state_changed.emit()


func _restore_visual_cards() -> void:
	for i in GameManager.field_cards.size():
		var runtime: Variant = GameManager.field_cards[i]
		if runtime == null or (not GameManager.pending_new_mark.is_empty() and i == GameManager.selected_slot):
			continue
		var target := _slot_position(i)
		var card := _make_field_card(card_root, runtime.card_id, target, runtime.orientation)
		card.position = target
		card.set_state(runtime.orientation, false)
		_slot_cards[i] = card
	_rebuild_hand()
	_apply_selection_visual()


func _animate_card_draw(pivot: Node3D, card: Card3D, on_drawn: Callable, reveal_sound: bool = false) -> void:
	pivot.rotation.z = PI
	card.set_back_visible(true)
	var start_y := pivot.position.y
	var draw := pivot.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	draw.tween_property(pivot, "rotation:z", 0.0, 0.50).set_trans(Tween.TRANS_LINEAR)
	draw.tween_property(pivot, "position:y", start_y + 0.8, 0.25).set_ease(Tween.EASE_OUT)
	draw.tween_callback(_reveal_drawn_card.bind(card, reveal_sound)).set_delay(0.25)
	draw.tween_property(pivot, "position:y", start_y + 0.2, 0.25).from(start_y + 0.8).set_delay(0.25).set_ease(Tween.EASE_IN)
	draw.finished.connect(_finish_card_draw.bind(pivot, card, on_drawn), CONNECT_ONE_SHOT)


func _reveal_drawn_card(card: Variant, reveal_sound: bool) -> void:
	if is_instance_valid(card):
		card.set_back_visible(false)
		if reveal_sound:
			Audio.play_sfx("card_reveal", -2.0)


func _finish_card_draw(pivot: Node3D, card: Variant, on_drawn: Callable) -> void:
	pivot.queue_free()
	if not is_instance_valid(card) or card.is_queued_for_deletion():
		return
	card.reparent(card_root, true)
	on_drawn.call()


func _animate_card_entry(card: Card3D, target: Vector3, orientation: String, on_entered: Callable, slot: int = -1) -> void:
	Audio.play_sfx("card_slide", -7.0)
	var tween := card.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "position", target, CARD_MOVE_TIME)
	tween.tween_property(card, "scale", Vector3.ONE, CARD_MOVE_TIME * 0.8)
	tween.finished.connect(_finish_card_travel.bind(card, target, orientation, on_entered, slot), CONNECT_ONE_SHOT)


func _finish_card_travel(card: Card3D, target: Vector3, orientation: String, on_entered: Callable, slot: int) -> void:
	if slot >= 0:
		var runtime: Variant = GameManager.field_cards[slot]
		if runtime != null and runtime["card_id"] == card.card_id:
			orientation = str(runtime["orientation"])
			card.set_effect_text(_effect_text(card.card_id, orientation))
			_style_card_labels(card)
	var target_reversed := orientation.to_upper() == "REVERSED"
	if card.is_reversed != target_reversed:
		Audio.play_sfx("card_flip", -5.0)
		card.set_state(orientation)
		if card._flip_tween != null and card._flip_tween.is_valid():
			card._flip_tween.finished.connect(_finish_card_entry.bind(card, target, on_entered), CONNECT_ONE_SHOT)
			return
	_finish_card_entry(card, target, on_entered)


func _finish_card_entry(card: Card3D, target: Vector3, on_entered: Callable) -> void:
	card.animation_locked = false
	card.base_position = target
	card.area.input_ray_pickable = true
	_apply_selection_visual()
	on_entered.call()


func _on_card_clicked(card_id: int) -> void:
	if not _can_choose():
		return
	Audio.play_sfx("card_tap", -5.0)
	GameManager.select_card(card_id)


func _on_selected_card_changed(_card_id: int, _slot: int) -> void:
	_apply_selection_visual()
	_refresh_narrative_preview()


func _on_card_accept() -> void:
	if _can_choose():
		GameManager.accept_selected()


func _on_card_refuse() -> void:
	if _can_choose():
		GameManager.refuse_selected()


func _can_choose() -> bool:
	return (
		GameManager.phase == GameManager.Phase.SELECT and not _intro_active and not _returning_to_menu
		and not _choice_animating and not _roll_pending and not _narrative.is_playing()
	)


func _on_choice_committed(accepted: bool, card_id: int, slot: int) -> void:
	if _choice_animating:
		return
	if slot < 0 or slot >= _slot_cards.size():
		return
	var card: Card3D = _slot_cards[slot]
	if card == null or not is_instance_valid(card) or card.card_id != card_id:
		return
	for other in _slot_cards:
		if other != null and is_instance_valid(other):
			other.hide_actions()
	_choice_animating = true
	_defer_hand_rebuild = accepted
	card.animation_locked = true
	card.set_selected(false)
	card.set_dimmed(false)
	card.set_effect_text("")
	card.area.input_ray_pickable = false
	# A full hand holds the accepted card above the fan so the player drops one first.
	var hold := accepted and GameManager.marks.size() >= GameManager.MAX_MARKS
	if hold:
		_hold_slot = slot
		_pending_hold_card = card
		_lift_hand()
		return
	var accept_layout: Dictionary = {}
	var hand_count := 0
	if accepted:
		hand_count = GameManager.marks.size() + 1
		accept_layout = _hand_slot_layout(hand_count - 1, hand_count)
	_play_choice_exit(card, accepted, slot, accept_layout, hand_count)


func _lift_hand() -> void:
	if _hand_lift_tween != null and _hand_lift_tween.is_valid():
		_hand_lift_tween.kill()
	_hand_lift_tween = create_tween()
	_hand_lift_tween.set_parallel(true)
	_hand_lift_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for holder in _hand_holders:
		if holder == null or not is_instance_valid(holder):
			continue
		_hand_lift_tween.tween_property(holder, "position:y", holder.position.y + 0.15, 0.36)


func _animate_hand_gap(count: int) -> void:
	if _hand_lift_tween != null and _hand_lift_tween.is_valid():
		_hand_lift_tween.kill()
	if count <= 1 or _hand_holders.is_empty():
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in _hand_holders.size():
		var holder: Node3D = _hand_holders[i]
		if holder == null or not is_instance_valid(holder):
			continue
		var layout := _hand_slot_layout(i, count)
		tween.tween_property(holder, "position", layout["position"], 0.40)
		tween.tween_property(holder, "rotation:y", float(layout["yaw"]), 0.40)
	await tween.finished


func _play_choice_exit(card: Card3D, accepted: bool, slot: int, accept_layout: Dictionary, hand_count: int) -> void:
	var generation := _table_generation
	await get_tree().create_timer(0.08).timeout
	if generation != _table_generation:
		return
	if not is_instance_valid(card):
		_after_choice_exit(accepted, slot)
		return
	if accepted:
		await _animate_hand_gap(hand_count)
		if generation != _table_generation or not is_instance_valid(card):
			return
		Audio.play_sfx("card_slide", -3.0)
	else:
		Audio.play_sfx("card_discard", -3.0)
	var target: Vector3
	var target_scale: Vector3
	var target_yaw: float
	if accepted:
		target = accept_layout["position"]
		target_scale = Vector3.ONE * float(accept_layout["scale"])
		target_yaw = float(accept_layout["yaw"])
	else:
		target = DISCARD_POS
		target_scale = Vector3.ONE * 0.82
		target_yaw = card.rotation.y + deg_to_rad(30.0)
	var move_time := CARD_MOVE_TIME
	if accepted:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(card, "position", target, move_time)
		tween.tween_property(card, "scale", target_scale, move_time)
		tween.tween_property(card, "rotation:y", target_yaw, move_time)
		await tween.finished
	else:
		var move := create_tween()
		move.set_parallel(true)
		move.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		move.tween_property(card, "position:x", target.x, move_time)
		move.tween_property(card, "position:z", target.z, move_time)
		move.tween_property(card, "scale", target_scale, move_time)
		move.tween_property(card, "rotation:y", target_yaw, move_time)
		var lift := create_tween()
		lift.tween_property(card, "position:y", target.y, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await lift.finished
		await move.finished
	if generation != _table_generation:
		return
	if is_instance_valid(card):
		card.queue_free()
	_after_choice_exit(accepted, slot)


func _after_choice_exit(accepted: bool, slot: int) -> void:
	if slot >= 0 and slot < _slot_cards.size():
		_slot_cards[slot] = null
	_defer_hand_rebuild = false
	if accepted:
		_rebuild_hand()
	_apply_pending_field()


func _apply_pending_field() -> void:
	if not _field_update_pending:
		_choice_animating = false
		_show_world_if_ready()
		return
	var generation := _table_generation
	await get_tree().create_timer(0.08).timeout
	if generation != _table_generation:
		return
	_field_update_pending = false
	var cards := _pending_field_cards
	_pending_field_cards = []
	_choice_animating = false
	_apply_field_cards(cards)
	_show_world_if_ready()


func _apply_selection_visual() -> void:
	var has_selection: bool = int(GameManager.selected_card) >= 0
	for card in _slot_cards:
		if card == null or not is_instance_valid(card):
			continue
		var is_selected: bool = card.card_id == int(GameManager.selected_card)
		card.set_selected(is_selected)
		card.set_dimmed(has_selection and not is_selected)
	_refresh_card_actions()


func _refresh_card_actions() -> void:
	for card in _slot_cards:
		if card != null and is_instance_valid(card):
			card.hide_actions()
	if not _can_choose() or GameManager.selected_slot < 0:
		return
	var card: Card3D = _slot_cards[GameManager.selected_slot]
	var runtime := GameManager.get_selected_runtime()
	if card == null or not is_instance_valid(card) or runtime.is_empty():
		return
	var o_data := CardDatabase.orientation_data(int(runtime["card_id"]), str(runtime["orientation"]).to_lower())
	card.show_actions(o_data.get("accept", []), o_data.get("refuse", []))
	_style_card_labels(card)


func _on_orientation_rolled(value: int) -> void:
	_roll_pending = true
	_refresh_narrative_preview()
	for card in _slot_cards:
		if card != null and is_instance_valid(card):
			card.hide_actions()
	dice.roll_to(value)


func _on_die_roll_finished(_value: int) -> void:
	if not _roll_pending:
		return
	_roll_pending = false
	var any_flip := false
	for i in _slot_cards.size():
		var card: Card3D = _slot_cards[i]
		var runtime = GameManager.field_cards[i] if i < GameManager.field_cards.size() else null
		if card != null and is_instance_valid(card) and not card.animation_locked and runtime != null:
			var target_reversed := str(runtime["orientation"]).to_upper() == "REVERSED"
			if card.is_reversed != target_reversed:
				any_flip = true
			card.set_state(str(runtime["orientation"]))
			card.set_effect_text(_effect_text(int(runtime["card_id"]), str(runtime["orientation"])))
			_style_card_labels(card)
	if any_flip:
		Audio.play_sfx("card_flip", -4.0)
	_refresh_card_actions()
	_refresh_narrative_preview()


func _on_die_clicked() -> void:
	if _can_choose():
		Audio.play_sfx("dice_roll", -2.0)
		GameManager.roll_die()


func _on_game_started(_seed_value: int) -> void:
	_table_generation += 1
	_field_deal_id += 1
	if _intro_active and not _setting_up_intro_game:
		_cancel_intro_immediately()
	Audio.start_music()
	restart_button.set_highlight(false)
	_roll_pending = false
	dice.reset(int(GameManager.die_value))
	deck.reset()
	_clear_cards()
	_clear_hand()
	_clear_hold_card()
	_hold_slot = -1
	_world_shown = false
	_choice_animating = false
	_defer_hand_rebuild = false
	_hand_discarding = false
	_field_update_pending = false
	_pending_field_cards = []


func _on_narrative_started(_seed_value: int) -> void:
	if _narrative_stage != null:
		_narrative_stage.clear()
	_narrative.begin(opening_question)


func _ensure_narrative_stage() -> void:
	if _narrative_stage != null:
		return
	_narrative_stage = NarrativeStage.new()
	add_child(_narrative_stage)
	_narrative_stage.beat_finished.connect(_narrative.finish_beat)
	_narrative_stage.beat_finished.connect(_refresh_card_actions)
	_narrative_stage.beat_finished.connect(_refresh_narrative_preview)
	_narrative_stage.finale_acknowledged.connect(_narrative.acknowledge_finale)


func _play_narrative_beat(beat: Dictionary, finale: bool) -> void:
	_ensure_narrative_stage()
	_narrative_stage.play(beat, finale)


func _refresh_narrative_preview() -> void:
	if _narrative.is_playing():
		return
	var line := _narrative.preview_for(GameManager.selected_card) if _can_choose() else ""
	var heading := ""
	if _can_choose() and GameManager.choice_limit == GameManager.STORY_CHOICES:
		heading = NarrativeSkills.heading(GameManager.choices_completed + 1)
	if not line.is_empty() or not heading.is_empty():
		_ensure_narrative_stage()
	if _narrative_stage != null:
		_narrative_stage.preview(line, heading)


func _on_turn_resolved(result: Dictionary) -> void:
	# A fatal card effect can end the run before the held card can enter the hand.
	if result["state"]["reason"] != "reason.death" or _hold_slot < 0 or _hand_discarding:
		return
	var card := _pending_hold_card
	var slot := _hold_slot
	_pending_hold_card = null
	_hold_slot = -1
	if is_instance_valid(card):
		if _hand_lift_tween != null and _hand_lift_tween.is_valid():
			_hand_lift_tween.kill()
		_rebuild_hand()
		_play_choice_exit(card, false, slot, {}, 0)
	else:
		_after_choice_exit(false, slot)


func _on_language_changed() -> void:
	for i in _slot_cards.size():
		var card: Card3D = _slot_cards[i]
		var runtime = GameManager.field_cards[i] if i < GameManager.field_cards.size() else null
		if card != null and is_instance_valid(card) and runtime != null:
			card.refresh_language()
			card.set_effect_text(_effect_text(int(runtime["card_id"]), str(runtime["orientation"])))
			_style_card_labels(card)
	for i in _hand_cards.size():
		var hand_card: Card3D = _hand_cards[i]
		var mark = GameManager.marks[i] if i < GameManager.marks.size() else null
		if hand_card != null and is_instance_valid(hand_card) and mark != null:
			var text := _effect_text(int(mark["card_id"]), str(mark["orientation"]))
			hand_card.refresh_language()
			hand_card.set_hover_effect_text(text)
			if hand_card.hovered:
				hand_card.set_effect_text(text)
				_style_card_labels(hand_card)


func _on_state_changed() -> void:
	_apply_selection_visual()
	restart_button.set_highlight(GameManager.phase == GameManager.Phase.GAME_OVER)
	_show_world_if_ready()


func _show_world_if_ready() -> void:
	if not _intro_active and (GameManager.phase == GameManager.Phase.FINAL or (GameManager.phase == GameManager.Phase.GAME_OVER and GameManager.game_over_reason_key == "reason.world_end")):
		_show_world()


func _on_restart_pressed() -> void:
	_restart(0)


func _restart(seed_value: int) -> void:
	if GameManager.phase == GameManager.Phase.GAME_OVER and _narrative.is_playing():
		return
	GameManager.new_game(seed_value, not opening_question.strip_edges().is_empty())


func _show_world() -> void:
	if _world_shown or _choice_animating:
		return
	_world_shown = true
	_field_deal_id += 1
	_clear_cards()
	var target := _slot_position(1)
	var pivot := Node3D.new()
	pivot.position = card_root.to_local(deck.top_card_position())
	card_root.add_child(pivot)
	_world_card = CARD_SCENE.instantiate()
	pivot.add_child(_world_card)
	_world_card.position = Vector3.ZERO
	_world_card.setup(WORLD_ID, _texture_for(WORLD_ID))
	_world_card.front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	_world_card.back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	_world_card.base_position = target
	_world_card.scale = Vector3.ONE * 0.9
	_world_card.animation_locked = true
	_world_card.area.input_ray_pickable = false
	Audio.play_sfx("card_draw", -4.0)
	_animate_card_draw(pivot, _world_card, _finish_world_draw.bind(_world_card, target), true)


func _finish_world_draw(card: Card3D, target: Vector3) -> void:
	deck.hide_all()
	_animate_card_entry(card, target, "UPRIGHT", _finish_world_entry.bind(card))


func _finish_world_entry(card: Card3D) -> void:
	card.area.input_ray_pickable = false
	card.set_world_display()
	card.set_selected(true)


func _clear_cards() -> void:
	if _world_card != null and is_instance_valid(_world_card):
		_world_card.queue_free()
	_world_card = null
	for card in _slot_cards:
		if card != null and is_instance_valid(card):
			card.queue_free()
	_slot_cards = [null, null, null]


func _on_marks_changed(_marks: Array) -> void:
	if _intro_active or _defer_hand_rebuild:
		return
	_rebuild_hand()


func _hand_slot_layout(index: int, count: int) -> Dictionary:
	var center := (count - 1) * 0.5
	var offset := float(index) - center
	var spacing := HAND_SPACING if count <= 5 else 0.72
	var layer := HAND_STACK_STEP if offset > 0.0 else 0.0
	return {
		"position": Vector3(
			offset * spacing,
			CARD_Y + absf(offset) * 0.08 + layer,
			HAND_Z + offset * 0.05
		),
		"yaw": deg_to_rad(-offset * HAND_FAN_DEGREES),
		"scale": HAND_SCALE,
	}


func _rebuild_hand() -> void:
	_clear_hand()
	var count := GameManager.marks.size()
	for i in count:
		var mark: Dictionary = GameManager.marks[i]
		var card_id := int(mark["card_id"])
		var orientation := str(mark["orientation"])
		var layout := _hand_slot_layout(i, count)
		var holder := Node3D.new()
		holder.position = layout["position"]
		holder.rotation.y = float(layout["yaw"])
		holder.scale = Vector3.ONE * float(layout["scale"])
		_hand_root.add_child(holder)
		var card: Card3D = CARD_SCENE.instantiate()
		holder.add_child(card)
		card.setup(card_id, _texture_for(card_id))
		card.set_shadows_enabled(false)
		card.set_state(orientation, false)
		card.set_effect_text("")
		card.set_hover_effect_text(_effect_text(card_id, orientation))
		card.area.mouse_entered.connect(_style_card_labels.bind(card))
		card.clicked.connect(_on_hand_card_clicked.bind(card_id))
		_hand_holders.append(holder)
		_hand_cards.append(card)
	# The incoming card (hand already full) floats above the fan until one is dropped.
	if not GameManager.pending_new_mark.is_empty():
		_ensure_hold_card()
	else:
		_clear_hold_card()


func _on_hand_card_clicked(_emitted_id: int, card_id: int) -> void:
	if _intro_active or GameManager.pending_new_mark.is_empty() or _hand_discarding:
		return
	_discard_and_replace(card_id)


func _discard_and_replace(card_id: int) -> void:
	var generation := _table_generation
	# Drop the chosen card first, then fly the held card into the opened slot.
	var idx := -1
	for i in _hand_cards.size():
		if is_instance_valid(_hand_cards[i]) and _hand_cards[i].card_id == card_id:
			idx = i
			break
	if idx < 0:
		return
	_hand_discarding = true
	_choice_animating = true
	_defer_hand_rebuild = true
	var holder: Node3D = _hand_holders[idx]
	_hand_holders.remove_at(idx)
	_hand_cards.remove_at(idx)
	GameManager.replace_mark(card_id)
	await _animate_hand_drop(holder)
	if generation != _table_generation:
		return
	await _animate_hand_gap(GameManager.marks.size())
	if generation != _table_generation:
		return
	await _animate_hold_into_hand()
	if generation != _table_generation:
		return
	if _hold_slot >= 0 and _hold_slot < _slot_cards.size() and _slot_cards[_hold_slot] == _pending_hold_card:
		_slot_cards[_hold_slot] = null
	_hold_slot = -1
	_defer_hand_rebuild = false
	_hand_discarding = false
	_rebuild_hand()
	_apply_pending_field()


func _animate_hand_drop(holder: Node3D) -> void:
	if holder == null or not is_instance_valid(holder):
		return
	Audio.play_sfx("card_discard", -3.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(holder, "position", holder.position + Vector3(0.0, -0.4, 1.6), 0.36)
	tween.tween_property(holder, "scale", holder.scale * 0.4, 0.36)
	tween.tween_property(holder, "rotation:y", holder.rotation.y + deg_to_rad(40.0), 0.36)
	await tween.finished
	if is_instance_valid(holder):
		holder.queue_free()


func _animate_hold_into_hand() -> void:
	if _pending_hold_card == null or not is_instance_valid(_pending_hold_card):
		return
	var count := GameManager.marks.size()
	if count <= 0:
		return
	var layout := _hand_slot_layout(count - 1, count)
	var card := _pending_hold_card
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "position", layout["position"], 0.50)
	tween.tween_property(card, "scale", Vector3.ONE * float(layout["scale"]), 0.50)
	tween.tween_property(card, "rotation:y", float(layout["yaw"]), 0.50)
	await tween.finished


func _ensure_hold_card() -> void:
	if _pending_hold_card != null and is_instance_valid(_pending_hold_card):
		return
	var pending := GameManager.pending_new_mark
	if pending.is_empty():
		return
	var card_id := int(pending["card_id"])
	var card: Card3D = CARD_SCENE.instantiate()
	card.position = HAND_HOLD_POS
	card.scale = Vector3.ONE * HAND_HOLD_SCALE
	card_root.add_child(card)
	card.setup(card_id, _texture_for(card_id))
	card.set_shadows_enabled(false)
	card.set_state(str(pending["orientation"]), false)
	card.area.input_ray_pickable = false
	_pending_hold_card = card


func _clear_hold_card() -> void:
	if _pending_hold_card != null and is_instance_valid(_pending_hold_card):
		_pending_hold_card.queue_free()
	_pending_hold_card = null


func _clear_hand() -> void:
	for holder in _hand_holders:
		if holder != null and is_instance_valid(holder):
			holder.queue_free()
	_hand_holders.clear()
	_hand_cards.clear()


func _effect_text(card_id: int, orientation: String) -> String:
	var o_data := CardDatabase.orientation_data(card_id, orientation.to_lower())
	return str(o_data.get("mark_text_" + Loc.language, o_data.get("mark_text_en", "")))


func _texture_for(card_id: int) -> Texture2D:
	if _textures.has(card_id):
		return _textures[card_id]
	var path := CardDatabase.texture_path(card_id)
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			texture = loaded
	if texture == null:
		push_warning("Cat-Tarot: missing card texture, using placeholder: " + path)
	_textures[card_id] = texture
	return texture
