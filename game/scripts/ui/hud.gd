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
	call_deferred("_hook_base_core")
	call_deferred("_refresh_companion_label")
	call_deferred("_refresh_progress_labels")
	_apply_phase_color(TimeManager.current_phase)


func _process(_delta: float) -> void:
	var phase: String = TimeManager.get_phase_name()
	var remaining: int = int(ceil(TimeManager.remaining_seconds))
	time_label.text = "Day %d - %s (%ds)" % [TimeManager.day_number, phase, remaining]
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
		resource_list.add_child(row)
		_rows[definition.id] = row


func _on_resource_changed(id: StringName, new_value: int, _delta: int) -> void:
	var row: Label = _rows.get(id, null) as Label
	if row == null:
		push_warning("HUD: no row for resource id '%s'" % id)
		return
	var definition: ResourceDefinition = ResourceManager.get_definition(id)
	var display_name: String = definition.display_name if definition != null else String(id)
	row.text = "%s: %d" % [display_name, new_value]


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
	build_mode_label.text = "Build: %s (%s) - LMB place, RMB/Esc cancel" % [
		definition.display_name, definition.cost_summary()
	]


func _refresh_companion_label() -> void:
	var companions: Array = get_tree().get_nodes_in_group("companions")
	if companions.is_empty():
		companion_task_label.text = "Companion: -"
		return
	var first: Node = companions[0]
	var task_name: String = "?"
	if first.has_method("get_task_name"):
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
