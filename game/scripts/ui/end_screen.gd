extends CanvasLayer

## EndScreen
##
## Shown when GameManager ends the run: victory after the final dawn,
## or defeat when the campfire goes out or the boy is knocked out.
## Summarises the run and points testers at the playtest log.
## A win opens the chapter's ending storybook first and
## shows the stats after; a defeat says why, as a voiced story line.
## In Chapter 2, Mum walks into the camp before the book.
## An endless run says how far it got, and "New record!" when it beat
## the best. Under the stats, the Camp Badges this run earned: the win
## badges are awarded as the run ends, after the HUD is paused and
## hidden under this screen, so this is where they are seen.

var _root: Control = null
var _title: Label = null
var _badge: CenterContainer = null
var _stars: HBoxContainer = null
var _stats_row: HBoxContainer = null
var _log_path: Label = null
var _story: VBoxContainer = null
var _record: Label = null
var _badges_row: HBoxContainer = null
## The badges earned since this screen's run began, in order.
var _earned: Array[BadgeDefinition] = []


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
	_record = UiKit.label("", 26, UiKit.COLOR_GOLD)
	_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_record)
	_story = UiKit.vbox(6)
	_story.custom_minimum_size = Vector2(620, 0)
	column.add_child(_story)
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
	_badges_row = HBoxContainer.new()
	_badges_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_badges_row.add_theme_constant_override("separation", 18)
	column.add_child(_badges_row)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	var again: Button = HudWidgets.icon_button("restart", "Again", GameManager.start_run, Color(0.55, 0.9, 0.4))
	buttons.add_child(again)
	buttons.add_child(HudWidgets.icon_button("home", "", GameManager.go_to_title))
	buttons.add_child(HudWidgets.icon_button("close", "", get_tree().quit, Color(1.0, 0.45, 0.4)))
	column.add_child(buttons)
	# Small print for playtest facilitators, not for kids.
	_log_path = UiKit.label("", 11, Color(0.45, 0.45, 0.45))
	_log_path.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_log_path)
	_root.visible = false
	add_to_group("end_screen")
	GameManager.run_ended.connect(_on_run_ended)
	Badges.badge_earned.connect(_on_badge_earned)


func _on_run_ended(won: bool, _reason: String) -> void:
	_show_story(won)
	_show_summary(won)
	var pages: Array = StoryLibrary.find(&"win", RunSession.config.chapter) if won else []
	if pages.is_empty():
		_root.visible = true
		return
	# The true ending: Mum walks out of the woods first.
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if RunSession.config.chapter == 2 and player != null and ResourceLoader.exists(MumArrival.MODEL_PATH):
		var arrival: MumArrival = MumArrival.play(get_tree().current_scene, player.global_position)
		await arrival.finished
	var book: StoryBook = StoryBook.play(pages, RunSession.config.hero_id, layer + 1)
	book.finished.connect(func() -> void:
		_root.visible = true
		if RunSession.config.chapter == 2:
			StoryLibrary.mark_seen(StoryLibrary.TRUE_ENDING))


## The names of the badges this run earned, as the end screen lists them.
func badges_text() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for badge in _earned:
		out.append(badge.display_name)
	return out


func _on_badge_earned(badge: BadgeDefinition) -> void:
	_earned.append(badge)
	_show_badges()


func _show_badges() -> void:
	for child in _badges_row.get_children():
		child.queue_free()
	_badges_row.visible = not _earned.is_empty()
	for badge in _earned:
		_badges_row.add_child(HudWidgets.icon_count(badge.icon_texture(), "trophy", badge.display_name, 34.0))


## The line under the title on a defeat: why the run ended ("The dark
## came in..."), voiced. A win has told its story in the book already.
func _show_story(won: bool) -> void:
	for child in _story.get_children():
		child.queue_free()
	var lines: Array = _story_lines(won)
	for line in lines:
		_story.add_child(StoryCard.line_row(line, 22, 48, true))
	_story.visible = not lines.is_empty()
	StoryCard.speak(lines, self)


func _story_lines(won: bool) -> Array:
	if won:
		return []
	var beat: StoryBeat = StoryLibrary.first(GameManager.end_trigger, RunSession.config.chapter)
	return beat.lines_for(RunSession.config.hero_id) if beat != null else []


## The endless line under the title ("You lasted to night 9. New
## record!"), or "" for a story run.
func record_text() -> String:
	if not RunSession.config.endless:
		return ""
	var lasted: String = "You lasted to night %d." % GameManager.current_day
	if GameManager.new_record:
		return lasted + "  New record!"
	return "%s  %s" % [lasted, EndlessRecord.best_text()]


func story_text() -> String:
	var out: PackedStringArray = PackedStringArray()
	for line in _story_lines(GameManager.run_state == GameManager.RunState.WON):
		out.append(UiKit.party_text(String(line.get("text", ""))))
	return " ".join(out)


func _show_summary(won: bool) -> void:
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
	_record.text = record_text()
	_record.visible = _record.text != ""
	_title.add_theme_color_override("font_color", UiKit.COLOR_GOLD if won else Color(0.9, 0.35, 0.3))
	var stats: Dictionary = GameManager.stats
	for child in _stars.get_children():
		child.queue_free()
	var nights: int = int(stats.get(&"nights_survived", 0))
	for i in range(RunSession.config.nights_to_win):
		_stars.add_child(HudWidgets.Glyph.new("star" if i < nights else "star_empty", Color(1.0, 0.85, 0.3),
			64 if RunSession.config.nights_to_win <= 4 else 44))
	for child in _stats_row.get_children():
		child.queue_free()
	_stats_row.add_child(HudWidgets.icon_count(load("res://assets/icons/portrait_imp.png"), "", str(stats.get(&"kills", 0))))
	_stats_row.add_child(HudWidgets.icon_count(load("res://assets/icons/wood.png"), "", str(stats.get(&"gathered", 0))))
	_stats_row.add_child(HudWidgets.icon_count(load("res://assets/icons/fence.png"), "", str(stats.get(&"built", 0))))
	_stats_row.add_child(HudWidgets.icon_count(load("res://assets/icons/torch.png"), "", str(stats.get(&"torches_placed", 0))))
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		_stats_row.add_child(HudWidgets.icon_count(RunSession.config.hero().portrait, "",
			"Lv %d" % ProgressionManager.get_level(player)))
	_show_badges()
	_log_path.text = PlaytestLog.get_absolute_path()
