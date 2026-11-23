extends Node

const Client := preload("res://scripts/agent_client.gd")
const Plan := preload("res://scripts/narrative_plan.gd")
const TEST_KEY := "fixture-token-123"

var _server := TCPServer.new()
var _peer: StreamPeerTCP
var _buffer := PackedByteArray()
var _failures: int = 0
var _served: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var listen_result := _server.listen(0, "127.0.0.1")
	if listen_result != OK:
		push_error("Could not start API fixture: " + error_string(listen_result))
		get_tree().quit(1)
		return
	var endpoint := "http://127.0.0.1:%d/v1" % _server.get_local_port()
	var menu := preload("res://scenes/theatre_menu.tscn").instantiate()
	var tree := get_tree()
	TheatreSession.profile_path = "user://test_agent_play_%d.dat" % OS.get_process_id()
	TheatreSession.read_profile()
	tree.root.add_child(menu)
	tree.current_scene = menu
	menu._open_settings()
	menu._open_agent_console()
	var console: PanelContainer = menu.panel
	for i in AgentSettings.PROVIDERS.size():
		console._switch_provider(i)
		console._endpoint.text = endpoint.trim_suffix("/v1") if i == 0 else endpoint
		console._model.text = "fixture-model"
		console._key.text = TEST_KEY
		console._fixture.select(GameManager.STORY_CHOICES if i == 1 else i)
		console._test()
		var returned := await _wait_until(func() -> bool: return not console._send.disabled)
		_check(returned and console._status.text.contains("HTTP 200"), "provider replied to the console")
		_check(console._response.text.contains("Remote fixture"), "console renders a validated model plan")
		_check(not console._request.text.contains(TEST_KEY), "request inspector omits authorization")

	console._switch_provider(0)
	console._endpoint.text = endpoint + "/chat/completions"
	console._model.text = "fixture-html"
	console._key.text = TEST_KEY
	console._test()
	await _wait_until(func() -> bool: return not console._send.disabled)
	_check(console._status.text.contains("HTTP 200") and console._status.text.contains("HTML") and console._status.text.contains("/v1/chat/completions"), "HTML dashboard replies identify the endpoint problem")
	_check(console._response.text.contains("New API"), "HTML dashboard stays visible in the response inspector")
	console._model.text = "fixture-rejected"
	console._key.text = TEST_KEY
	console._test()
	await _wait_until(func() -> bool: return not console._send.disabled)
	_check(console._status.text.contains("401") and console._response.text.contains("[redacted]"), "HTTP errors surface with reflected keys removed")
	console._model.text = "fixture-invalid"
	console._test()
	await _wait_until(func() -> bool: return not console._send.disabled)
	_check(console._status.text.contains("failed validation"), "invalid stage cues are rejected")
	console._model.text = "fixture-model"
	AgentSettings.enabled = true
	AgentSettings.active_provider = "openai"
	AgentSettings._profiles["openai"] = console._form()
	menu._close_panel()
	menu._enter_game(false)
	_check(menu.mode == "question", "enabled Agent prompts for the opening question")
	menu._enter_game(false, "What should I do next?")
	await tree.scene_changed
	var table := tree.current_scene
	_check(table._narrative.is_playing(), "the opening gates play while the model is preparing the scene")
	var played := await _wait_until(func() -> bool:
		return str(TheatreSession.narrative.get("beat", {}).get("line", "")).contains("Remote fixture")
	)
	_check(played and table._narrative_stage != null, "actual gameplay plays the authenticated remote opening")
	_check(TheatreSession.narrative.get("question") == "What should I do next?", "question survives the menu handoff")
	_check(TheatreSession.narrative.get("opening_anchor") == "a brass key" and table._narrative_stage._continue.visible, "the opening keeps its motif and can be advanced once read")
	_check(_served == 7, "all requests reached the same local HTTP fixture")
	TheatreSession.tracking = false
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TheatreSession.profile_path + suffix):
			DirAccess.remove_absolute(TheatreSession.profile_path + suffix)
	table.queue_free()
	await tree.process_frame
	print("Agent API failures: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _process(_delta: float) -> void:
	if _peer == null and _server.is_connection_available():
		_peer = _server.take_connection()
		_buffer.clear()
	if _peer == null:
		return
	_peer.poll()
	var available := _peer.get_available_bytes()
	if available > 0:
		_buffer.append_array(_peer.get_data(available)[1])
	var request := _buffer.get_string_from_utf8()
	var header_end := request.find("\r\n\r\n")
	if header_end < 0:
		return
	var headers := request.left(header_end)
	var length := 0
	for header: String in headers.split("\r\n"):
		if header.to_lower().begins_with("content-length:"):
			length = header.get_slice(":", 1).strip_edges().to_int()
	if _buffer.size() < header_end + 4 + length:
		return
	_respond(headers, JSON.parse_string(request.substr(header_end + 4)))
	_peer = null


func _respond(headers: String, payload: Dictionary) -> void:
	_served += 1
	var context: Dictionary
	var protocol := "openai"
	if headers.begins_with("POST /v1/messages "):
		protocol = "anthropic"
		context = JSON.parse_string(payload["messages"][0]["content"])
		_check(headers.to_lower().contains("x-api-key: " + TEST_KEY), "Anthropic key header")
	elif headers.begins_with("POST /v1/models/fixture-model:generateContent "):
		protocol = "gemini"
		context = JSON.parse_string(payload["contents"][0]["parts"][0]["text"])
		_check(headers.to_lower().contains("x-goog-api-key: " + TEST_KEY), "Gemini key header")
	else:
		_check(headers.begins_with("POST /v1/chat/completions "), "compatible endpoint path")
		_check(headers.to_lower().contains("authorization: bearer " + TEST_KEY), "compatible bearer header")
		context = JSON.parse_string(payload["messages"][1]["content"])
	var plan := Plan.fallback(context)
	_check(context.has("act") and context["act"]["total"] == 5, "model request contains the current five-act skill")
	if context["state"]["terminal"]:
		_check(context["act"]["id"] == "resolution" and context["act"]["task"].contains("opening question"), "finale uses the answer skill")
	var scene: Dictionary = plan["finale"] if context["state"]["terminal"] else plan["opening"]
	scene["line"] = "Remote fixture"
	if not context["state"]["terminal"]:
		scene["anchor"] = "a brass key"
	if payload.get("model") == "fixture-invalid":
		scene["cue"] = "unsupported"
	var content := JSON.stringify(plan)
	var reply := {"choices": [{"message": {"content": content}}]}
	if protocol == "anthropic":
		reply = {"content": [{"type": "text", "text": content}]}
	elif protocol == "gemini":
		reply = {"candidates": [{"content": {"parts": [{"text": content}]}}]}
	var status := "200 OK"
	if payload.get("model") == "fixture-rejected":
		status = "401 Unauthorized"
		reply = {"error": {"message": TEST_KEY}}
	var bytes := JSON.stringify(reply).to_utf8_buffer()
	var content_type := "application/json"
	if payload.get("model") == "fixture-html":
		content_type = "text/html; charset=utf-8"
		bytes = "<!doctype html><html><head><title>New API</title></head></html>".to_utf8_buffer()
	_peer.put_data(("HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [status, content_type, bytes.size()]).to_utf8_buffer())
	_peer.put_data(bytes)
	_peer.disconnect_from_host()


func _wait_until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 3500
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return condition.call()


func _check(passed: bool, message: String) -> void:
	if not passed:
		_failures += 1
		push_error(message)
