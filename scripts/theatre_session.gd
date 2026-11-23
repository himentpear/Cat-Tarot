extends Node
## Player profile and the shared rules/narrative checkpoint.

const PROFILE_PATH := "user://theatre_profile.dat"
const NarrativePlan := preload("res://scripts/narrative_plan.gd")
const VERSION := 2
const BUS_NAMES := ["Music", "SFX"]

var profile_path: String = PROFILE_PATH
var checkpoint: Dictionary = {}
var narrative: Dictionary = {}
var collected: Array[int] = []
var levels: Array[float] = [db_to_linear(Audio.MUSIC_BUS_DB), db_to_linear(Audio.SFX_BUS_DB)]
var tracking: bool = false
var resume_requested: bool = false
var _enter_transition: Dictionary = {}
var _return_transition: Dictionary = {}


func begin_enter_transition(kind: String, cam_transform: Transform3D, cam_fov: float, curtains: Dictionary, question: String = "") -> void:
	_return_transition.clear()
	_enter_transition = {
		"kind": kind,
		"camera_transform": cam_transform,
		"camera_fov": cam_fov,
		"curtains": curtains,
		"question": question,
	}


func consume_enter_transition() -> Dictionary:
	if _enter_transition.is_empty():
		return {}
	var data := _enter_transition.duplicate(true)
	_enter_transition.clear()
	return data


func begin_return_transition(cam_transform: Transform3D, cam_fov: float, curtains: Dictionary) -> void:
	_enter_transition.clear()
	_return_transition = {
		"camera_transform": cam_transform,
		"camera_fov": cam_fov,
		"curtains": curtains,
	}


func consume_return_transition() -> Dictionary:
	if _return_transition.is_empty():
		return {}
	var data := _return_transition.duplicate(true)
	_return_transition.clear()
	return data


func _ready() -> void:
	read_profile()
	GameManager.checkpoint_reached.connect(_on_checkpoint)
	GameManager.game_started.connect(_on_game_started)


func read_profile() -> void:
	checkpoint.clear()
	narrative = {}
	collected.clear()
	levels.assign([db_to_linear(Audio.MUSIC_BUS_DB), db_to_linear(Audio.SFX_BUS_DB)])
	var data := _read_file(profile_path)
	if data.is_empty():
		data = _read_file(profile_path + ".bak")
	for id in data.get("collected", []):
		if id is int and id >= 0 and id <= GameManager.WORLD_ID and not collected.has(id):
			collected.append(id)
	var saved_levels: Array = data.get("levels", [])
	if saved_levels.size() == levels.size():
		for i in levels.size():
			levels[i] = clampf(float(saved_levels[i]), 0.0, 1.0)
	for i in levels.size():
		_apply_level(i)
	var saved: Dictionary = data.get("run", {})
	if data.get("version") == 1 and not saved.is_empty():
		_migrate_run(saved)
	if not saved.is_empty() and not saved.has("choice_limit"):
		saved["choice_limit"] = GameManager.TOTAL_CARDS
	if _valid_run(saved):
		checkpoint = saved


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 8 or file.get_length() > 1000000:
		return {}
	var data: Variant = file.get_var(false)
	if data is Dictionary and data.get("version") in [1, VERSION] and data.get("run") is Dictionary and data.get("collected") is Array and data.get("levels") is Array:
		return data
	return {}


func _valid_run(run: Dictionary) -> bool:
	for key: String in GameManager.CHECKPOINT_FIELDS:
		if not run.has(key) or typeof(run[key]) != typeof(GameManager.get(key)):
			return false
	if not run.get("rng_state") is int or run.field_cards.size() != 3 or run.revision < 0:
		return false
	if run.choice_limit not in [GameManager.STORY_CHOICES, GameManager.TOTAL_CARDS] or run.choices_completed < 0 or run.choices_completed > run.choice_limit:
		return false
	if run.die_value < 1 or run.die_value > 6 or run.selected_slot < -1 or run.selected_slot >= 3:
		return false
	for key: String in GameManager.STAT_KEYS:
		if not run.stats.get(key) is int:
			return false
	for card: Variant in run.field_cards:
		if card != null and (not _valid_card(card) or not card.has("last_roll")):
			return false
	for mark: Variant in run.marks:
		if not _valid_card(mark) or not mark.get("uses") is Dictionary:
			return false
	for id: Variant in run.deck:
		if not id is int or id < 0 or id >= GameManager.TOTAL_CARDS:
			return false
	if run.marks.size() > GameManager.MAX_MARKS or not run.get("narrative", {}) is Dictionary:
		return false
	var story: Dictionary = run.get("narrative", {})
	if not story.is_empty() and not _valid_narrative(story):
		return false
	if run.phase == GameManager.Phase.RESOLVE:
		return _valid_card(run.pending_new_mark) and run.selected_slot >= 0 and run.marks.size() == GameManager.MAX_MARKS and _valid_pending_resolution(run._pending_resolution)
	if not run.pending_new_mark.is_empty() or not run._pending_resolution.is_empty():
		return false
	if run.phase == GameManager.Phase.GAME_OVER:
		return not story.is_empty() and not story["finale"].is_empty() and run.game_over_reason_key in ["reason.death", "reason.world_end"]
	return run.phase == GameManager.Phase.SELECT


