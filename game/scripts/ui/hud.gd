extends CanvasLayer

## HUD
##
## In-game HUD in the campcraft style (feature 033), built in code
## from HudWidgets:
##   top centre    - one slim strip: nights-to-win moons, the day dial
##                   medallion, campfire HP; an imp tag hangs under the
##                   dial at night, and event banners show on a ribbon
##   top left      - the companion: portrait, HP, current task
##   top right     - resource tray with icons
##   bottom centre - the played hero: portrait + level, HP and XP bars, and the
##                   action bar (Space attack, E gather, Q torch, R eat,
##                   C craft, B build) with counts and cooldowns
##   left, under the companion - the dawn story card (feature 035), out
##                   of the way of the camp; left of the top strip, the
##                   Moon Lantern dial (feature 036)
##   under the top strip - the boss bar while the Moon-Eater stands
##                   (feature 038), with a thin bar for its lantern reach
##   right, under the tray - toasts (HudToast): short notes such as the
##                   companion's perk card, clear of the banner and the
##                   story card; the perk picker covers them
## Everything is signal-driven except the clock, cooldown and imp count,
## which tick in _process. Names and portraits come from the party
## (GameManager.party_hero / party_companion, feature 034).

const _BANNER_SECONDS: float = 3.5
const _PHASE_COLOR_DAY: Color = Color(1, 0.95, 0.8)
const _PHASE_COLOR_SUNSET: Color = Color(1, 0.6, 0.45)
const _PHASE_COLOR_NIGHT: Color = Color(0.75, 0.65, 1.0)
const _PHASE_COLOR_DAWN: Color = Color(1, 0.88, 0.65)

const _TOP_WIDTH: float = 330.0
const _DIAL_SIZE: float = 58.0
const _BANNER_Y: float = 104.0
## The banner's subtitle sits this far under the ribbon's top.
const _BANNER_SUB_GAP: float = 62.0
## The banner drops below the boss bar while it is up.
const _BANNER_Y_BOSS: float = 170.0
const _BOSS_COLOR: Color = Color(0.5, 0.36, 0.86)
## Toasts start this far down the right edge, under the resource tray.
const _TOAST_Y: float = 92.0
const _TOAST_MAX: int = 3

var _vignette: TextureRect = null
const _TRAY_ITEMS: Array[StringName] = [&"wood", &"stone", &"berries", &"clay", &"scrap", &"glow_shards", &"torch", &"snack"]
const _ICON_DIR: String = "res://assets/icons/"

var _player: Node = null
var _companion: Node = null
var _base_core: Node = null

var _clock: HudWidgets.DayClock = null
var _moons: Array = []  # HudWidgets.Glyph per night to survive
var _imps_row: Control = null  # canvas tag under the dial
var _campfire_bar: HudWidgets.StatBar = null
var _imps_label: Label = null
var _banner: Label = null
var _banner_plate: PanelContainer = null
var _banner_tween: Tween = null
## A line under the banner: what a creature is, the first time one shows
## up in a run (feature 046).
var _banner_sub: Label = null
var _banner_sub_plate: PanelContainer = null
## The banner's faded-in alpha; it is drawn at zero while the perk
## picker is open, so "NIGHT N!" never sits on the picker's heading.
var _banner_alpha: float = 0.0
var _pickers_open: int = 0
var _met_mobs: Dictionary = {}
var _build_label: Label = null

var _hero_portrait: HudWidgets.Portrait = null
var _hero_hp: HudWidgets.StatBar = null
var _hero_xp: HudWidgets.StatBar = null
var _slots: Dictionary = {}  # StringName -> AbilitySlot

var _sibling_portrait: HudWidgets.Portrait = null
var _sibling_hp: HudWidgets.StatBar = null
var _task_buttons: Array = []  # Button per companion task (index = task)
var _build_row: HBoxContainer = null

var _story_host: Control = null
var _boss_plate: PanelContainer = null
var _boss_bar: HudWidgets.StatBar = null
var _reach_bar: HudWidgets.StatBar = null
var _boss: BossController = null
var _story_card: StoryCard = null
var _story_queue: Array = []
var _perk_host: Control = null
var _toast_stack: VBoxContainer = null
var _lantern_dial: HudWidgets.LanternDial = null
var _tray_labels: Dictionary = {}  # StringName -> Label
var _tray_rows: Dictionary = {}    # StringName -> Control


func _ready() -> void:
	add_to_group("hud")
	var root: Control = Control.new()
	root.theme = UiKit.theme()
	UiKit.full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top(root)
	_build_sibling_frame(root)
	_build_tray(root)
	_build_hero_bar(root)
	_build_banner(root)
	_build_boss_bar(root)
	_build_story_host(root)
	_build_toast_stack(root)
	_build_perk_host(root)

	ResourceManager.resource_changed.connect(_on_resource_changed)
	ResourceManager.caps_changed.connect(_refresh_tray)
	BuildManager.build_mode_entered.connect(_on_build_mode_entered)
	BuildManager.build_mode_exited.connect(func() -> void: (_build_label.get_meta(&"plate") as Control).visible = false)
	BuildManager.placement_validity_changed.connect(_on_placement_validity_changed)
	# A perk can change what buildings cost (Builder's Knack).
	PerkManager.perk_taken.connect(func(_c: Node, _p: PerkDefinition) -> void:
		if BuildManager.is_in_build_mode():
			_refresh_build_label(BuildManager.get_active_definition()))
	GameManager.companion_task_changed.connect(func(_c: Node, _t: int) -> void: _refresh_sibling())
	ProgressionManager.xp_gained.connect(func(character: Node, _a: int, _s: StringName) -> void: _refresh_progress(character))
	ProgressionManager.level_up.connect(_on_level_up)
	TimeManager.sunset_warning.connect(_on_sunset_warning)
	var spawner: Node = get_tree().get_first_node_in_group("mob_spawner")
	if spawner != null and spawner.has_signal("mob_spawned"):
		spawner.mob_spawned.connect(_on_mob_spawned)
	TimeManager.night_started.connect(_on_night_started)
	TimeManager.dawn_started.connect(_on_dawn_started)
	TimeManager.day_started.connect(_on_day_started)
	CraftingManager.crafted.connect(_on_crafted)
	_hook_world.call_deferred()
	_refresh_tray()


