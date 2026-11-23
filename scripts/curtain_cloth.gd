extends RefCounted
## A low-resolution cloth lattice drives the imported curtain surface on the GPU.

const FABRIC := preload("res://shaders/theatre_curtain.gdshader")
const COLUMNS := 13
const ROWS := 8
const POINTS := COLUMNS * ROWS
const SOLVER_PASSES := 3

var _material := ShaderMaterial.new()
var _rest := PackedVector3Array()
var _positions := PackedVector3Array()
var _previous := PackedVector3Array()
var _offsets := PackedVector4Array()
var _width: float
var _height: float
var _direction: float
var _horizontal: float
var _vertical: float
var _diagonal: float
var _time: float = 0.0


func _init(panel: MeshInstance3D, direction: float) -> void:
	var bounds := panel.mesh.get_aabb()
	_width = bounds.size.x
	_height = bounds.size.y
	_direction = direction
	_horizontal = _width / float(COLUMNS - 1)
	_vertical = _height / float(ROWS - 1)
	_diagonal = Vector2(_horizontal, _vertical).length()
	for row in ROWS:
		for column in COLUMNS:
			_rest.append(Vector3(column * _horizontal, _height - row * _vertical, 0.0))
	_positions.resize(POINTS)
	_previous.resize(POINTS)
	_offsets.resize(POINTS)
	_material.shader = FABRIC
	_material.set_shader_parameter("panel_width", _width)
	_material.set_shader_parameter("panel_height", _height)
	_material.set_shader_parameter("direction", direction)
	panel.material_override = _material
	panel.custom_aabb = bounds.grow(0.4)
	snap(0.0)


func snap(openness: float) -> void:
	for i in POINTS:
		var guide := _guide(i, openness)
		_positions[i] = guide
		_previous[i] = guide
	_upload(openness)


func advance(openness: float, delta: float) -> void:
	_time += delta
	for i in POINTS:
		var guide := _guide(i, openness)
		var position := _positions[i]
		var velocity := (position - _previous[i]) * 0.89
		_previous[i] = position
		if i < COLUMNS:
			_positions[i] = guide
			continue
		var depth := 1.0 - _rest[i].y / _height
		var air := sin(_time * 8.0 + depth * 3.8 + _direction * 0.7)
		var force := (guide - position) * Vector3(175.0, 220.0, 202.0)
		force += Vector3(0.0, -5.0, air * 4.5 * depth * openness)
		_positions[i] = position + velocity + force * delta * delta

	for pass_index in SOLVER_PASSES:
		for i in range(COLUMNS, POINTS):
			_constrain(i, i - COLUMNS, _vertical, 0.93)
			if i % COLUMNS != 0:
				_constrain(i, i - 1, _horizontal, 0.64)
				_constrain(i, i - COLUMNS - 1, _diagonal, 0.25)
		for i in range(COLUMNS, POINTS):
			var point := _positions[i]
			_positions[i] = Vector3(clampf(point.x, 0.0, _width), maxf(point.y, -0.025), point.z)
	_upload(openness)


func capture() -> Dictionary:
	return {"positions": _positions.duplicate(), "previous": _previous.duplicate(), "time": _time}


func restore(state: Dictionary, openness: float) -> void:
	_positions = state["positions"].duplicate()
	_previous = state["previous"].duplicate()
	_time = state["time"]
	_upload(openness)


func _guide(i: int, openness: float) -> Vector3:
	var u := float(i % COLUMNS) / float(COLUMNS - 1)
	var v := 1.0 - _rest[i].y / _height
	var draw := openness - sin(openness * PI) * v * 0.16
	var width := lerpf(_width, _width * 0.14, draw)
	var hem_lift := 0.075 * draw * v * u
	var fold := sin(u * TAU * 3.0) * _horizontal * draw
	return Vector3(width * u, _rest[i].y + hem_lift, fold + 0.045 * draw * v)


func _constrain(a: int, b: int, distance: float, stiffness: float) -> void:
	var difference := _positions[b] - _positions[a]
	var length := difference.length()
	if length < 0.0001:
		return
	var correction := difference * ((length - distance) / length * stiffness)
	if b < COLUMNS:
		_positions[a] += correction
		return
	_positions[a] += correction * 0.5
	_positions[b] -= correction * 0.5


func _upload(openness: float) -> void:
	for i in POINTS:
		var delta := _positions[i] - _rest[i]
		_offsets[i] = Vector4(delta.x * _direction, delta.y, delta.z, 0.0)
	_material.set_shader_parameter("cloth_offsets", _offsets)
	_material.set_shader_parameter("openness", openness)
