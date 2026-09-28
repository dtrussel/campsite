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
const _TRAY_ITEMS: Array[StringName] = [&"wood", &"stone", &"berries", &"fiber", &"leaves", &"resin", &"torch"]
const _ICON_DIR: String = "res://assets/icons/"

var _player: Node = null
var _companion: Node = null
var _base_core: Node = null

var _clock: HudWidgets.DayClock = null
var _phase_label: Label = null
var _goal_label: Label = null
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
var _sibling_task: Label = null

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
	BuildManager.build_mode_exited.connect(func() -> void: _build_label.visible = false)
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
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	plate.add_child(row)
	_clock = HudWidgets.DayClock.new()
	_clock.custom_minimum_size = Vector2(56, 56)
	row.add_child(_clock)
	var text_column: VBoxContainer = VBoxContainer.new()
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.add_theme_constant_override("separation", 0)
	row.add_child(text_column)
	_phase_label = UiKit.title("Day 1", 22)
	text_column.add_child(_phase_label)
	_goal_label = UiKit.label("", 15, UiKit.COLOR_MUTED)
	text_column.add_child(_goal_label)

	_campfire_bar = HudWidgets.StatBar.new(Color(0.88, 0.55, 0.12), Color(1.0, 0.82, 0.4))
	_campfire_bar.custom_minimum_size = Vector2(380, 20)
	_campfire_bar.tick_every = 25.0
	holder.add_child(_campfire_bar)

	_imps_label = UiKit.label("", 17, Color(0.85, 0.6, 1.0))
	_imps_label.add_theme_font_override("font", Fx.bold_font())
	_imps_label.add_theme_constant_override("outline_size", 6)
	_imps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_imps_label.visible = false
	holder.add_child(_imps_label)


func _build_sibling_frame(root: Control) -> void:
	var plate: PanelContainer = _plate(10)
	plate.position = Vector2(14, 12)
	root.add_child(plate)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	plate.add_child(row)
	_sibling_portrait = HudWidgets.Portrait.new(_icon("portrait_sibling"))
	_sibling_portrait.custom_minimum_size = Vector2(62, 62)
	row.add_child(_sibling_portrait)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 3)
	row.add_child(column)
	column.add_child(UiKit.title("Sibling", 16, UiKit.COLOR_GOLD))
	_sibling_hp = HudWidgets.StatBar.new(Color(0.2, 0.7, 0.4), Color(0.5, 0.95, 0.65))
	_sibling_hp.custom_minimum_size = Vector2(170, 14)
	column.add_child(_sibling_hp)
	_sibling_task = UiKit.label("Idle", 14, UiKit.COLOR_TEXT)
	column.add_child(_sibling_task)
	column.add_child(UiKit.label("F follow  G guard  T gather  Y idle", 12, UiKit.COLOR_MUTED))


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


func _build_hero_bar(root: Control) -> void:
	var plate: PanelContainer = _plate(10)
	plate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	plate.position = Vector2(-270, -128)
	plate.custom_minimum_size = Vector2(540, 0)
	root.add_child(plate)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	plate.add_child(row)
	_hero_portrait = HudWidgets.Portrait.new(_icon("portrait_boy"))
	_hero_portrait.custom_minimum_size = Vector2(96, 96)
	row.add_child(_hero_portrait)
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
		[&"eat", "berries", "R", "Eat 2 berries: +15 HP (R)"],
		[&"craft", "campfire", "C", "Crafting (C, near the campfire)"],
		[&"build", "fence", "B", "Build fences and watch posts (B)"],
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

	_build_label = UiKit.label("", 16, Color(0.6, 1.0, 0.6))
	_build_label.add_theme_font_override("font", Fx.bold_font())
	_build_label.add_theme_constant_override("outline_size", 6)
	_build_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_build_label.position = Vector2(-300, -176)
	_build_label.custom_minimum_size = Vector2(600, 0)
	_build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_label.visible = false
	root.add_child(_build_label)

	var hint: Label = UiKit.label("H  Help      Esc  Pause      Wheel  Zoom", 13, UiKit.COLOR_MUTED)
	hint.add_theme_constant_override("outline_size", 4)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-300, -26)
	hint.custom_minimum_size = Vector2(286, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hint)


