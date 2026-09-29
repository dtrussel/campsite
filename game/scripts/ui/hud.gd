extends CanvasLayer

## HUD
##
## LoL-inspired in-game HUD, built in code from HudWidgets:
##   top centre    - day clock, phase + timer, nights survived, campfire HP,
##                   imp counter at night, event banners
##   top left      - sibling portrait, HP, current task
##   top right     - resource tray with icons
##   bottom centre - the boy: portrait + level, HP and XP bars, and the
##                   action bar (Space attack, E gather, Q torch, R eat,
##                   C craft, B build) with counts and cooldowns
## Everything is signal-driven except the clock, cooldown and imp count,
## which tick in _process.

const _BANNER_SECONDS: float = 3.5
const _PHASE_COLOR_DAY: Color = Color(1, 0.95, 0.8)
const _PHASE_COLOR_SUNSET: Color = Color(1, 0.6, 0.45)
const _PHASE_COLOR_NIGHT: Color = Color(0.75, 0.65, 1.0)
const _PHASE_COLOR_DAWN: Color = Color(1, 0.88, 0.65)

var _vignette: TextureRect = null
const _TRAY_ITEMS: Array[StringName] = [&"wood", &"stone", &"berries", &"fiber", &"leaves", &"resin", &"clay",
	&"mushrooms", &"scrap", &"glow_shards", &"torch", &"snack"]
const _ICON_DIR: String = "res://assets/icons/"

var _player: Node = null
var _companion: Node = null
var _base_core: Node = null

var _clock: HudWidgets.DayClock = null
var _moons: Array = []  # HudWidgets.Glyph per night to survive
var _imps_row: Control = null
var _campfire_bar: HudWidgets.StatBar = null
var _imps_label: Label = null
var _banner: Label = null
var _banner_tween: Tween = null
var _build_label: Label = null

var _hero_portrait: HudWidgets.Portrait = null
var _hero_hp: HudWidgets.StatBar = null
var _hero_xp: HudWidgets.StatBar = null
var _slots: Dictionary = {}  # StringName -> AbilitySlot

var _sibling_portrait: HudWidgets.Portrait = null
var _sibling_hp: HudWidgets.StatBar = null
var _task_buttons: Array = []  # Button per companion task (index = task)
var _build_row: HBoxContainer = null

var _tray_labels: Dictionary = {}  # StringName -> Label
var _tray_rows: Dictionary = {}    # StringName -> Control


func _ready() -> void:
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

	ResourceManager.resource_changed.connect(_on_resource_changed)
	BuildManager.build_mode_entered.connect(_on_build_mode_entered)
	BuildManager.build_mode_exited.connect(func() -> void: (_build_label.get_meta(&"plate") as Control).visible = false)
	BuildManager.placement_validity_changed.connect(_on_placement_validity_changed)
	GameManager.companion_task_changed.connect(func(_c: Node, _t: int) -> void: _refresh_sibling())
	ProgressionManager.xp_gained.connect(func(character: Node, _a: int, _s: StringName) -> void: _refresh_progress(character))
	ProgressionManager.level_up.connect(_on_level_up)
	TimeManager.sunset_warning.connect(_on_sunset_warning)
	TimeManager.night_started.connect(_on_night_started)
	TimeManager.dawn_started.connect(_on_dawn_started)
	TimeManager.day_started.connect(_on_day_started)
	CraftingManager.crafted.connect(_on_crafted)
	_hook_world.call_deferred()
	_refresh_tray()


# --- Layout ------------------------------------------------------------------

func _build_top(root: Control) -> void:
	var holder: VBoxContainer = VBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_TOP)
	holder.position = Vector2(-190, 10)
	holder.custom_minimum_size = Vector2(380, 0)
	holder.alignment = BoxContainer.ALIGNMENT_BEGIN
	holder.add_theme_constant_override("separation", 6)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)

	var plate: PanelContainer = _plate(12)
	holder.add_child(plate)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	plate.add_child(stack)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	stack.add_child(row)
	_clock = HudWidgets.DayClock.new()
	_clock.custom_minimum_size = Vector2(56, 56)
	row.add_child(_clock)
	# One moon per night to survive; they light up as nights are won.
	for i in range(GameManager.nights_to_win):
		var moon: HudWidgets.Glyph = HudWidgets.Glyph.new("moon_empty", Color(1.0, 0.92, 0.55), 46)
		row.add_child(moon)
		_moons.append(moon)

	var fire_row: HBoxContainer = HBoxContainer.new()
	fire_row.add_theme_constant_override("separation", 6)
	fire_row.alignment = BoxContainer.ALIGNMENT_CENTER
	fire_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(fire_row)
	fire_row.add_child(HudWidgets.Glyph.new("fire", Color(1.0, 0.55, 0.15), 30))
	_campfire_bar = HudWidgets.StatBar.new(Color(0.88, 0.55, 0.12), Color(1.0, 0.82, 0.4))
	_campfire_bar.custom_minimum_size = Vector2(300, 22)
	_campfire_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_campfire_bar.tick_every = 25.0
	_campfire_bar.show_text = false
	fire_row.add_child(_campfire_bar)

	_imps_row = HudWidgets.icon_count(_icon("portrait_imp"), "", "0", 44)
	_imps_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_imps_row.visible = false
	_imps_label = _imps_row.get_child(1) as Label
	_imps_label.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	stack.add_child(_imps_row)


