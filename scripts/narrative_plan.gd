extends RefCounted
## Data contract shared by the provider, local fallback, and stage.

const CUES := ["quiet", "warm", "tense", "reveal"]
const MAX_LINE := 640
const MAX_ANCHOR := 60
const Skills := preload("res://scripts/narrative_skills.gd")


static func fallback(context: Dictionary) -> Dictionary:
	var state: Dictionary = context["state"]
	var zh: bool = context["language"] == "zh"
	var act := Skills.act_number(state)
	if state["terminal"]:
		var ending := ""
		if state["won"]:
			ending = (
				"答案是：选一条还能回头的路。你已经在几次取舍间保住了平衡，下一步也可以从一次小小的尝试开始。"
				if zh else "Choose a path you can still step back from. You kept your balance through a series of tradeoffs. Start with one small step again."
			)
		else:
			var limit_stat := ""
			for stat: String in GameManager.STAT_KEYS:
				var value := int(state["stats"][stat])
				if value <= 0 or value >= 10:
					limit_stat = Loc.stat_name(stat)
					break
			ending = (
				"答案是：先停一停。%s已经越限，等你找回平衡，再作下一次决定。" % limit_stat
				if zh else "Pause before you decide. %s crossed its limit. Find your balance before taking another step." % limit_stat
			)
		var question := str(context["question"])
		var history: Array = context.get("history", [])
		if act > 0 and not history.is_empty():
			var choice: Dictionary = history.back()
			var card := Loc.card_name(int(choice["card_id"]))
			var decision := ("接纳" if choice["action"] == "accept" else "放下") if zh else ("accepted" if choice["action"] == "accept" else "let go of")
			ending += (" 最后一次取舍里，你选择了%s%s。" if zh else " In your last choice, you %s %s.") % [decision, card]
		return {"finale": _beat(question + "\n" + ending, "reveal")}

	var branches: Array[Dictionary] = []
	for option: Dictionary in state["options"]:
		var id := int(option["card_id"])
		var card := Loc.card_name(id)
		var orientation := Loc.orientation_name(option["orientation"])
		var accept := "你让%s上台。猫往旁边让了一步，给这个可能留出位置。" % card if zh else "You let %s take the stage. The cat steps aside to make room for this possibility." % card
		var refuse := "你把%s留在幕外。猫收回爪子，台上空出一处光。" % card if zh else "You leave %s outside the curtain. The cat draws back its paw, leaving an empty patch of light." % card
		var accept_cue := "warm" if option["orientation"] == "UPRIGHT" else "tense"
		var refuse_cue := "quiet"
		if act > 0:
			accept = Skills.fallback_line(act, "accept", card, context["language"])
			refuse = Skills.fallback_line(act, "refuse", card, context["language"])
			accept_cue = Skills.fallback_cue(act, "accept")
			refuse_cue = Skills.fallback_cue(act, "refuse")
		if not str(context.get("opening_scene", "")).is_empty() and not context.get("local_opening", false):
			accept = _continuation(card, true, context)
			refuse = _continuation(card, false, context)
		branches.append({
			"card_id": id,
			"orientation": option["orientation"],
			"accept": _beat(accept, accept_cue),
			"refuse": _beat(refuse, refuse_cue),
			"preview": "%s · %s" % [card, orientation],
		})
	var question := str(context["question"])
	var opening := (
		"入夜后，小剧场只剩一盏灯。守门的黑猫听完来客的疑问，翻过门牌，把一张纸条推到灯下。台上还没人开口，门外已经响起了脚步。纸上写着：%s" % question
		if zh else "After dark, one lamp is left burning in the playhouse. The black cat keeping the door hears its visitor out, turns the sign, and slides a note under the lamp. Footsteps are already audible outside. On the note is the question: %s" % question
	)
	return {"opening": _beat(opening, "quiet"), "branches": branches}


