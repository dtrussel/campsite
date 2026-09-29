class_name UiKit
extends RefCounted

## UiKit
##
## The game's UI look, inspired by the LoL client "hextech" style:
## deep navy panels, thin gold trims, Cinzel display type for titles,
## Nunito Sans for body text, and gold-framed buttons with a warm hover.
## `theme()` is applied to the root window once, so every Control
## picks it up; the builders below assemble common menu pieces.

const COLOR_NAVY: Color = Color(0.02, 0.06, 0.1, 0.94)
const COLOR_NAVY_LIGHT: Color = Color(0.06, 0.12, 0.17, 0.96)
const COLOR_GOLD: Color = Color(0.78, 0.67, 0.43)
const COLOR_GOLD_DARK: Color = Color(0.47, 0.35, 0.16)
const COLOR_GOLD_LIGHT: Color = Color(0.94, 0.9, 0.82)
const COLOR_TEAL: Color = Color(0.04, 0.78, 0.73)
const COLOR_DIM: Color = Color(0.0, 0.02, 0.05, 0.62)
const COLOR_TEXT: Color = Color(0.94, 0.9, 0.82)
const COLOR_MUTED: Color = Color(0.63, 0.61, 0.55)
## Kept for older call sites.
const COLOR_ACCENT: Color = COLOR_GOLD
const COLOR_PANEL: Color = COLOR_NAVY

const GOAL_TEXT: String = "Survive 3 nights. Keep the campfire burning!"

## [keys, action] rows shared by the title screen and the in-game overlay.
const CONTROLS: Array = [
	["Right click", "Move / attack an imp / gather / use the campfire"],
	["Left click", "Attack or use what you click (never moves)"],
	["Mouse wheel", "Zoom"],
	["Space", "Attack the nearest imp"],
	["E", "Gather the nearest resource"],
	["Q", "Plant a crafted torch"],
	["R", "Eat 2 berries to heal"],
	["C", "Crafting (near the campfire)"],
	["B, then 1 / 2", "Build: Wooden Fence / Watch Post  (R rotate, LMB place, RMB cancel)"],
	["F / G / T / Y", "Nela: Follow / Guard camp / Gather / Idle"],
	["N", "Call the night early (daytime only)"],
	["W A S D", "Walk directly (optional)"],
	["H  /  Esc", "Help  /  Pause"],
]

static var _theme: Theme = null


## Project-wide theme, built once.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = Fx.body_font(600)
	t.default_font_size = 18

	t.set_color("font_color", "Label", COLOR_TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 1))
	t.set_constant("outline_size", "Label", 0)
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())

	t.set_font("font", "Button", title_font_for_buttons())
	t.set_font_size("font_size", "Button", 19)
	t.set_color("font_color", "Button", Color(0.8, 0.75, 0.57))
	t.set_color("font_hover_color", "Button", COLOR_GOLD_LIGHT)
	t.set_color("font_pressed_color", "Button", COLOR_GOLD)
	t.set_color("font_focus_color", "Button", COLOR_GOLD_LIGHT)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.4))
	t.set_stylebox("normal", "Button", button_style(Color(0.08, 0.11, 0.13, 0.95), COLOR_GOLD_DARK))
	t.set_stylebox("hover", "Button", button_style(Color(0.12, 0.17, 0.2, 0.98), COLOR_GOLD))
	t.set_stylebox("pressed", "Button", button_style(Color(0.04, 0.06, 0.08, 1.0), COLOR_GOLD))
	t.set_stylebox("focus", "Button", button_style(Color(0, 0, 0, 0), COLOR_GOLD_LIGHT, 1))
	t.set_stylebox("disabled", "Button", button_style(Color(0.06, 0.07, 0.08, 0.9), Color(0.25, 0.25, 0.25)))

	var separator: StyleBoxLine = StyleBoxLine.new()
	separator.color = Color(COLOR_GOLD_DARK, 0.8)
	separator.thickness = 1
	t.set_stylebox("separator", "HSeparator", separator)
	t.set_constant("separation", "HSeparator", 10)
	_theme = t
	return _theme


static func title_font_for_buttons() -> Font:
	return Fx.title_font(700)


static func panel_style(fill: Color = COLOR_NAVY, border: Color = COLOR_GOLD_DARK) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(20)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	return style


static func button_style(fill: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(2)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func full_rect(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0


static func dim_background() -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = COLOR_DIM
	full_rect(rect)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return rect


static func centered() -> CenterContainer:
	var center: CenterContainer = CenterContainer.new()
	full_rect(center)
	return center


static func panel(padding: int = 24) -> PanelContainer:
	var container: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = panel_style()
	style.set_content_margin_all(padding)
	container.add_theme_stylebox_override("panel", style)
	return container


static func vbox(separation: int = 12) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func label(text: String, size: int = 18, color: Color = COLOR_TEXT) -> Label:
	var result: Label = Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	if size >= 24:
		result.add_theme_constant_override("outline_size", 6)
	return result


## Gold Cinzel heading, LoL-style.
static func title(text: String, size: int = 34, color: Color = COLOR_GOLD) -> Label:
	var result: Label = label(text.to_upper(), size, color)
	result.add_theme_font_override("font", Fx.title_font(700))
	result.add_theme_constant_override("outline_size", 8)
	result.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.01, 1))
	return result


