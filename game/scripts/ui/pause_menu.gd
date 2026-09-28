extends CanvasLayer

## PauseMenu
##
## Esc / P toggles pause during a run. Esc is shared with other
## overlays, so it first closes the crafting panel and leaves build
## mode cancellation to BuildManager.

var _root: Control = null


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	UiKit.full_rect(_root)
	add_child(_root)
	_root.add_child(UiKit.dim_background())
	var center: CenterContainer = UiKit.centered()
	_root.add_child(center)
	var panel: PanelContainer = UiKit.panel()
	center.add_child(panel)
	var column: VBoxContainer = UiKit.vbox(10)
	panel.add_child(column)
	var title: Label = UiKit.label("Paused", 34, UiKit.COLOR_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(UiKit.button("Resume", _resume, false))
	column.add_child(UiKit.button("Controls", _show_controls, false))
	column.add_child(UiKit.button("Restart run", _restart, false))
	column.add_child(UiKit.button("Quit to title", _quit_to_title, false))
	column.add_child(UiKit.button("Quit game", _quit_game, false))
	_root.visible = false


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


func _restart() -> void:
	PlaytestLog.write("run_restarted_from_pause day=%d" % TimeManager.day_number)
	GameManager.start_run()


func _quit_to_title() -> void:
	PlaytestLog.write("run_abandoned day=%d" % TimeManager.day_number)
	GameManager.go_to_title()


func _quit_game() -> void:
	PlaytestLog.write("quit_from_pause day=%d" % TimeManager.day_number)
	get_tree().quit()
