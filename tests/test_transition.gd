extends Node

var passed: int = 0
var failed: int = 0
var profile: String = ""


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	profile = "user://test_transition_%d.dat" % OS.get_process_id()
	TheatreSession.profile_path = profile
	TheatreSession.tracking = false
	TheatreSession.resume_requested = false
	TheatreSession.consume_enter_transition()
	TheatreSession.consume_return_transition()
	TheatreSession.read_profile()

	var tree := get_tree()
	await _test_splash_to_menu_to_start(tree)
	await _test_esc_return_and_continue_resume(tree)
	await _test_direct_main_skips_intro(tree)

	Audio.stop_music()
	TheatreSession.tracking = false
	TheatreSession.resume_requested = false
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile + suffix):
			DirAccess.remove_absolute(profile + suffix)
	print("Transition test results: %d passed, %d failed" % [passed, failed])
	tree.quit(1 if failed > 0 else 0)


func _test_splash_to_menu_to_start(tree: SceneTree) -> void:
	var rules_before := GameManager.capture_checkpoint()
	var splash := preload("res://scenes/splash_screen.tscn").instantiate()
	tree.root.add_child(splash)
	tree.current_scene = splash
	splash._finish_immediately()
	await tree.scene_changed

	var menu := tree.current_scene
	check(menu != null and menu.scene_file_path.ends_with("theatre_menu.tscn"), "splash transitions to theatre_menu.tscn")
	check(TablePreloader.finished and is_instance_valid(TablePreloader._table), "splash prepares the table before showing the menu")
	check_eq(GameManager.capture_checkpoint(), rules_before, "warming the table leaves the rules untouched")
	check(TheatreSession.checkpoint.is_empty(), "warming does not save a run")
	var warmed_id: int = TablePreloader._table.get_instance_id() if is_instance_valid(TablePreloader._table) else 0
	await tree.physics_frame
	await tree.physics_frame

	check_approx(menu.stage.gallery_lid.rotation_degrees.x, TheatreSet.GALLERY_LID_CLOSED_X, 0.05, "gallery starts closed")
	check(menu.stage.gallery_deck.visible, "the gallery has a deck inside")
	check(not menu.stage.gallery_preview_cards[0].visible, "closed gallery conceals the fan")
	menu.keyboard_focus = true
	menu._set_focus(TheatreSet.GALLERY)
	var gallery_open := await _wait_until(tree, func() -> bool:
		return absf(menu.stage.gallery_lid.rotation_degrees.x - TheatreSet.GALLERY_LID_OPEN_X) < 0.05
	, 1.0)
	check(gallery_open, "hover opens the gallery lid")
	for face: MeshInstance3D in menu.stage.gallery_preview_cards:
		check(face.visible and face.global_position.y > menu.stage.gallery_deck.top_card_position().y, "hover fans the card above the deck")
	menu._set_focus(-1)
	var gallery_closed := await _wait_until(tree, func() -> bool:
		return not menu.stage.gallery_preview_cards[0].visible and absf(menu.stage.gallery_lid.rotation_degrees.x) < 0.05
	, 1.0)
	check(gallery_closed, "leaving the gallery closes the lid and hides the cards")

	menu._activate(TheatreSet.START)
	await tree.create_timer(0.20).timeout
	var moving_cloth: Dictionary = menu.stage.capture_curtains()
	check(moving_cloth["openness"] > 0.0 and moving_cloth["openness"] < 1.0, "the curtain rail moves during opening")
	var points: PackedVector3Array = moving_cloth["panels"][0]["positions"]
	check(points[points.size() - 1].x > points[12].x + 0.05, "the curtain hem trails the rail rather than scaling uniformly")
	await tree.scene_changed

	var main := tree.current_scene
	check(main != null and main.scene_file_path.ends_with("main.tscn"), "TheatreSet.START transitions to main.tscn")
	if main == null:
		return
	check_eq(main.get_instance_id(), warmed_id, "START promotes the warmed table instead of rebuilding it")
	check(not TablePreloader.finished and TablePreloader._table == null, "handoff clears the staging slot")

	# Frame 0 assertions right after entering from theatre_menu.
	check(main.is_intro_active(), "main.is_intro_active() is true right after menu START")
	check_eq(main.theatre_set.capture_curtains(), menu.stage.capture_curtains(), "the new scene inherits the cloth and the rail's running motion")
	check(main.theatre_set.get_curtain_openness() < 1.0, "the curtain keeps opening in the gameplay shot")
	check(
		main.camera.global_position.distance_to(Vector3(0.0, 3.94, 13.1)) < 0.85,
		"camera.global_position starts near theatre_menu HOME"
	)
	var spawn_pos: Vector3 = main.theatre_set.get_gallery_deck_spawn_position()
	check(
		main.deck.global_position.distance_to(spawn_pos) < 0.25,
		"Deck3D starts inside Gallery chest cavity"
	)
	check(main.deck.scale.x < 0.7, "Deck3D starts scaled inside chest cavity")
	check_approx(main.theatre_set.gallery_lid.rotation_degrees.x, TheatreSet.GALLERY_LID_OPEN_X, 0.05, "the chest stays open across the handoff")
	check(main.theatre_set.gallery_preview_cards[0].visible, "the preview fan is present at the opening frame")
	check(not main.theatre_set.gallery_deck.visible, "the gameplay deck takes the place of the menu deck")
	check_eq(GameManager.field_cards.size(), 3, "GameManager field_cards valid on frame 0")
	check_eq(GameManager.deck.size(), 18, "GameManager deck valid on frame 0")
	check_eq(TheatreSession.collected.size(), 3, "TheatreSession.collected has 3 opening cards on frame 0")

	# Wait through intro choreography (~1.4s -> check around ~2.0s that intro finished).
	var intro_done := await _wait_until(tree, func() -> bool:
		return not main.is_intro_active()
	, 3.2)
	check(intro_done, "intro choreography finishes within 3.2s")
	check(not main.is_intro_active(), "main.is_intro_active() is false after intro choreography")
	check(not main.theatre_set.is_physics_processing(), "settled curtains stop using physics time")

	# Wait for the 3 opening field cards to finish dealing onto the velvet cloth.
	var deal_done := await _wait_until(tree, func() -> bool:
		for i in 3:
			var card = main._slot_cards[i]
			if card == null or not is_instance_valid(card) or card.animation_locked:
				return false
		return true
	, 6.0)
	check(deal_done, "3 opening field cards finish dealing within 6.0s")

	for i in 5:
		check(not main.theatre_set.props[i].visible, "menu prop %d hidden after intro" % i)
	check(not main.theatre_set.loose_card.visible, "loose_card hidden after intro")
	for hitbox in main.theatre_set.prop_hitboxes:
		check(hitbox.collision_layer == 0 and not hitbox.input_ray_pickable, "menu prop hitbox disabled in gameplay")

	check(main.deck.global_position.distance_to(main.DECK_REST_POS) < 0.02, "Deck3D rests at DECK_REST_POS")
	check(main.deck.scale.is_equal_approx(Vector3.ONE), "Deck3D settles at Vector3.ONE")
	check(main.dice.global_position.distance_to(main.DICE_REST_POS) < 0.02, "Dice3D rests at DICE_REST_POS")
	check(main.restart_button.global_position.distance_to(main.RESTART_REST_POS) < 0.02, "RestartButton3D rests at RESTART_REST_POS")
	check(main.camera.global_position.distance_to(main.GAMEPLAY_CAM_POS) < 0.03, "camera settles at GAMEPLAY_CAM_POS")
	check_approx(main.camera.fov, main.GAMEPLAY_CAM_FOV, 0.25, "camera settles at GAMEPLAY_CAM_FOV")

	for i in 3:
		var slot_card = main._slot_cards[i]
		check(slot_card != null and is_instance_valid(slot_card), "field card %d dealt onto velvet cloth" % i)
		if slot_card != null:
			check(
				slot_card.position.distance_to(main._slot_position(i)) < 0.03,
				"field card %d rests at slot position" % i
			)


