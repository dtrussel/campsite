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
@onready var build_mode_label: Label = $Panel/VBox/BuildModeLabel
@onready var camp_destroyed_label: Label = $Panel/VBox/CampDestroyedLabel
@onready var resource_list: VBoxContainer = $Panel/VBox/ResourceList

const _BUILD_COLOR_VALID: Color = Color(0.6, 1.0, 0.6, 1)
const _BUILD_COLOR_INVALID: Color = Color(1.0, 0.6, 0.6, 1)
const _PHASE_COLOR_DAY: Color = Color(1, 1, 1, 1)
const _PHASE_COLOR_SUNSET: Color = Color(1, 0.55, 0.45, 1)
const _PHASE_COLOR_NIGHT: Color = Color(0.7, 0.75, 1, 1)
const _PHASE_COLOR_DAWN: Color = Color(1, 0.9, 0.7, 1)

var _rows: Dictionary = {}  # StringName -> Label
var _base_core: Node = null


func _ready() -> void:
	_populate_resources()
	ResourceManager.resource_changed.connect(_on_resource_changed)
	BuildManager.build_mode_entered.connect(_on_build_mode_entered)
	BuildManager.build_mode_exited.connect(_on_build_mode_exited)
	BuildManager.placement_validity_changed.connect(_on_placement_validity_changed)
	TimeManager.phase_changed.connect(_on_phase_changed)
	GameManager.camp_destroyed.connect(_on_camp_destroyed)
	GameManager.companion_task_changed.connect(_on_companion_task_changed)
	call_deferred("_hook_base_core")
	call_deferred("_refresh_companion_label")
	_apply_phase_color(TimeManager.current_phase)


func _process(_delta: float) -> void:
	var phase: String = TimeManager.get_phase_name()
	var remaining: int = int(ceil(TimeManager.remaining_seconds))
	time_label.text = "Day %d - %s (%ds)" % [TimeManager.day_number, phase, remaining]
	if _base_core != null and is_instance_valid(_base_core):
		base_hp_label.text = "Base HP: %d / %d" % [
			_base_core.current_hp, _base_core.max_hp
		]


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
