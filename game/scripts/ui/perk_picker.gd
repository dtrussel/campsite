class_name PerkPicker
extends Control

## PerkPicker
##
## The level-up card picker: up to
## three wood plate cards, each with its key cap, icon, name and one
## line. Pick by clicking a card or pressing 1/2/3. It never pauses the
## game: while it is open the game runs at SLOW_FACTOR speed, and after
## `auto_pick_seconds` of real time it takes the first card itself, so
## it never hides a fight for long. PerkManager opens it through the HUD:
##
##   hud.show_perk_picker(cards, PerkManager.auto_pick_seconds)

## The card taken, or null when it closed without a pick (run ended).
signal closed(perk: PerkDefinition)

const SLOW_FACTOR: float = 0.1
const CARD_SIZE: Vector2 = Vector2(230, 280)
const FADE_SECONDS: float = 0.25

var _cards: Array[PerkDefinition] = []
var _auto_pick_seconds: float = 10.0
var _opened_at: float = 0.0
var _saved_scale: float = 1.0
var _slow_scale: float = -1.0
var _closing: bool = false
var _card_buttons: Array[Button] = []
var _countdown: Label = null


static func make(cards: Array[PerkDefinition], auto_pick_seconds: float) -> PerkPicker:
	var picker: PerkPicker = PerkPicker.new()
	picker.name = "PerkPicker"
	picker._cards = cards
	picker._auto_pick_seconds = auto_pick_seconds
	picker._build()
	return picker


func cards() -> Array[PerkDefinition]:
	return _cards


## The card buttons, left to right (tests press them).
func card_buttons() -> Array[Button]:
	return _card_buttons


func is_closing() -> bool:
	return _closing


## Takes card `index` (0-based) and closes.
func pick(index: int) -> void:
	if _closing or index < 0 or index >= _cards.size():
		return
	_close(_cards[index])


## Closes without taking a card.
func dismiss() -> void:
	_close(null)