func _test_esc_return_and_continue_resume(tree: SceneTree) -> void:
	var main := tree.current_scene
	if main == null or not main.scene_file_path.ends_with("main.tscn"):
		return

	# Accept Fool upright in slot 0 so checkpoint has both field cards and a held mark.
	GameManager.debug_set_field_card(0, 0, "UPRIGHT")
	var re_deal_done := await _wait_until(tree, func() -> bool:
		var c = main._slot_cards[0]
		return c != null and is_instance_valid(c) and c.card_id == 0 and not c.animation_locked
	, 3.0)
	check(re_deal_done, "slot 0 ready before accepting mark for resume checkpoint")
	main._on_card_clicked(0)
	await tree.process_frame
	main._on_card_accept()
	var accept_done := await _wait_until(tree, func() -> bool:
		var c = main._slot_cards[0]
		return (
			GameManager.phase == GameManager.Phase.SELECT
			and GameManager.marks.size() == 1
			and not main._choice_animating
			and c != null
			and is_instance_valid(c)
			and not c.animation_locked
		)
	, 4.5)
	check(accept_done, "accept completes and refills field before Esc return")

	var expected_field: Array = GameManager.field_cards.duplicate(true)
	var expected_marks: Array = GameManager.marks.duplicate(true)
	check_eq(expected_marks.size(), 1, "checkpoint holds 1 hand mark before Esc")

	var gameplay_cam_pos: Vector3 = main.GAMEPLAY_CAM_POS
	var cached_menu_id: int = TablePreloader._menu.get_instance_id() if is_instance_valid(TablePreloader._menu) else 0
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	main._unhandled_key_input(esc)
	await tree.scene_changed

	var menu := tree.current_scene
	check(menu != null and menu.scene_file_path.ends_with("theatre_menu.tscn"), "Esc returns to theatre_menu.tscn")
	if menu == null:
		return
	check_eq(menu.get_instance_id(), cached_menu_id, "Esc restores the original menu instance")

	# Immediately after scene switch, camera should start from gameplay pose (not snapped to HOME).
	check(
		menu.camera.global_position.distance_to(gameplay_cam_pos) < 1.2,
		"return camera hands off smoothly from gameplay position"
	)
	check(menu.camera.fov > 36.0, "return camera hands off gameplay FOV")
	check(menu.stage.get_curtain_openness() > 0.9, "curtains start open on return transition")

	await tree.create_timer(1.05).timeout
	await tree.physics_frame
	await tree.physics_frame

	check_approx(menu.stage.get_curtain_openness(), 0.0, 0.03, "the curtain rail returns closed")
	for panel: Node3D in menu.stage.curtains:
		check_approx(panel.scale.x, 1.0, 0.03, "cloth deformation preserves the model scale")
	for i in 5:
		check(menu.stage.props[i].visible, "menu prop %d visible after return" % i)
		check(
			menu.stage.props[i].position.distance_to(menu.stage.base_positions[i]) < 0.03,
			"menu prop %d returns to base_position" % i
		)
		var center: Vector3 = menu.stage.props[i].global_position
		if i == TheatreSet.START:
			center = menu.stage.ticket.global_position
		check_eq(menu._pick(menu.camera.unproject_position(center)), i, "returned prop %d remains pickable" % i)
	check(
		menu.stage.loose_card.visible and menu.stage.loose_card.position.distance_to(menu.stage.loose_card_base_pos) < 0.03,
		"loose_card returns to base position"
	)
	check(menu.camera.position.distance_to(menu.HOME) < 0.35, "menu camera converges back to HOME")
	check_approx(menu.camera.fov, menu.HOME_FOV, 0.6, "menu camera FOV converges back to HOME_FOV")
	check_approx(menu.stage.gallery_lid.rotation_degrees.x, TheatreSet.GALLERY_LID_CLOSED_X, 0.05, "returning to the menu keeps the gallery closed")
	check(not menu.stage.gallery_preview_cards[0].visible and menu.stage.gallery_deck.visible, "returning resets the gallery with the deck stored")

	# Trigger CONTINUE from saved checkpoint.
	menu._activate(TheatreSet.CONTINUE)
	await tree.scene_changed

	var resumed_main := tree.current_scene
	check(resumed_main != null and resumed_main.scene_file_path.ends_with("main.tscn"), "CONTINUE transitions back to main.tscn")
	if resumed_main == null:
		return
	check(resumed_main.is_intro_active(), "CONTINUE plays enter intro transition")
	check_eq(GameManager.marks.size(), expected_marks.size(), "GameManager marks restored on frame 0")

	var resume_intro_done := await _wait_until(tree, func() -> bool:
		return not resumed_main.is_intro_active()
	, 3.2)
	check(resume_intro_done, "CONTINUE intro completes within 3.2s")
	await tree.process_frame

	check_eq(resumed_main._hand_cards.size(), expected_marks.size(), "CONTINUE restores 3D hand marks")
	for i in expected_marks.size():
		check_eq(resumed_main._hand_cards[i].card_id, int(expected_marks[i]["card_id"]), "restored hand mark %d card_id matches" % i)
		var expected_rev: bool = str(expected_marks[i]["orientation"]).to_upper() == "REVERSED"
		var actual_rev: bool = absf(resumed_main._hand_cards[i].front.rotation.z - PI) < 0.05
		check_eq(actual_rev, expected_rev, "restored hand mark %d orientation matches" % i)

	for i in 3:
		var slot_card = resumed_main._slot_cards[i]
		check(slot_card != null and is_instance_valid(slot_card), "CONTINUE restores field card %d" % i)
		if slot_card != null:
			check_eq(slot_card.card_id, int(expected_field[i]["card_id"]), "restored field card %d card_id matches" % i)
			var expected_rev: bool = str(expected_field[i]["orientation"]).to_upper() == "REVERSED"
			check_eq(slot_card.is_reversed, expected_rev, "restored field card %d orientation matches" % i)


