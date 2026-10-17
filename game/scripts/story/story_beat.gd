class_name StoryBeat
extends Resource

## StoryBeat
##
## One card of the story (feature 035, docs/design/story.md): a painted
## page of the intro or an ending, a dawn dialogue, or a defeat line.
## Each line is a dictionary:
##   {"id": "dawn.c1.n1.leo.1", "speaker": "leo", "text": "...", "when": "leo"}
## - `speaker`: a hero id (leo, nela), "mum" or "narrator".
## - `when` (optional): only shown when that hero is played, so the
##   played hero speaks first and the companion replies.
## - `face` (optional, Mum only): her expression portrait, one of
##   StoryLibrary.MUM_FACES.
## - The voice recording is found by the line id (StoryLibrary.voice),
##   so the team's voice files drop in without code changes.

## Where the beat plays. `shard` is the first Glow Shard of a run.
const TRIGGERS: Array[StringName] = [&"intro", &"dawn", &"shard", &"win", &"loss_fire", &"loss_hero"]
const SPEAKERS: Array[String] = ["leo", "nela", "mum", "narrator"]

@export var id: StringName = &""
## 1 = "The Dark Moon" (3 nights), 2 = "Into the Hollow" (7 nights),
## 0 = any chapter.
@export var chapter: int = 0
@export var trigger: StringName = &"dawn"
## For dawn beats: the night just survived.
@export var night: int = 0
## Order of the pages of an intro or an ending.
@export var page: int = 1
## The painting behind an intro or ending page. Placeholders reuse the
## loading paintings until the team's art arrives.
@export var painting: Texture2D = null
@export var lines: Array = []


## The lines for the party: lines for another played hero are left out.
func lines_for(hero_id: StringName) -> Array:
	var out: Array = []
	for line in lines:
		var when: String = String((line as Dictionary).get("when", ""))
		if when == "" or when == String(hero_id):
			out.append(line)
	return out