func _build() -> void:
	theme = UiKit.theme()
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Lighter than a menu's dim: the night goes on behind the cards.
	var dim: ColorRect = UiKit.dim_background()
	dim.color = Color(UiKit.COLOR_DIM, 0.4)
	add_child(dim)
	var center: CenterContainer = UiKit.centered()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column: VBoxContainer = UiKit.vbox(14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)

	# The heading sits on the banner's canvas ribbon, so the night's own
	# words (the "LEVEL UP!" over the hero, a bark) never read through it.
	var ribbon_plate: PanelContainer = PanelContainer.new()
	ribbon_plate.add_theme_stylebox_override("panel", _ribbon_style())
	ribbon_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(ribbon_plate)
	var heading: Label = UiKit.title("Level up! Pick a card", 32, UiKit.COLOR_GOLD_LIGHT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_constant_override("outline_size", 9)
	ribbon_plate.add_child(heading)

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	for i in range(_cards.size()):
		var card: Button = _make_card(_cards[i], i)
		row.add_child(card)
		_card_buttons.append(card)

	_countdown = UiKit.label("", 16, UiKit.COLOR_MOON.lightened(0.3))
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.add_theme_constant_override("outline_size", 5)
	_countdown.add_theme_color_override("font_outline_color", UiKit.COLOR_INK)
	column.add_child(_countdown)


## The HUD banner's ribbon (hud.gd `_build_banner`), sized for the heading.
func _ribbon_style() -> StyleBox:
	var ribbon: StyleBox = UiKit.art_style("ribbon", 0)
	if ribbon is StyleBoxTexture:
		var texture_style: StyleBoxTexture = ribbon as StyleBoxTexture
		texture_style.texture_margin_left = 46
		texture_style.texture_margin_right = 46
		texture_style.texture_margin_top = 0
		texture_style.texture_margin_bottom = 0
	ribbon.content_margin_left = 64
	ribbon.content_margin_right = 64
	ribbon.content_margin_top = 12
	ribbon.content_margin_bottom = 10
	return ribbon


## One card: a wood plate button holding its key cap, icon, name and line.
func _make_card(perk: PerkDefinition, index: int) -> Button:
	var card: Button = UiKit.button("", pick.bind(index), false)
	card.name = "Card%d" % (index + 1)
	card.custom_minimum_size = CARD_SIZE
	card.tooltip_text = UiKit.party_text(perk.description)
	card.add_theme_stylebox_override("normal", UiKit.panel_style(UiKit.COLOR_WOOD, UiKit.COLOR_BRASS_DARK, 14))
	var hover: StyleBox = UiKit.panel_style(UiKit.COLOR_WOOD, UiKit.COLOR_BRASS_DARK, 14)
	if hover is StyleBoxTexture:
		(hover as StyleBoxTexture).modulate_color = Color(1.25, 1.15, 1.0)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("hover_pressed", hover)
	card.add_theme_stylebox_override("pressed", UiKit.art_style("slot", 14))

	var margin: MarginContainer = MarginContainer.new()
	UiKit.full_rect(margin)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	card.add_child(margin)
	var column: VBoxContainer = UiKit.vbox(8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var cap: Control = UiKit.key_cap(str(index + 1), 32)
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(cap)
	var picture: TextureRect = TextureRect.new()
	picture.texture = perk.icon_texture()
	picture.custom_minimum_size = Vector2(84, 84)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(picture)
	var title: Label = UiKit.title(perk.display_name, 20, UiKit.COLOR_GOLD_LIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var line: Label = UiKit.label(UiKit.party_text(perk.description), 16, UiKit.COLOR_TEXT)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(line)
	return card


func _ready() -> void:
	# Slow the game (not pause it), from under any running hit-stop.
	_saved_scale = Fx.unstopped_time_scale()
	_slow_scale = _saved_scale * SLOW_FACTOR
	Engine.time_scale = _slow_scale
	_opened_at = _now()
	AudioManager.play_sfx(&"ui_click")
	if not GameManager.run_ended.is_connected(_on_run_ended):
		GameManager.run_ended.connect(_on_run_ended)
	# Real time: the slow-down must not stretch the wait.
	get_tree().create_timer(_auto_pick_seconds, true, false, true).timeout.connect(_on_auto_pick)
	# Fades in, in real time.
	modulate.a = 0.0
	var tween: Tween = _real_time_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	_refresh_countdown()


func _process(_delta: float) -> void:
	_refresh_countdown()


func _refresh_countdown() -> void:
	if _countdown == null:
		return
	var left: int = ceili(maxf(0.0, _auto_pick_seconds - (_now() - _opened_at)))
	_countdown.text = "Press 1, 2 or 3 - the first card is taken in %d s" % left


## Keys 1/2/3 pick a card. Read here (before build mode's
## select_building_1..3) and marked handled, so they do only this.
func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if _closing or key == null or not key.pressed or key.echo:
		return
	var index: int = -1
	match key.physical_keycode:
		KEY_1, KEY_KP_1: index = 0
		KEY_2, KEY_KP_2: index = 1
		KEY_3, KEY_KP_3: index = 2
	if index >= 0 and index < _cards.size():
		get_viewport().set_input_as_handled()
		pick(index)


func _on_auto_pick() -> void:
	if _closing or not is_inside_tree():
		return
	if get_tree().paused:
		# The pause menu is up: wait for the player to come back.
		get_tree().create_timer(1.0, true, false, true).timeout.connect(_on_auto_pick)
		return
	PlaytestLog.write("perk_picker auto_pick")
	pick(0)


func _on_run_ended(_won: bool, _reason: String) -> void:
	dismiss()


func _close(perk: PerkDefinition) -> void:
	if _closing:
		return
	_closing = true
	_restore_time_scale()
	closed.emit(perk)
	if not is_inside_tree():
		queue_free()
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween: Tween = _real_time_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(queue_free)


## Back to the speed it was opened at, unless something else (a new
## run, a test) has set the speed since. A hit-stop that started while
## the picker was open is seen through.
func _restore_time_scale() -> void:
	if _slow_scale > 0.0 and is_equal_approx(Fx.unstopped_time_scale(), _slow_scale):
		Engine.time_scale = _saved_scale
	_slow_scale = -1.0


func _exit_tree() -> void:
	# Freed with the HUD while still open: never leave the game slowed.
	if not _closing:
		_closing = true
		_restore_time_scale()
		closed.emit(null)


## A tween that runs in real time at the current time scale (Godot 4.3
## tweens have no ignore-time-scale switch).
func _real_time_tween() -> Tween:
	return create_tween().set_speed_scale(1.0 / maxf(Engine.time_scale, 0.001))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
