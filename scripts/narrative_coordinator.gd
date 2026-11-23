extends Node
## Owns request lifetime. TheatreSession owns the durable narrative state.

signal beat_requested(beat: Dictionary, finale: bool)
signal plan_ready

const Plan := preload("res://scripts/narrative_plan.gd")
const Skills := preload("res://scripts/narrative_skills.gd")
const REQUEST_TIMEOUT := 3.0
const FINALE_GRACE := 3.0
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
	_show_opening_wait()


func resume() -> void:
	_invalidate_request()
	_finale_visible = false
	var story := TheatreSession.narrative
	if story.is_empty():
		return
	_present()
	var state := GameManager.rules_context()
	if state["terminal"] and not story["beat"].is_empty() and not story.get("finale_ready", false):
		_request_plan(state, story.get("last_resolution", {}))
	if not state["terminal"] and GameManager.phase == GameManager.Phase.SELECT and (not story["plan"].get("ready", false) or not story["opened"]):
		_request_plan(state)
		_show_opening_wait()


func is_playing() -> bool:
	var story := TheatreSession.narrative
	return not story.is_empty() and (not story["beat"].is_empty() or not story["finale"].is_empty() or _waiting_for_opening())


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
		beat["consequence"] = Plan.consequence(result, Loc.language)
		if state["choice_limit"] == GameManager.STORY_CHOICES:
			beat["act_number"] = int(state["choices_completed"])
			record["act_number"] = beat["act_number"]
		story["beat"] = beat
		record["line"] = beat["line"]
		story["history"].append(record)
	story["last_resolution"] = record
	story["plan"] = {}
	if state["terminal"]:
		story["finale"] = Plan.fallback(_context(state, record))["finale"]
		story["finale_act"] = Skills.act_number(state, action)
		if action == "roll":
			var line := "骰子停下了。猫望向失衡的刻度。" if Loc.language == "zh" else "The die comes to rest. The cat looks toward the scale that tipped."
			story["beat"] = {"cue": "tense", "line": line, "consequence": Plan.consequence(result, Loc.language)}
			story["beat"]["act_number"] = story["finale_act"]
	_present()
	_request_plan(state, record)


func _chosen_beat(result: Dictionary) -> Dictionary:
	var story := TheatreSession.narrative
	var plan: Dictionary = story["plan"]
	if _has_plan(result["previous_revision"]):
		for branch: Dictionary in plan["branches"]:
			if branch["card_id"] == result["card_id"] and branch["orientation"] == result["orientation"]:
				return branch[result["action"]].duplicate()
	var state: Dictionary = result["state"].duplicate()
	state["terminal"] = false
	state["choices_completed"] -= 1
	state["options"] = [result]
	var fallback := Plan.fallback(_context(state, {}))
	return fallback["branches"][0][result["action"]]


func _has_plan(revision: int) -> bool:
	return TheatreSession.narrative["plan"].get("revision") == revision


func _context(state: Dictionary, last: Dictionary) -> Dictionary:
	var story := TheatreSession.narrative
	return {
		"question": story["question"], "language": Loc.language,
		"history": story["history"], "state": state, "last_resolution": last,
		"opening_scene": story.get("opening_scene", ""), "opening_anchor": story.get("opening_anchor", ""),
		"local_opening": story.get("local_opening", false),
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
	var local := not provider.is_valid() or not Plan.is_valid(plan, state)
	if local:
		plan = Plan.fallback(context)
	if state["terminal"]:
		if not _finale_visible:
			story["finale"] = _copy_beat(plan["finale"])
			story["finale_ready"] = true
			if story["beat"].is_empty():
				_present()
	elif GameManager.phase == GameManager.Phase.SELECT:
		_store_branches(plan, state["revision"], true)
		if not story["opened"]:
			story["opened"] = true
			var opening: Dictionary = plan.get("opening", {})
			if opening.is_empty() and GameManager.choice_limit == GameManager.STORY_CHOICES:
				opening = Plan.fallback(context)["opening"]
				local = true
			if not opening.is_empty():
				story["opening_scene"] = opening["line"]
				var anchor: Variant = opening.get("anchor", "")
				story["opening_anchor"] = anchor.strip_edges().left(Plan.MAX_ANCHOR) if anchor is String else ""
				story["local_opening"] = local
				story["beat"] = _copy_beat(opening)
				story["beat"]["is_opening"] = true
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


func _waiting_for_opening() -> bool:
	return GameManager.choice_limit == GameManager.STORY_CHOICES and not TheatreSession.narrative.get("opened", true)


func _show_opening_wait() -> void:
	if provider.is_valid() and _waiting_for_opening():
		var line := "剧场正在为这个问题准备开场……" if Loc.language == "zh" else "The theatre is setting the scene for this question…"
		beat_requested.emit({"line": line, "cue": "quiet", "heading": Skills.heading(1), "waiting": true}, false)


func _present() -> void:
	var story := TheatreSession.narrative
	if not story["beat"].is_empty():
		var beat: Dictionary = story["beat"].duplicate()
		if GameManager.choice_limit == GameManager.STORY_CHOICES:
			beat["heading"] = Skills.heading(int(beat.get("act_number", maxi(1, GameManager.choices_completed))))
		beat_requested.emit(beat, false)
	elif not story["finale"].is_empty():
		var heading := Skills.heading(int(story.get("finale_act", Skills.act_number(GameManager.rules_context()))))
		if GameManager.choice_limit == GameManager.STORY_CHOICES and _expire.is_valid() and not story.get("finale_ready", false):
			if _deadline.time_left > FINALE_GRACE:
				_deadline.start(FINALE_GRACE)
			var line := "猫在幕边写下最后一句……" if Loc.language == "zh" else "The cat writes its last line by the curtain…"
			beat_requested.emit({"line": line, "cue": "quiet", "heading": heading, "waiting": true}, false)
			return
		_finale_visible = true
		var finale: Dictionary = story["finale"].duplicate()
		finale["heading"] = heading
		beat_requested.emit(finale, true)
