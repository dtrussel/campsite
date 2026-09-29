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
	return recipe != null and ResourceManager.can_afford(recipe.inputs)


func craft(recipe: CraftingRecipe, crafter: Node) -> bool:
	if not can_craft(recipe):
		return false
	if not ResourceManager.spend_costs(recipe.inputs):
		return false
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
