extends CanvasLayer

## HUD
##
## Subscribes to ResourceManager.resource_changed and updates one
## resource label per event (no per-frame polling for inventory).
## The time-of-day label still ticks every frame via _process.

@onready var time_label: Label = $Panel/VBox/TimeLabel
@onready var base_hp_label: Label = $Panel/VBox/BaseHPLabel
@onready var build_mode_label: Label = $Panel/VBox/BuildModeLabel
@onready var resource_list: VBoxContainer = $Panel/VBox/ResourceList

const _BUILD_COLOR_VALID: Color = Color(0.6, 1.0, 0.6, 1)
const _BUILD_COLOR_INVALID: Color = Color(1.0, 0.6, 0.6, 1)

var _rows: Dictionary = {}  # StringName -> Label


func _ready() -> void:
	_populate_resources()
	ResourceManager.resource_changed.connect(_on_resource_changed)
	BuildManager.build_mode_entered.connect(_on_build_mode_entered)
	BuildManager.build_mode_exited.connect(_on_build_mode_exited)
	BuildManager.placement_validity_changed.connect(_on_placement_validity_changed)


func _process(_delta: float) -> void:
	if TimeManager:
		time_label.text = "Day %d - %s" % [TimeManager.day_number, TimeManager.get_phase_label()]
	base_hp_label.text = "Base HP: 100 / 100"


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


func _refresh_build_label(definition: BuildingDefinition) -> void:
	if definition == null:
		build_mode_label.text = "Build: -"
		return
	build_mode_label.text = "Build: %s (%s) - LMB place, RMB/Esc cancel" % [
		definition.display_name, definition.cost_summary()
	]
