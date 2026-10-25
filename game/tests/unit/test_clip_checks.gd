extends "res://tests/unit/unit_test.gd"

## The hero clip measures the validator reports (tools/clip_checks.gd):
## how far a looping clip's last pose is from its first, and how far a
## foot slides per stride at a given ground speed. Each test keys a tiny
## two-bone leg (hips at 1 m, a foot below it) by hand, so the expected
## numbers are worked out from the keys, not from the code.

const ClipChecks: GDScript = preload("res://tools/clip_checks.gd")

var _skeleton: Skeleton3D = null


func _init() -> void:
	_skeleton = Skeleton3D.new()
	_skeleton.add_bone("hips")
	_skeleton.set_bone_rest(0, Transform3D(Basis(), Vector3(0, 1, 0)))
	_skeleton.add_bone("foot.l")
	_skeleton.set_bone_parent(1, 0)
	_skeleton.set_bone_rest(1, Transform3D(Basis(), Vector3(0, -1, 0)))


func after_each() -> void:
	_skeleton.free()


## A 1 s clip whose hips position is keyed at each [time, position].
func _hips_clip(keys: Array) -> Animation:
	var anim: Animation = Animation.new()
	anim.length = 1.0
	var track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, NodePath("Skel:hips"))
	for key in keys:
		anim.position_track_insert_key(track, key[0], key[1])
	return anim


func test_a_clip_that_ends_where_it_starts_does_not_pop() -> void:
	var anim: Animation = _hips_clip([[0.0, Vector3(0, 1, 0)], [0.5, Vector3(0, 1.1, 0)], [1.0, Vector3(0, 1, 0)]])
	var pop: Dictionary = ClipChecks.loop_pop(anim, _skeleton, "Skel", 1.0)
	check(float(pop.metres) < 0.0001, "a loop back to its first pose jumps 0 m (got %.4f)" % pop.metres)
	check(float(pop.degrees) < 0.01, "and turns no bone (got %.3f deg)" % pop.degrees)


func test_a_clip_that_ends_elsewhere_pops_by_the_gap_at_model_scale() -> void:
	var anim: Animation = _hips_clip([[0.0, Vector3(0, 1, 0)], [1.0, Vector3(0, 1.1, 0)]])
	var pop: Dictionary = ClipChecks.loop_pop(anim, _skeleton, "Skel", 0.5)
	# The hips (and the foot under them) end 10 cm higher; at half scale, 5 cm.
	check(absf(float(pop.metres) - 0.05) < 0.001, "the wrap jumps 0.05 m (got %.4f)" % pop.metres)


func test_a_turned_bone_at_the_wrap_reports_its_angle() -> void:
	var anim: Animation = Animation.new()
	anim.length = 1.0
	var track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track, NodePath("Skel:foot.l"))
	anim.rotation_track_insert_key(track, 0.0, Quaternion())
	anim.rotation_track_insert_key(track, 1.0, Quaternion(Vector3.UP, deg_to_rad(20.0)))
	var pop: Dictionary = ClipChecks.loop_pop(anim, _skeleton, "Skel", 1.0)
	check(absf(float(pop.degrees) - 20.0) < 0.1, "the foot turns 20 deg at the wrap (got %.2f)" % pop.degrees)


## A 1 s step for the left foot: planted for the first half while its
## model-space z goes from `planted_from` to `planted_to`, a quick lift,
## a swing back to the start in the air, and a quick set-down.
func _step_clip(planted_from: float, planted_to: float) -> Animation:
	var anim: Animation = Animation.new()
	anim.length = 1.0
	var track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, NodePath("Skel:foot.l"))
	anim.position_track_insert_key(track, 0.0, Vector3(0, -1, planted_from))
	anim.position_track_insert_key(track, 0.5, Vector3(0, -1, planted_to))
	anim.position_track_insert_key(track, 0.55, Vector3(0, -0.8, planted_to))
	anim.position_track_insert_key(track, 0.95, Vector3(0, -0.8, planted_from))
	anim.position_track_insert_key(track, 1.0, Vector3(0, -1, planted_from))
	return anim