# --- Layout ------------------------------------------------------------------

func _build_top(root: Control) -> void:
	# One slim strip: moons to win | day dial medallion | campfire health.
	# The dial overhangs the strip; the imp tag hangs under it at night.
	var top: Control = Control.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.custom_minimum_size = Vector2(_TOP_WIDTH, 96)
	_anchor(top, Control.PRESET_CENTER_TOP, Vector2(0, 6))
	root.add_child(top)

	var plate: PanelContainer = _plate(6, 14)
	plate.position = Vector2(0, 9)
	plate.custom_minimum_size = Vector2(_TOP_WIDTH, 44)
	plate.size = plate.custom_minimum_size
	top.add_child(plate)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	plate.add_child(row)

	# One moon per night to survive; they light up as nights are won.
	var moons: HBoxContainer = HBoxContainer.new()
	moons.alignment = BoxContainer.ALIGNMENT_CENTER
	moons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moons.add_theme_constant_override("separation", 3 if GameManager.nights_to_win <= 4 else 1)
	moons.tooltip_text = "Nights to survive"
	moons.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(moons)
	var moon_size: float = 24.0 if GameManager.nights_to_win <= 4 else 15.0
	for i in range(GameManager.nights_to_win):
		var moon: HudWidgets.Glyph = HudWidgets.Glyph.new("moon_empty", Color(1.0, 0.92, 0.6), moon_size)
		moon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		moons.add_child(moon)
		_moons.append(moon)

	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(_DIAL_SIZE + 8.0, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)

	var fire_row: HBoxContainer = HBoxContainer.new()
	fire_row.add_theme_constant_override("separation", 4)
	fire_row.alignment = BoxContainer.ALIGNMENT_CENTER
	fire_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fire_row.tooltip_text = "Campfire"
	fire_row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(fire_row)
	var fire: HudWidgets.Glyph = HudWidgets.Glyph.new("fire", UiKit.COLOR_EMBER, 22)
	fire.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fire_row.add_child(fire)
	_campfire_bar = HudWidgets.StatBar.new(Color(0.9, 0.42, 0.1), Color(1.0, 0.78, 0.36))
	_campfire_bar.custom_minimum_size = Vector2(96, 12)
	_campfire_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_campfire_bar.tick_every = 25.0
	_campfire_bar.show_text = false
	fire_row.add_child(_campfire_bar)

	_clock = HudWidgets.DayClock.new()
	_clock.custom_minimum_size = Vector2(_DIAL_SIZE, _DIAL_SIZE)
	_clock.size = _clock.custom_minimum_size
	_clock.position = Vector2((_TOP_WIDTH - _DIAL_SIZE) * 0.5, 0)
	top.add_child(_clock)

	# Imp tag: a small canvas label hanging under the dial.
	var hang: CenterContainer = CenterContainer.new()
	hang.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hang.position = Vector2(0, _DIAL_SIZE - 4.0)
	hang.size = Vector2(_TOP_WIDTH, 34)
	top.add_child(hang)
	var tag: PanelContainer = PanelContainer.new()
	var tag_style: StyleBox = UiKit.art_style("canvas", 2)
	tag_style.content_margin_left = 8
	tag_style.content_margin_right = 10
	tag.add_theme_stylebox_override("panel", tag_style)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hang.add_child(tag)
	_imps_row = tag
	_imps_row.visible = false
	var imps: HBoxContainer = HudWidgets.icon_count(_icon("portrait_imp"), "", "0", 26)
	imps.add_theme_constant_override("separation", 4)
	tag.add_child(imps)
	_imps_label = imps.get_child(1) as Label
	_imps_label.add_theme_color_override("font_color", Color(0.36, 0.18, 0.5))
	_imps_label.add_theme_constant_override("outline_size", 0)

	# The Moon Lantern dial sits just left of the strip.
	_lantern_dial = HudWidgets.LanternDial.new()
	_lantern_dial.size = Vector2(44, 44)
	_lantern_dial.position = Vector2(-52, 9)
	top.add_child(_lantern_dial)


