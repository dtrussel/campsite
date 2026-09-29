extends Node

## ResourceManager
##
## Autoload owning the global resource inventory. Loads every
## ResourceDefinition under res://resources/items/ at startup,
## initialises each id to zero, and exposes a small add/spend API.
##
## State changes are announced via resource_changed; callers should
## connect to that signal rather than poll.

signal resource_changed(id: StringName, new_value: int, delta: int)
signal inventory_ready
## Storage Crates were built or destroyed: caps changed.
signal caps_changed

const STORAGE_GROUP: StringName = &"storage"

const ITEM_DIR: String = "res://resources/items/"

var _definitions: Array[ResourceDefinition] = []
var _by_id: Dictionary = {}        # StringName -> ResourceDefinition
var _inventory: Dictionary = {}    # StringName -> int


func _ready() -> void:
	_load_definitions()
	for definition in _definitions:
		_inventory[definition.id] = 0
	inventory_ready.emit()


## Zeroes every counter (new run). Emits resource_changed per id so
## any listening UI refreshes.
func reset() -> void:
	for id in _inventory.keys():
		var previous: int = int(_inventory[id])
		_inventory[id] = 0
		if previous != 0:
			resource_changed.emit(id, 0, -previous)


func get_definitions() -> Array[ResourceDefinition]:
	return _definitions


func get_definition(id: StringName) -> ResourceDefinition:
	return _by_id.get(id, null) as ResourceDefinition


func get_count(id: StringName) -> int:
	return int(_inventory.get(id, 0))


func has(id: StringName, amount: int) -> bool:
	return get_count(id) >= amount


## Adds up to the stash cap. Returns the new count; `room_for()` tells
## callers beforehand whether anything fits.
func add(id: StringName, amount: int) -> int:
	if amount <= 0 or not _inventory.has(id):
		return get_count(id)
	var added: int = mini(amount, room_for(id))
	if added <= 0:
		return get_count(id)
	var new_value: int = get_count(id) + added
	_inventory[id] = new_value
	resource_changed.emit(id, new_value, added)
	return new_value


## The stash limit for an item: base_cap per crate plus the camp's own
## (0 = unlimited).
func get_cap(id: StringName) -> int:
	var definition: ResourceDefinition = get_definition(id)
	if definition == null or definition.base_cap <= 0:
		return 0
	return definition.base_cap * (1 + get_storage_count())


func get_storage_count() -> int:
	return get_tree().get_nodes_in_group(STORAGE_GROUP).size() if is_inside_tree() else 0


## How many more of an item fit (a big number when uncapped).
func room_for(id: StringName) -> int:
	var cap: int = get_cap(id)
	return 1_000_000 if cap <= 0 else maxi(0, cap - get_count(id))


func is_full(id: StringName) -> bool:
	return room_for(id) <= 0


## Called by Storage Crates when they are built or removed.
func notify_caps_changed() -> void:
	caps_changed.emit()


func spend(id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	if not has(id, amount):
		return false
	var new_value: int = get_count(id) - amount
	_inventory[id] = new_value
	resource_changed.emit(id, new_value, -amount)
	return true


func can_afford(costs: Dictionary) -> bool:
	for key in costs.keys():
		var id: StringName = StringName(key)
		if not has(id, int(costs[key])):
			return false
	return true


func spend_costs(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for key in costs.keys():
		spend(StringName(key), int(costs[key]))
	return true


func _load_definitions() -> void:
	_definitions.clear()
	_by_id.clear()
	for loaded in DefinitionLoader.load_all(ITEM_DIR):
		var def: ResourceDefinition = loaded as ResourceDefinition
		if def == null:
			push_warning("ResourceManager: %s is not a ResourceDefinition" % loaded.resource_path)
		elif def.id == &"":
			push_warning("ResourceManager: %s has empty id; skipping" % loaded.resource_path)
		else:
			_definitions.append(def)
			_by_id[def.id] = def
	_definitions.sort_custom(_compare_definitions)


func _compare_definitions(a: ResourceDefinition, b: ResourceDefinition) -> bool:
	if a.rarity != b.rarity:
		return a.rarity < b.rarity
	return a.display_name < b.display_name
