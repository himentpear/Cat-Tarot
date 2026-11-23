extends Node
## Prepares the actual table instance for handoff to the main viewport.

signal preparation_finished

const TABLE_PATH := "res://scenes/main.tscn"
const WARMUP_SIZE := Vector2i(320, 180)

var finished: bool = false
var _table: Node3D
var _menu: Node3D
var _viewport: SubViewport
var _load_requested: bool = false
var _preparing: bool = false


func begin_load() -> void:
	if _load_requested:
		return
	_load_requested = true
	ResourceLoader.load_threaded_request(TABLE_PATH, "PackedScene")


func prepare() -> void:
	if finished or _preparing:
		return
	begin_load()
	_preparing = true
	_prepare.call_deferred()


func take_table() -> Node3D:
	if not finished:
		return null
	finished = false
	_load_requested = false
	var table := _table
	_table = null
	if not is_instance_valid(table):
		return null
	_viewport.remove_child(table)
	_viewport.queue_free()
	_viewport = null
	table.set("preparing_offscreen", false)
	table.request_ready()
	return table


func keep_menu(menu: Node3D) -> void:
	# SceneTree frees the current scene on a swap. Keep this one detached for Esc.
	if is_instance_valid(_menu):
		_menu.free()
	get_tree().current_scene = null
	menu.get_parent().remove_child(menu)
	_menu = menu


func take_menu() -> Node3D:
	var menu := _menu
	_menu = null
	if is_instance_valid(menu):
		menu.request_ready()
	return menu


func _exit_tree() -> void:
	if is_instance_valid(_menu):
		_menu.free()


func _prepare() -> void:
	var tree := get_tree()
	var status := ResourceLoader.load_threaded_get_status(TABLE_PATH)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await tree.process_frame
		status = ResourceLoader.load_threaded_get_status(TABLE_PATH)
	var packed: PackedScene
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(TABLE_PATH) as PackedScene
	else:
		packed = load(TABLE_PATH) as PackedScene
	if packed != null:
		_table = packed.instantiate() as Node3D
	if _table != null:
		_viewport = SubViewport.new()
		_viewport.size = WARMUP_SIZE
		_viewport.world_3d = World3D.new()
		_viewport.msaa_3d = get_viewport().msaa_3d
		_viewport.gui_disable_input = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_viewport)
		_table.set("preparing_offscreen", true)
		_viewport.add_child(_table)
		if DisplayServer.get_name() != "headless":
			_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
	finished = true
	_preparing = false
	preparation_finished.emit()