func _build_sibling_frame(root: Control) -> void:
	var plate: PanelContainer = _plate(8, 10)
	_anchor(plate, Control.PRESET_TOP_LEFT, Vector2(10, 8))
	root.add_child(plate)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	plate.add_child(row)
	var companion: HeroDefinition = GameManager.party_companion()
	_sibling_portrait = HudWidgets.Portrait.new(companion.portrait)
	_sibling_portrait.custom_minimum_size = Vector2(52, 52)
	row.add_child(_name_tag(_sibling_portrait, companion.display_name, 14))
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 7)
	row.add_child(column)
	_sibling_hp = HudWidgets.StatBar.new(Color(0.33, 0.62, 0.24), Color(0.62, 0.86, 0.42))
	_sibling_hp.custom_minimum_size = Vector2(0, 10)
	_sibling_hp.show_text = false
	column.add_child(_sibling_hp)
	# Task picker: idle, follow, guard, gather, repair (Companion.Task order).
	var tasks: HBoxContainer = HBoxContainer.new()
	tasks.add_theme_constant_override("separation", 4)
	column.add_child(tasks)
	var specs: Array = [["zzz", "Y"], ["footsteps", "F"], ["shield", "G"], ["basket", "T"], ["hammer", "V"]]
	for i in range(specs.size()):
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(36, 36)
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.tooltip_text = specs[i][1]
		_style_task_button(button)
		var glyph: HudWidgets.Glyph = HudWidgets.Glyph.new(specs[i][0], Color(0.98, 0.92, 0.76), 24)
		glyph.position = Vector2(6, 7)
		glyph.size = Vector2(24, 24)
		button.add_child(glyph)
		var key: Label = UiKit.label(specs[i][1], 10, UiKit.COLOR_INK)
		key.add_theme_font_override("font", Fx.bold_font())
		var tab: StyleBoxFlat = UiKit.flat_style(UiKit.COLOR_CANVAS, UiKit.COLOR_INK, 1, 3)
		tab.content_margin_left = 3
		tab.content_margin_right = 3
		key.add_theme_stylebox_override("normal", tab)
		key.position = Vector2(-3, -5)
		button.add_child(key)
		button.pressed.connect(_on_task_button.bind(i))
		tasks.add_child(button)
		_task_buttons.append(button)


## Task buttons: brass-framed slots; the active task glows ember.
func _style_task_button(button: Button) -> void:
	var normal: StyleBox = UiKit.art_style("slot", 0)
	var hover: StyleBox = UiKit.art_style("slot", 0)
	hover.modulate_color = Color(1.25, 1.12, 0.95)
	var active: StyleBoxFlat = UiKit.flat_style(Color(0.5, 0.3, 0.12, 0.95), UiKit.COLOR_EMBER, 2, 7)
	active.shadow_color = Color(1.0, 0.6, 0.15, 0.5)
	active.shadow_size = 4
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", active)
	button.add_theme_stylebox_override("hover_pressed", active)


func _build_tray(root: Control) -> void:
	var plate: PanelContainer = _plate(8, 12)
	_anchor(plate, Control.PRESET_TOP_RIGHT, Vector2(-10, 8))
	root.add_child(plate)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 0)
	plate.add_child(grid)
	for id in _TRAY_ITEMS:
		var definition: ResourceDefinition = ResourceManager.get_definition(id)
		if definition == null:
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		row.tooltip_text = "%s - %s" % [definition.display_name, UiKit.party_text(definition.description)]
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var icon: TextureRect = TextureRect.new()
		icon.texture = definition.icon
		icon.custom_minimum_size = Vector2(26, 26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var count: Label = UiKit.label("0", 16)
		count.add_theme_font_override("font", Fx.bold_font())
		count.add_theme_constant_override("outline_size", 4)
		count.custom_minimum_size = Vector2(30, 0)
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(count)
		grid.add_child(row)
		_tray_labels[id] = count
		_tray_rows[id] = row


## Portrait with the character's name underneath (the only word kids need).
func _name_tag(portrait: Control, character_name: String, font_size: int) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", -5)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(portrait)
	var label: Label = Label.new()
	label.text = character_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Fx.bold_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiKit.COLOR_GOLD_LIGHT)
	label.add_theme_color_override("font_outline_color", UiKit.COLOR_INK)
	label.add_theme_constant_override("outline_size", 5)
	column.add_child(label)
	return column


