extends RefCounted
## Each skill gives an act a dramatic task, a constraint, and a playable fallback.

const ACTS := [
	{
		"id": "opening", "zh": "开端", "en": "Opening", "accept_cue": "warm", "refuse_cue": "quiet",
		"task": "Stage the question in a specific time and place with named or clearly identified characters, a visible problem, and an object or sensory detail that can return later.",
		"accept_zh": "猫推开门，借%s迈出第一步。", "refuse_zh": "猫没走%s指向的路。它在门槛上停住，先看清自己想去哪里。",
		"accept_en": "The cat pushes the door open and takes its first step with %s.", "refuse_en": "The cat passes on the path marked by %s. It pauses at the threshold to decide where it wants to go.",
	}, {
		"id": "complication", "zh": "遇阻", "en": "Complication", "accept_cue": "tense", "refuse_cue": "quiet",
		"task": "Show a person or the setting responding to the choice already made. Make the new obstacle and the different costs visible without predicting unresolved stat changes.",
		"accept_zh": "门后还有一道窄缝。猫用%s试探它，才发现前路需要有所取舍。", "refuse_zh": "猫把%s留在门外。窄缝还在，它得换一种办法。",
		"accept_en": "A narrow gap waits beyond the door. The cat tests it with %s and discovers that getting through will cost something.", "refuse_en": "The cat leaves %s outside. The gap is still there, so it needs another way through.",
	}, {
		"id": "turning_point", "zh": "转折", "en": "Turning point", "accept_cue": "reveal", "refuse_cue": "reveal",
		"task": "Reinterpret an established detail. Reveal why the earlier approach fell short and offer a concrete change of direction.",
		"accept_zh": "猫举起%s，才发觉那道窄缝也能透光。它换了一个方向看。", "refuse_zh": "猫放下%s，退后一步。原来自己一直盯着门缝，忘了还有门把手。",
		"accept_en": "The cat raises %s and sees light through the gap. What looked like a dead end now points somewhere.", "refuse_en": "The cat sets %s down and steps back. It has been staring at the gap so long that it missed the handle.",
	}, {
		"id": "climax", "zh": "高潮", "en": "Climax", "accept_cue": "tense", "refuse_cue": "tense",
		"task": "Bring the original desire and the cost into direct conflict. Give each choice a distinct act of commitment or restraint.",
		"accept_zh": "猫带着%s握住门把手。这一回，它必须决定愿意付出多少。", "refuse_zh": "猫让%s从爪边滑下。它守住愿意付出的界线，即使门随时可能关上。",
		"accept_en": "With %s beside it, the cat grips the handle. Now it has to decide how much it is willing to spend.", "refuse_en": "The cat lets %s slip past its paw. It keeps its limit even as the door starts to close.",
	}, {
		"id": "resolution", "zh": "收束", "en": "Resolution", "accept_cue": "warm", "refuse_cue": "quiet",
		"task": "Bring an earlier detail back and show the immediate consequence of this last choice. Leave the direct answer to the post-choice finale.",
		"accept_zh": "猫带着%s回望门槛。它记住了自己跨出去的那一步。", "refuse_zh": "猫把%s放回门边。它记住了让自己停下来的理由。",
		"accept_en": "The cat looks back at the threshold with %s beside it. It remembers the step it chose to take.", "refuse_en": "The cat returns %s to the door and remembers what made it stop.",
	},
]


static func act_number(state: Dictionary, last_action: String = "") -> int:
	if int(state.get("choice_limit", 0)) != ACTS.size():
		return 0
	var completed := int(state.get("choices_completed", 0))
	return clampi(completed + (0 if state.get("terminal", false) and last_action != "roll" else 1), 1, ACTS.size())


static func brief(state: Dictionary, last_action: String = "") -> Dictionary:
	var number := act_number(state, last_action)
	if number == 0:
		return {}
	var entry: Dictionary = ACTS[number - 1]
	var task: String = entry["task"]
	if state.get("terminal", false):
		if state.get("won", false):
			task = "Answer the opening question directly. Cite one or two real selected choices and offer a next step in the same theatre story. Close this fifth act without another draw."
		else:
			task = "End at the actual boundary breach. Answer the opening question using the choices made so far and the tendency that crossed its limit. Do not invent the remaining acts."
	return {
		"number": number, "total": ACTS.size(), "id": entry["id"], "task": task,
		"suggested_cues": {"finale": "reveal"} if state.get("terminal", false) else {
			"accept": fallback_cue(number, "accept"), "refuse": fallback_cue(number, "refuse"),
		},
	}


static func heading(number: int) -> String:
	if number < 1 or number > ACTS.size():
		return ""
	var entry: Dictionary = ACTS[number - 1]
	if Loc.language == "zh":
		return "第 %d 幕 · %s" % [number, entry["zh"]]
	return "Act %d · %s" % [number, entry["en"]]


static func fallback_line(number: int, action: String, card: String, language: String) -> String:
	var entry: Dictionary = ACTS[number - 1]
	return str(entry[action + ("_zh" if language == "zh" else "_en")]) % card


static func fallback_cue(number: int, action: String) -> String:
	return ACTS[number - 1][action + "_cue"]
