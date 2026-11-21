extends CanvasLayer
## Plays validated subtitle, color and sound cues on the table scene.

signal beat_finished
signal finale_acknowledged

const CUE_COLORS := {
	"quiet": Color("#241c29"), "warm": Color("#46291d"),
	"tense": Color("#482233"), "reveal": Color("#3c3153"),
}
const CUE_SOUNDS := {"warm": "card_slide", "tense": "card_flip", "reveal": "card_reveal"}

var _panel: PanelContainer
var _label: Label
var _continue: Button
var _finish_timer: Timer
var _style: StyleBoxFlat


func _ready() -> void:
	layer = 5
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_panel.anchor_left = 0.16
	_panel.anchor_right = 0.84
	_panel.offset_top = 20.0
	_panel.theme = UiFonts.build_ui_theme(20)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.set_corner_radius_all(10)
	_style.content_margin_left = 18.0
	_style.content_margin_right = 18.0
	_style.content_margin_top = 9.0
	_style.content_margin_bottom = 9.0
	_panel.add_theme_stylebox_override("panel", _style)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color("#ffebce"))
	column.add_child(_label)
	_continue = Button.new()
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue.pressed.connect(_acknowledge)
	column.add_child(_continue)
	_finish_timer = Timer.new()
	_finish_timer.one_shot = true
	_finish_timer.timeout.connect(_finish)
	add_child(_finish_timer)
	clear()


func play(beat: Dictionary, finale: bool) -> void:
	clear()
	var cue: String = beat["cue"]
	_style.bg_color = CUE_COLORS[cue]
	_label.text = beat["line"]
	_continue.text = "合上剧本" if Loc.language == "zh" else "Close the script"
	_continue.visible = finale
	_panel.show()
	if CUE_SOUNDS.has(cue):
		Audio.play_sfx(CUE_SOUNDS[cue], -9.0)
	if not finale:
		_finish_timer.start(clampf(float(_label.text.length()) / 22.0, 2.4, 7.0))


func preview(line: String) -> void:
	clear()
	if line.is_empty():
		return
	_label.text = line
	_style.bg_color = CUE_COLORS["quiet"]
	_continue.hide()
	_panel.show()


func clear() -> void:
	_finish_timer.stop()
	_panel.hide()


func _finish() -> void:
	clear()
	beat_finished.emit()


func _acknowledge() -> void:
	clear()
	finale_acknowledged.emit()
