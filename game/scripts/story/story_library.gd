class_name StoryLibrary
extends RefCounted

## StoryLibrary
##
## Finds story beats (res://resources/story/), speaker names and
## portraits, and the voice recording for each line. Also remembers
## which beats the player has seen (the chapter intros and the true
## ending) through the Profile's verbs (Profile.mark_seen), so an intro
## plays once per chapter.
##
## Voice files: res://assets/audio/voice/<line id>.ogg
## (or .wav / .mp3). A line without a file is shown as text only.

const BEATS_DIR: String = "res://resources/story/"
const VOICE_DIR: String = "res://assets/audio/voice/"
const VOICE_EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]
## Mum's portraits, cut from the team's character sheet
## (art/ui/story_art.py): mum.png, and mum_<face>.png per expression.
const MUM_PORTRAIT: String = "res://assets/ui/story/mum.png"
const MUM_FACES: Array[String] = ["smile", "curious", "laugh", "surprised", "worried", "proud"]
const CHAPTER_NAMES: Dictionary = {1: "The Dark Moon", 2: "Into the Hollow"}
## Seen once Chapter 2's ending has played: Mum is home.
const TRUE_ENDING: String = "ending.c2"

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
		"note":
			return "Mum's note"
	var hero: HeroDefinition = HeroRoster.get_hero(StringName(speaker))
	return hero.display_name if hero != null else speaker.capitalize()


## `face` picks one of Mum's expressions (a line's "face" key). Her
## notes show her face too, and a kid's line shows their painted
## expression when one exists.
static func speaker_portrait(speaker: String, face: String = "") -> Texture2D:
	if speaker == "mum" or speaker == "note":
		var path: String = MUM_PORTRAIT.replace(".png", "_%s.png" % face) if face != "" else MUM_PORTRAIT
		if not ResourceLoader.exists(path):
			path = MUM_PORTRAIT
		return load(path) as Texture2D if ResourceLoader.exists(path) else null
	# The kids' painted expressions, where the team has drawn
	# that one; otherwise the hero's own portrait.
	if face != "" and ResourceLoader.exists(hero_face_path(speaker, face)):
		return load(hero_face_path(speaker, face)) as Texture2D
	var hero: HeroDefinition = HeroRoster.get_hero(StringName(speaker))
	return hero.portrait if hero != null else null


## Where a kid's expression portrait lives: assets/ui/story/<hero>_<face>.png.
static func hero_face_path(hero_id: String, face: String) -> String:
	return MUM_PORTRAIT.get_base_dir().path_join("%s_%s.png" % [hero_id, face])


## The recording for a line id, or null while there is none yet.
static func voice(line_id: String) -> AudioStream:
	for extension in VOICE_EXTENSIONS:
		var path: String = "%s%s.%s" % [VOICE_DIR, line_id, extension]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


## Whether the player has seen this beat ("intro.c1", TRUE_ENDING).
static func has_seen(key: String) -> bool:
	return Profile.has_seen(key)


static func mark_seen(key: String) -> void:
	Profile.mark_seen(key)


## Forgets every seen beat; the rest of the profile stays.
static func forget_progress() -> void:
	Profile.forget_seen()
