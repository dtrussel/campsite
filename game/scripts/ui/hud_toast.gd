class_name HudToast
extends PanelContainer

## HudToast
##
## A small wood plate with an icon and one line ("Nela took Eagle
## Eye!") that pops out under the resource tray, holds a moment and
## fades by itself (or on a click). It never pauses or slows the game,
## and its timing is in real seconds, so the perk picker's slow-down and
## the tests' speed-up do not stretch it. The HUD stacks them:
##
##   hud.show_toast("Nela took Eagle Eye!", "eye")

signal dismissed

const SECONDS: float = 3.5
const POP_SECONDS: float = 0.25
const FADE_SECONDS: float = 0.5
## The scale it pops out from.
const POP_FROM: float = 0.8

var _text: String = ""
var _seconds: float = SECONDS
var _age: float = 0.0
var _closing: bool = false
var _close_age: float = 0.0


## A toast reading `text`, with the `icon` from assets/icons (empty for
## none), shown for `seconds` real seconds.
static func make(text: String, icon: String = "", color: Color = UiKit.COLOR_GOLD_LIGHT, seconds: float = SECONDS) -> HudToast:
	var toast: HudToast = HudToast.new()
	toast._text = text
	toast._seconds = seconds
	toast._build(icon, color)
	return toast


func text() -> String:
	return _text


func is_closing() -> bool:
	return _closing


## Fades it out now; it frees itself.
func dismiss() -> void:
	if _closing:
		return
	_closing = true
	_close_age = _age
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build(icon: String, color: Color) -> void:
	name = "HudToast"
	add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COLOR_WOOD, UiKit.COLOR_BRASS_DARK, 8))
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Click to close"
	size_flags_horizontal = Control.SIZE_SHRINK_END
	modulate.a = 0.0
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	var texture: Texture2D = Fx.icon(icon) if icon != "" else null
	if texture != null:
		var picture: TextureRect = TextureRect.new()
		picture.texture = texture
		picture.custom_minimum_size = Vector2(30, 30)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(picture)
	var words: Label = UiKit.label(_text, 18, color)
	words.add_theme_font_override("font", Fx.bold_font())
	words.add_theme_constant_override("outline_size", 5)
	words.add_theme_color_override("font_outline_color", UiKit.COLOR_INK)
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(words)
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			accept_event()
			dismiss())


func _process(delta: float) -> void:
	# Real seconds: undo the time scale (picker slow-down, test speed-up).
	_age += delta / maxf(Engine.time_scale, 0.001)
	if not _closing and _age >= POP_SECONDS + _seconds:
		dismiss()
	var shown: float = clampf(_age / POP_SECONDS, 0.0, 1.0)
	if _closing:
		var gone: float = clampf((_age - _close_age) / FADE_SECONDS, 0.0, 1.0)
		modulate.a = minf(shown, 1.0 - gone)
		if gone >= 1.0:
			dismissed.emit()
			queue_free()
			return
	else:
		modulate.a = shown
	# Pop out from the right edge (the stack owns our position, not our scale).
	var ease_in: float = 1.0 - pow(1.0 - shown, 3.0)
	pivot_offset = Vector2(size.x, size.y * 0.5)
	scale = Vector2.ONE * lerpf(POP_FROM, 1.0, ease_in)
