class_name StartingPerks
extends RefCounted

## StartingPerks
##
## Starting perks: a Camp Badge unlocks a perk card
## that a run can start with already taken. Hero select offers the
## unlocked ones; the pick is kept in the profile, hero select puts it
## on the run config, and GameManager gives it to the played hero when a new run
## starts (PerkManager.take_starting). Continue never gives it again:
## the save already holds it.
##
## Only shared cards, so either hero can start with any of them.

## The starting list, in hero-select order: perk id -> the badge that
## unlocks it.
const UNLOCKS: Dictionary = {
	&"quick_hands": &"gatherer",
	&"builders_knack": &"builder",
	&"ember_heart": &"torch_bearer",
}
## The profile key of the pick ("" for none).
const CHOSEN_KEY: String = "perks.starting"


## The starting perks the profile's badges unlock, in list order.
static func unlocked() -> Array[StringName]:
	var out: Array[StringName] = []
	for perk in UNLOCKS:
		if is_unlocked(perk):
			out.append(perk)
	return out


static func is_unlocked(perk: StringName) -> bool:
	return UNLOCKS.has(perk) and Badges.has_badge(UNLOCKS[perk])


## The pick for the next run, or &"" when none is picked or it is no
## longer unlocked (the profile was deleted).
static func chosen() -> StringName:
	var perk: StringName = StringName(String(Profile.get_value(CHOSEN_KEY, "")))
	return perk if is_unlocked(perk) else &""


## Keeps `perk` as the pick for the next runs (&"" for none).
static func choose(perk: StringName) -> void:
	Profile.set_value(CHOSEN_KEY, String(perk) if is_unlocked(perk) else "")


## What is wrong with the list, for validate_project.gd: an unknown or
## hero-only perk, or an unknown badge. Empty when sound.
static func problems() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for perk in UNLOCKS:
		var definition: PerkDefinition = PerkManager.get_definition(perk)
		if definition == null:
			out.append("lists unknown perk '%s'" % perk)
		elif definition.pool != &"shared":
			out.append("lists '%s', which is not a shared card" % perk)
		if Badges.get_badge(UNLOCKS[perk]) == null:
			out.append("unlocks '%s' with unknown badge '%s'" % [perk, UNLOCKS[perk]])
	return out
