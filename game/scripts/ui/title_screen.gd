extends Control

## TitleScreen
##
## Entry scene: a live 3D dusk backdrop of the camp (TitleBackdrop)
## under a LoL-client-style menu - gold Cinzel logo, hextech buttons,
## and a How-to-play panel. Two Play buttons pick a fresh run: Chapter
## 1 "The Dark Moon" (3 nights) or Chapter 2 "Into the Hollow" (7
## nights, feature 035), then the hero select screen (feature 034);
## Continue (shown
## when there is an autosave) resumes the saved run, with its party, at
## its next morning. Once the true ending has been seen, Endless
## ("How long can you last?") starts a Chapter 2 run with no last night.

const BACKDROP: Script = preload("res://scripts/ui/title_backdrop.gd")

var _controls_panel: Control = null


func _ready() -> void:
	UiKit.full_rect(self)
	theme = UiKit.theme()
	var backdrop: Node3D = BACKDROP.new()
	add_child(backdrop)
	AudioManager.set_mood(&"day")

	# Vignette so the menu reads over the 3D scene.
	var shade: TextureRect = TextureRect.new()
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.07, 0.035, 0.02, 0.0))
	gradient.set_color(1, Color(0.07, 0.035, 0.02, 0.85))
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
	buttons.position = Vector2(-236, -260)
	add_child(buttons)
	var save: Dictionary = SaveManager.load_save()
	var play: Button = null
	if not save.is_empty():
		# Continue: the saved run, with its nights so far as moons.
		play = HudWidgets.icon_button("play", "Continue", _on_continue, Color(0.55, 0.9, 0.4))
		play.custom_minimum_size = Vector2(300, 72)
		play.add_theme_font_size_override("font_size", 30)
		var saved_hero: HeroDefinition = HeroRoster.get_hero(GameManager.party_of(save)["hero"])
		var hero_name: String = saved_hero.display_name if saved_hero != null else "Leo"
		var night: int = int(save["day"]) + 1
		if bool(save.get("endless", false)):
			play.tooltip_text = "%s - Endless, night %d" % [hero_name, night]
		else:
			play.tooltip_text = "%s - night %d of %d" % [hero_name, night, int(save["nights_to_win"])]
		buttons.add_child(play)
	var lengths: HBoxContainer = HBoxContainer.new()
	lengths.alignment = BoxContainer.ALIGNMENT_CENTER
	lengths.add_theme_constant_override("separation", 12)
	buttons.add_child(lengths)
	for chapter in [1, 2]:
		var nights: int = 3 if chapter == 1 else 7
		var slot: VBoxContainer = UiKit.vbox(2)
		lengths.add_child(slot)
		var start: Button = HudWidgets.icon_button("moon", StoryLibrary.chapter_name(chapter), _on_play.bind(nights),
			Color(1.0, 0.92, 0.55))
		start.custom_minimum_size = Vector2(250, 64)
		start.add_theme_font_size_override("font_size", 21)
		start.tooltip_text = "Survive %d nights, then choose your hero. The game saves every morning." % nights
		slot.add_child(start)
		var subtitle: Label = UiKit.label("Chapter %d  -  %d nights" % [chapter, nights], 15, UiKit.COLOR_GOLD_LIGHT)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_constant_override("outline_size", 6)
		subtitle.add_theme_color_override("font_outline_color", UiKit.COLOR_INK)
		slot.add_child(subtitle)
		if play == null:
			play = start
	if StoryLibrary.has_seen(StoryLibrary.TRUE_ENDING):
		var endless: Button = HudWidgets.icon_button("moon", "Endless", _on_endless, Color(0.7, 0.8, 1.0))
		endless.custom_minimum_size = Vector2(250, 56)
		endless.tooltip_text = "How long can you last? The Moon Lantern starts lit, and the nights never end."
		buttons.add_child(endless)
		buttons.position.y -= endless.custom_minimum_size.y + 10.0  # room for the extra row
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
		"v%s  -  playtest build  -  see CREDITS.md" % ProjectSettings.get_setting("application/config/version", "dev"),
		13, UiKit.COLOR_MUTED
	)
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(14, -28)
	add_child(version)

	play.grab_focus()


func _on_play(nights: int) -> void:
	GameManager.open_hero_select(nights)


func _on_endless() -> void:
	GameManager.open_hero_select(7, true)


func _on_continue() -> void:
	if not GameManager.continue_run():
		GameManager.start_run(3)


func _on_toggle_controls() -> void:
	_controls_panel.visible = not _controls_panel.visible


func _on_quit() -> void:
	get_tree().quit()
