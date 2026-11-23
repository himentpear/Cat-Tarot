extends PanelContainer
## Minimal configuration and inspection UI for the live narrative transport.

signal close_requested

const Client := preload("res://scripts/agent_client.gd")
const Skills := preload("res://scripts/narrative_skills.gd")
const PROVIDER_NAMES := ["OpenAI-compatible", "Anthropic Messages", "Gemini GenerateContent"]

var _client := Client.new()
var _provider := OptionButton.new()
var _endpoint := LineEdit.new()
var _model := LineEdit.new()
var _key := LineEdit.new()
var _remember := CheckBox.new()
var _enabled := CheckBox.new()
var _question := LineEdit.new()
var _fixture := OptionButton.new()
var _status := Label.new()
var _request := TextEdit.new()
var _response := TextEdit.new()
var _send := Button.new()
var _drafts: Dictionary = {}
var _selected: String = ""


func _ready() -> void:
	add_child(_client)
	_build()
	var index := AgentSettings.PROVIDERS.find(AgentSettings.active_provider)
	_provider.select(index)
	_switch_provider(index)
	_enabled.button_pressed = AgentSettings.enabled
	_provider.grab_focus()


func _build() -> void:
	theme = UiFonts.build_ui_theme(17)
	theme.set_color("font_color", "Label", Color("#27272a"))
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("#f6f5f3")
	surface.border_color = Color("#939095")
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(6)
	surface.content_margin_left = 24
	surface.content_margin_right = 24
	surface.content_margin_top = 18
	surface.content_margin_bottom = 18
	add_theme_stylebox_override("panel", surface)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := _label(header, _text("Agent 控制台", "Agent console"))
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, _text("返回设置", "Back to settings"), close_requested.emit)
	root.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	var config := VBoxContainer.new()
	config.custom_minimum_size.x = 350
	config.add_theme_constant_override("separation", 8)
	columns.add_child(config)
	_label(config, _text("API 协议", "API protocol"))
	for name_text: String in PROVIDER_NAMES:
		_provider.add_item(name_text)
	_provider.item_selected.connect(_switch_provider)
	config.add_child(_provider)
	_field(config, _text("基础 URL", "Base URL"), _endpoint)
	_field(config, _text("模型 ID", "Model ID"), _model)
	_field(config, _text("API 密钥", "API key"), _key)
	_key.secret = true
	_key.placeholder_text = _text("留空使用系统环境变量", "Blank uses the environment variable")
	_remember.text = _text("记住密钥（本机明文）", "Remember key (local plaintext)")
	_enabled.text = _text("在新局中启用 Agent", "Enable Agent in new plays")
	_style_checkbox(_remember)
	_style_checkbox(_enabled)
	config.add_child(_remember)
	config.add_child(_enabled)
	_button(config, _text("保存配置", "Save configuration"), _save)

	var debug := VBoxContainer.new()
	debug.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug.add_theme_constant_override("separation", 8)
	columns.add_child(debug)
	_field(debug, _text("测试问题", "Test question"), _question)
	_question.max_length = 240
	_question.text = _text("我下一步该怎么走？", "What should I do next?")
	var actions := HBoxContainer.new()
	debug.add_child(actions)
	for i in GameManager.STORY_CHOICES:
		_fixture.add_item(Skills.heading(i + 1))
	_fixture.add_item(_text("终幕回答", "Finale"))
	actions.add_child(_fixture)
	_send.text = _text("发送测试请求", "Send test request")
	_send.pressed.connect(_test)
	actions.add_child(_send)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color("#27272a"))
	debug.add_child(_status)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	debug.add_child(tabs)
	for view: TextEdit in [_request, _response]:
		view.editable = false
		view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		tabs.add_child(view)
	tabs.set_tab_title(0, _text("请求", "Request"))
	tabs.set_tab_title(1, _text("回复", "Response"))
	tabs.current_tab = 1


