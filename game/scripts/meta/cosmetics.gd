class_name Cosmetics
extends RefCounted

## Cosmetics
##
## Badge-unlocked looks: hero outfit tints and tent
## colours. Tints only: the colour multiplies the painted texture
## through the Stylize tint hook (Stylize.TINT_META), so no new art is
## needed. Hats and capes are a follow-up once there is art.
##
## Each entry is {id, name, color, badge}: `badge` is the Camp Badge
## that unlocks it, empty for the default everyone has. The picks are
## kept in the profile: one outfit per hero (Profile.outfit_pick) and
## one tent (Profile.tent_pick). A pick whose badge is no longer
## earned (the profile was deleted) reads as the default.

const DEFAULT_OUTFIT: StringName = &"ranger"
const DEFAULT_TENT: StringName = &"canvas"

const OUTFITS: Array[Dictionary] = [
	{"id": &"ranger", "name": "Ranger", "color": Color(1, 1, 1), "badge": &""},
	{"id": &"moss", "name": "Moss", "color": Color(0.72, 0.9, 0.62), "badge": &"first_night"},
	{"id": &"ember", "name": "Ember", "color": Color(1.0, 0.74, 0.58), "badge": &"fire_keeper"},
	{"id": &"dusk", "name": "Dusk", "color": Color(0.78, 0.74, 1.0), "badge": &"night_owl"},
	{"id": &"moonlight", "name": "Moonlight", "color": Color(0.7, 0.86, 1.0), "badge": &"lantern_lighter"},
	{"id": &"mushroom", "name": "Mushroom", "color": Color(1.0, 0.82, 0.86), "badge": &"gremlin_catcher"},
]

const TENTS: Array[Dictionary] = [
	{"id": &"canvas", "name": "Canvas", "color": Color(1, 1, 1), "badge": &""},
	{"id": &"berry", "name": "Berry", "color": Color(1.0, 0.68, 0.74), "badge": &"builder"},
	{"id": &"pine", "name": "Pine", "color": Color(0.7, 0.92, 0.72), "badge": &"chapter_1"},
	{"id": &"night", "name": "Night Sky", "color": Color(0.68, 0.72, 1.0), "badge": &"chapter_2"},
	{"id": &"sunrise", "name": "Sunrise", "color": Color(1.0, 0.86, 0.56), "badge": &"both_heroes"},
]


## Whether entry (one of OUTFITS or TENTS) can be picked: its badge is
## earned, or it is a default.
static func is_unlocked(entry: Dictionary) -> bool:
	var badge: StringName = entry.get("badge", &"")
	return badge == &"" or Profile.is_badge_earned(badge)


## How to unlock entry, for a locked swatch's tooltip.
static func unlock_hint(entry: Dictionary) -> String:
	var badge: BadgeDefinition = Badges.get_badge(entry.get("badge", &""))
	return "Earn the %s badge" % badge.display_name if badge != null else ""


static func outfit(id: StringName) -> Dictionary:
	return _find(OUTFITS, id)


static func tent(id: StringName) -> Dictionary:
	return _find(TENTS, id)


## The outfit hero wears: the one picked, if still unlocked.
static func outfit_id(hero: StringName) -> StringName:
	return _picked(OUTFITS, Profile.outfit_pick(hero), DEFAULT_OUTFIT)


static func outfit_tint(hero: StringName) -> Color:
	return outfit(outfit_id(hero)).get("color", Color.WHITE)


## Keeps id as hero's outfit; false (and nothing kept) when it is
## unknown or locked.
static func choose_outfit(hero: StringName, id: StringName) -> bool:
	if not _can_pick(OUTFITS, id):
		return false
	Profile.record_outfit_pick(hero, id)
	PlaytestLog.write("cosmetic_picked hero=%s outfit=%s" % [hero, id])
	return true


static func tent_id() -> StringName:
	return _picked(TENTS, Profile.tent_pick(), DEFAULT_TENT)


static func tent_tint() -> Color:
	return tent(tent_id()).get("color", Color.WHITE)


static func choose_tent(id: StringName) -> bool:
	if not _can_pick(TENTS, id):
		return false
	Profile.record_tent_pick(id)
	PlaytestLog.write("cosmetic_picked tent=%s" % id)
	return true


## Every badge an entry names, for validate_project.gd.
static func badges_named() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in OUTFITS + TENTS:
		if entry["badge"] != &"":
			out.append(entry["badge"])
	return out


static func _find(entries: Array[Dictionary], id: StringName) -> Dictionary:
	for entry in entries:
		if entry["id"] == id:
			return entry
	return {}


## The entry `picked` names, or fallback when none or it is locked.
static func _picked(entries: Array[Dictionary], picked: StringName, fallback: StringName) -> StringName:
	var entry: Dictionary = _find(entries, picked)
	return entry["id"] if not entry.is_empty() and is_unlocked(entry) else fallback


## Whether id is a known entry that can be picked now.
static func _can_pick(entries: Array[Dictionary], id: StringName) -> bool:
	var entry: Dictionary = _find(entries, id)
	return not entry.is_empty() and is_unlocked(entry)
