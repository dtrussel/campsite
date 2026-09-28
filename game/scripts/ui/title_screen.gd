extends Control

## TitleScreen
##
## Entry scene: a live 3D dusk backdrop of the camp (TitleBackdrop)
## under a LoL-client-style menu - gold Cinzel logo, hextech buttons,
## and a How-to-play panel. Play starts a fresh run via GameManager.

const BACKDROP: Script = preload("res://scripts/ui/title_backdrop.gd")

var _controls_panel: Control = null


func _ready() -> void:
	UiKit.full_rect(self)
	theme = UiKit.theme()
	var backdrop: Node3D = BACKDROP.new()
	add_child(backdrop)

	# Vignette so the menu reads over the 3D scene.
	var shade: TextureRect = TextureRect.new()
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0, 0.02, 0.05, 0.0))
	gradient.set_color(1, Color(0, 0.02, 0.05, 0.85))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.45)
	texture.fill_to = Vector2(1.1, 1.1)
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	UiKit.full_rect(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var column: VBoxContainer = UiKit.vbox(10)
	column.set_anchors_preset(Control.PRESET_CENTER_TOP)
	column.position = Vector2(-320, 70)
	column.custom_minimum_size = Vector2(640, 0)
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(column)

	var logo: Label = UiKit.title("Campsite", 92, UiKit.COLOR_GOLD)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_constant_override("outline_size", 14)
	column.add_child(logo)
	column.add_child(UiKit.goal_picture(3))

	var buttons: VBoxContainer = UiKit.vbox(10)
	buttons.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	buttons.position = Vector2(-140, -230)
	add_child(buttons)
	var play: Button = HudWidgets.icon_button("play", "Play", _on_play, Color(0.5, 1.0, 0.55))
	play.custom_minimum_size = Vector2(300, 72)
	play.add_theme_font_size_override("font_size", 32)
	buttons.add_child(play)
	var small: HBoxContainer = HBoxContainer.new()
	small.alignment = BoxContainer.ALIGNMENT_CENTER
	small.add_theme_constant_override("separation", 12)
	small.add_child(HudWidgets.icon_button("help", "", _on_toggle_controls))
	small.add_child(HudWidgets.icon_button("close", "", _on_quit, Color(1.0, 0.45, 0.4)))
	buttons.add_child(small)

	_controls_panel = UiKit.panel(18)
	var controls_column: VBoxContainer = UiKit.vbox(8)
	controls_column.add_child(UiKit.picture_guide(1))
	_controls_panel.add_child(controls_column)
	_controls_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_controls_panel.position = Vector2(-420, -300)
	_controls_panel.visible = false
	add_child(_controls_panel)

	var version: Label = UiKit.label(
		"v%s  -  playtest build  -  art: KayKit (CC0) by Kay Lousberg" % ProjectSettings.get_setting("application/config/version", "dev"),
		13, UiKit.COLOR_MUTED
	)
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(14, -28)
	add_child(version)

	play.grab_focus()


func _on_play() -> void:
	GameManager.start_run()


func _on_toggle_controls() -> void:
	_controls_panel.visible = not _controls_panel.visible


func _on_quit() -> void:
	get_tree().quit()
