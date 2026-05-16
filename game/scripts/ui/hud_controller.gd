extends CanvasLayer

## Manages the heads-up display: resources, time, base health, warnings.

const RESOURCE_DISPLAY_NAMES: Dictionary = {
	"wood":        "Wood",
	"stone":       "Stone",
	"berries":     "Berries",
	"fiber":       "Fiber",
	"mushrooms":   "Mushrooms",
	"clay":        "Clay",
	"leaves":      "Leaves",
	"resin":       "Resin",
	"scrap":       "Scrap",
	"glow_shards": "Glow Shards",
}

@onready var _time_label: Label = $Panel/VBox/TimeLabel
@onready var _day_label: Label = $Panel/VBox/DayLabel
@onready var _base_health_label: Label = $Panel/VBox/BaseHealthLabel
@onready var _resource_container: VBoxContainer = $Panel/VBox/Resources
@onready var _warning_label: Label = $Panel/VBox/WarningLabel

var _resource_labels: Dictionary = {}

func _ready() -> void:
	_build_resource_labels()
	_connect_signals()
	_warning_label.visible = false

func _build_resource_labels() -> void:
	for id in RESOURCE_DISPLAY_NAMES.keys():
		var label: Label = Label.new()
		label.text = "%s: 0" % RESOURCE_DISPLAY_NAMES[id]
		label.name = "Res_%s" % id
		_resource_container.add_child(label)
		_resource_labels[id] = label

func _connect_signals() -> void:
	ResourceManager.resource_changed.connect(_on_resource_changed)
	TimeManager.time_updated.connect(_on_time_updated)
	TimeManager.sunset_warning.connect(_on_sunset_warning)
	TimeManager.day_started.connect(_on_day_started)
	TimeManager.night_started.connect(_on_night_started)
	TimeManager.dawn_started.connect(_on_dawn_started)
	GameManager.new_day_started.connect(_on_new_day)

func _on_resource_changed(resource_id: String, new_amount: int) -> void:
	if _resource_labels.has(resource_id):
		var label: Label = _resource_labels[resource_id]
		var display: String = RESOURCE_DISPLAY_NAMES.get(resource_id, resource_id)
		label.text = "%s: %d" % [display, new_amount]

func _on_time_updated(normalized_time: float) -> void:
	var phase: String = TimeManager.get_phase().capitalize()
	_time_label.text = "Phase: %s" % phase

func _on_new_day(day_number: int) -> void:
	_day_label.text = "Day %d" % day_number

func _on_sunset_warning(seconds_remaining: float) -> void:
	_warning_label.text = "NIGHT APPROACHING — %.0f sec" % seconds_remaining
	_warning_label.visible = true

func _on_day_started() -> void:
	_warning_label.visible = false
	_time_label.text = "Phase: Day"

func _on_night_started() -> void:
	_warning_label.text = "NIGHT — DEFEND THE CAMP!"
	_warning_label.visible = true

func _on_dawn_started() -> void:
	_warning_label.text = "Dawn — You survived!"
	_warning_label.visible = true

func update_base_health(current: int, maximum: int) -> void:
	_base_health_label.text = "Base HP: %d / %d" % [current, maximum]