func _build_hero_bar(root: Control) -> void:
	var plate: PanelContainer = _plate(8, 12)
	_anchor(plate, Control.PRESET_CENTER_BOTTOM, Vector2(0, -6))
	root.add_child(plate)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	plate.add_child(row)
	var hero: HeroDefinition = GameManager.party_hero()
	var companion: HeroDefinition = GameManager.party_companion()
	_hero_portrait = HudWidgets.Portrait.new(hero.portrait)
	_hero_portrait.custom_minimum_size = Vector2(74, 74)
	row.add_child(_name_tag(_hero_portrait, hero.display_name, 15))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)

	var slots: HBoxContainer = HBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	column.add_child(slots)
	var definitions: Array = [
		[&"attack", "slingshot" if hero.ranged else "axe", "SP",
			"Shoot (Space, or click an imp)" if hero.ranged else "Attack (Space, or click an imp)"],
		[&"gather", "wood", "E", "Gather the nearest resource (E, or right-click it)"],
		[&"torch", "torch", "Q", "Plant a torch (Q). Craft torches at the campfire."],
		[&"eat", "berries", "R", "Eat (R): a Berry Snack gives +35 HP, else 2 berries give +15 HP"],
		[&"bandage", "bandage", "X", "Put a bandage on %s (X, close by): +25 HP, or wakes them up" % companion.display_name],
		[&"craft", "campfire", "C", "Crafting (C, near the campfire or a Crafting Table)"],
		[&"build", "fence", "B", "Build (B), then 1-7: fence, wall, watch post, snap trap, glow lantern, crate, crafting table"],
	]
	for entry in definitions:
		var slot: HudWidgets.AbilitySlot = HudWidgets.AbilitySlot.new(_icon(entry[1]), entry[2])
		slot.tooltip_text = entry[3]
		slots.add_child(slot)
		_slots[entry[0]] = slot

	_hero_hp = HudWidgets.StatBar.new()
	_hero_hp.custom_minimum_size = Vector2(0, 17)
	column.add_child(_hero_hp)
	_hero_xp = HudWidgets.StatBar.new(Color(0.55, 0.42, 0.86), Color(0.78, 0.68, 1.0))
	_hero_xp.custom_minimum_size = Vector2(0, 7)
	_hero_xp.tick_every = 0.0
	_hero_xp.show_text = false
	_hero_xp.tooltip_text = "Experience"
	column.add_child(_hero_xp)

	# Build hint: what you are placing and what it costs, as icons.
	var build_plate: PanelContainer = _plate(6, 10)
	_anchor(build_plate, Control.PRESET_CENTER_BOTTOM, Vector2(0, -132))
	build_plate.visible = false
	root.add_child(build_plate)
	_build_row = HBoxContainer.new()
	_build_row.add_theme_constant_override("separation", 8)
	build_plate.add_child(_build_row)
	_build_label = Label.new()  # kept for the validity colour hook
	build_plate.set_meta(&"is_build_plate", true)
	_build_label.set_meta(&"plate", build_plate)

	# Help and pause as small icon buttons (bottom right).
	var corner: HBoxContainer = HBoxContainer.new()
	corner.add_theme_constant_override("separation", 6)
	_anchor(corner, Control.PRESET_BOTTOM_RIGHT, Vector2(-10, -10))
	root.add_child(corner)
	corner.add_child(HudWidgets.icon_button("help", "", _on_help_pressed, UiKit.COLOR_GOLD_LIGHT, null, false, 44))
	corner.add_child(HudWidgets.icon_button("pause", "", _on_pause_pressed, UiKit.COLOR_GOLD_LIGHT, null, false, 44))


## Event banner: a canvas ribbon under the top strip, clear of the fire.
func _build_banner(root: Control) -> void:
	_banner_plate = PanelContainer.new()
	var ribbon: StyleBox = UiKit.art_style("ribbon", 0)
	if ribbon is StyleBoxTexture:
		var texture_style: StyleBoxTexture = ribbon as StyleBoxTexture
		texture_style.texture_margin_left = 46
		texture_style.texture_margin_right = 46
		texture_style.texture_margin_top = 0
		texture_style.texture_margin_bottom = 0
	ribbon.content_margin_left = 58
	ribbon.content_margin_right = 58
	ribbon.content_margin_top = 11
	ribbon.content_margin_bottom = 9
	_banner_plate.add_theme_stylebox_override("panel", ribbon)
	_banner_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_plate.custom_minimum_size = Vector2(260, 60)
	_anchor(_banner_plate, Control.PRESET_CENTER_TOP, Vector2(0, _BANNER_Y))
	_banner_plate.modulate.a = 0.0
	root.add_child(_banner_plate)
	_banner = UiKit.title("", 30, UiKit.COLOR_GOLD_LIGHT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 9)
	_banner_plate.add_child(_banner)
	_banner_sub_plate = _plate(6, 16)
	_anchor(_banner_sub_plate, Control.PRESET_CENTER_TOP, Vector2(0, _BANNER_Y + _BANNER_SUB_GAP))
	_banner_sub_plate.modulate.a = 0.0
	_banner_sub_plate.visible = false
	root.add_child(_banner_sub_plate)
	_banner_sub = UiKit.label("", 19, UiKit.COLOR_TEXT)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_constant_override("outline_size", 6)
	_banner_sub.add_theme_color_override("font_outline_color", UiKit.COLOR_INK)
	_banner_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_sub_plate.add_child(_banner_sub)


## The Moon-Eater's health under the top strip (feature 038), and a thin
## moon-coloured bar for how long the kids have while it holds the
## lantern. Hidden until a boss rises.
func _build_boss_bar(root: Control) -> void:
	_boss_plate = _plate(6, 16)
	_anchor(_boss_plate, Control.PRESET_CENTER_TOP, Vector2(0, 100))
	root.add_child(_boss_plate)
	var column: VBoxContainer = UiKit.vbox(3)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_boss_plate.add_child(column)
	var name_label: Label = UiKit.title("THE MOON-EATER", 22, UiKit.COLOR_MOON.lightened(0.35))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_constant_override("outline_size", 7)
	column.add_child(name_label)
	_boss_bar = HudWidgets.StatBar.new(_BOSS_COLOR, Color(0.75, 0.62, 1.0))
	_boss_bar.custom_minimum_size = Vector2(420, 16)
	_boss_bar.show_text = false
	column.add_child(_boss_bar)
	_reach_bar = HudWidgets.StatBar.new(UiKit.COLOR_MOON, UiKit.COLOR_MOON.lightened(0.4))
	_reach_bar.custom_minimum_size = Vector2(420, 8)
	_reach_bar.show_text = false
	_reach_bar.tick_every = 0.0
	_reach_bar.tooltip_text = "Time before it swallows the lantern's light"
	column.add_child(_reach_bar)
	_boss_plate.visible = false
	_reach_bar.visible = false


func _show_boss(boss: BossController) -> void:
	_boss = boss
	_boss_plate.visible = true
	_boss_bar.set_values(boss.current_hp, boss.max_hp())
	_set_banner_y(_BANNER_Y_BOSS)
	boss.health_changed.connect(func(hp: int, max_hp: int) -> void: _boss_bar.set_values(hp, max_hp))
	boss.phase_changed.connect(_on_boss_phase.bind(boss))
	boss.calmed.connect(func(_b: Node3D) -> void:
		_boss_plate.visible = false
		_set_banner_y(_BANNER_Y)
		show_banner("It let the moon go!", UiKit.COLOR_MOON.lightened(0.4)))


