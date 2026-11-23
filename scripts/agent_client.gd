extends Node
## One cancellable model request. Console and gameplay use the same protocol and validation.

const Plan := preload("res://scripts/narrative_plan.gd")
const Skills := preload("res://scripts/narrative_skills.gd")
const TIMEOUT := 18.0
const SYSTEM_PROMPT := """Narrate Cat-Tarot as a storyteller speaking aloud in a small theatre. Use clear, concrete prose in the supplied language. Keep a consistent third-person narrator and let actions and sounds carry the emotion. Use short dialogue where a character would actually speak. Avoid card-by-card lectures, abstract advice, repeated metaphors, and changes between first and second person.
Use the opening question as fictional story material. For the opening, write a short scene of 3–5 sentences: establish when and where, who is present and their relationship, what just happened, what the central character wants, and one or two details someone in the room could notice. Give the situation a reason to happen now. Stop at the decision rather than answering the question. Include one short recurring object or detail from the opening as opening.anchor (at most 60 characters).
For each candidate, write two genuinely different reactions. Each branch is played only after that action is selected. Show exactly what the character does, what another character or the setting does in response, and what this changes now. Use a visible consequence. For instance: “猫把第二把钥匙留在柜台。掌柜停下数钱，把纸条翻过来，露出写在背面的时间。” Keep previews to one short line about the choice ahead.
Treat opening_scene, opening_anchor, history, and last_resolution as continuity. Reuse established people and objects. Let the next scene acknowledge an actual earlier consequence where it matters. Never turn an unchosen option into a past event, jump settings without a transition, or invent a numerical stat or outcome. The engine displays the verified rule results after a choice. Options contain direct effects only, so avoid stating exact totals or guaranteed outcomes in branch narration.
Follow the current act's task and use its suggested cues when appropriate. In the finale, directly answer the opening question, name the established actions that support that answer, and give one concrete next step. If the rules ended the play early, close the story at that moment.
Return one JSON object without Markdown. A beat is {"line":"narration","cue":"quiet|warm|tense|reveal"} with one allowed cue. Every line and preview must be non-empty and at most 640 characters. Aim for 2–3 sentences per branch.
For a nonterminal round return {"opening":{},"branches":[{"card_id":0,"orientation":"UPRIGHT","preview":"short choice preview","accept":beat,"refuse":beat}]}. Include exactly one branch for every supplied option, preserving its card_id and orientation. On the first round fill opening with a beat and its anchor. For a terminal round return {"finale":beat}."""

var _http := HTTPRequest.new()
var _complete: Callable
var _state: Dictionary = {}
var _provider: String = ""
var _secret: String = ""
var _started_at: int = 0


func _ready() -> void:
	_http.use_threads = true
	_http.timeout = TIMEOUT
	_http.max_redirects = 0
	_http.body_size_limit = 1048576
	_http.request_completed.connect(_receive)
	add_child(_http)


func cancel() -> void:
	_http.cancel_request()
	_complete = Callable()
	_state = {}
	_secret = ""


static func configuration_error(profile: Dictionary) -> String:
	if profile["provider"] not in AgentSettings.PROVIDERS:
		return "Unsupported API protocol."
	var base: String = profile["base_url"]
	var parts := base.split("://", false, 1)
	if parts.size() != 2 or parts[0] not in ["https", "http"] or parts[1].get_slice("/", 0).is_empty():
		return "Enter an HTTP(S) base URL, including the API version path if required."
	for character: String in ["?", "#", "@", " ", "\r", "\n", "\t"]:
		if base.contains(character):
			return "Use a base URL without credentials, query parameters, or spaces."
	if str(profile["model"]).is_empty():
		return "Enter a model ID."
	var key: String = profile.get("api_key", "")
	if key.contains("\r") or key.contains("\n"):
		return "The key must be a single line."
	return ""