func _build_banner(root: Control) -> void:
	_banner = UiKit.title("", 30, UiKit.COLOR_GOLD_LIGHT)
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
	var phase_name: String = TimeManager.get_phase_name()
	var remaining: int = int(ceil(TimeManager.remaining_seconds))
	_phase_label.text = "DAY %d  -  %s" % [TimeManager.day_number, phase_name.to_upper()]
	_phase_label.add_theme_color_override("font_color", _phase_color(TimeManager.current_phase))
	_goal_label.text = "Nights survived %d / %d      %d:%02d" % [
		int(GameManager.stats.get(&"nights_survived", 0)), GameManager.nights_to_win,
		remaining / 60, remaining % 60,
	]
	var total: float = _phase_duration(TimeManager.current_phase)
	_clock.set_phase_progress(TimeManager.current_phase, 1.0 - TimeManager.remaining_seconds / maxf(total, 0.01))
	var imps: int = get_tree().get_nodes_in_group("mobs").size()
	_imps_label.visible = imps > 0
	_imps_label.text = "%d SHADOW IMP%s" % [imps, "" if imps == 1 else "S"]
	_refresh_slots()


func _refresh_slots() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var cooldown: float = float(_player.get("_attack_cooldown_remaining")) / maxf(float(_player.attack_cooldown_seconds), 0.01)
	(_slots[&"attack"] as HudWidgets.AbilitySlot).set_state(true, "", clampf(cooldown, 0.0, 1.0))
	(_slots[&"gather"] as HudWidgets.AbilitySlot).set_state(true)
	var torches: int = ResourceManager.get_count(&"torch")
	(_slots[&"torch"] as HudWidgets.AbilitySlot).set_state(torches > 0, str(torches) if torches > 0 else "")
	var berries: int = ResourceManager.get_count(&"berries")
	(_slots[&"eat"] as HudWidgets.AbilitySlot).set_state(berries >= 2, str(berries) if berries > 0 else "")
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
	_sibling_task.text = "Knocked out - back at dawn" if knocked else String(_companion.get_task_name())
	_sibling_task.add_theme_color_override("font_color", Color(1, 0.55, 0.45) if knocked else UiKit.COLOR_TEXT)
	_sibling_portrait.dimmed = knocked
	_sibling_portrait.set_level(ProgressionManager.get_level(_companion))


func _refresh_campfire() -> void:
	if _base_core == null or not is_instance_valid(_base_core):
		return
	_campfire_bar.text_override = "CAMPFIRE  %d / %d" % [_base_core.current_hp, _base_core.max_hp]
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
	_build_label.visible = true
	_refresh_build_label(definition)


func _on_placement_validity_changed(is_valid: bool) -> void:
	_build_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if is_valid else Color(1.0, 0.55, 0.5))
	_refresh_build_label(BuildManager.get_active_definition())


func _refresh_build_label(definition: BuildingDefinition) -> void:
	if definition == null:
		return
	_build_label.text = "BUILDING %s  (%s)\n1 / 2 switch    R rotate    Left click place    Right click cancel" % [
		definition.display_name.to_upper(), definition.cost_summary()
	]


func _on_level_up(character: Node, new_level: int) -> void:
	_refresh_progress(character)
	if character == _companion:
		_refresh_sibling()
	elif character == _player:
		show_banner("Level %d!" % new_level, Color(1.0, 0.86, 0.45))


func _on_day_started(day_number: int) -> void:
	if day_number == 1:
		show_banner("Day 1 - gather, build and craft before dark", _PHASE_COLOR_DAY)
	else:
		show_banner("Day %d - repair and prepare" % day_number, _PHASE_COLOR_DAY)


func _on_sunset_warning(seconds: float) -> void:
	show_banner("The sun is setting - imps in %ds!" % int(seconds), _PHASE_COLOR_SUNSET)


func _on_night_started(day_number: int) -> void:
	var spawner: Node = get_tree().get_first_node_in_group("mob_spawner")
	var count: int = spawner.get_wave_size(day_number) if spawner != null else 0
	show_banner("Night %d - %d Shadow Imps rise!" % [day_number, count], _PHASE_COLOR_NIGHT)


func _on_dawn_started(day_number: int) -> void:
	show_banner("Dawn - you survived night %d" % day_number, _PHASE_COLOR_DAWN)


func _on_crafted(recipe: CraftingRecipe, _crafter: Node) -> void:
	if recipe.output_id == &"torch":
		show_banner("Torch crafted - press Q to plant it", Color(1, 0.75, 0.35))


func _on_companion_knocked_out(is_down: bool) -> void:
	if is_down:
		show_banner("Your sibling is knocked out until dawn!", Color(1, 0.6, 0.45))
	_refresh_sibling()