func boss_bar_visible() -> bool:
	return _boss_plate.visible


func _on_boss_phase(phase: int, boss: BossController) -> void:
	_reach_bar.visible = boss.is_draining()
	if boss.is_draining():
		show_banner("It wants the lantern!", UiKit.COLOR_MOON.lightened(0.4))
	elif phase == BossController.Phase.SUMMONING:
		_pulse_vignette(Color(0.45, 0.2, 0.7, 0.6))


func _set_banner_y(y: float) -> void:
	_banner_plate.offset_top = y
	_banner_plate.offset_bottom = y
	_banner_sub_plate.offset_top = y + _BANNER_SUB_GAP
	_banner_sub_plate.offset_bottom = y + _BANNER_SUB_GAP


## The story card's place: down the left edge, under the companion and
## clear of the banner, so it never covers the kids or the fire.
func _build_story_host(root: Control) -> void:
	_story_host = Control.new()
	_story_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(_story_host, Control.PRESET_TOP_LEFT, Vector2(12, 176))
	root.add_child(_story_host)
	GameManager.run_ended.connect(func(_won: bool, _reason: String) -> void:
		_story_queue.clear()
		_met_mobs.clear()
		if story_card() != null:
			story_card().dismiss())


## Shows a story card (dawn talk, first shard). A card that is still
## talking is never cut short (feature 046): the new one waits for it
## and null is returned.
func show_story(beat: StoryBeat, hint: String = "") -> StoryCard:
	if beat == null:
		return null
	var open: StoryCard = story_card()
	if open != null and not open.is_closing():
		_story_queue.append([beat, hint])
		return null
	if open != null:
		open.queue_free()
	_story_card = StoryCard.make(beat, GameManager.hero_id, hint)
	_story_card.dismissed.connect(_show_queued_story, CONNECT_DEFERRED)
	_story_host.add_child(_story_card)
	PlaytestLog.write("story_card id=%s" % beat.id)
	return _story_card


## Toasts stack down the right edge under the resource tray: away from
## the banner (top centre), the story card (left) and the hero bar.
func _build_toast_stack(root: Control) -> void:
	_toast_stack = UiKit.vbox(6)
	_toast_stack.name = "ToastStack"
	_toast_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	_anchor(_toast_stack, Control.PRESET_TOP_RIGHT, Vector2(-10, _TOAST_Y))
	root.add_child(_toast_stack)


## Shows a toast under the tray; the newest goes at the bottom. With
## more than _TOAST_MAX up, the oldest fades early.
func show_toast(text: String, icon: String = "", color: Color = UiKit.COLOR_GOLD_LIGHT, seconds: float = HudToast.SECONDS) -> HudToast:
	var toast: HudToast = HudToast.make(text, icon, color, seconds)
	_toast_stack.add_child(toast)
	var open: Array[HudToast] = toasts()
	if open.size() > _TOAST_MAX:
		open[0].dismiss()
	PlaytestLog.write("toast text=%s" % text)
	return toast


## The toasts up now, oldest first (not the ones fading out).
func toasts() -> Array[HudToast]:
	var out: Array[HudToast] = []
	for child in _toast_stack.get_children():
		if child is HudToast and not (child as HudToast).is_closing():
			out.append(child as HudToast)
	return out


## The perk picker's place: over the whole screen, above the story card.
func _build_perk_host(root: Control) -> void:
	_perk_host = Control.new()
	_perk_host.name = "PerkHost"
	_perk_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_perk_host)
	root.add_child(_perk_host)


## Opens the level-up card picker (perk cards). PerkManager calls this
## and takes the card the picker closes with.
func show_perk_picker(cards: Array[PerkDefinition], auto_pick_seconds: float) -> PerkPicker:
	var picker: PerkPicker = PerkPicker.make(cards, auto_pick_seconds)
	_pickers_open += 1
	picker.closed.connect(_on_perk_picker_closed, CONNECT_ONE_SHOT)
	_perk_host.add_child(picker)
	_set_banner_alpha(_banner_alpha)
	return picker


func _on_perk_picker_closed(_perk: PerkDefinition) -> void:
	_pickers_open = maxi(0, _pickers_open - 1)
	if _banner_plate != null and is_instance_valid(_banner_plate):
		_set_banner_alpha(_banner_alpha)


## True while the centre banner is hidden under an open perk picker.
func is_banner_hidden() -> bool:
	return _pickers_open > 0


func _show_queued_story() -> void:
	if not _story_queue.is_empty() and GameManager.is_playing():
		var next: Array = _story_queue.pop_front()
		show_story(next[0] as StoryBeat, String(next[1]))


func story_card() -> StoryCard:
	return _story_card if _story_card != null and is_instance_valid(_story_card) else null


func _lantern_hint() -> String:
	var lantern: MoonLantern = MoonLantern.find(get_tree())
	return lantern.hint_text() if lantern != null else ""


func _plate(padding_y: int, padding_x: int = -1) -> PanelContainer:
	var plate: PanelContainer = PanelContainer.new()
	var style: StyleBox = UiKit.panel_style(UiKit.COLOR_WOOD, UiKit.COLOR_BRASS_DARK, padding_y)
	style.content_margin_left = padding_x if padding_x >= 0 else padding_y
	style.content_margin_right = style.content_margin_left
	plate.add_theme_stylebox_override("panel", style)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return plate


