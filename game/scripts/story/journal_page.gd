class_name JournalPage
extends Resource

## JournalPage
##
## One page of Mum's journal (story layers 3-4 of
## docs/design/story.md): a short note in her ranger's voice that the
## kids find and keep in the profile for good. Stored as a .tres under
## res://resources/story/journal/ (the file order is the journal's
## order); the Journal class finds them and keeps the found ones.
##
## How it is found (`found_in`):
## - `dawn`: it is one of Mum's dawn notes (046). `note_id` names that
##   note's story line, whose text, face and sketch the page shows, so
##   the dawn card stays the one source of the words. Found when that
##   dawn card plays.
## - `chest`: in a day chest at the map edge (at most one a run).
## - `badge`: earning `badge` finds it.

const FOUND_IN: Array[StringName] = [&"dawn", &"chest", &"badge"]
## A page's lines stay card-short, like every story line.
const MAX_LINE: int = 60
const MAX_LINES: int = 2

@export var id: StringName = &""
## The page's heading in the journal ("The old lantern").
@export var title: String = ""
## One of FOUND_IN.
@export var found_in: StringName = &"chest"
## For `dawn`: the id of the note line on that dawn card.
@export var note_id: String = ""
## For `badge`: the Camp Badge that gives it.
@export var badge: StringName = &""
## Mum's words, for chest and badge pages (dawn pages read their note):
## one or two lines, split by a newline.
@export_multiline var words: String = ""
## One of StoryLibrary.MUM_FACES, for chest and badge pages.
@export var face: String = "smile"
## Optional: a res:// path to one of her notebook sketches.
@export var sketch: String = ""


## Mum's words on the page.
func text() -> String:
	return String(_note().get("text", "")) if found_in == &"dawn" else words


## Her expression beside the page.
func face_shown() -> String:
	return String(_note().get("face", "")) if found_in == &"dawn" else face


## The sketch beside the page, or "" for none.
func sketch_path() -> String:
	return String(_note().get("sketch", "")) if found_in == &"dawn" else sketch


## What is missing or wrong, for validate_project.gd. Empty when sound.
func problems() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if id == &"":
		out.append("has no id")
	if title.strip_edges() == "":
		out.append("has no title")
	if not FOUND_IN.has(found_in):
		out.append("is found in unknown '%s'" % found_in)
	if found_in == &"dawn" and _note().is_empty():
		out.append("names no note line of a dawn card ('%s')" % note_id)
	if found_in == &"badge" and Badges.get_badge(badge) == null:
		out.append("is given by unknown badge '%s'" % badge)
	var lines: PackedStringArray = text().split("\n")
	if text().strip_edges() == "" or lines.size() > MAX_LINES:
		out.append("needs 1-%d lines of words" % MAX_LINES)
	for line in lines:
		if line.length() > MAX_LINE:
			out.append("has a line over %d characters (%d)" % [MAX_LINE, line.length()])
	if not StoryLibrary.MUM_FACES.has(face_shown()):
		out.append("has face '%s' (Mum's are %s)" % [face_shown(), StoryLibrary.MUM_FACES])
	if sketch_path() != "" and not ResourceLoader.exists(sketch_path()):
		out.append("has a missing sketch '%s'" % sketch_path())
	return out


## The dawn note line this page shows, or {} when there is none.
func _note() -> Dictionary:
	if note_id == "":
		return {}
	for res in StoryLibrary.all():
		var beat: StoryBeat = res as StoryBeat
		if beat == null or beat.trigger != &"dawn":
			continue
		for line in beat.lines:
			var entry: Dictionary = line as Dictionary
			if String(entry.get("id", "")) == note_id and String(entry.get("speaker", "")) == "note":
				return entry
	return {}
