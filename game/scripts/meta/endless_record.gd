class_name EndlessRecord
extends RefCounted

## EndlessRecord
##
## The best endless run, kept in the profile for good: the furthest
## night an endless run reached (the night it ended on) and the hero who
## played it. The profile keeps it when an endless run ends
## (Profile.record_run_end); this reads it for the title, under Endless,
## and the end screen.


## The record as the title and end screen show it ("Best: night 9 -
## Leo"), or "" when there is none yet.
static func best_text() -> String:
	var nights: int = Profile.endless_best_night()
	if nights <= 0:
		return ""
	var hero: HeroDefinition = HeroRoster.get_hero(Profile.endless_best_hero())
	return "Best: night %d - %s" % [nights, hero.display_name if hero != null else "?"]
