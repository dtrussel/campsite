extends CanvasLayer

## ControlsOverlay
##
## Pauses the game and lists the goal and controls. Shown automatically
## at the start of every run (so a first-time tester always sees it)
## and on demand with H.

signal closed

var _root: Control = null
var _start_button: Button = null


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("controls_overlay")
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
	column.add_child(UiKit.goal_picture(GameManager.nights_to_win))
	var divider_row: CenterContainer = CenterContainer.new()
	divider_row.add_child(UiKit.divider(560))
	column.add_child(divider_row)
	column.add_child(UiKit.picture_guide(2))
	_start_button = HudWidgets.icon_button("play", "Go!", close, Color(0.5, 1.0, 0.55), null, false)
	var row: CenterContainer = CenterContainer.new()
	row.add_child(_start_button)
	column.add_child(row)
	_root.visible = false
	GameManager.run_started.connect(open)


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if not GameManager.is_playing():
		return
	_root.visible = true
	get_tree().paused = true


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_playing():
		return
	if event.is_action_pressed("toggle_help"):
		if is_open():
			close()
		elif not get_tree().paused:
			open()
		get_viewport().set_input_as_handled()
	elif is_open() and (event.is_action_pressed("pause") or event.is_action_pressed("ui_accept")):
		close()
		get_viewport().set_input_as_handled()
