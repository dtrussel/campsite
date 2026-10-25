extends "res://tests/unit/unit_test.gd"

## Stride matching (CharacterVisual): the walk and run cycles play
## faster or slower with the character's real speed, so a cycle
## authored for one ground speed keeps its feet planted at another.
## Idle always plays at its natural rate.

var _visual: CharacterVisual = null


func _init() -> void:
	_visual = CharacterVisual.new()
	_visual.clips = {&"idle": "Idle", &"walk": "Walk", &"move": "Run"}
	_visual.walk_speed = 1.6
	_visual.walk_reference_speed = 1.2
	_visual.reference_speed = 4.0


func after_each() -> void:
	_visual.free()


func test_a_walk_plays_at_the_speed_it_was_authored_for() -> void:
	check(is_equal_approx(CharacterVisual.walk_play_speed(1.2, 1.2), 1.0),
		"a walk authored for 1.2 m/s plays at 1x at 1.2 m/s")
	check(is_equal_approx(CharacterVisual.walk_play_speed(1.6, 1.2), 1.6 / 1.2),
		"and at 1.33x at 1.6 m/s, so its feet keep up with the ground")


func test_a_walk_without_a_reference_speed_plays_at_its_natural_rate() -> void:
	check(is_equal_approx(CharacterVisual.walk_play_speed(1.6, 0.0), 1.0), "no reference speed: 1x (a stock walk)")


func test_standing_still_plays_the_idle_at_its_natural_rate() -> void:
	check(is_equal_approx(_visual.locomotion_play_speed(0.0, 0.0), 1.0), "idle at 1x")


func test_at_walk_speed_the_walk_is_scaled_by_the_real_speed() -> void:
	check(is_equal_approx(_visual.locomotion_play_speed(1.6, 1.6), 1.6 / 1.2),
		"at walk speed the walk plays at 1.33x (got %.3f)" % _visual.locomotion_play_speed(1.6, 1.6))


func test_running_the_run_is_scaled_by_the_real_speed() -> void:
	var speed: float = 4.0
	check(is_equal_approx(_visual.locomotion_play_speed(speed, speed), 1.0),
		"at its 4 m/s reference the run plays at 1x (got %.3f)" % _visual.locomotion_play_speed(speed, speed))
	check(is_equal_approx(_visual.locomotion_play_speed(5.0, 5.0), 1.25), "and at 1.25x at 5 m/s")
