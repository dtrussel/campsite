extends Node

## Single source of truth for all base/global resources.
## No resources are stored on scene nodes.

signal resource_changed(resource_id: String, new_amount: int)

const RESOURCE_IDS: Array[String] = [
	"wood", "stone", "berries", "fiber", "mushrooms",
	"clay", "leaves", "resin", "scrap", "glow_shards"
]

var _inventory: Dictionary = {}

func _ready() -> void:
	for id in RESOURCE_IDS:
		_inventory[id] = 0

func add(resource_id: String, amount: int) -> void:
	if not _inventory.has(resource_id):
		push_warning("ResourceManager: unknown resource id '%s'" % resource_id)
		return
	_inventory[resource_id] += amount
	resource_changed.emit(resource_id, _inventory[resource_id])

func remove(resource_id: String, amount: int) -> bool:
	if not has_amount(resource_id, amount):
		return false
	_inventory[resource_id] -= amount
	resource_changed.emit(resource_id, _inventory[resource_id])
	return true

func get_amount(resource_id: String) -> int:
	return _inventory.get(resource_id, 0)

func has_amount(resource_id: String, amount: int) -> bool:
	return get_amount(resource_id) >= amount

func can_afford(costs: Dictionary) -> bool:
	for resource_id in costs:
		if not has_amount(resource_id, costs[resource_id]):
			return false
	return true

func spend(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for resource_id in costs:
		remove(resource_id, costs[resource_id])
	return true

func get_all() -> Dictionary:
	return _inventory.duplicate()

func debug_add_all(amount: int = 10) -> void:
	for id in RESOURCE_IDS:
		add(id, amount)
