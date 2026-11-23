extends Node

const TEST_SCENE := "res://tests/theatre_test.tscn"
var failures := 0
var profile := ""


func _ready() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 3 and args[0] == "--read-theatre-fixture":
		TheatreSession.profile_path = args[1]
		TheatreSession.read_profile()
		TheatreSession.resume_requested = true
		var table := preload("res://scenes/main.tscn").instantiate()
		add_child(table)
		_check(GameManager.selected_card == 0 and GameManager.selected_slot == 0, "selected card restored")
		_check(GameManager.phase == GameManager.Phase.RESOLVE and not GameManager.pending_new_mark.is_empty(), "pending choice restored")
		_check(table._hand_cards.size() == 5 and is_instance_valid(table._pending_hold_card), "held card reconstructed")
		_check(table.deck._remaining == GameManager.deck.size(), "deck reconstructed")
		_check(GameManager.rng.randi() == args[2].to_int(), "next random value matches")
		_check(is_equal_approx(TheatreSession.levels[1],.35), "sound level persisted")
		GameManager.replace_mark(1)
		_check(GameManager.pending_new_mark.is_empty() and GameManager.choices_completed == 1, "replace once after restore")
		get_tree().quit(failures)
		return
	profile = "user://test_theatre_%d.dat" % OS.get_process_id()
	TheatreSession.profile_path = profile
	TheatreSession.read_profile()
	var tree := get_tree()
	var splash := preload("res://scenes/splash_screen.tscn").instantiate()
	tree.root.add_child(splash)
	tree.current_scene = splash
	splash._finish_immediately()
	await tree.scene_changed
	var menu: Node = tree.current_scene
	_check(menu.scene_file_path.ends_with("theatre_menu.tscn"), "splash opens theatre")
	await tree.physics_frame
	await tree.physics_frame
	for id in 5:
		var center: Vector3 = menu.stage.props[id].global_position
		if id == TheatreSet.START:
			center = menu.stage.ticket.global_position
		_check(menu._pick(menu.camera.unproject_position(center)) == id, "pick prop %d" % id)
	_check(menu._pick(menu.camera.unproject_position(menu.stage.flat_ticket.global_position)) == TheatreSet.START, "pick second ticket")
	_check(menu.stage.find_child("CatAnchor",true,false).get_child(0).scene_file_path.ends_with("cat_placeholder.tscn"), "cat mount is replaceable")
	menu._activate(TheatreSet.CONTINUE)
	_check(menu.hint.text == Loc.t("theatre.no_run"), "empty continue")
	menu._activate(TheatreSet.QUIT)
	_check(menu.mode == "quit", "bell confirmation")
	menu._close_panel()
	menu._open_gallery()
	await tree.create_timer(0.55).timeout
	var display: Node3D = menu.stage.gallery_display
	var initial_card: Card3D = display.presented_card
	_check(is_instance_valid(initial_card), "the gallery draws a physical card from the chest")
	_check(initial_card.front.material_override.albedo_texture.resource_path.ends_with("card_back.svg"), "unseen card remains covered")
	_check(is_equal_approx(menu.stage.gallery_lid.rotation_degrees.x, TheatreSet.GALLERY_LID_OPEN_X), "gallery panel keeps the chest open")
	_check(not menu.stage.gallery_preview_cards[0].visible, "the physical card takes the place of the hover fan")
	var initial_position := initial_card.position
	TheatreSession.collected.append(2)
	menu._turn_card(1)
	await tree.create_timer(0.24).timeout
	_check(display.presented_card == initial_card and not initial_card.position.is_equal_approx(initial_position), "the outgoing card moves before the description changes")
	menu._turn_card(1)
	await tree.create_timer(1.2).timeout
	_check(display.presented_card.card_id == 2, "rapid input presents the last requested card")
	_check(menu.card_title.text == Loc.card_name(2) and display.presented_card.front.material_override.albedo_texture.resource_path == CardDatabase.texture_path(2), "card art and description agree after the draw")
	_check(menu.card_description.text.contains(Loc.orientation_name("upright")) and menu.card_description.text.contains(Loc.orientation_name("reversed")), "the description uses the card's localized effects")
	TheatreSession.collected.clear()
	menu._close_panel()
	await tree.create_timer(0.4).timeout
	_check(display.presented_card == null and is_zero_approx(menu.stage.gallery_lid.rotation_degrees.x), "closing the gallery puts the card away and shuts the chest")
	menu._open_settings()
	await tree.create_timer(.9).timeout
	var knob: Node3D = menu.stage.sliders[0]
	var gear_angle: float = menu.stage.gears[0].rotation.z
	menu._start_drag(menu.camera.unproject_position(knob.global_position))
	_check(menu.dragging == 0,"pick physical fader")
	if menu.dragging == 0:
		menu._drag(menu.camera.unproject_position(knob.to_global(Vector3(0,.08,0))))
		menu._end_drag()
		_check(not is_equal_approx(gear_angle,menu.stage.gears[0].rotation.z),"fader moves gears")
	menu.volume_controls[1].value = .35
	_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))), .35), "settings update audio bus")
	menu._close_panel()
	menu._activate(TheatreSet.START)
	await tree.scene_changed
	_check(tree.current_scene.scene_file_path.ends_with("main.tscn"), "ticket starts run")
	_check(TheatreSession.collected.size() == 3, "opening field joins gallery")
	GameManager.new_game(99)
	GameManager.select_slot(1)
	GameManager.roll_die()
	var after_roll := TheatreSession.checkpoint.duplicate(true)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	tree.current_scene._unhandled_key_input(esc)
	await tree.scene_changed
	tree.current_scene._activate(TheatreSet.CONTINUE)
	await tree.scene_changed
	_check(GameManager.die_value == after_roll.die_value and GameManager.stats == after_roll.stats and GameManager.rng.state == after_roll.rng_state, "resume after roll without a second charge")
	_check(GameManager.selected_slot == 1 and GameManager.field_cards == after_roll.field_cards, "restore selected field")
	GameManager.new_game(99)
	var discovered := TheatreSession.collected.duplicate()
	for id in [1,2,3,5,6]:
		GameManager.debug_grant_mark(id,"upright")
	GameManager.debug_set_field_card(0,0,"UPRIGHT")
	GameManager.select_slot(0)
	GameManager.accept_selected()
	var rng := RandomNumberGenerator.new()
	rng.state = GameManager.rng.state
	var output: Array = []
	var child_exit := OS.execute(OS.get_executable_path(),PackedStringArray([
		"--headless","--path",ProjectSettings.globalize_path("res://"),TEST_SCENE,
		"--","--read-theatre-fixture",profile,str(rng.randi())
	]),output,true)
	_check(child_exit == 0,"cross-process checkpoint: "+str(output))
	tree.current_scene._unhandled_key_input(esc)
	await tree.scene_changed
	menu = tree.current_scene
	menu._activate(TheatreSet.START)
	_check(menu.mode == "overwrite", "existing run prompts for replacement")
	menu._close_panel()
	menu._activate(TheatreSet.CONTINUE)
	await tree.scene_changed
	_check(GameManager.phase == GameManager.Phase.RESOLVE and GameManager.marks.size() == 5, "book resumes")
	GameManager._enter_final_end()
	_check(TheatreSession.checkpoint.is_empty() and TheatreSession.collected.has(21), "World collected and finished run closed")
	GameManager.new_game(42)
	_check(discovered.all(func(id: int) -> bool: return TheatreSession.collected.has(id)), "collection persists across plays")
	Audio.stop_music()
	TheatreSession.tracking = false
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile+suffix):
			DirAccess.remove_absolute(profile+suffix)
	print("Theatre test failures: ",failures)
	tree.quit(failures)

