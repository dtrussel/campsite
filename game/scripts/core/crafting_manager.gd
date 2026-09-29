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
	return recipe != null and ResourceManager.can_afford(recipe.inputs) and _effect_possible(recipe.effect)


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
	return false


func _apply_effect(effect: StringName) -> void:
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
