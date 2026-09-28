extends Control

## TitleScreen
##
## Entry scene. Play starts a fresh run through GameManager; How to
## Play toggles the controls list; Quit exits.

var _controls_panel: Control = null


func _ready() -> void:
	UiKit.full_rect(self)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.08, 0.13, 0.1)
	UiKit.full_rect(background)
	add_child(background)

	var center: CenterContainer = UiKit.centered()
	add_child(center)
	var column: VBoxContainer = UiKit.vbox(14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)

	var title: Label = UiKit.label("CAMPSITE", 64, UiKit.COLOR_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var tagline: Label = UiKit.label(
		"By day, gather and build. By night, the forest comes for your campfire.", 18, UiKit.COLOR_MUTED
	)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)
	var goal: Label = UiKit.label(UiKit.GOAL_TEXT, 20)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(goal)
	column.add_child(Control.new())

	var buttons: VBoxContainer = UiKit.vbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var play: Button = UiKit.button("Play", _on_play)
	buttons.add_child(play)
	buttons.add_child(UiKit.button("How to play", _on_toggle_controls))
	buttons.add_child(UiKit.button("Quit", _on_quit))
	var button_row: CenterContainer = CenterContainer.new()
	button_row.add_child(buttons)
	column.add_child(button_row)

	_controls_panel = UiKit.panel(16)
	_controls_panel.add_child(UiKit.controls_grid())
	_controls_panel.visible = false
	var controls_row: CenterContainer = CenterContainer.new()
	controls_row.add_child(_controls_panel)
	column.add_child(controls_row)

	var version: Label = UiKit.label(
		"v%s - playtest build" % ProjectSettings.get_setting("application/config/version", "dev"),
		14, UiKit.COLOR_MUTED
	)
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(12, -28)
	add_child(version)

	play.grab_focus()


func _on_play() -> void:
	GameManager.start_run()


func _on_toggle_controls() -> void:
	_controls_panel.visible = not _controls_panel.visible


func _on_quit() -> void:
	get_tree().quit()
