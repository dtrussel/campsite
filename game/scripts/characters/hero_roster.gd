class_name HeroRoster
extends RefCounted

## HeroRoster
##
## The playable heroes in select-screen order (feature 034). Adding a
## hero is one .tres in res://resources/heroes/ plus one line here.
## Each hero in the world joins the group "hero_<id>", so recipes and
## saves can find a hero whichever role it plays.

const HEROES: Array[HeroDefinition] = [
	preload("res://resources/heroes/leo.tres"),
	preload("res://resources/heroes/nela.tres"),
]


static func all() -> Array[HeroDefinition]:
	return HEROES


static func get_hero(id: StringName) -> HeroDefinition:
	for hero in HEROES:
		if hero.id == id:
			return hero
	return null


static func has_hero(id: StringName) -> bool:
	return get_hero(id) != null


## The companion that goes with `hero_id` until there is a companion
## picker: the first other hero.
static func default_companion(hero_id: StringName) -> StringName:
	for hero in HEROES:
		if hero.id != hero_id:
			return hero.id
	return hero_id


static func group_for(id: StringName) -> StringName:
	return StringName("hero_%s" % id)


## The hero's character node in the running world, or null.
static func node_for(tree: SceneTree, id: StringName) -> Node:
	return tree.get_first_node_in_group(group_for(id))