static func _continuation(card: String, accepted: bool, context: Dictionary) -> String:
	var zh: bool = context["language"] == "zh"
	var anchor := str(context.get("opening_anchor", ""))
	if zh:
		var detail := "猫又看了一眼%s。" % anchor if not anchor.is_empty() else ""
		return detail + ("猫接过%s，把刚才还悬着的决定往前推了一步。" % card if accepted else "猫把%s轻轻推回去，留下一刻，让在场的人重新想一想该怎么走。" % card)
	var detail := "The cat looks once more at %s. " % anchor if not anchor.is_empty() else ""
	return detail + ("The cat takes %s and acts on the decision it had left hanging." % card if accepted else "The cat slides %s back and leaves the others a moment to reconsider their next move." % card)


static func consequence(result: Dictionary, language: String) -> String:
	var zh := language == "zh"
	var state: Dictionary = result["state"]
	var card_id := int(result["card_id"])
	var action: String = result["action"]
	var facts := PackedStringArray()
	if action == "roll":
		facts.append(("骰子停在 %d 点。" if zh else "The die landed on %d.") % state["die_value"])
	else:
		var card := "%s（%s）" % [Loc.card_name(card_id), Loc.orientation_name(result["orientation"])] if zh else "%s (%s)" % [Loc.card_name(card_id), Loc.orientation_name(result["orientation"])]
		var decision := ("接纳" if action == "accept" else "拒绝") if zh else ("Accepted" if action == "accept" else "Refused")
		facts.append(("%s了%s。" if zh else "%s %s.") % [decision, card])

	var changes := PackedStringArray()
	for stat: String in GameManager.STAT_KEYS:
		var before: int = result["stats_before"][stat]
		var after: int = state["stats"][stat]
		if before != after:
			changes.append("%s %d → %d" % [Loc.stat_name(stat), before, after])
	if changes.is_empty():
		facts.append("四项数值与行动前相同。" if zh else "All four stats ended unchanged.")
	else:
		facts.append(("，" if zh else ", ").join(changes) + ("。" if zh else "."))

	var replaced := int(result.get("replaced_mark", -1))
	if replaced >= 0:
		facts.append(("用%s替换了%s的印记。" if zh else "The %s mark replaced %s.") % [Loc.card_name(card_id), Loc.card_name(replaced)])
	elif action == "accept":
		for mark: Dictionary in state["marks"]:
			if int(mark["card_id"]) == card_id:
				facts.append(("获得%s的印记。" if zh else "Gained the %s mark.") % Loc.card_name(card_id))
				break
	var triggered := PackedStringArray()
	for effect: Dictionary in result["effects"]:
		var name := Loc.card_name(int(effect["card_id"]))
		if not triggered.has(name):
			triggered.append(name)
	if not triggered.is_empty():
		facts.append(("这些印记也触发了效果：%s。" if zh else "Mark effects also triggered: %s.") % ("、" if zh else ", ").join(triggered))
	if state["reason"] == "reason.death":
		for stat: String in GameManager.STAT_KEYS:
			if int(state["stats"][stat]) not in range(1, 10):
				facts.append(("%s越限，故事在这里结束。" if zh else "%s crossed its limit, ending the story.") % Loc.stat_name(stat))
				break
	return ("" if zh else " ").join(facts)


static func is_valid(plan: Dictionary, state: Dictionary) -> bool:
	if state["terminal"]:
		return is_beat(plan.get("finale"))
	var branches: Variant = plan.get("branches")
	if not branches is Array or branches.size() != state["options"].size():
		return false
	var opening: Variant = plan.get("opening", {})
	if not opening is Dictionary or (not opening.is_empty() and not is_beat(opening)):
		return false
	for option: Dictionary in state["options"]:
		var found := false
		for branch: Variant in branches:
			if not branch is Dictionary or branch.get("card_id") != option["card_id"]:
				continue
			if found or branch.get("orientation") != option["orientation"]:
				return false
			if not _valid_line(branch.get("preview")) or not is_beat(branch.get("accept")) or not is_beat(branch.get("refuse")):
				return false
			found = true
		if not found:
			return false
	return true


static func is_beat(value: Variant) -> bool:
	return (
		value is Dictionary and value.get("cue") is String and value["cue"] in CUES
		and _valid_line(value.get("line"))
	)


static func _valid_line(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= MAX_LINE


static func _beat(line: String, cue: String) -> Dictionary:
	return {"line": line, "cue": cue}
