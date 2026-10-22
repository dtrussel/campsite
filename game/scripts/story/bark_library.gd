class_name BarkLibrary
extends RefCounted

## BarkLibrary
##
## Finds the siblings' barks in res://resources/barks/.
## A bark is picked at random among a speaker's lines for a trigger,
## never the same line twice in a row.

const BARKS_PATH: String = "res://resources/barks/barks.tres"

static var _set: BarkSet = null


static func bark_set() -> BarkSet:
	if _set == null:
		_set = load(BARKS_PATH) as BarkSet
		if _set == null:
			push_warning("BarkLibrary: missing %s" % BARKS_PATH)
			_set = BarkSet.new()
	return _set


## A trigger's tuning (role, cooldown, urgent, once), or {} if unknown.
static func trigger(name: StringName) -> Dictionary:
	return bark_set().triggers.get(name, {}) as Dictionary


## A speaker's lines for a trigger when `played` is the played hero.
static func lines_for(name: StringName, speaker: StringName, played: StringName) -> Array:
	var out: Array = []
	for value in bark_set().lines:
		var line: Dictionary = value as Dictionary
		if String(line.get("trigger", "")) != String(name) or String(line.get("speaker", "")) != String(speaker):
			continue
		var when: String = String(line.get("when", ""))
		if when == "" or when == String(played):
			out.append(line)
	return out


## A random line, avoiding the id `last` when there is a choice.
static func pick(name: StringName, speaker: StringName, played: StringName, last: String = "") -> Dictionary:
	var options: Array = lines_for(name, speaker, played)
	if options.size() > 1:
		options = options.filter(func(line: Dictionary) -> bool: return String(line.get("id", "")) != last)
	return options.pick_random() as Dictionary if not options.is_empty() else {}
