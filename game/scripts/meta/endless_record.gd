class_name EndlessRecord
extends RefCounted

## EndlessRecord
##
## The best endless run, kept in the profile for good: the furthest
## night an endless run reached (the night it ended on) and the hero who
## played it (Profile.record_endless and its reads). The
## title shows it under Endless; the end screen says "New record!".


## An endless run ended on `night` playing `hero`: keeps it as the record
## when it beats the best so far. True when it did.
static func submit(night: int, hero: StringName) -> bool:
	var beaten: bool = Profile.record_endless(night, hero)
	if beaten:
		PlaytestLog.write("endless_record nights=%d hero=%s" % [night, hero])
	return beaten


## The record as the title and end screen show it ("Best: night 9 -
## Leo"), or "" when there is none yet.
static func best_text() -> String:
	var nights: int = Profile.endless_best_night()
	if nights <= 0:
		return ""
	var hero: HeroDefinition = HeroRoster.get_hero(Profile.endless_best_hero())
	return "Best: night %d - %s" % [nights, hero.display_name if hero != null else "?"]
