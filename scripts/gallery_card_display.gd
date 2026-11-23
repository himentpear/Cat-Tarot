extends Node3D
## Two physical card meshes share the draw and return paths above the chest.

signal card_presented(card_id: int)

const CARD_SCENE := preload("res://scenes/card_3d.tscn")
const CARD_BACK := preload("res://assets/models/theatre/card_back.svg")
const STACK_POSITION := Vector3(0.0, 0.09, 0.03)
const DISPLAY_POSITION := Vector3(-0.02, 0.47, 0.15)
const DISPLAY_ROTATION := Vector3(-18.0, -8.0, -3.0)
const STACK_SCALE := 0.235
const DISPLAY_SCALE := 0.30
const RETURN_TIME := 0.30
const DRAW_TIME := 0.43

var presented_card: Card3D
var _cards: Array[Card3D] = []
var _motion: Tween
var _queued_id: int = -1
var _queued_texture: Texture2D
var _queued_direction: int = 1


func _ready() -> void:
	var back_material := StandardMaterial3D.new()
	back_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back_material.albedo_texture = CARD_BACK
	for i in 2:
		var card: Card3D = CARD_SCENE.instantiate()
		add_child(card)
		card.area.collision_layer = 0
		card.area.input_ray_pickable = false
		card.animation_locked = true
		card.back.material_override = back_material
		card.back.get_node("BackIcon").hide()
		card.hide()
		_cards.append(card)


func show_card(card_id: int, texture: Texture2D, direction: int) -> void:
	if _motion != null and _motion.is_running():
		_queued_id = card_id
		_queued_texture = texture
		_queued_direction = direction
		return
	if presented_card != null and presented_card.card_id == card_id:
		return
	var incoming := _cards[1] if presented_card == _cards[0] else _cards[0]
	incoming.setup(card_id, texture)
	var side := -1.0 if direction < 0 else 1.0
	_move_incoming(0.0, incoming, side)
	var outgoing := presented_card
	var draw_delay := 0.0
	_motion = create_tween().set_parallel(true)
	if outgoing == null:
		incoming.show()
	else:
		draw_delay = 0.19
		_motion.tween_method(_move_outgoing.bind(outgoing, side), 0.0, 1.0, RETURN_TIME)
		_motion.tween_callback(outgoing.hide).set_delay(RETURN_TIME)
		_motion.tween_callback(incoming.show).set_delay(draw_delay)
	_motion.tween_callback(Audio.play_sfx.bind("card_slide", -9.0)).set_delay(draw_delay)
	_motion.tween_method(_move_incoming.bind(incoming, side), 0.0, 1.0, DRAW_TIME).set_delay(draw_delay)
	_motion.tween_callback(Audio.play_sfx.bind("card_flip", -10.0)).set_delay(draw_delay + 0.24)
	_motion.finished.connect(_finish_draw.bind(incoming), CONNECT_ONE_SHOT)


func clear() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	_queued_id = -1
	_queued_texture = null
	presented_card = null
	for card in _cards:
		card.hide()


func _move_outgoing(progress: float, card: Card3D, side: float) -> void:
	var travel := smoothstep(0.0, 1.0, progress)
	var arch := sin(PI * travel)
	card.position = DISPLAY_POSITION.lerp(STACK_POSITION, travel) + Vector3(0.23 * side, 0.14, 0.04) * arch
	card.rotation_degrees = DISPLAY_ROTATION.lerp(Vector3(-90.0, 90.0, 0.0), travel)
	card.rotation_degrees.z -= side * 19.0 * arch
	card.scale = Vector3.ONE * lerpf(DISPLAY_SCALE, STACK_SCALE, travel)


func _move_incoming(progress: float, card: Card3D, side: float) -> void:
	var lift := smoothstep(0.0, 0.80, progress)
	var turn := smoothstep(0.20, 0.91, progress)
	var arch := sin(PI * lift)
	var settle := sin(PI * smoothstep(0.72, 1.0, progress))
	card.position = STACK_POSITION.lerp(DISPLAY_POSITION, lift) + Vector3(-0.14 * side, 0.12, 0.12) * arch
	card.position.y += 0.025 * settle
	card.rotation_degrees = Vector3(90.0, 90.0, 0.0).lerp(DISPLAY_ROTATION, turn)
	card.rotation_degrees.z += side * (14.0 * arch - 4.0 * settle)
	card.scale = Vector3.ONE * lerpf(STACK_SCALE, DISPLAY_SCALE, lift)


func _finish_draw(card: Card3D) -> void:
	_motion = null
	presented_card = card
	card_presented.emit(card.card_id)
	if _queued_id < 0:
		return
	var next_id := _queued_id
	var next_texture := _queued_texture
	_queued_id = -1
	_queued_texture = null
	show_card(next_id, next_texture, _queued_direction)