## Pins `control` to a screen corner or edge centre by `offset`, growing
## away from the edge so it sizes itself to its content.
func _anchor(control: Control, preset: Control.LayoutPreset, offset: Vector2) -> void:
	control.set_anchors_preset(preset)
	var right: bool = preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT]
	var bottom: bool = preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM]
	var centre: bool = preset in [Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM]
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH if centre else (Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END)
	control.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
	control.offset_left = offset.x
	control.offset_right = offset.x
	control.offset_top = offset.y
	control.offset_bottom = offset.y


func _icon(name: String) -> Texture2D:
	var path: String = _ICON_DIR + name + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


# --- Wiring ----------------------------------------------------------------

func _hook_world() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_companion = get_tree().get_first_node_in_group("companions")
	_base_core = get_tree().get_first_node_in_group("base_core")
	if _player != null:
		_player.health_changed.connect(func(hp: int, max_hp: int) -> void: _hero_hp.set_values(hp, max_hp))
		_hero_hp.set_values(_player.current_hp, _player.max_hp)
		_refresh_progress(_player)
	if _companion != null:
		_companion.health_changed.connect(func(hp: int, max_hp: int) -> void: _sibling_hp.set_values(hp, max_hp))
		_companion.knocked_out_changed.connect(_on_companion_knocked_out)
		_sibling_hp.set_values(_companion.current_hp, _companion.max_hp)
		_refresh_sibling()
	var lantern: MoonLantern = MoonLantern.find(get_tree())
	if lantern != null:
		lantern.stage_changed.connect(_on_lantern_stage)
	if _base_core != null:
		_base_core.damaged.connect(func(_hp: int) -> void: _refresh_campfire())
		_base_core.repaired.connect(func(_hp: int) -> void: _refresh_campfire())
		_refresh_campfire()


func _process(_delta: float) -> void:
	var survived: int = int(GameManager.stats.get(&"nights_survived", 0))
	for i in range(_moons.size()):
		var moon: HudWidgets.Glyph = _moons[i]
		var kind: String = "moon" if i < survived else "moon_empty"
		if moon.kind != kind:
			moon.set_kind(kind)
	var total: float = _phase_duration(TimeManager.current_phase)
	_clock.set_phase_progress(TimeManager.current_phase, 1.0 - TimeManager.remaining_seconds / maxf(total, 0.01))
	var imps: int = get_tree().get_nodes_in_group("mobs").size()
	_imps_row.visible = imps > 0
	_imps_label.text = "x %d" % imps
	_refresh_slots()
	var lantern: MoonLantern = MoonLantern.find(get_tree())
	_lantern_dial.visible = lantern != null
	if lantern != null:
		_lantern_dial.set_stage(lantern.stage, lantern.max_stage())
	if _reach_bar.visible and _boss != null and is_instance_valid(_boss):
		_reach_bar.set_values(_boss.reach_left_ratio(), 1.0)


func _refresh_slots() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var cooldown: float = float(_player.get("_attack_cooldown_remaining")) / maxf(float(_player.attack_cooldown_seconds), 0.01)
	(_slots[&"attack"] as HudWidgets.AbilitySlot).set_state(true, "", clampf(cooldown, 0.0, 1.0))
	(_slots[&"gather"] as HudWidgets.AbilitySlot).set_state(true)
	var torches: int = ResourceManager.get_count(&"torch")
	(_slots[&"torch"] as HudWidgets.AbilitySlot).set_state(torches > 0, str(torches) if torches > 0 else "")
	var eat_slot: HudWidgets.AbilitySlot = _slots[&"eat"] as HudWidgets.AbilitySlot
	var snacks: int = ResourceManager.get_count(&"snack")
	var eat_icon: Texture2D = _icon("snack" if snacks > 0 else "berries")
	if eat_slot.icon != eat_icon:
		eat_slot.icon = eat_icon
		eat_slot.queue_redraw()
	if snacks > 0:
		eat_slot.set_state(true, str(snacks))
	else:
		var berries: int = ResourceManager.get_count(&"berries")
		eat_slot.set_state(berries >= 2, str(berries) if berries > 0 else "")
	var bandages: int = ResourceManager.get_count(&"bandage")
	(_slots[&"bandage"] as HudWidgets.AbilitySlot).set_state(bandages > 0, str(bandages) if bandages > 0 else "")
	var craft_ready: bool = false
	for recipe in CraftingManager.get_recipes():
		craft_ready = craft_ready or CraftingManager.can_craft(recipe)
	(_slots[&"craft"] as HudWidgets.AbilitySlot).set_state(craft_ready)
	var can_build: bool = false
	for definition in BuildManager.get_known_definitions():
		can_build = can_build or ResourceManager.can_afford(BuildManager.cost_of(definition))
	(_slots[&"build"] as HudWidgets.AbilitySlot).set_state(can_build)
	(_slots[&"build"] as HudWidgets.AbilitySlot).highlight = BuildManager.is_in_build_mode()


