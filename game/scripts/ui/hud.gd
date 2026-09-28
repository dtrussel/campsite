extends CanvasLayer

## HUD
##
## Surfaces live game state: time of day with countdown, base HP,
## companion task, build-mode info, resource counts, and the camp-
## destroyed banner. All values are signal-driven; _process only
## ticks the countdown text so it animates each frame.

@onready var time_label: Label = $Panel/VBox/TimeLabel
@onready var base_hp_label: Label = $Panel/VBox/BaseHPLabel
@onready var companion_task_label: Label = $Panel/VBox/CompanionTaskLabel
@onready var player_progress_label: Label = $Panel/VBox/PlayerProgressLabel
@onready var companion_progress_label: Label = $Panel/VBox/CompanionProgressLabel
@onready var build_mode_label: Label = $Panel/VBox/BuildModeLabel
@onready var camp_destroyed_label: Label = $Panel/VBox/CampDestroyedLabel
@onready var resource_list: VBoxContainer = $Panel/VBox/ResourceList

const _BUILD_COLOR_VALID: Color = Color(0.6, 1.0, 0.6, 1)
const _BUILD_COLOR_INVALID: Color = Color(1.0, 0.6, 0.6, 1)
const _PHASE_COLOR_DAY: Color = Color(1, 1, 1, 1)
const _PHASE_COLOR_SUNSET: Color = Color(1, 0.55, 0.45, 1)
const _PHASE_COLOR_NIGHT: Color = Color(0.7, 0.75, 1, 1)
const _PHASE_COLOR_DAWN: Color = Color(1, 0.9, 0.7, 1)
const _PROGRESS_COLOR_DEFAULT: Color = Color(1, 1, 1, 1)
const _PROGRESS_COLOR_LEVEL_UP: Color = Color(0.6, 1.0, 0.6, 1)
const _LEVEL_UP_FLASH_SECONDS: float = 1.2

var _rows: Dictionary = {}  # StringName -> Label
var _base_core: Node = null
var _player: Node = null
var _companion: Node = null
var _level_up_flash_until: Dictionary = {}  # Node -> float (msec)

const _BANNER_SECONDS: float = 3.5

var _player_hp_bar: ProgressBar = null
var _player_hp_text: Label = null
var _companion_hp_bar: ProgressBar = null
var _companion_hp_text: Label = null
var _goal_label: Label = null
var _imps_label: Label = null
var _banner: Label = null
var _banner_tween: Tween = null
var _empty_inventory_label: Label = null


func _ready() -> void:
	_populate_resources()
	ResourceManager.resource_changed.connect(_on_resource_changed)
	BuildManager.build_mode_entered.connect(_on_build_mode_entered)
	BuildManager.build_mode_exited.connect(_on_build_mode_exited)
	BuildManager.placement_validity_changed.connect(_on_placement_validity_changed)
	TimeManager.phase_changed.connect(_on_phase_changed)
	GameManager.camp_destroyed.connect(_on_camp_destroyed)
	GameManager.companion_task_changed.connect(_on_companion_task_changed)
	ProgressionManager.xp_gained.connect(_on_xp_gained)
	ProgressionManager.level_up.connect(_on_level_up)
	TimeManager.sunset_warning.connect(_on_sunset_warning)
	TimeManager.night_started.connect(_on_night_started)
	TimeManager.dawn_started.connect(_on_dawn_started)
	TimeManager.day_started.connect(_on_day_started)
	CraftingManager.crafted.connect(_on_crafted)
	_build_dynamic_widgets()
	call_deferred("_hook_base_core")
	call_deferred("_refresh_companion_label")
	call_deferred("_refresh_progress_labels")
	call_deferred("_hook_health")
	_apply_phase_color(TimeManager.current_phase)


## Widgets added in code so HUD.tscn stays a simple skeleton.
func _build_dynamic_widgets() -> void:
	var vbox: VBoxContainer = $Panel/VBox
	_goal_label = Label.new()
	vbox.add_child(_goal_label)
	vbox.move_child(_goal_label, time_label.get_index() + 1)
	_imps_label = Label.new()
	_imps_label.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0))
	_imps_label.visible = false
	vbox.add_child(_imps_label)
	vbox.move_child(_imps_label, _goal_label.get_index() + 1)

	var player_row: Array = _make_hp_row("Boy", Color(0.95, 0.35, 0.3))
	_player_hp_bar = player_row[0]
	_player_hp_text = player_row[1]
	vbox.add_child(player_row[2])
	vbox.move_child(player_row[2], base_hp_label.get_index() + 1)
	var companion_row: Array = _make_hp_row("Sibling", Color(0.45, 0.8, 0.45))
	_companion_hp_bar = companion_row[0]
	_companion_hp_text = companion_row[1]
	vbox.add_child(companion_row[2])
	vbox.move_child(companion_row[2], (player_row[2] as Control).get_index() + 1)

	# Short hint at the bottom of the panel; the full list lives behind H.
	var hint: Label = $Panel/VBox/Hint
	hint.text = "H: controls & help    Esc: pause"
	hint.add_theme_color_override("font_color", Color(1, 0.85, 0.5))

	_banner = Label.new()
	# Spans the screen to the right of the stats panel so they never overlap.
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 24
	_banner.offset_left = 300
	_banner.offset_right = -24
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 30)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.modulate.a = 0.0
	add_child(_banner)


