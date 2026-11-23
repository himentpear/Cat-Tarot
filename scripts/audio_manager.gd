extends Node

const MUSIC_PATH := "res://assets/audio/music/tarot_ambience.ogg"
const SFX_DIR := "res://assets/audio/sfx/"
const SFX_FILES := {
	"card_draw": "card_draw.wav",
	"card_flip": "card_flip.wav",
	"card_slide": "card_slide.wav",
	"card_tap": "card_tap.wav",
	"card_discard": "card_discard.wav",
	"card_reveal": "card_reveal.wav",
	"card_fan_open": "card_fan_open.wav",
	"dice_roll": "dice_roll.wav",
	"theatre_bell": "theatre_bell.wav",
}
const SFX_VOICES := 12
const MUSIC_BUS_DB := -13.0
const SFX_BUS_DB := -3.0
const MUSIC_FADE_TIME := 2.5

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_tween: Tween
var _next_voice: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_setup_bus("Music", MUSIC_BUS_DB)
	_setup_bus("SFX", SFX_BUS_DB)
	_load_sfx()
	_create_voices()
	_create_music()


func _setup_bus(bus_name: String, volume_db: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		index = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
	AudioServer.set_bus_volume_db(index, volume_db)


func _load_sfx() -> void:
	for key in SFX_FILES:
		var path := SFX_DIR + str(SFX_FILES[key])
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				_streams[key] = stream


func _create_voices() -> void:
	for i in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "SFX%d" % i
		player.bus = "SFX"
		add_child(player)
		_players.append(player)


func _create_music() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = "Music"
	add_child(_music)
	if not ResourceLoader.exists(MUSIC_PATH):
		return
	var stream := load(MUSIC_PATH) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music.stream = stream


func _exit_tree() -> void:
	if _music != null:
		_music.stop()
		_music.stream = null
	for player in _players:
		if player != null:
			player.stop()
			player.stream = null
	_streams.clear()


func start_music() -> void:
	if _music == null or _music.stream == null:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music.volume_db = -40.0
	_music.play()
	_music.seek(0.0)
	_music_tween = create_tween()
	_music_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_music_tween.tween_property(_music, "volume_db", 0.0, MUSIC_FADE_TIME)


func stop_music() -> void:
	if _music == null:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music.stop()


func is_music_playing() -> bool:
	return _music != null and _music.playing


func play_sfx(key: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(key):
		return
	var player := _next_player()
	player.stream = _streams[key]
	player.volume_db = volume_db
	player.pitch_scale = pitch * _rng.randf_range(0.985, 1.015)
	player.play()


func _next_player() -> AudioStreamPlayer:
	for offset in _players.size():
		var index := (_next_voice + offset) % _players.size()
		if not _players[index].playing:
			_next_voice = (index + 1) % _players.size()
			return _players[index]
	var fallback := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	return fallback