func _switch_provider(index: int) -> void:
	_client.cancel()
	if not _selected.is_empty():
		_drafts[_selected] = _form()
	_selected = AgentSettings.PROVIDERS[index]
	var profile: Dictionary = _drafts.get(_selected, AgentSettings.get_profile(_selected))
	_endpoint.text = profile["base_url"]
	_model.text = profile["model"]
	_key.text = profile["api_key"]
	_remember.button_pressed = profile["remember_key"]
	_request.text = ""
	_response.text = ""
	_send.disabled = false
	_status.text = ""


func _form() -> Dictionary:
	return {
		"provider": _selected, "base_url": _endpoint.text.strip_edges(), "model": _model.text.strip_edges(),
		"api_key": _key.text.strip_edges(), "remember_key": _remember.button_pressed,
	}


func _save() -> void:
	var profile := _form()
	if _enabled.button_pressed or not str(profile["model"]).is_empty():
		var error := Client.configuration_error(profile)
		if not error.is_empty():
			_status.text = error
			return
	var result := AgentSettings.save_profile(profile, _enabled.button_pressed)
	_status.text = _text("配置已保存。", "Configuration saved.") if result == OK else error_string(result)


func _test() -> void:
	var profile := AgentSettings.with_environment_key(_form())
	var error := Client.configuration_error(profile)
	if not error.is_empty():
		_status.text = error
		return
	var fixture := _test_context(_fixture.selected)
	var request := Client.request_data(profile, fixture)
	var preview := "POST %s\n\n%s" % [request["url"], JSON.stringify(request["payload"], "  ")]
	var key: String = profile["api_key"]
	_request.text = preview if key.is_empty() else preview.replace(key, "[redacted]")
	_response.text = ""
	_status.text = _text("正在请求模型…", "Waiting for the model…")
	_send.disabled = true
	_client.send(fixture, profile, _show_result)


func _show_result(result: Dictionary) -> void:
	_send.disabled = false
	var label := _text("场景校验通过", "Scene validated") if result["error"].is_empty() else str(result["error"])
	_status.text = "%s  ·  HTTP %s  ·  %d ms" % [label, str(result["status"]) if result["status"] else "—", result["elapsed_ms"]]
	_response.text = JSON.stringify(result["plan"], "  ") if not result["plan"].is_empty() else result["raw"]


func _test_context(index: int) -> Dictionary:
	var completed := clampi(index, 0, GameManager.STORY_CHOICES)
	var finale := completed == GameManager.STORY_CHOICES
	var options: Array[Dictionary] = []
	if not finale:
		for id in 3:
			var data := CardDatabase.orientation_data(id, "upright")
			options.append({"slot": id, "card_id": id, "orientation": "UPRIGHT", "accept": data.get("accept", []), "refuse": data.get("refuse", [])})
	var history: Array[Dictionary] = []
	for i in completed:
		var id := i + 3
		history.append({
			"act_number": i + 1, "card_id": id, "orientation": "UPRIGHT", "action": "accept",
			"line": Skills.fallback_line(i + 1, "accept", Loc.card_name(id), Loc.language),
		})
	return {
		"language": Loc.language, "question": _question.text.strip_edges(), "history": history, "last_resolution": {},
		"state": {
			"revision": completed, "choices_completed": completed, "choice_limit": GameManager.STORY_CHOICES, "options": options,
			"marks": [], "die_value": 1, "stats": {"passion": 4, "intuition": 4, "curiosity": 4, "comfort": 4},
			"terminal": finale, "won": finale, "reason": "reason.world_end" if finale else "",
		},
	}


func _text(zh: String, en: String) -> String:
	return zh if Loc.language == "zh" else en


func _label(parent: Control, words: String) -> Label:
	var label := Label.new()
	label.text = words
	parent.add_child(label)
	return label


func _field(parent: Control, caption: String, input: LineEdit) -> void:
	_label(parent, caption)
	parent.add_child(input)


func _button(parent: Control, words: String, action: Callable) -> void:
	var button := Button.new()
	button.text = words
	button.pressed.connect(action)
	parent.add_child(button)


func _style_checkbox(box: CheckBox) -> void:
	for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		box.add_theme_color_override(color, Color("#27272a"))
