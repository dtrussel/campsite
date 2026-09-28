extends CanvasLayer

## EndScreen
##
## Shown when GameManager ends the run: victory after the final dawn,
## or defeat when the campfire goes out or the boy is knocked out.
## Summarises the run and points testers at the playtest log.

var _root: Control = null
var _title: Label = null
var _reason: Label = null
var _stats: Label = null
var _log_path: Label = null


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	UiKit.full_rect(_root)
	add_child(_root)
	_root.add_child(UiKit.dim_background())
	var center: CenterContainer = UiKit.centered()
	_root.add_child(center)
	var panel: PanelContainer = UiKit.panel(28)
	center.add_child(panel)
	var column: VBoxContainer = UiKit.vbox(10)
	panel.add_child(column)
	_title = UiKit.label("", 44)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_reason = UiKit.label("", 22)
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_reason)
	column.add_child(HSeparator.new())
	_stats = UiKit.label("", 18)
	column.add_child(_stats)
	column.add_child(HSeparator.new())
	var buttons: VBoxContainer = UiKit.vbox(8)
	buttons.add_child(UiKit.button("Play again", GameManager.start_run))
	buttons.add_child(UiKit.button("Title screen", GameManager.go_to_title))
	buttons.add_child(UiKit.button("Quit", get_tree().quit))
	var row: CenterContainer = CenterContainer.new()
	row.add_child(buttons)
	column.add_child(row)
	_log_path = UiKit.label("", 13, UiKit.COLOR_MUTED)
	_log_path.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_path.custom_minimum_size = Vector2(460, 0)
	column.add_child(_log_path)
	_root.visible = false
	GameManager.run_ended.connect(_on_run_ended)


func _on_run_ended(won: bool, reason: String) -> void:
	_title.text = "Victory!" if won else "Game over"
	_title.add_theme_color_override("font_color", Color(0.6, 1, 0.6) if won else Color(1, 0.45, 0.4))
	_reason.text = reason
	var stats: Dictionary = GameManager.stats
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Reached day %d" % TimeManager.day_number)
	lines.append("Nights survived: %d / %d" % [stats.get(&"nights_survived", 0), GameManager.nights_to_win])
	lines.append("Shadow Imps defeated: %d" % stats.get(&"kills", 0))
	lines.append("Resources gathered: %d" % stats.get(&"gathered", 0))
	lines.append("Buildings placed: %d" % stats.get(&"built", 0))
	lines.append("Items crafted: %d   Torches planted: %d" % [
		stats.get(&"crafted", 0), stats.get(&"torches_placed", 0)
	])
	for node in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("companions"):
		var character_stats: CharacterStatsDefinition = ProgressionManager.get_stats(node)
		var display: String = character_stats.display_name if character_stats != null else String(node.name)
		lines.append("%s reached level %d" % [display, ProgressionManager.get_level(node)])
	_stats.text = "\n".join(lines)
	_log_path.text = "Playtest log: %s" % PlaytestLog.get_absolute_path()
	_root.visible = true