func _refresh_tray() -> void:
	for id in _tray_labels.keys():
		var count: int = ResourceManager.get_count(id)
		var cap: int = ResourceManager.get_cap(id)
		var label: Label = _tray_labels[id] as Label
		label.text = str(count)
		# A full stash glows gold: time to build a Storage Crate.
		var full: bool = cap > 0 and count >= cap
		label.add_theme_color_override("font_color", UiKit.COLOR_EMBER if full else UiKit.COLOR_TEXT)
		var row: Control = _tray_rows[id] as Control
		row.modulate = Color(1, 1, 1, 1.0 if count > 0 else 0.38)
		var definition: ResourceDefinition = ResourceManager.get_definition(id)
		if definition != null:
			var amount: String = "%d/%d" % [count, cap] if cap > 0 else str(count)
			row.tooltip_text = "%s %s - %s" % [definition.display_name, amount, UiKit.party_text(definition.description)]


func _refresh_progress(character: Node) -> void:
	if character == null or character != _player:
		return
	var level: int = ProgressionManager.get_level(character)
	var xp: int = ProgressionManager.get_xp(character)
	var to_next: int = ProgressionManager.get_xp_to_next_level(character)
	var stats: CharacterStatsDefinition = ProgressionManager.get_stats(character)
	var floor_xp: int = stats.xp_threshold_for_level(level) if stats != null else 0
	var span: int = maxi(1, xp + to_next - floor_xp)
	_hero_xp.set_values(xp - floor_xp, span)
	_hero_portrait.set_level(level)


func _refresh_sibling() -> void:
	if _companion == null or not is_instance_valid(_companion):
		return
	var knocked: bool = _companion.get("is_knocked_out") == true
	var task: int = int(_companion.get("current_task"))
	for i in range(_task_buttons.size()):
		(_task_buttons[i] as Button).set_pressed_no_signal(i == task)
		(_task_buttons[i] as Button).modulate = Color(0.5, 0.5, 0.55) if knocked else Color.WHITE
	_sibling_portrait.dimmed = knocked
	_sibling_portrait.set_level(ProgressionManager.get_level(_companion))


func _refresh_campfire() -> void:
	if _base_core == null or not is_instance_valid(_base_core):
		return
	_campfire_bar.set_values(_base_core.current_hp, _base_core.max_hp)


func _phase_color(phase: int) -> Color:
	match phase:
		TimeManager.Phase.SUNSET: return _PHASE_COLOR_SUNSET
		TimeManager.Phase.NIGHT: return _PHASE_COLOR_NIGHT
		TimeManager.Phase.DAWN: return _PHASE_COLOR_DAWN
	return _PHASE_COLOR_DAY


func _phase_duration(phase: int) -> float:
	match phase:
		TimeManager.Phase.SUNSET: return TimeManager.sunset_seconds
		TimeManager.Phase.NIGHT: return TimeManager.night_seconds
		TimeManager.Phase.DAWN: return TimeManager.dawn_seconds
	return TimeManager.day_seconds


# --- Events --------------------------------------------------------------------

func show_banner(text: String, color: Color = UiKit.COLOR_GOLD_LIGHT, subtitle: String = "") -> void:
	_banner.text = text.to_upper()
	_banner.add_theme_color_override("font_color", color)
	_banner_sub.text = subtitle
	_banner_sub_plate.visible = subtitle != ""
	_banner_sub_plate.reset_size()
	if _banner_tween != null:
		_banner_tween.kill()
	_set_banner_alpha(0.0)
	_banner_tween = create_tween()
	_banner_tween.tween_method(_set_banner_alpha, 0.0, 1.0, 0.25)
	# A subtitle needs a moment longer to read.
	_banner_tween.tween_interval(_BANNER_SECONDS + (2.0 if subtitle != "" else 0.0))
	_banner_tween.tween_method(_set_banner_alpha, 1.0, 0.0, 0.6)


func banner_subtitle() -> String:
	return _banner_sub.text


func _set_banner_alpha(alpha: float) -> void:
	_banner_alpha = alpha
	var shown: float = 0.0 if _pickers_open > 0 else alpha
	_banner_plate.modulate.a = shown
	_banner_sub_plate.modulate.a = shown


func _on_resource_changed(id: StringName, _value: int, delta: int) -> void:
	_refresh_tray()
	# The first Glow Shard of a run: what the shards are (story layer 1).
	if id == &"glow_shards" and delta > 0 and int(GameManager.stats.get(&"shards", 0)) == 0 and GameManager.is_playing():
		show_story(StoryLibrary.first(&"shard", GameManager.chapter()), _lantern_hint())


func _on_build_mode_entered(definition: BuildingDefinition) -> void:
	(_build_label.get_meta(&"plate") as Control).visible = true
	_refresh_build_label(definition)


func _on_placement_validity_changed(is_valid: bool) -> void:
	var plate: Control = _build_label.get_meta(&"plate")
	plate.modulate = Color.WHITE if is_valid else Color(1.0, 0.6, 0.55)
	_refresh_build_label(BuildManager.get_active_definition())


