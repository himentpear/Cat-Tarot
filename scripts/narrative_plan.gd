extends RefCounted
## Data contract shared by the provider, local fallback, and stage.

const CUES := ["quiet", "warm", "tense", "reveal"]
const MAX_LINE := 640


static func fallback(context: Dictionary) -> Dictionary:
	var state: Dictionary = context["state"]
	var zh: bool = context["language"] == "zh"
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
		return {"finale": _beat(question + "\n" + ending, "reveal")}

	var branches: Array[Dictionary] = []
	for option: Dictionary in state["options"]:
		var id := int(option["card_id"])
		var card := Loc.card_name(id)
		var orientation := Loc.orientation_name(option["orientation"])
		var accept := "你让%s上台。猫往旁边让了一步，给这个可能留出位置。" % card if zh else "You let %s take the stage. The cat steps aside to make room for this possibility." % card
		var refuse := "你把%s留在幕外。猫收回爪子，台上空出一处光。" % card if zh else "You leave %s outside the curtain. The cat draws back its paw, leaving an empty patch of light." % card
		branches.append({
			"card_id": id,
			"orientation": option["orientation"],
			"accept": _beat(accept, "warm" if option["orientation"] == "UPRIGHT" else "tense"),
			"refuse": _beat(refuse, "quiet"),
			"preview": "%s · %s" % [card, orientation],
		})
	var opening := "幕布拉开，猫在你的问题旁坐下。\n" if zh else "The curtain opens. The cat settles next to your question.\n"
	return {"opening": _beat(opening + str(context["question"]), "quiet"), "branches": branches}


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
