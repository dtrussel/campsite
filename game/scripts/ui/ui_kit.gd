class_name UiKit
extends RefCounted

## UiKit
##
## Builders for the placeholder menu UI (title, pause, end screen,
## controls, crafting). Everything is constructed in code from engine
## Controls so the menus stay consistent without a theme asset.

const COLOR_PANEL: Color = Color(0.06, 0.08, 0.07, 0.92)
const COLOR_DIM: Color = Color(0, 0, 0, 0.55)
const COLOR_ACCENT: Color = Color(1.0, 0.72, 0.35)
const COLOR_TEXT: Color = Color(0.95, 0.95, 0.9)
const COLOR_MUTED: Color = Color(0.7, 0.72, 0.68)

const GOAL_TEXT: String = "Survive 3 nights. Keep the campfire burning!"

## [keys, action] rows shared by the title screen and the in-game overlay.
const CONTROLS: Array = [
	["W A S D / Arrows", "Move"],
	["E", "Gather from a tree, pine, rock or bush"],
	["Left click / Space", "Swing at nearby Shadow Imps"],
	["B, then 1 / 2", "Build mode: Wooden Fence / Watch Post"],
	["R / Left click / Right click", "In build mode: rotate / place / cancel"],
	["C", "Crafting (stand near the campfire)"],
	["Q", "Plant a crafted torch"],
	["R", "Eat 2 berries to heal"],
	["F / G / T / Y", "Sibling: Follow / Guard camp / Gather / Idle"],
	["N", "Call the night early (daytime only)"],
	["H", "Show this help"],
	["Esc / P", "Pause"],
]


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
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.set_corner_radius_all(10)
	style.set_content_margin_all(padding)
	style.border_color = Color(COLOR_ACCENT, 0.5)
	style.set_border_width_all(2)
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
	result.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	result.add_theme_constant_override("outline_size", 4 if size >= 24 else 0)
	return result


## `focusable = false` for in-game overlays, so Space (attack) is never
## swallowed by a focused button.
static func button(text: String, on_pressed: Callable, focusable: bool = true) -> Button:
	var result: Button = Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(260, 44)
	result.add_theme_font_size_override("font_size", 20)
	result.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	result.pressed.connect(on_pressed)
	return result


static func controls_grid() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	for row in CONTROLS:
		grid.add_child(label(row[0], 17, COLOR_ACCENT))
		grid.add_child(label(row[1], 17))
	return grid