func test_a_foot_swept_back_at_the_ground_speed_does_not_slide() -> void:
	# Half a metre back in the half second it is down: 1 m/s, the speed.
	var anim: Animation = _step_clip(0.25, -0.25)
	var slide: float = ClipChecks.foot_slide(anim, _skeleton, "Skel", 1.0, 1.0, 1.0)
	check(slide < 0.02, "a foot planted at 1 m/s slides under 2 cm a stride (got %.3f)" % slide)
	slide = ClipChecks.foot_slide(anim, _skeleton, "Skel", 0.5, 0.5, 1.0)
	check(slide < 0.02, "and at half scale it matches half the speed (got %.3f)" % slide)


func test_a_foot_held_still_slides_by_the_ground_covered_while_down() -> void:
	var anim: Animation = _step_clip(0.0, 0.0)
	var slide: float = ClipChecks.foot_slide(anim, _skeleton, "Skel", 1.0, 1.0, 1.0)
	check(absf(slide - 0.5) < 0.02, "down for 0.5 s at 1 m/s, it slides 0.5 m a stride (got %.3f)" % slide)
	slide = ClipChecks.foot_slide(anim, _skeleton, "Skel", 1.0, 1.0, 2.0)
	check(absf(slide - 0.25) < 0.02, "played twice as fast, it is down 0.25 s: 0.25 m (got %.3f)" % slide)


## A hero whose model holds this test's leg and `anims` (clip name ->
## Animation), with `clips` as its state -> clip map.
func _hero(clips: Dictionary, anims: Dictionary) -> HeroDefinition:
	var root: Node3D = Node3D.new()
	root.name = "Kid"
	var skeleton: Skeleton3D = _skeleton.duplicate() as Skeleton3D
	skeleton.name = "Skel"
	root.add_child(skeleton)
	skeleton.owner = root
	var player: AnimationPlayer = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	var library: AnimationLibrary = AnimationLibrary.new()
	for clip in anims:
		library.add_animation(StringName(clip), anims[clip])
	player.add_animation_library(&"", library)
	root.add_child(player)
	player.owner = root
	player.root_node = NodePath("..")
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	var hero: HeroDefinition = HeroDefinition.new()
	hero.id = &"test"
	hero.model_scene = scene
	hero.model_scale = 1.0
	hero.clips = clips
	return hero


func _rows(rows: Array[Dictionary], state: StringName, kind: String) -> Array[Dictionary]:
	return rows.filter(func(row: Dictionary) -> bool: return row.state == state and row.check == kind)


func test_a_mapped_state_without_its_clip_fails() -> void:
	var hero: HeroDefinition = _hero({&"idle": "Idle", &"cheer": "Missing"}, {"Idle": _hips_clip([[0.0, Vector3(0, 1, 0)]])})
	var rows: Array[Dictionary] = ClipChecks.check_hero(hero, {}, {})
	var missing: Array[Dictionary] = _rows(rows, &"cheer", "clip")
	check(missing.size() == 1 and missing[0].over and missing[0].enforced, "cheer -> 'Missing' is a failing row")
	check(ClipChecks.failures(rows).size() == 1, "and the only failure")


func test_a_check_over_its_limit_reports_until_it_is_switched_to_enforce() -> void:
	var popping: Animation = _hips_clip([[0.0, Vector3(0, 1, 0)], [1.0, Vector3(0, 1.1, 0)]])
	var hero: HeroDefinition = _hero({&"idle": "Idle"}, {"Idle": popping})
	var rows: Array[Dictionary] = ClipChecks.check_hero(hero, {}, {})
	var loop: Array[Dictionary] = _rows(rows, &"idle", "loop")
	check(loop.size() == 1 and loop[0].over and not loop[0].enforced, "a 10 cm pop is over the limit, reported")
	check(ClipChecks.failures(rows).is_empty(), "a reported check does not fail")
	rows = ClipChecks.check_hero(hero, {&"test": {&"idle": ["loop"]}}, {})
	check(ClipChecks.failures(rows).size() == 1, "switched to enforce, the idle loop fails")