## Thin gold rule with a diamond in the middle (hextech divider).
static func divider(width: float = 320.0) -> Control:
	var rule: _Divider = _Divider.new()
	rule.custom_minimum_size = Vector2(width, 14)
	return rule


## `focusable = false` for in-game overlays, so Space (attack) is never
## swallowed by a focused button.
static func button(text: String, on_pressed: Callable, focusable: bool = true) -> Button:
	var result: Button = Button.new()
	result.text = text.to_upper()
	result.custom_minimum_size = Vector2(280, 46)
	result.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	result.pressed.connect(func() -> void: AudioManager.play_sfx(&"ui_click"))
	result.pressed.connect(on_pressed)
	return result


## A keyboard key cap, e.g. "Q".
static func key_cap(text: String, size_px: int = 40) -> PanelContainer:
	var cap: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.92, 0.9, 0.84)
	style.border_color = Color(0.35, 0.3, 0.25)
	style.set_border_width_all(2)
	style.border_width_bottom = 5
	style.set_corner_radius_all(6)
	style.set_content_margin_all(2)
	cap.add_theme_stylebox_override("panel", style)
	cap.custom_minimum_size = Vector2(size_px * maxf(1.0, text.length() * 0.55), size_px)
	var l: Label = label(text, int(size_px * 0.55), Color(0.15, 0.12, 0.1))
	l.add_theme_font_override("font", Fx.bold_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_child(l)
	return cap


## Picture-guide rows for kids: [input] -> [picture] word.
## Each entry: [input kind ("mouse_right", "key:Q"), picture (icon name or
## "glyph:<kind>"), word].
const PICTURE_GUIDE: Array = [
	["mouse_right", "glyph:footsteps", "Walk"],
	["mouse_right", "portrait_imp", "Fight"],
	["mouse_right", "tree", "Chop"],
	["mouse_right", "bush", "Pick"],
	["mouse_right", "campfire", "Craft"],
	["mouse_right", "glyph:hammer", "Fix"],
	["key:Q", "torch", "Torch"],
	["key:R", "berries", "Eat"],
	["key:B", "fence", "Build"],
	["key:F G T Y V", "portrait_nela", "Nela"],
	["key:N", "glyph:moon", "Night"],
]


static func picture_guide(columns: int = 2) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 10)
	for entry in PICTURE_GUIDE:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var input: String = entry[0]
		if input.begins_with("key:"):
			for k in input.substr(4).split(" "):
				row.add_child(key_cap(k, 38))
		else:
			row.add_child(HudWidgets.Glyph.new(input, Color(0.35, 0.9, 1.0), 42))
		row.add_child(HudWidgets.Glyph.new("arrow", COLOR_GOLD_DARK, 28))
		var picture: String = entry[1]
		if picture.begins_with("glyph:"):
			row.add_child(HudWidgets.Glyph.new(picture.substr(6), Color(1.0, 0.9, 0.55), 48))
		else:
			var rect: TextureRect = TextureRect.new()
			rect.texture = load("res://assets/icons/%s.png" % picture)
			rect.custom_minimum_size = Vector2(52, 52)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(rect)
		var word: Label = label(entry[2], 22)
		word.add_theme_font_override("font", Fx.bold_font())
		word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(word)
		grid.add_child(row)
	return grid


## Goal as a picture: campfire + three moons.
static func goal_picture(nights: int = 3) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var fire: TextureRect = TextureRect.new()
	fire.texture = load("res://assets/icons/campfire.png")
	fire.custom_minimum_size = Vector2(72, 72)
	fire.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fire.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(fire)
	row.add_child(HudWidgets.Glyph.new("heart", Color(1.0, 0.4, 0.45), 40))
	for i in range(nights):
		row.add_child(HudWidgets.Glyph.new("moon", Color(1.0, 0.92, 0.55), 48))
	return row


static func controls_grid() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 5)
	for row in CONTROLS:
		var keys: Label = label(row[0], 16, COLOR_GOLD)
		keys.add_theme_font_override("font", Fx.bold_font())
		grid.add_child(keys)
		grid.add_child(label(row[1], 16))
	return grid


class _Divider extends Control:
	func _draw() -> void:
		var y: float = size.y * 0.5
		var mid: float = size.x * 0.5
		draw_line(Vector2(0, y), Vector2(mid - 10, y), UiKit.COLOR_GOLD_DARK, 1.0)
		draw_line(Vector2(mid + 10, y), Vector2(size.x, y), UiKit.COLOR_GOLD_DARK, 1.0)
		var diamond: PackedVector2Array = PackedVector2Array([
			Vector2(mid, y - 5), Vector2(mid + 6, y), Vector2(mid, y + 5), Vector2(mid - 6, y)
		])
		draw_colored_polygon(diamond, UiKit.COLOR_GOLD)
