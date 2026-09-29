extends Node

## CraftingManager
##
## Autoload that owns the recipe list and the craft action. Loads
## every CraftingRecipe under res://resources/recipes/ at startup.
## Spending and granting go through ResourceManager; XP goes through
## ProgressionManager, credited to whoever crafted.

signal crafted(recipe: CraftingRecipe, crafter: Node)

const RECIPES_DIR: String = "res://resources/recipes/"

## True only while craft() is adding the output, so listeners can tell
## crafted items apart from gathered ones.
var is_crafting: bool = false

var _recipes: Array[CraftingRecipe] = []


func _ready() -> void:
	for loaded in DefinitionLoader.load_all(RECIPES_DIR):
		var recipe: CraftingRecipe = loaded as CraftingRecipe
		if recipe == null or recipe.id == &"":
			push_warning("CraftingManager: skipping invalid recipe %s" % loaded.resource_path)
			continue
		_recipes.append(recipe)
	_recipes.sort_custom(func(a: CraftingRecipe, b: CraftingRecipe) -> bool:
		return a.sort_order < b.sort_order
	)


func get_recipes() -> Array[CraftingRecipe]:
	return _recipes


func can_craft(recipe: CraftingRecipe) -> bool:
	if recipe == null or not ResourceManager.can_afford(recipe.inputs) or not _effect_possible(recipe.effect):
		return false
	if recipe.output_id != &"" and ResourceManager.room_for(recipe.output_id) < recipe.output_amount:
		return false
	return recipe.station != CraftingRecipe.STATION_TABLE or has_table()


## Whether a Crafting Table stands in the camp (unlocks table recipes).
func has_table() -> bool:
	return not get_tree().get_nodes_in_group(CraftingTable.GROUP).is_empty()


func craft(recipe: CraftingRecipe, crafter: Node) -> bool:
	if not can_craft(recipe):
		return false
	if not ResourceManager.spend_costs(recipe.inputs):
		return false
	if recipe.effect != &"":
		_apply_effect(recipe.effect)
	if recipe.output_id != &"":
		is_crafting = true
		ResourceManager.add(recipe.output_id, recipe.output_amount)
		is_crafting = false
	if crafter != null:
		ProgressionManager.award_xp(crafter, recipe.xp_reward, &"craft")
	GameManager.record(&"crafted", recipe.output_amount)
	PlaytestLog.write("crafted id=%s day=%d" % [recipe.id, TimeManager.day_number])
	AudioManager.play_sfx(&"craft")
	crafted.emit(recipe, crafter)
	return true


func _campfire() -> BaseCore:
	return get_tree().get_first_node_in_group("base_core") as BaseCore


## Whether an effect recipe can do anything right now (no wasted wood on
## a full campfire, and the hearth only once).
func _effect_possible(effect: StringName) -> bool:
	match effect:
		&"":
			return true
		&"feed_fire":
			var fire: BaseCore = _campfire()
			return fire != null and fire.get_missing_hp() > 0
		&"stone_hearth":
			var fire: BaseCore = _campfire()
			return fire != null and not fire.has_hearth and not fire.is_destroyed
		&"sturdy_stick":
			var player: Node = _player()
			return player != null and not bool(player.get("has_sturdy_stick"))
		&"slingshot":
			var sibling: Node = _sibling()
			return sibling != null and not bool(sibling.get("has_slingshot"))
		&"trap_refill":
			for trap in get_tree().get_nodes_in_group(SnapTrap.GROUP):
				if (trap as SnapTrap).needs_refill():
					return true
			return false
	return false


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _sibling() -> Node:
	return get_tree().get_first_node_in_group("companions")


func _apply_effect(effect: StringName) -> void:
	match effect:
		&"sturdy_stick":
			_player().call("upgrade_stick")
			return
		&"slingshot":
			_sibling().call("give_slingshot")
			return
		&"trap_refill":
			for trap in get_tree().get_nodes_in_group(SnapTrap.GROUP):
				(trap as SnapTrap).recharge()
			return
	var fire: BaseCore = _campfire()
	if fire == null:
		return
	match effect:
		&"feed_fire":
			fire.repair(fire.repair_per_tap)
			Fx.burst(&"repair", fire.global_position + Vector3(0, 0.8, 0))
			Fx.float_text(fire, "+%d" % fire.repair_per_tap, Color(0.55, 1.0, 0.6), 1.8)
			GameManager.record(&"repairs")
		&"stone_hearth":
			fire.build_hearth()
