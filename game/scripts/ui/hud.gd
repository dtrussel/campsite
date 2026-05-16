extends CanvasLayer

## HUD
##
## Subscribes to ResourceManager.resource_changed and updates one
## resource label per event (no per-frame polling for inventory).
## The time-of-day label still ticks every frame via _process.

@onready var time_label: Label = $Panel/VBox/TimeLabel
@onready var base_hp_label: Label = $Panel/VBox/BaseHPLabel
@onready var resource_list: VBoxContainer = $Panel/VBox/ResourceList

var _rows: Dictionary = {}  # StringName -> Label


func _ready() -> void:
	_populate_resources()
	ResourceManager.resource_changed.connect(_on_resource_changed)


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