func _test_direct_main_skips_intro(tree: SceneTree) -> void:
	TheatreSession.tracking = false
	TheatreSession.resume_requested = false
	TheatreSession.consume_enter_transition()
	tree.change_scene_to_file("res://scenes/main.tscn")
	await tree.scene_changed
	await tree.process_frame

	var direct_main := tree.current_scene
	check(direct_main != null and direct_main.scene_file_path.ends_with("main.tscn"), "direct main.tscn launch loads main")
	if direct_main == null:
		return
	check(not direct_main.is_intro_active(), "direct main.tscn launch skips intro immediately")
	check(direct_main.camera.global_position.distance_to(direct_main.GAMEPLAY_CAM_POS) < 0.03, "direct launch places camera at GAMEPLAY_CAM_POS")
	check(direct_main.deck.position.distance_to(direct_main.DECK_REST_POS) < 0.03, "direct launch places Deck3D at DECK_REST_POS")
	check(direct_main.dice.position.distance_to(direct_main.DICE_REST_POS) < 0.03, "direct launch places Dice3D at DICE_REST_POS")
	check(direct_main.restart_button.position.distance_to(direct_main.RESTART_REST_POS) < 0.03, "direct launch places RestartButton3D at RESTART_REST_POS")
	for i in 5:
		check(not direct_main.theatre_set.props[i].visible, "direct launch hides menu prop %d immediately" % i)
	check(not direct_main.theatre_set.loose_card.visible, "direct launch hides loose_card immediately")


func _wait_until(tree: SceneTree, predicate: Callable, timeout_sec: float) -> bool:
	var elapsed := 0.0
	var step := 0.05
	while elapsed < timeout_sec:
		if predicate.call():
			return true
		await tree.create_timer(step).timeout
		elapsed += step
	return bool(predicate.call())


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
