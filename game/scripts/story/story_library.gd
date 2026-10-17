class_name StoryLibrary
extends RefCounted

## StoryLibrary
##
## Finds story beats (res://resources/story/), speaker names and
## portraits, and the voice recording for each line. Also remembers
## which chapter intros the player has seen (user://story.cfg), so an
## intro plays once per chapter.
##
## Voice files (feature 035): res://assets/audio/voice/<line id>.ogg
## (or .wav / .mp3). A line without a file is shown as text only.

const BEATS_DIR: String = "res://resources/story/"
const VOICE_DIR: String = "res://assets/audio/voice/"
const VOICE_EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]
## Mum's portraits, cut from the team's character sheet (feature 043,
## art/ui/story_art.py): mum.png, and mum_<face>.png per expression.
const MUM_PORTRAIT: String = "res://assets/ui/story/mum.png"
const MUM_FACES: Array[String] = ["smile", "curious", "laugh", "surprised", "worried", "proud"]
const CHAPTER_NAMES: Dictionary = {1: "The Dark Moon", 2: "Into the Hollow"}
## Seen once Chapter 2's ending has played: Mum is home (feature 043).
const TRUE_ENDING: String = "ending.c2"

## Tests point this somewhere else so a player's progress is untouched.
static var progress_path: String = "user://story.cfg"
static var _beats: Array = []


static func all() -> Array:
	if _beats.is_empty():
		_beats = DefinitionLoader.load_all(BEATS_DIR)
	return _beats


## Beats for a trigger, in page order. Chapter 0 beats fit any chapter;
## `night` < 0 matches any night.
static func find(trigger: StringName, chapter: int, night: int = -1) -> Array:
	var out: Array = []
	for res in all():
		var beat: StoryBeat = res as StoryBeat
		if beat == null or beat.trigger != trigger:
			continue
		if beat.chapter != 0 and beat.chapter != chapter:
			continue
		if night >= 0 and beat.night != night:
			continue
		out.append(beat)
	out.sort_custom(func(a: StoryBeat, b: StoryBeat) -> bool: return a.page < b.page)
	return out


static func first(trigger: StringName, chapter: int, night: int = -1) -> StoryBeat:
	var beats: Array = find(trigger, chapter, night)
	return beats[0] if not beats.is_empty() else null


static func chapter_name(chapter: int) -> String:
	return String(CHAPTER_NAMES.get(chapter, ""))


static func speaker_name(speaker: String) -> String:
	match speaker:
		"narrator":
			return ""
		"mum":
			return "Mum"
	var hero: HeroDefinition = HeroRoster.get_hero(StringName(speaker))
	return hero.display_name if hero != null else speaker.capitalize()


## `face` picks one of Mum's expressions (a line's "face" key).
static func speaker_portrait(speaker: String, face: String = "") -> Texture2D:
	if speaker == "mum":
		var path: String = MUM_PORTRAIT.replace(".png", "_%s.png" % face) if face != "" else MUM_PORTRAIT
		if not ResourceLoader.exists(path):
			path = MUM_PORTRAIT
		return load(path) as Texture2D if ResourceLoader.exists(path) else null
	var hero: HeroDefinition = HeroRoster.get_hero(StringName(speaker))
	return hero.portrait if hero != null else null


## The recording for a line id, or null while there is none yet.
static func voice(line_id: String) -> AudioStream:
	for extension in VOICE_EXTENSIONS:
		var path: String = "%s%s.%s" % [VOICE_DIR, line_id, extension]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


static func has_seen(key: String) -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(progress_path) != OK:
		return false
	return bool(config.get_value("seen", key, false))


static func mark_seen(key: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(progress_path)  # keep what is there
	config.set_value("seen", key, true)
	config.save(progress_path)


static func forget_progress() -> void:
	if FileAccess.file_exists(progress_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress_path))