func test_an_action_clip_is_timed_at_its_play_speed() -> void:
	var attack: Animation = _hips_clip([[0.0, Vector3(0, 1, 0)]])
	attack.length = 1.5
	var hero: HeroDefinition = _hero({&"attack": "Attack"}, {"Attack": attack})
	# Heroes play the attack at 1.5x: a 1.5 s clip lasts 1 s.
	var rows: Array[Dictionary] = ClipChecks.check_hero(hero, {}, {&"test": {&"attack": 1.0}})
	var timed: Array[Dictionary] = _rows(rows, &"attack", "duration")
	check(timed.size() == 1 and absf(float(timed[0].value) - 1.0) < 0.001 and not timed[0].over,
		"a 1.5 s attack at 1.5x lasts its 1 s target")
	rows = ClipChecks.check_hero(hero, {}, {&"test": {&"attack": 0.7}})
	check(_rows(rows, &"attack", "duration")[0].over, "against a 0.7 s target it is over")


func test_a_walk_is_measured_at_its_stride_matched_play_speed() -> void:
	# Planted for 0.5 s while it sweeps 0.5 m: authored for 1 m/s. The
	# walk is measured at CharacterVisual.walk_speed (1.6 m/s).
	var hero: HeroDefinition = _hero({&"walk": "Walk"}, {"Walk": _step_clip(0.25, -0.25)})
	hero.walk_reference_speed = 1.0
	var slide: Array[Dictionary] = _rows(ClipChecks.check_hero(hero, {}, {}), &"walk", "slide")
	check(slide.size() == 1 and float(slide[0].value) < 0.02,
		"played at 1.6x to match 1.6 m/s, its foot stays planted (got %.3f)" % float(slide[0].value))
	hero.walk_reference_speed = 0.0
	slide = _rows(ClipChecks.check_hero(hero, {}, {}), &"walk", "slide")
	check(float(slide[0].value) > 0.2, "played at 1x, it slides (got %.3f)" % float(slide[0].value))


func test_a_hand_made_cycles_reference_speed_is_its_recorded_stride_over_its_length() -> void:
	var hero: HeroDefinition = _hero({&"walk": "Walk", &"move": "Run", &"idle": "Idle"}, {})
	hero.model_scale = 0.5
	# 2 model metres a 0.5 s stride at half scale: 2 m/s in the game.
	var record: Dictionary = {"Walk": {"seconds": 0.5, "stride": 2.0}, "Run": {"seconds": 0.25, "stride": 2.0},
		"Idle": {"seconds": 1.0}}
	hero.walk_reference_speed = 2.0
	hero.reference_speed = 4.0
	check(ClipChecks.stride_problems(hero, record).is_empty(), "walk 2 m/s and run 4 m/s agree with the record")
	hero.reference_speed = 7.0
	var problems: Array[String] = ClipChecks.stride_problems(hero, record)
	check(problems.size() == 1 and problems[0].contains("4.00"), "a run reference of 7 m/s is reported against 4 m/s: %s"
		% str(problems))
	hero.clips[&"move"] = "Running_A"
	check(ClipChecks.stride_problems(hero, record).is_empty(), "a stock run (no record) is skipped")


func test_a_run_is_measured_at_both_roles_speeds_and_the_worse_counts() -> void:
	# Authored for 1 m/s (reference 1). The companion's 0.5 m/s is below
	# the run's slowest play speed (0.6x), so its foot slides.
	var hero: HeroDefinition = _hero({&"move": "Run"}, {"Run": _step_clip(0.25, -0.25)})
	hero.reference_speed = 1.0
	hero.move_speed = 1.0
	hero.companion_move_speed = 1.0
	var slide: Array[Dictionary] = _rows(ClipChecks.check_hero(hero, {}, {}), &"move", "slide")
	check(slide.size() == 1 and float(slide[0].value) < 0.02,
		"at 1 m/s in both roles it stays planted (got %.3f)" % float(slide[0].value))
	hero.companion_move_speed = 0.5
	slide = _rows(ClipChecks.check_hero(hero, {}, {}), &"move", "slide")
	# Down 0.5 s / 0.6 = 0.83 s at 0.5 m/s covers 0.42 m of the 0.5 m swept.
	check(slide.size() == 1 and absf(float(slide[0].value) - 0.083) < 0.02,
		"the companion's 0.5 m/s slides 8 cm a stride, and that row counts (got %.3f)" % float(slide[0].value))
