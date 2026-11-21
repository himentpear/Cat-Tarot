extends Node
## Owns request lifetime. TheatreSession owns the durable narrative state.

signal beat_requested(beat: Dictionary, finale: bool)
signal plan_ready

const Plan := preload("res://scripts/narrative_plan.gd")
const REQUEST_TIMEOUT := 3.0
const MAX_QUESTION := 240

## Optional provider receives a detached context and a completion Callable(Dictionary).
var provider: Callable
var provider_cancel: Callable
var provider_timeout: float = REQUEST_TIMEOUT
var _request_id: int = 0
var _finale_visible: bool = false
var _deadline := Timer.new()
var _expire: Callable


func _ready() -> void:
	_deadline.one_shot = true
	_deadline.timeout.connect(_on_timeout)
	add_child(_deadline)
	GameManager.turn_resolved.connect(_on_turn_resolved)


func begin(question: String) -> void:
	_invalidate_request()
	_finale_visible = false
	TheatreSession.narrative = {}
	var clean := question.strip_edges().left(MAX_QUESTION)
	if clean.is_empty():
		return
	TheatreSession.narrative = {
		"question": clean, "history": [], "plan": {}, "beat": {}, "finale": {},
		"opened": false, "finale_ready": false,
	}
	_request_plan(GameManager.rules_context())


func resume() -> void:
	_invalidate_request()
	_finale_visible = false
	var story := TheatreSession.narrative
	if story.is_empty():
		return
	_present()
	var state := GameManager.rules_context()
	if state["terminal"] and not story["beat"].is_empty() and not story.get("finale_ready", false):
		_request_plan(state)
	if not state["terminal"] and GameManager.phase == GameManager.Phase.SELECT and not story["plan"].get("ready", false):
		_request_plan(state)


func is_playing() -> bool:
	var story := TheatreSession.narrative
	return not story.is_empty() and (not story["beat"].is_empty() or not story["finale"].is_empty())


func preview_for(card_id: int) -> String:
	var story := TheatreSession.narrative
	if card_id < 0 or story.is_empty() or not _has_plan(GameManager.revision):
		return ""
	for branch: Dictionary in story["plan"]["branches"]:
		if branch["card_id"] == card_id:
			return str(branch.get("preview", ""))
	return ""


func finish_beat() -> void:
	var story := TheatreSession.narrative
	if story.is_empty() or story["beat"].is_empty():
		return
	story["beat"] = {}
	TheatreSession.save_checkpoint()
	_present()


func acknowledge_finale() -> void:
	var story := TheatreSession.narrative
	if story.is_empty() or not _finale_visible:
		return
	_invalidate_request()
	story["finale"] = {}
	_finale_visible = false
	TheatreSession.save_checkpoint()


func _on_turn_resolved(result: Dictionary) -> void:
	var story := TheatreSession.narrative
	if story.is_empty():
		return
	var state: Dictionary = result["state"]
	var action: String = result["action"]
	var record := {
		"action": action, "stats_before": result["stats_before"], "stats_after": state["stats"],
		"stat_changes": result["stat_changes"], "effects": result["effects"],
		"card_id": result["card_id"], "orientation": result["orientation"],
		"replaced_mark": result.get("replaced_mark", -1),
	}
	if action != "roll":
		story["opened"] = true
		var beat := _chosen_beat(result)
		story["beat"] = beat
		record["line"] = beat["line"]
		story["history"].append(record)
	story["plan"] = {}
	if state["terminal"]:
		story["finale"] = Plan.fallback(_context(state, record))["finale"]
		if action == "roll":
			var line := "骰子停下了。猫望向失衡的刻度。" if Loc.language == "zh" else "The die comes to rest. The cat looks toward the scale that tipped."
			story["beat"] = {"cue": "tense", "line": line}
	_present()
	_request_plan(state, record)


func _chosen_beat(result: Dictionary) -> Dictionary:
	var story := TheatreSession.narrative
	var plan: Dictionary = story["plan"]
	if _has_plan(result["previous_revision"]):
		for branch: Dictionary in plan["branches"]:
			if branch["card_id"] == result["card_id"] and branch["orientation"] == result["orientation"]:
				return branch[result["action"]].duplicate()
	var state := {"terminal": false, "options": [result]}
	var fallback := Plan.fallback(_context(state, {}))
	return fallback["branches"][0][result["action"]]


func _has_plan(revision: int) -> bool:
	return TheatreSession.narrative["plan"].get("revision") == revision


func _context(state: Dictionary, last: Dictionary) -> Dictionary:
	var story := TheatreSession.narrative
	return {
		"question": story["question"], "language": Loc.language,
		"history": story["history"], "state": state, "last_resolution": last,
	}.duplicate(true)


func _request_plan(state: Dictionary, last: Dictionary = {}) -> void:
	_invalidate_request()
	var request_id := _request_id
	var context := _context(state, last)
	if not state["terminal"] and not _has_plan(state["revision"]):
		_store_branches(Plan.fallback(context), state["revision"], false)
	# Deferred invocation also keeps synchronous providers out of the rules transaction.
	_dispatch_plan.call_deferred(request_id, context)


func _dispatch_plan(request_id: int, context: Dictionary) -> void:
	if request_id != _request_id:
		return
	var complete := _receive_plan.bind(request_id, context)
	if provider.is_valid():
		_expire = complete
		_deadline.start(provider_timeout)
		provider.call(context.duplicate(true), complete)
	else:
		complete.call(Plan.fallback(context))


func _receive_plan(plan: Dictionary, request_id: int, context: Dictionary) -> void:
	if request_id != _request_id or TheatreSession.narrative.is_empty():
		return
	_invalidate_request()
	var state: Dictionary = context["state"]
	var story := TheatreSession.narrative
	if state["revision"] != GameManager.revision or not is_inside_tree():
		return
	if not Plan.is_valid(plan, state):
		plan = Plan.fallback(context)
	if state["terminal"]:
		if not _finale_visible:
			story["finale"] = _copy_beat(plan["finale"])
			story["finale_ready"] = true
	elif GameManager.phase == GameManager.Phase.SELECT:
		_store_branches(plan, state["revision"], true)
		if not story["opened"]:
			story["opened"] = true
			var opening: Dictionary = plan.get("opening", {})
			if not opening.is_empty():
				story["beat"] = _copy_beat(opening)
				_present()
		plan_ready.emit()
	TheatreSession.save_checkpoint()


func _invalidate_request() -> void:
	_request_id += 1
	_deadline.stop()
	_expire = Callable()
	if provider_cancel.is_valid():
		provider_cancel.call()


func _on_timeout() -> void:
	_expire.call({})


func _store_branches(plan: Dictionary, revision: int, ready: bool) -> void:
	var branches: Array[Dictionary] = []
	for branch: Dictionary in plan["branches"]:
		branches.append({
			"card_id": int(branch["card_id"]), "orientation": branch["orientation"], "preview": branch["preview"],
			"accept": _copy_beat(branch["accept"]), "refuse": _copy_beat(branch["refuse"]),
		})
	TheatreSession.narrative["plan"] = {"revision": revision, "branches": branches, "ready": ready}


func _copy_beat(beat: Dictionary) -> Dictionary:
	return {"cue": beat["cue"], "line": beat["line"]}


func _present() -> void:
	var story := TheatreSession.narrative
	if not story["beat"].is_empty():
		beat_requested.emit(story["beat"].duplicate(), false)
	elif not story["finale"].is_empty():
		_finale_visible = true
		beat_requested.emit(story["finale"].duplicate(), true)
