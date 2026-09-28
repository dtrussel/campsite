extends CanvasLayer

## EndScreen
##
## Shown when GameManager ends the run: victory after the final dawn,
## or defeat when the campfire goes out or the boy is knocked out.
## Summarises the run and points testers at the playtest log.

var _root: Control = null
var _title: Label = null
var _badge: CenterContainer = null
var _stars: HBoxContainer = null
var _stats_row: HBoxContainer = null
var _log_path: Label = null


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UiKit.theme()
	UiKit.full_rect(_root)
	add_child(_root)
	_root.add_child(UiKit.dim_background())
	var center: CenterContainer = UiKit.centered()
	_root.add_child(center)
	var panel: PanelContainer = UiKit.panel(28)
	center.add_child(panel)
	var column: VBoxContainer = UiKit.vbox(14)
	panel.add_child(column)
	_badge = CenterContainer.new()
	column.add_child(_badge)
	_title = UiKit.title("", 58)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_stars = HBoxContainer.new()
	_stars.alignment = BoxContainer.ALIGNMENT_CENTER
	_stars.add_theme_constant_override("separation", 10)
	column.add_child(_stars)
	var divider_row: CenterContainer = CenterContainer.new()
	divider_row.add_child(UiKit.divider(420))
	column.add_child(divider_row)
	_stats_row = HBoxContainer.new()
	_stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stats_row.add_theme_constant_override("separation", 28)
	column.add_child(_stats_row)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	var again: Button = HudWidgets.icon_button("restart", "Again", GameManager.start_run, Color(0.5, 1.0, 0.55))
	buttons.add_child(again)
	buttons.add_child(HudWidgets.icon_button("home", "", GameManager.go_to_title))
	buttons.add_child(HudWidgets.icon_button("close", "", get_tree().quit, Color(1.0, 0.45, 0.4)))
	column.add_child(buttons)
	# Small print for playtest facilitators, not for kids.
	_log_path = UiKit.label("", 11, Color(0.45, 0.45, 0.45))
	_log_path.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_log_path)
	_root.visible = false
	GameManager.run_ended.connect(_on_run_ended)


func _on_run_ended(won: bool, _reason: String) -> void:
	for child in _badge.get_children():
		child.queue_free()
	if won:
		_badge.add_child(HudWidgets.Glyph.new("trophy", UiKit.COLOR_GOLD, 110))
	else:
		var fire: TextureRect = TextureRect.new()
		fire.texture = load("res://assets/icons/campfire.png")
		fire.custom_minimum_size = Vector2(110, 110)
		fire.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fire.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fire.modulate = Color(0.45, 0.45, 0.55)
		_badge.add_child(fire)
	_title.text = "YOU WIN!" if won else "OH NO!"
	_title.add_theme_color_override("font_color", UiKit.COLOR_GOLD if won else Color(0.9, 0.35, 0.3))
	var stats: Dictionary = GameManager.stats
	for child in _stars.get_children():
		child.queue_free()
	var nights: int = int(stats.get(&"nights_survived", 0))
	for i in range(GameManager.nights_to_win):
		_stars.add_child(HudWidgets.Glyph.new("star" if i < nights else "star_empty", Color(1.0, 0.85, 0.3), 64))
	for child in _stats_row.get_children():
		child.queue_free()
	_stats_row.add_child(HudWidgets.icon_count(load("res://assets/icons/portrait_imp.png"), "", str(stats.get(&"kills", 0))))
	_stats_row.add_child(HudWidgets.icon_count(load("res://assets/icons/wood.png"), "", str(stats.get(&"gathered", 0))))
	_stats_row.add_child(HudWidgets.icon_count(load("res://assets/icons/fence.png"), "", str(stats.get(&"built", 0))))
	_stats_row.add_child(HudWidgets.icon_count(load("res://assets/icons/torch.png"), "", str(stats.get(&"torches_placed", 0))))
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		_stats_row.add_child(HudWidgets.icon_count(load("res://assets/icons/portrait_boy.png"), "",
			"Lv %d" % ProgressionManager.get_level(player)))
	_log_path.text = PlaytestLog.get_absolute_path()
	_root.visible = true
