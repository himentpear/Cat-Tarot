extends Node

const Coordinator := preload("res://scripts/narrative_coordinator.gd")
const Plan := preload("res://scripts/narrative_plan.gd")

var _story := Coordinator.new()
var _requests: Array[Dictionary] = []
var _beats: Array[Dictionary] = []
var _resolutions: Array[Dictionary] = []
var _failures: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TheatreSession.profile_path = "user://test_narrative_%d.dat" % OS.get_process_id()
	TheatreSession.tracking = true
	add_child(_story)
	_story.provider = _request
	_story.beat_requested.connect(func(beat: Dictionary, finale: bool) -> void:
		_beats.append({"beat": beat, "finale": finale})
	)
	GameManager.turn_resolved.connect(func(result: Dictionary) -> void: _resolutions.append(result))
	GameManager.new_game(99)
	GameManager.debug_clear_field()
	GameManager.debug_set_field_card(0, 0)
	GameManager.debug_set_field_card(1, 18)
	GameManager.debug_set_field_card(2, 20)
	GameManager.debug_set_deck([3, 8, 9])
	for id in [1, 2, 5, 6, 7]:
		GameManager.debug_grant_mark(id)
	_story.begin("What should I do next?")
	await get_tree().process_frame
	_check(_requests.size() == 1, "opening queues one provider request")
	_check(TheatreSession.narrative["plan"]["branches"].size() == 3, "the three branches are available locally during generation")

	GameManager.debug_set_roll_cost(false)
	GameManager.debug_force_rolls([4])
	GameManager.roll_die()
	await get_tree().process_frame
	_answer(0)
	_check(_beats.is_empty(), "a stale response cannot play its opening")
	_check(_resolutions.size() == 1 and _resolutions[0]["state"]["revision"] == 1, "roll publishes a new stable revision")
	_answer(1, "Selected branch")
	_check(_beats.size() == 1, "the current plan plays its opening")
	_story.finish_beat()

	GameManager.select_slot(0)
	var before := GameManager.stats.duplicate()
	GameManager.accept_selected()
	_check(GameManager.phase == GameManager.Phase.RESOLVE and _resolutions.size() == 1, "replacement pauses before publishing the choice")
	GameManager.replace_mark(-1)
	_check(GameManager.marks.size() == 5 and not GameManager.pending_new_mark.is_empty(), "invalid replacement leaves the pending choice intact")
	var old_profile := TheatreSession.checkpoint.duplicate(true)
	TheatreSession.read_profile()
	_check(TheatreSession.restore_game(), "the rules and plan restore together while replacement is pending")
	_story.resume()
	GameManager.replace_mark(1)
	_check(_resolutions.size() == 2 and _resolutions.back()["stats_before"] == before, "the resumed choice publishes exactly once with pre-choice stats")
	_check(_resolutions.back()["replaced_mark"] == 1 and GameManager.field_cards[0]["card_id"] == 3, "replacement and refill happen before publication")
	_check(_beats.back()["beat"]["line"] == "Selected branch", "only the committed branch plays")
	var consequence: String = _beats.back()["beat"]["consequence"]
	_check(consequence.contains(Loc.card_name(0)) and consequence.contains(Loc.card_name(1)) and consequence.contains("→"), "playback explains the settled stats and the actual mark replacement")
	await get_tree().process_frame
	_check(_requests.size() == 3 and _story.is_playing(), "the next request begins during the selected beat")
	_check(_requests.back()["context"]["history"].size() == 1, "only one chosen branch enters the provider's history")
	_story.finish_beat()
	_answer(2, "", true)
	_check(TheatreSession.narrative["plan"]["branches"].size() == 3, "unexpected stage cues fall back to a valid plan")

	GameManager.debug_set_stats(4, 4, 4, 9)
	GameManager.debug_set_roll_cost(true)
	GameManager.debug_force_rolls([4])
	GameManager.roll_die()
	_check(GameManager.phase == GameManager.Phase.GAME_OVER and not TheatreSession.checkpoint.is_empty(), "a lethal roll checkpoints its unfinished ending")
	TheatreSession.read_profile()
	_check(TheatreSession.restore_game(), "terminal phase and pending finale restore")
	_story.resume()
	_story.finish_beat()
	_check(_beats.back()["finale"] and _beats.back()["beat"]["line"].contains("What should I do next?"), "resumed finale includes the opening question")
	_story.acknowledge_finale()
	_check(TheatreSession.checkpoint.is_empty(), "acknowledgement retires the terminal checkpoint")

	_test_legacy_profile(old_profile)
	await _test_five_acts()
	await _test_table_entry()
	TheatreSession.tracking = false
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TheatreSession.profile_path + suffix):
			DirAccess.remove_absolute(TheatreSession.profile_path + suffix)
	print("Narrative test failures: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _request(context: Dictionary, complete: Callable) -> void:
	_requests.append({"context": context, "complete": complete})


func _answer(index: int, line: String = "", invalid: bool = false) -> void:
	var request := _requests[index]
	var plan := Plan.fallback(request["context"])
	if not line.is_empty():
		plan["branches"][0]["accept"]["line"] = line
	if invalid:
		plan["branches"][0]["accept"]["cue"] = "unknown"
	var complete: Callable = request["complete"]
	complete.call(plan)


func _test_legacy_profile(state: Dictionary) -> void:
	for key: String in ["narrative", "revision", "game_over_won", "game_over_reason_key", "_pending_resolution", "choice_limit"]:
		state.erase(key)
	var file := FileAccess.open(TheatreSession.profile_path, FileAccess.WRITE)
	file.store_var({"version": 1, "levels": [0.3, 0.6], "collected": [0], "run": state})
	file.close()
	TheatreSession.read_profile()
	_check(TheatreSession.restore_game(), "a version-one pending replacement migrates")
	_check(TheatreSession.narrative.is_empty() and is_equal_approx(TheatreSession.levels[0], 0.3), "legacy profiles retain settings and remain classical runs")
	_check(GameManager.choice_limit == GameManager.TOTAL_CARDS, "old saves retain their original choice limit")
	GameManager.replace_mark(1)
	_check(GameManager.marks.size() == 5 and GameManager.phase == GameManager.Phase.SELECT, "a migrated mark replacement can finish")


func _test_five_acts() -> void:
	GameManager.new_game(88, true)
	_story.provider = Callable()
	_story.begin("Which way should I go?")
	await get_tree().process_frame
	_story.finish_beat()
	var resolved: Array[int] = []
	for act in range(1, GameManager.STORY_CHOICES + 1):
		if act == 5:
			_story.provider = _request
			_story.provider_timeout = 12.0
		_check(GameManager.rules_context()["options"].size() == 3, "each act offers three candidates")
		GameManager.debug_set_stats(4, 4, 4, 4)
		GameManager.select_slot(0)
		var id: int = GameManager.selected_card
		var deck_before: int = GameManager.deck.size()
		GameManager.refuse_selected()
		resolved.append(id)
		_check(GameManager.choices_completed == act, "one choice closes exactly one act")
		_check(TheatreSession.narrative["history"].back()["act_number"] == act, "the selected branch records its act")
		await get_tree().process_frame
		_story.finish_beat()
		if act == 3:
			TheatreSession.read_profile()
			_check(TheatreSession.restore_game() and GameManager.choice_limit == 5, "five-act run resumes with the same limit")
			_story.resume()
		if act == 5:
			_check(GameManager.deck.size() == deck_before, "there is no sixth draw after the resolution")
			_check(_beats.back()["beat"].get("waiting", false), "the finale briefly waits for a pending model answer")
			var final_request: Dictionary = _requests.back()
			var plan := Plan.fallback(final_request["context"])
			plan["finale"]["line"] += "\nRemote finale fixture."
			var complete: Callable = final_request["complete"]
			complete.call(plan)
	_check(GameManager.game_over_won and resolved.size() == 5, "the fifth choice ends the story")
	_check(_beats.back()["finale"] and _beats.back()["beat"]["line"].contains(Loc.card_name(resolved.back())), "the finale recalls the last selected card")
	_check(_beats.back()["beat"]["line"].contains("Remote finale fixture."), "the pending model answer replaces the local fallback")
	_story.acknowledge_finale()


func _test_table_entry() -> void:
	_story.queue_free()
	await get_tree().process_frame
	var table := preload("res://scenes/main.tscn").instantiate()
	table.opening_question = "What is worth keeping?"
	add_child(table)
	await get_tree().process_frame
	_check(table._narrative.is_playing() and table._narrative_stage._label.text.contains(table.opening_question), "the table shows the opening question on its stage")
	_check(GameManager.choice_limit == 5 and table._narrative_stage._heading.visible, "question-based entry enables the five-act UI")
	GameManager.debug_set_roll_cost(false)
	GameManager.debug_force_rolls([2, 4])
	table._on_die_clicked()
	_check(GameManager.revision == 0, "an active scene blocks tabletop commands")
	table._narrative_stage._finish()
	table._on_die_clicked()
	table._on_die_clicked()
	_check(GameManager.revision == 1 and GameManager.die_value == 2, "rolling animation gates another click")
	table.queue_free()
	await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error(label)