func _make_hp_row(title: String, color: Color) -> Array:
	var row: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = title
	name_label.custom_minimum_size = Vector2(62, 0)
	row.add_child(name_label)
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(120, 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	bar.add_theme_stylebox_override("background", background)
	row.add_child(bar)
	var text: Label = Label.new()
	row.add_child(text)
	return [bar, text, row]


func _hook_health() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("health_changed"):
		player.health_changed.connect(_set_hp.bind(_player_hp_bar, _player_hp_text))
		_set_hp(player.current_hp, player.max_hp, _player_hp_bar, _player_hp_text)
	var companion: Node = get_tree().get_first_node_in_group("companions")
	if companion != null and companion.has_signal("health_changed"):
		companion.health_changed.connect(_set_hp.bind(_companion_hp_bar, _companion_hp_text))
		companion.knocked_out_changed.connect(_on_companion_knocked_out)
		_set_hp(companion.current_hp, companion.max_hp, _companion_hp_bar, _companion_hp_text)


func _set_hp(current: int, maximum: int, bar: ProgressBar, text: Label) -> void:
	bar.max_value = maximum
	bar.value = current
	text.text = " %d/%d" % [current, maximum]


func show_banner(text: String, color: Color = Color(1, 1, 1)) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(_BANNER_SECONDS)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _on_day_started(day_number: int) -> void:
	if day_number == 1:
		show_banner("Day 1 - gather wood and fiber, build fences, craft torches", Color(1, 0.95, 0.8))
	else:
		show_banner("Day %d - repair your defences and prepare" % day_number, Color(1, 0.95, 0.8))


func _on_sunset_warning(seconds: float) -> void:
	show_banner("The sun is setting... imps in %ds! Get back to the fire." % int(seconds), _PHASE_COLOR_SUNSET)


func _on_night_started(day_number: int) -> void:
	var spawner: Node = get_tree().get_first_node_in_group("mob_spawner")
	var count: int = spawner.get_wave_size(day_number) if spawner != null else 0
	show_banner("Night %d - %d Shadow Imps are coming!" % [day_number, count], Color(0.85, 0.6, 1.0))


func _on_dawn_started(day_number: int) -> void:
	show_banner("Dawn! You survived night %d" % day_number, _PHASE_COLOR_DAWN)


func _on_crafted(recipe: CraftingRecipe, _crafter: Node) -> void:
	if recipe.output_id == &"torch":
		show_banner("Torch crafted - press Q to plant it", Color(1, 0.75, 0.35))


func _on_companion_knocked_out(is_down: bool) -> void:
	if is_down:
		show_banner("Your sibling is knocked out until dawn!", Color(1, 0.6, 0.4))
	_refresh_companion_label()


func _process(_delta: float) -> void:
	var phase: String = TimeManager.get_phase_name()
	var remaining: int = int(ceil(TimeManager.remaining_seconds))
	time_label.text = "Day %d - %s (%ds)" % [TimeManager.day_number, phase, remaining]
	_goal_label.text = "Goal: survive %d nights (%d done)" % [
		GameManager.nights_to_win, int(GameManager.stats.get(&"nights_survived", 0))
	]
	var imps: int = get_tree().get_nodes_in_group("mobs").size()
	_imps_label.visible = imps > 0
	_imps_label.text = "Shadow Imps: %d" % imps
	if _base_core != null and is_instance_valid(_base_core):
		base_hp_label.text = "Base HP: %d / %d" % [
			_base_core.current_hp, _base_core.max_hp
		]
	_tick_level_up_flash()


func _populate_resources() -> void:
	for child in resource_list.get_children():
		child.queue_free()
	_rows.clear()
	for definition in ResourceManager.get_definitions():
		var row: Label = Label.new()
		row.text = "%s: %d" % [definition.display_name, ResourceManager.get_count(definition.id)]
		row.add_theme_color_override("font_color", definition.ui_color)
		row.visible = ResourceManager.get_count(definition.id) > 0
		resource_list.add_child(row)
		_rows[definition.id] = row
	_empty_inventory_label = Label.new()
	_empty_inventory_label.text = "(nothing yet - press E near a tree)"
	_empty_inventory_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	resource_list.add_child(_empty_inventory_label)
	_refresh_empty_inventory_label()


## Rows for items the player has none of are hidden to keep the panel short.
func _refresh_empty_inventory_label() -> void:
	var any_visible: bool = false
	for id in _rows.keys():
		if (_rows[id] as Label).visible:
			any_visible = true
			break
	_empty_inventory_label.visible = not any_visible


func _on_resource_changed(id: StringName, new_value: int, _delta: int) -> void:
	var row: Label = _rows.get(id, null) as Label
	if row == null:
		push_warning("HUD: no row for resource id '%s'" % id)
		return
	var definition: ResourceDefinition = ResourceManager.get_definition(id)
	var display_name: String = definition.display_name if definition != null else String(id)
	row.text = "%s: %d" % [display_name, new_value]
	row.visible = new_value > 0
	_refresh_empty_inventory_label()


func _on_build_mode_entered(definition: BuildingDefinition) -> void:
	build_mode_label.visible = true
	_refresh_build_label(definition)


func _on_build_mode_exited() -> void:
	build_mode_label.visible = false


func _on_placement_validity_changed(is_valid: bool) -> void:
	var color: Color = _BUILD_COLOR_VALID if is_valid else _BUILD_COLOR_INVALID
	build_mode_label.add_theme_color_override("font_color", color)
	_refresh_build_label(BuildManager.get_active_definition())


func _on_phase_changed(new_phase: int) -> void:
	_apply_phase_color(new_phase)


func _on_camp_destroyed() -> void:
	camp_destroyed_label.visible = true
	camp_destroyed_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))


