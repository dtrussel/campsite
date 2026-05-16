extends CanvasLayer

## HUD
##
## Phase 0 placeholder HUD. Lists time of day, base HP, and all 10
## resources with placeholder values. Real values arrive in later
## phases (ResourceManager in Phase 2, base HP wiring in Phase 5).

const RESOURCE_NAMES: Array[String] = [
	"Wood",
	"Stone",
	"Berries",
	"Fiber",
	"Mushrooms",
	"Clay",
	"Leaves",
	"Resin",
	"Scrap",
	"Glow Shards",
]

@onready var time_label: Label = $Panel/VBox/TimeLabel
@onready var base_hp_label: Label = $Panel/VBox/BaseHPLabel
@onready var resource_list: VBoxContainer = $Panel/VBox/ResourceList


func _ready() -> void:
	_populate_resources()


func _process(_delta: float) -> void:
	if TimeManager:
		time_label.text = "Day %d - %s" % [TimeManager.day_number, TimeManager.get_phase_label()]
	base_hp_label.text = "Base HP: 100 / 100"


func _populate_resources() -> void:
	for child in resource_list.get_children():
		child.queue_free()
	for res_name in RESOURCE_NAMES:
		var row: Label = Label.new()
		row.text = "%s: 0" % res_name
		resource_list.add_child(row)
