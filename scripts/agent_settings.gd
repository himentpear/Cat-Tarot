extends Node

const PATH := "user://agent_api.cfg"
const PROVIDERS := ["openai", "anthropic", "gemini"]
const BASE_URLS := {
	"openai": "https://api.openai.com/v1",
	"anthropic": "https://api.anthropic.com/v1",
	"gemini": "https://generativelanguage.googleapis.com/v1beta",
}
const KEY_ENV := {"openai": "OPENAI_API_KEY", "anthropic": "ANTHROPIC_API_KEY", "gemini": "GEMINI_API_KEY"}

var enabled: bool = false
var active_provider: String = "openai"
var _profiles: Dictionary = {}


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	var provider := str(config.get_value("agent", "provider", "openai"))
	if provider in PROVIDERS:
		active_provider = provider
	enabled = bool(config.get_value("agent", "enabled", false))
	for id: String in PROVIDERS:
		var profile := get_profile(id)
		for key: String in ["base_url", "model", "api_key"]:
			profile[key] = str(config.get_value(id, key, profile[key]))
		profile["remember_key"] = bool(config.get_value(id, "remember_key", false))
		_profiles[id] = profile


func get_profile(provider: String) -> Dictionary:
	return _profiles.get(provider, {
		"provider": provider, "base_url": BASE_URLS.get(provider, ""), "model": "",
		"api_key": "", "remember_key": false,
	}).duplicate()


func with_environment_key(profile: Dictionary) -> Dictionary:
	var runtime := profile.duplicate()
	if str(runtime.get("api_key", "")).is_empty():
		runtime["api_key"] = OS.get_environment(KEY_ENV.get(runtime.get("provider"), "")).strip_edges()
	return runtime


func save_profile(profile: Dictionary, use_agent: bool) -> Error:
	var provider: String = profile["provider"]
	var profiles := _profiles.duplicate()
	profiles[provider] = profile.duplicate()
	var config := ConfigFile.new()
	config.set_value("agent", "enabled", use_agent)
	config.set_value("agent", "provider", provider)
	for id: String in profiles:
		var saved: Dictionary = profiles[id]
		config.set_value(id, "base_url", saved["base_url"])
		config.set_value(id, "model", saved["model"])
		config.set_value(id, "remember_key", saved["remember_key"])
		if saved["remember_key"] and not str(saved["api_key"]).is_empty():
			config.set_value(id, "api_key", saved["api_key"])
	var error := config.save(PATH)
	if error == OK:
		_profiles = profiles
		active_provider = provider
		enabled = use_agent
	return error
