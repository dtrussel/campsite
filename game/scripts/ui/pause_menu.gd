extends CanvasLayer

## PauseMenu
##
## Esc / P toggles pause during a run. Esc is shared with other
## overlays, so it first closes the crafting panel and leaves build
## mode cancellation to BuildManager. Its settings end with Delete
## profile (journal badges 01), which asks first and forgets the
## player's progress (Profile), never the audio or look settings.

## Opens the Delete profile confirmation.
var delete_profile_button: Button = null
## Asks before the profile is deleted.
var delete_profile_confirm: ConfirmationDialog = null
var _root: Control = null


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	_root = Control.new()
	_root.theme = UiKit.theme()
	UiKit.full_rect(_root)
	add_child(_root)
	_root.add_child(UiKit.dim_background())
	var center: CenterContainer = UiKit.centered()
	_root.add_child(center)
	var panel: PanelContainer = UiKit.panel()
	center.add_child(panel)
	var column: VBoxContainer = UiKit.vbox(10)
	panel.add_child(column)
	var title: Control = HudWidgets.Glyph.new("pause", UiKit.COLOR_GOLD, 64)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(title)
	column.add_child(UiKit.divider(280))
	column.add_child(HudWidgets.icon_button("play", "Play", _resume, Color(0.55, 0.9, 0.4), null, false))
	column.add_child(HudWidgets.icon_button("help", "Help", _show_controls, UiKit.COLOR_GOLD, null, false))
	column.add_child(HudWidgets.icon_button("restart", "Again", _restart, UiKit.COLOR_GOLD, null, false))
	column.add_child(HudWidgets.icon_button("home", "Home", _quit_to_title, UiKit.COLOR_GOLD, null, false))
	column.add_child(HudWidgets.icon_button("close", "Quit", _quit_game, Color(1.0, 0.45, 0.4), null, false))
	column.add_child(UiKit.divider(280))
	column.add_child(_volume_row("Music", AudioManager.music_volume, AudioManager.set_music_volume))
	column.add_child(_volume_row("Sounds", AudioManager.sfx_volume, AudioManager.set_sfx_volume))
	column.add_child(_choice_row("Blur", PostFx.BLUR_NAMES, PostFx.blur_level(), PostFx.set_blur_level))
	column.add_child(_toggle_row("Auto-fight", GameSettings.auto_attack(), GameSettings.set_auto_attack))
	column.add_child(UiKit.divider(280))
	delete_profile_button = HudWidgets.icon_button("close", "Delete profile", _ask_delete_profile,
		Color(1.0, 0.45, 0.4), null, false, 44.0)
	delete_profile_button.add_theme_font_size_override("font_size", 16)
	delete_profile_button.tooltip_text = "Forget chapters won and the last hero. Sound and look settings stay."
	column.add_child(delete_profile_button)
	delete_profile_confirm = ConfirmationDialog.new()
	delete_profile_confirm.title = "Delete profile?"
	delete_profile_confirm.dialog_text = "This forgets the chapters you have won and locks Chapter 2 again.\nYour sound and look settings stay."
	delete_profile_confirm.ok_button_text = "Delete"
	delete_profile_confirm.cancel_button_text = "Keep"
	delete_profile_confirm.confirmed.connect(_delete_profile)
	_root.add_child(delete_profile_confirm)
	_root.visible = false


## A labelled 0..1 slider; changes apply (and are saved) as it moves.
func _volume_row(caption: String, value: float, on_changed: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label: Label = UiKit.label(caption.to_upper(), 18)
	label.custom_minimum_size = Vector2(96, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(160, 32)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(on_changed)
	row.add_child(slider)
	return row


## A labelled on/off switch; changes apply (and are saved) at once.
func _toggle_row(caption: String, value: bool, on_toggled: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label: Label = UiKit.label(caption.to_upper(), 18)
	label.custom_minimum_size = Vector2(96, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var toggle: CheckButton = CheckButton.new()
	toggle.button_pressed = value
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(on_toggled)
	row.add_child(toggle)
	return row


## A labelled row of exclusive choices; picking one applies (and saves) it.
func _choice_row(caption: String, names: PackedStringArray, value: int, on_picked: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label: Label = UiKit.label(caption.to_upper(), 18)
	label.custom_minimum_size = Vector2(96, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var group: ButtonGroup = ButtonGroup.new()
	for i in names.size():
		var choice: Button = Button.new()
		choice.text = names[i]
		choice.toggle_mode = true
		choice.button_group = group
		choice.button_pressed = i == value
		choice.focus_mode = Control.FOCUS_NONE
		choice.pressed.connect(on_picked.bind(i))
		row.add_child(choice)
	return row


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or not GameManager.is_playing():
		return
	if _root.visible:
		_resume()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused:
		return  # another overlay (help) owns the pause
	var crafting: Node = get_tree().get_first_node_in_group("crafting_panel")
	if crafting != null and crafting.is_open():
		crafting.close()
		get_viewport().set_input_as_handled()
		return
	if BuildManager.is_in_build_mode():
		return  # BuildManager cancels build mode on the same key
	_root.visible = true
	get_tree().paused = true
	get_viewport().set_input_as_handled()


## Opens the menu from the HUD pause button.
func open_menu() -> void:
	if _root.visible or not GameManager.is_playing() or get_tree().paused:
		return
	_root.visible = true
	get_tree().paused = true


func _resume() -> void:
	_root.visible = false
	get_tree().paused = false


func _show_controls() -> void:
	_root.visible = false
	var overlay: Node = get_tree().get_first_node_in_group("controls_overlay")
	if overlay == null:
		_resume()
		return
	get_tree().paused = false
	overlay.open()


func _ask_delete_profile() -> void:
	delete_profile_confirm.popup_centered()


func _delete_profile() -> void:
	Profile.delete()
	PlaytestLog.write("profile_deleted")


func _restart() -> void:
	PlaytestLog.write("run_restarted_from_pause day=%d" % TimeManager.day_number)
	GameManager.start_run()


func _quit_to_title() -> void:
	PlaytestLog.write("run_abandoned day=%d" % TimeManager.day_number)
	GameManager.go_to_title()


func _quit_game() -> void:
	PlaytestLog.write("quit_from_pause day=%d" % TimeManager.day_number)
	get_tree().quit()