func _build_sibling_frame(root: Control) -> void:
	var plate: PanelContainer = _plate(10)
	plate.position = Vector2(14, 12)
	root.add_child(plate)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	plate.add_child(row)
	_sibling_portrait = HudWidgets.Portrait.new(_icon("portrait_nela"))
	_sibling_portrait.custom_minimum_size = Vector2(62, 62)
	row.add_child(_name_tag(_sibling_portrait, "Nela", 16))
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	row.add_child(column)
	_sibling_hp = HudWidgets.StatBar.new(Color(0.2, 0.7, 0.4), Color(0.5, 0.95, 0.65))
	_sibling_hp.custom_minimum_size = Vector2(200, 14)
	_sibling_hp.show_text = false
	column.add_child(_sibling_hp)
	# Task picker: idle, follow, guard, gather, repair (Companion.Task order).
	var tasks: HBoxContainer = HBoxContainer.new()
	tasks.add_theme_constant_override("separation", 4)
	column.add_child(tasks)
	var specs: Array = [["zzz", "Y"], ["footsteps", "F"], ["shield", "G"], ["basket", "T"], ["hammer", "V"]]
	for i in range(specs.size()):
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(46, 46)
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.tooltip_text = specs[i][1]
		var glyph: HudWidgets.Glyph = HudWidgets.Glyph.new(specs[i][0], Color(0.95, 0.9, 0.75), 34)
		glyph.position = Vector2(6, 6)
		glyph.size = Vector2(34, 34)
		button.add_child(glyph)
		var key: Label = UiKit.label(specs[i][1], 11, UiKit.COLOR_GOLD)
		key.position = Vector2(3, 0)
		button.add_child(key)
		button.pressed.connect(_on_task_button.bind(i))
		tasks.add_child(button)
		_task_buttons.append(button)


func _build_tray(root: Control) -> void:
	var plate: PanelContainer = _plate(10)
	plate.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	plate.position = Vector2(-236, 12)
	plate.custom_minimum_size = Vector2(222, 0)
	root.add_child(plate)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	plate.add_child(grid)
	for id in _TRAY_ITEMS:
		var definition: ResourceDefinition = ResourceManager.get_definition(id)
		if definition == null:
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.tooltip_text = "%s - %s" % [definition.display_name, definition.description]
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var icon: TextureRect = TextureRect.new()
		icon.texture = definition.icon
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var count: Label = UiKit.label("0", 18)
		count.add_theme_font_override("font", Fx.bold_font())
		count.custom_minimum_size = Vector2(56, 0)
		row.add_child(count)
		grid.add_child(row)
		_tray_labels[id] = count
		_tray_rows[id] = row


## Portrait with the character's name underneath (the only word kids need).
func _name_tag(portrait: Control, character_name: String, font_size: int) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(portrait)
	var label: Label = Label.new()
	label.text = character_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Fx.bold_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5)
	column.add_child(label)
	return column


