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

const ITEM_DIR: String = "res://resources/items/"

var _definitions: Array[ResourceDefinition] = []
var _by_id: Dictionary = {}        # StringName -> ResourceDefinition
var _inventory: Dictionary = {}    # StringName -> int


func _ready() -> void:
	_load_definitions()
	for definition in _definitions:
		_inventory[definition.id] = 0
	inventory_ready.emit()


func get_definitions() -> Array[ResourceDefinition]:
	return _definitions


func get_definition(id: StringName) -> ResourceDefinition:
	return _by_id.get(id, null) as ResourceDefinition


func get_count(id: StringName) -> int:
	return int(_inventory.get(id, 0))


func has(id: StringName, amount: int) -> bool:
	return get_count(id) >= amount


func add(id: StringName, amount: int) -> int:
	if amount <= 0 or not _inventory.has(id):
		return get_count(id)
	var new_value: int = get_count(id) + amount
	_inventory[id] = new_value
	resource_changed.emit(id, new_value, amount)
	return new_value


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
	var dir: DirAccess = DirAccess.open(ITEM_DIR)
	if dir == null:
		push_warning("ResourceManager: cannot open %s" % ITEM_DIR)
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path: String = ITEM_DIR + file_name
			var loaded: Resource = load(path)
			var def: ResourceDefinition = loaded as ResourceDefinition
			if def == null:
				push_warning("ResourceManager: %s is not a ResourceDefinition" % path)
			elif def.id == &"":
				push_warning("ResourceManager: %s has empty id; skipping" % path)
			else:
				_definitions.append(def)
				_by_id[def.id] = def
		file_name = dir.get_next()
	dir.list_dir_end()
	_definitions.sort_custom(_compare_definitions)


func _compare_definitions(a: ResourceDefinition, b: ResourceDefinition) -> bool:
	if a.rarity != b.rarity:
		return a.rarity < b.rarity
	return a.display_name < b.display_name