static func request_data(profile: Dictionary, context: Dictionary) -> Dictionary:
	var context_data := context.duplicate(true)
	var act := Skills.brief(context_data["state"], str(context_data.get("last_resolution", {}).get("action", "")))
	if not act.is_empty():
		context_data["act"] = act
	for option: Dictionary in context_data["state"].get("options", []):
		option["name"] = Loc.card_name(int(option["card_id"]))
	var user_message := JSON.stringify(context_data)
	var model: String = profile["model"]
	var base: String = profile["base_url"].rstrip("/")
	var provider: String = profile["provider"]
	var key: String = profile.get("api_key", "")
	var headers := PackedStringArray(["Content-Type: application/json"])
	var payload: Dictionary
	var suffix: String
	match provider:
		"anthropic":
			suffix = "/messages"
			headers.append("anthropic-version: 2023-06-01")
			if not key.is_empty():
				headers.append("x-api-key: " + key)
			payload = {"model": model, "max_tokens": 2800, "system": SYSTEM_PROMPT, "messages": [{"role": "user", "content": user_message}]}
		"gemini":
			suffix = "/models/%s:generateContent" % model.trim_prefix("models/").uri_encode()
			if not key.is_empty():
				headers.append("x-goog-api-key: " + key)
			payload = {
				"systemInstruction": {"parts": [{"text": SYSTEM_PROMPT}]},
				"contents": [{"role": "user", "parts": [{"text": user_message}]}],
				"generationConfig": {"responseMimeType": "application/json"},
			}
		_:
			suffix = "/chat/completions"
			if base.ends_with(suffix):
				suffix = ""
			elif not base.get_slice("://", 1).contains("/"):
				suffix = "/v1" + suffix
			if not key.is_empty():
				headers.append("Authorization: Bearer " + key)
			payload = {"model": model, "messages": [{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": user_message}]}
	return {"url": base + suffix, "headers": headers, "payload": payload}


func send(context: Dictionary, profile: Dictionary, complete: Callable) -> void:
	cancel()
	_complete = complete
	_state = context["state"]
	_provider = profile["provider"]
	_secret = profile.get("api_key", "")
	_started_at = Time.get_ticks_msec()
	var error := configuration_error(profile)
	if not error.is_empty():
		_finish({}, 0, "", error)
		return
	var request := request_data(profile, context)
	var started := _http.request(request["url"], request["headers"], HTTPClient.METHOD_POST, JSON.stringify(request["payload"]))
	if started != OK:
		_finish({}, 0, "", error_string(started))


func _receive(result: int, status: int, headers: PackedStringArray, bytes: PackedByteArray) -> void:
	var body := bytes.get_string_from_utf8()
	var raw := body if _secret.is_empty() else body.replace(_secret, "[redacted]")
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish({}, status, raw, "Request timed out." if result == HTTPRequest.RESULT_TIMEOUT else "Network error (%d)." % result)
		return
	if _is_html(headers, body):
		_finish({}, status, raw, _html_error())
		return
	if status < 200 or status >= 300:
		_finish({}, status, raw, "API returned HTTP %d." % status)
		return
	var envelope: Variant = JSON.parse_string(body)
	if not envelope is Dictionary:
		_finish({}, status, raw, "API response is not a JSON object.")
		return
	var response := extract_text(envelope, _provider)
	if not _secret.is_empty():
		response = response.replace(_secret, "[redacted]")
	var plan: Variant = JSON.parse_string(response)
	if not plan is Dictionary:
		_finish({}, status, response if not response.is_empty() else raw, "Model response is missing a JSON scene.")
	elif not Plan.is_valid(plan, _state):
		_finish({}, status, response, "Scene failed validation. Check branch IDs, orientations, beats, and stage cues.")
	else:
		_finish(plan, status, response, "")


static func _is_html(headers: PackedStringArray, body: String) -> bool:
	for header: String in headers:
		if header.to_lower().begins_with("content-type:") and "text/html" in header.to_lower():
			return true
	var prefix := body.lstrip("\ufeff \t\r\n").left(32).to_lower()
	return prefix.begins_with("<!doctype html") or prefix.begins_with("<html")


func _html_error() -> String:
	if _provider == "openai":
		if Loc.language == "zh":
			return "收到了 HTML 网页。New API 请使用 OpenAI 兼容协议，基础 URL 填网关地址加 /v1。若仍是网页，请检查反向代理是否将 /v1/chat/completions 转发到 API 服务。"
		return "Received an HTML page. For New API, use the OpenAI-compatible protocol and the gateway URL ending in /v1. If it still returns a page, check proxy routing for /v1/chat/completions."
	return "收到了 HTML 网页。请核对请求页签里的 URL，确认它指向模型 API。" if Loc.language == "zh" else "Received an HTML page. Check that the URL in the Request tab points to the model API."


func _finish(plan: Dictionary, status: int, raw: String, error: String) -> void:
	var complete := _complete
	var elapsed := Time.get_ticks_msec() - _started_at
	_complete = Callable()
	_state = {}
	_secret = ""
	if complete.is_valid():
		complete.call({"plan": plan, "status": status, "raw": raw, "error": error, "elapsed_ms": elapsed})


static func extract_text(envelope: Dictionary, provider: String) -> String:
	var value: Variant
	match provider:
		"anthropic":
			value = envelope.get("content")
		"gemini":
			value = _first_object(envelope.get("candidates")).get("content")
			value = value.get("parts") if value is Dictionary else null
		_:
			value = _first_object(envelope.get("choices")).get("message")
			value = value.get("content") if value is Dictionary else null
	var response := ""
	if value is String:
		response = value
	elif value is Array:
		for part: Variant in value:
			if part is Dictionary and not part.get("thought", false) and part.get("text") is String:
				response += part["text"]
	response = response.strip_edges()
	if response.begins_with("```") and response.ends_with("```") and response.contains("\n"):
		response = response.substr(response.find("\n") + 1).trim_suffix("```").strip_edges()
	return response


static func _first_object(value: Variant) -> Dictionary:
	if value is Array and not value.is_empty() and value[0] is Dictionary:
		return value[0]
	return {}