func _build_hero_bar(root: Control) -> void:
	var plate: PanelContainer = _plate(10)
	plate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	plate.position = Vector2(-270, -128)
	plate.custom_minimum_size = Vector2(540, 0)
	root.add_child(plate)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	plate.add_child(row)
	_hero_portrait = HudWidgets.Portrait.new(_icon("portrait_leo"))
	_hero_portrait.custom_minimum_size = Vector2(96, 96)
	row.add_child(_name_tag(_hero_portrait, "Leo", 18))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)

	var slots: HBoxContainer = HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	column.add_child(slots)
	var definitions: Array = [
		[&"attack", "axe", "SP", "Attack (Space, or click an imp)"],
		[&"gather", "wood", "E", "Gather the nearest resource (E, or right-click it)"],
		[&"torch", "torch", "Q", "Plant a torch (Q). Craft torches at the campfire."],
		[&"eat", "berries", "R", "Eat (R): a Berry Snack gives +35 HP, else 2 berries give +15 HP"],
		[&"craft", "campfire", "C", "Crafting (C, near the campfire)"],
		[&"build", "fence", "B", "Build (B), then 1-4: fence, watch post, snap trap, glow lantern"],
	]
	for entry in definitions:
		var slot: HudWidgets.AbilitySlot = HudWidgets.AbilitySlot.new(_icon(entry[1]), entry[2])
		slot.tooltip_text = entry[3]
		slots.add_child(slot)
		_slots[entry[0]] = slot

	_hero_hp = HudWidgets.StatBar.new()
	_hero_hp.custom_minimum_size = Vector2(390, 22)
	column.add_child(_hero_hp)
	_hero_xp = HudWidgets.StatBar.new(Color(0.45, 0.35, 0.85), Color(0.7, 0.6, 1.0))
	_hero_xp.custom_minimum_size = Vector2(390, 10)
	_hero_xp.tick_every = 0.0
	_hero_xp.show_text = false
	column.add_child(_hero_xp)

	# Build hint: what you are placing and what it costs, as icons.
	var build_plate: PanelContainer = _plate(8)
	build_plate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	build_plate.position = Vector2(-150, -196)
	build_plate.visible = false
	root.add_child(build_plate)
	_build_row = HBoxContainer.new()
	_build_row.add_theme_constant_override("separation", 10)
	build_plate.add_child(_build_row)
	_build_label = Label.new()  # kept for the validity colour hook
	build_plate.set_meta(&"is_build_plate", true)
	_build_label.set_meta(&"plate", build_plate)

	# Help and pause as icon buttons (bottom right).
	var corner: HBoxContainer = HBoxContainer.new()
	corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.position = Vector2(-150, -74)
	corner.add_theme_constant_override("separation", 8)
	root.add_child(corner)
	corner.add_child(HudWidgets.icon_button("help", "", _on_help_pressed, UiKit.COLOR_GOLD, null, false))
	corner.add_child(HudWidgets.icon_button("pause", "", _on_pause_pressed, UiKit.COLOR_GOLD, null, false))


func _build_banner(root: Control) -> void:
	_banner = UiKit.title("", 44, UiKit.COLOR_GOLD_LIGHT)
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 150
	_banner.offset_left = 120
	_banner.offset_right = -120
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.modulate.a = 0.0
	root.add_child(_banner)


func _plate(padding: int) -> PanelContainer:
	var plate: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = UiKit.panel_style(Color(0.02, 0.05, 0.08, 0.82))
	style.set_content_margin_all(padding)
	style.shadow_size = 6
	plate.add_theme_stylebox_override("panel", style)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return plate


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
	var craft_ready: bool = false
	for recipe in CraftingManager.get_recipes():
		craft_ready = craft_ready or CraftingManager.can_craft(recipe)
	(_slots[&"craft"] as HudWidgets.AbilitySlot).set_state(craft_ready)
	var can_build: bool = false
	for definition in BuildManager.get_known_definitions():
		can_build = can_build or ResourceManager.can_afford(definition.cost)
	(_slots[&"build"] as HudWidgets.AbilitySlot).set_state(can_build)
	(_slots[&"build"] as HudWidgets.AbilitySlot).highlight = BuildManager.is_in_build_mode()


func _refresh_tray() -> void:
	for id in _tray_labels.keys():
		var count: int = ResourceManager.get_count(id)
		(_tray_labels[id] as Label).text = str(count)
		(_tray_rows[id] as Control).modulate = Color(1, 1, 1, 1.0 if count > 0 else 0.38)


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

func show_banner(text: String, color: Color = UiKit.COLOR_GOLD_LIGHT) -> void:
	_banner.text = text.to_upper()
	_banner.add_theme_color_override("font_color", color)
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner.scale = Vector2.ONE
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(_BANNER_SECONDS)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _on_resource_changed(_id: StringName, _value: int, _delta: int) -> void:
	_refresh_tray()


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
		(chip as HudWidgets.AbilitySlot).set_state(ResourceManager.can_afford(known[i].cost))
		(chip as HudWidgets.AbilitySlot).highlight = known[i] == definition
		chip.tooltip_text = "%s (%d): %s" % [known[i].display_name, i + 1, known[i].description]
		_build_row.add_child(chip)
	var picture: TextureRect = TextureRect.new()
	picture.texture = definition.icon
	picture.custom_minimum_size = Vector2(56, 56)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_build_row.add_child(picture)
	for key in definition.cost.keys():
		var item: ResourceDefinition = ResourceManager.get_definition(StringName(key))
		_build_row.add_child(HudWidgets.icon_count(item.icon if item != null else null, "star", "%d" % int(definition.cost[key]), 34))
	_build_row.add_child(HudWidgets.Glyph.new("mouse_left", Color(0.4, 1.0, 0.5), 30))
	_build_row.add_child(HudWidgets.Glyph.new("mouse_right", Color(1.0, 0.4, 0.35), 30))


func _on_level_up(character: Node, new_level: int) -> void:
	_refresh_progress(character)
	if character == _companion:
		_refresh_sibling()
	elif character == _player:
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


func _on_night_started(day_number: int) -> void:
	show_banner("Night %d!" % day_number, _PHASE_COLOR_NIGHT)


func _on_dawn_started(day_number: int) -> void:
	show_banner("Good morning!", _PHASE_COLOR_DAWN)


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