func _on_companion_task_changed(_companion: Node, _task: int) -> void:
	_refresh_companion_label()


func _apply_phase_color(phase: int) -> void:
	var color: Color = _PHASE_COLOR_DAY
	match phase:
		TimeManager.Phase.DAY: color = _PHASE_COLOR_DAY
		TimeManager.Phase.SUNSET: color = _PHASE_COLOR_SUNSET
		TimeManager.Phase.NIGHT: color = _PHASE_COLOR_NIGHT
		TimeManager.Phase.DAWN: color = _PHASE_COLOR_DAWN
	time_label.add_theme_color_override("font_color", color)


func _refresh_build_label(definition: BuildingDefinition) -> void:
	if definition == null:
		build_mode_label.text = "Build: -"
		return
	build_mode_label.text = "Build: %s (%s)\n1/2 switch - R rotate - LMB place - RMB/Esc cancel" % [
		definition.display_name, definition.cost_summary()
	]


func _refresh_companion_label() -> void:
	var companions: Array = get_tree().get_nodes_in_group("companions")
	if companions.is_empty():
		companion_task_label.text = "Companion: -"
		return
	var first: Node = companions[0]
	var task_name: String = "?"
	if first.get("is_knocked_out") == true:
		task_name = "Knocked out"
	elif first.has_method("get_task_name"):
		task_name = first.get_task_name()
	companion_task_label.text = "Companion: %s" % task_name


func _hook_base_core() -> void:
	for node in get_tree().get_nodes_in_group("base_core"):
		_base_core = node
		break


func _on_xp_gained(character: Node, _amount: int, _source: StringName) -> void:
	_refresh_progress_for(character)


func _on_level_up(character: Node, _new_level: int) -> void:
	_refresh_progress_for(character)
	_level_up_flash_until[character] = Time.get_ticks_msec() + int(_LEVEL_UP_FLASH_SECONDS * 1000.0)
	var label: Label = _progress_label_for(character)
	if label != null:
		label.add_theme_color_override("font_color", _PROGRESS_COLOR_LEVEL_UP)


func _refresh_progress_labels() -> void:
	# Resolve player / companion references once the scene tree is up.
	if _player == null:
		var players: Array = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			_player = players[0]
	if _companion == null:
		var companions: Array = get_tree().get_nodes_in_group("companions")
		if not companions.is_empty():
			_companion = companions[0]
	_refresh_progress_for(_player)
	_refresh_progress_for(_companion)


func _refresh_progress_for(character: Node) -> void:
	if character == null:
		return
	var label: Label = _progress_label_for(character)
	if label == null:
		return
	var stats: CharacterStatsDefinition = ProgressionManager.get_stats(character)
	var display: String = "?"
	if stats != null and stats.display_name != "":
		display = stats.display_name
	elif character.has_method("get_task_name"):
		display = "Sibling"
	else:
		display = "Player"
	var level: int = ProgressionManager.get_level(character)
	var xp: int = ProgressionManager.get_xp(character)
	var to_next: int = ProgressionManager.get_xp_to_next_level(character)
	if to_next <= 0 and stats != null and level >= stats.max_level():
		label.text = "%s: Lv %d - MAX" % [display, level]
	else:
		var threshold: int = xp + to_next
		label.text = "%s: Lv %d - %d / %d XP" % [display, level, xp, threshold]


func _progress_label_for(character: Node) -> Label:
	if character == _player:
		return player_progress_label
	if character == _companion:
		return companion_progress_label
	return null


func _tick_level_up_flash() -> void:
	if _level_up_flash_until.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var expired: Array = []
	for character in _level_up_flash_until.keys():
		if now >= int(_level_up_flash_until[character]):
			expired.append(character)
	for character in expired:
		_level_up_flash_until.erase(character)
		var label: Label = _progress_label_for(character)
		if label != null:
			label.add_theme_color_override("font_color", _PROGRESS_COLOR_DEFAULT)