func _valid_narrative(story: Dictionary) -> bool:
	if not (
		story.get("question") is String and not story["question"].is_empty()
		and story.get("history") is Array and story.get("plan") is Dictionary
		and story.get("beat") is Dictionary and story.get("finale") is Dictionary
		and story.get("opened") is bool
	):
		return false
	for key: String in ["beat", "finale"]:
		if not story[key].is_empty() and not NarrativePlan.is_beat(story[key]):
			return false
	var plan: Dictionary = story["plan"]
	if plan.is_empty():
		return true
	if not plan.get("revision") is int or not plan.get("branches") is Array:
		return false
	for branch: Variant in plan["branches"]:
		if not _valid_card(branch) or not NarrativePlan.is_beat(branch.get("accept")) or not NarrativePlan.is_beat(branch.get("refuse")):
			return false
	return true


func _valid_pending_resolution(result: Dictionary) -> bool:
	return (
		result.get("action") == "accept" and _valid_card(result)
		and result.get("stats_before") is Dictionary
		and result.get("stat_changes") is Array and result.get("effects") is Array
	)


func _migrate_run(run: Dictionary) -> void:
	run["revision"] = 0
	run["game_over_won"] = false
	run["game_over_reason_key"] = ""
	run["_pending_resolution"] = {}
	if run.get("phase") != GameManager.Phase.RESOLVE:
		return
	var mark: Variant = run.get("pending_new_mark")
	if not _valid_card(mark):
		return
	run["_pending_resolution"] = {
		"action": "accept", "card_id": mark["card_id"], "orientation": mark["orientation"],
		"slot": run.get("selected_slot", -1), "stats_before": run.get("stats", {}),
		"stat_changes": [], "effects": [],
	}


func _valid_card(card: Variant) -> bool:
	return card is Dictionary and card.get("card_id") is int and card.card_id >= 0 and card.card_id < GameManager.TOTAL_CARDS and str(card.get("orientation")).to_upper() in ["UPRIGHT", "REVERSED"]


func write_profile() -> void:
	var temp := profile_path + ".tmp"
	var backup := profile_path + ".bak"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write theatre profile: " + error_string(FileAccess.get_open_error()))
		return
	file.store_var({"version": VERSION, "run": checkpoint, "collected": collected, "levels": levels})
	file.flush()
	var written := file.get_error()
	file.close()
	if written != OK:
		push_error("Cannot flush theatre profile: " + error_string(written))
		return
	if FileAccess.file_exists(profile_path):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		if DirAccess.rename_absolute(profile_path, backup) != OK:
			push_error("Cannot back up theatre profile")
			return
	if DirAccess.rename_absolute(temp, profile_path) != OK:
		push_error("Cannot install theatre profile")


func save_checkpoint() -> void:
	_on_checkpoint()


func _on_game_started(_seed: int) -> void:
	narrative = {}


func _on_checkpoint() -> void:
	if not tracking:
		return
	for card: Variant in GameManager.field_cards:
		if card != null and not collected.has(int(card.card_id)):
			collected.append(int(card.card_id))
	if GameManager.phase == GameManager.Phase.GAME_OVER:
		if GameManager.game_over_won and not collected.has(GameManager.WORLD_ID):
			collected.append(GameManager.WORLD_ID)
		if narrative.is_empty() or narrative["finale"].is_empty():
			checkpoint = {}
			write_profile()
			return
	checkpoint = GameManager.capture_checkpoint()
	checkpoint["narrative"] = narrative.duplicate(true)
	write_profile()


func restore_game() -> bool:
	resume_requested = false
	if not _valid_run(checkpoint):
		return false
	narrative = checkpoint.get("narrative", {}).duplicate(true)
	GameManager.restore_checkpoint(checkpoint)
	return true


func set_level(index: int, value: float) -> void:
	levels[index] = clampf(value, 0.0, 1.0)
	_apply_level(index)


func _apply_level(index: int) -> void:
	var bus := AudioServer.get_bus_index(BUS_NAMES[index])
	AudioServer.set_bus_mute(bus, levels[index] <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.0001, levels[index])))