## Build hint as pictures: [building] = [cost icons x n]  [1][2] [R].
func _refresh_build_label(definition: BuildingDefinition) -> void:
	if definition == null:
		return
	for child in _build_row.get_children():
		child.queue_free()
	# Number chips for every building; the active one is lit.
	var known: Array[BuildingDefinition] = BuildManager.get_known_definitions()
	for i in range(known.size()):
		var chip: Control = HudWidgets.AbilitySlot.new(known[i].icon, str(i + 1))
		chip.custom_minimum_size = Vector2(40, 40)
		(chip as HudWidgets.AbilitySlot).set_state(ResourceManager.can_afford(BuildManager.cost_of(known[i])))
		(chip as HudWidgets.AbilitySlot).highlight = known[i] == definition
		chip.tooltip_text = "%s (%d): %s" % [known[i].display_name, i + 1, UiKit.party_text(known[i].description)]
		_build_row.add_child(chip)
	var picture: TextureRect = TextureRect.new()
	picture.texture = definition.icon
	picture.custom_minimum_size = Vector2(56, 56)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_build_row.add_child(picture)
	var cost: Dictionary = BuildManager.cost_of(definition)
	for key in cost.keys():
		var item: ResourceDefinition = ResourceManager.get_definition(StringName(key))
		_build_row.add_child(HudWidgets.icon_count(item.icon if item != null else null, "star", "%d" % int(cost[key]), 34))
	_build_row.add_child(HudWidgets.Glyph.new("mouse_left", Color(0.4, 1.0, 0.5), 30))
	_build_row.add_child(HudWidgets.Glyph.new("mouse_right", Color(1.0, 0.4, 0.35), 30))


func _on_level_up(character: Node, new_level: int) -> void:
	_refresh_progress(character)
	if character == _companion:
		_refresh_sibling()
	elif character == _player and not ProgressionManager.is_restoring:
		show_banner("Level up!", Color(1.0, 0.86, 0.45))


func _on_day_started(day_number: int) -> void:
	show_banner("Day %d" % day_number, _PHASE_COLOR_DAY)


func _on_sunset_warning(seconds: float) -> void:
	show_banner("Back to the fire!", _PHASE_COLOR_SUNSET)
	_pulse_vignette(Color(1.0, 0.42, 0.18))


## Warm glow creeping in from the screen edges, twice, with the owl call.
func _pulse_vignette(color: Color) -> void:
	if _vignette == null:
		var gradient: Gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.9)])
		var texture: GradientTexture2D = GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.05, 1.05)
		_vignette = TextureRect.new()
		_vignette.texture = texture
		_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_vignette.stretch_mode = TextureRect.STRETCH_SCALE
		_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_vignette)
		move_child(_vignette, 0)
	_vignette.modulate = Color(color, 0.0)
	var tween: Tween = create_tween()
	for i in 2:
		tween.tween_property(_vignette, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
		tween.tween_property(_vignette, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)


## A heavy mob gets its own warning: kids should run to their fences.
## The first of a kind in a run also says what it is.
func _on_mob_spawned(mob: Node3D, definition: MobDefinition) -> void:
	if definition == null:
		return
	var about: String = ""
	if not _met_mobs.has(definition.id):
		_met_mobs[definition.id] = true
		about = definition.description
	if definition.is_boss and mob is BossController:
		_show_boss(mob as BossController)
		show_banner("%s rises!" % definition.display_name, UiKit.COLOR_MOON.lightened(0.4), about)
	elif definition.prefers_buildings:
		show_banner("%s!" % definition.display_name, Color(0.6, 0.9, 0.35), about)
	elif definition.steals_resources:
		show_banner("%s!" % definition.display_name, Color(0.85, 0.55, 1.0), about)
		mob.stole.connect(func(_m: Node3D, item: StringName, amount: int) -> void:
			show_banner("Thief! -%d %s" % [amount, _item_name(item)], Color(1.0, 0.55, 0.5)))
		mob.escaped.connect(func(_m: Node3D, item: StringName, amount: int) -> void:
			show_banner("It got away with %d %s!" % [amount, _item_name(item)], Color(1.0, 0.55, 0.5)))
	elif about != "":
		# Imps come right after the "Night" banner: let that one read first.
		var name_text: String = "%s!" % definition.display_name
		get_tree().create_timer(2.5, false).timeout.connect(func() -> void:
			if GameManager.is_playing():
				show_banner(name_text, UiKit.COLOR_MOON.lightened(0.4), about))


func _item_name(id: StringName) -> String:
	var definition: ResourceDefinition = ResourceManager.get_definition(id)
	return definition.display_name if definition != null else String(id)


func _on_lantern_stage(stage: int, max_stage: int) -> void:
	if stage >= max_stage:
		show_banner("The Moon Lantern shines!", UiKit.COLOR_MOON.lightened(0.4))
	elif stage > 0:
		show_banner("The lantern glows brighter!", UiKit.COLOR_MOON.lightened(0.4))
	AudioManager.play_sfx(&"level_up")


func _on_night_started(day_number: int) -> void:
	show_banner("Night %d!" % day_number, _PHASE_COLOR_NIGHT)


func _on_dawn_started(day_number: int) -> void:
	show_banner("Good morning!", _PHASE_COLOR_DAWN)
	# The winning dawn ends the run; its story is the ending book.
	if GameManager.is_playing():
		show_story(StoryLibrary.first(&"dawn", GameManager.chapter(), day_number), _lantern_hint())


func _on_crafted(recipe: CraftingRecipe, _crafter: Node) -> void:
	if recipe.output_id == &"torch":
		show_banner("Torch!  Q", Color(1, 0.75, 0.35))


func _on_companion_knocked_out(is_down: bool) -> void:
	if is_down:
		show_banner("Ouch!", Color(1, 0.6, 0.45))
	_refresh_sibling()


func _on_task_button(task: int) -> void:
	GameManager.assign_companion_task(task)
	_refresh_sibling()


func _on_help_pressed() -> void:
	var overlay: Node = get_tree().get_first_node_in_group("controls_overlay")
	if overlay != null and not get_tree().paused:
		overlay.open()


func _on_pause_pressed() -> void:
	var menu: Node = get_tree().get_first_node_in_group("pause_menu")
	if menu != null:
		menu.open_menu()
