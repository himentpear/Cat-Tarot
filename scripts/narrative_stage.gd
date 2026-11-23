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
var _heading: Label
var _label: Label
var _consequence: Label
var _continue: Button
var _closing_script: bool = false
var _finish_timer: Timer
var _style: StyleBoxFlat


func _ready() -> void:
	layer = 5
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_panel.anchor_left = 0.16
	_panel.anchor_right = 0.84
	_panel.offset_top = 66.0
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
	_heading = Label.new()
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.add_theme_font_size_override("font_size", 16)
	_heading.add_theme_color_override("font_color", Color("#d6ba8c"))
	column.add_child(_heading)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color("#ffebce"))
	column.add_child(_label)
	_consequence = Label.new()
	_consequence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_consequence.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_consequence.add_theme_font_size_override("font_size", 16)
	_consequence.add_theme_color_override("font_color", Color("#d6ba8c"))
	column.add_child(_consequence)
	_continue = Button.new()
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue.pressed.connect(_continue_reading)
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
	_set_heading(str(beat.get("heading", "")))
	_label.text = beat["line"]
	_label.show()
	_consequence.text = beat.get("consequence", "")
	_consequence.visible = not _consequence.text.is_empty()
	var opening: bool = beat.get("is_opening", false)
	_closing_script = finale
	_continue.text = ("合上剧本" if finale else "继续") if Loc.language == "zh" else ("Close the script" if finale else "Continue")
	_continue.visible = finale or opening
	_panel.show()
	if CUE_SOUNDS.has(cue):
		Audio.play_sfx(CUE_SOUNDS[cue], -9.0)
	if not finale and not beat.get("waiting", false):
		var characters := _label.text.length() + _consequence.text.length()
		_finish_timer.start(clampf(float(characters) / (14.0 if opening else 22.0), 6.0 if opening else 2.4, 14.0 if opening else 10.0))


func preview(line: String, heading: String = "") -> void:
	clear()
	if line.is_empty() and heading.is_empty():
		return
	_set_heading(heading)
	_label.text = line
	_label.visible = not line.is_empty()
	_consequence.hide()
	_style.bg_color = CUE_COLORS["quiet"]
	_continue.hide()
	_panel.show()


func _set_heading(heading: String) -> void:
	_heading.text = heading
	_heading.visible = not heading.is_empty()


func clear() -> void:
	_finish_timer.stop()
	_panel.hide()


func _finish() -> void:
	clear()
	beat_finished.emit()


func _continue_reading() -> void:
	if _closing_script:
		clear()
		finale_acknowledged.emit()
	else:
		_finish()
