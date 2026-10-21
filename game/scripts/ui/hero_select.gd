extends Control

## HeroSelect
##
## "Choose your hero" (feature 034), between the title screen's run
## length buttons and the loading screen. The roster's heroes stand by
## the fire (HeroStage); one wood card per hero shows their portrait,
## name, a line about them, health / power / reach pips and their
## signature craft. The hero not picked comes along as the companion,
## shown under the cards - the place for a companion picker once there
## are more heroes. Start begins the run; Back returns to the title.
##
## Keys: Left / Right (or A / D) pick, Enter starts, Esc goes back.
##
## The outfit row (journal badges 05) under the goal shows the badge
## cosmetics (Cosmetics): the picked hero's outfit tints and the tent
## colours. A locked one is shown dimmed, says which badge unlocks it
## and can't be picked; a pick is kept in the profile straight away.

const STAGE: Script = preload("res://scripts/ui/hero_stage.gd")
const CARD_SIZE: Vector2 = Vector2(320, 200)
const SELECT_COLOR: Color = Color(1.0, 0.66, 0.28)

var selected: int = 0

var _stage: Node3D = null
var _cards: Array[Button] = []
var _glows: Array[Panel] = []
var _companion_portrait: TextureRect = null
var _companion_name: Label = null
var _start: Button = null


func _ready() -> void:
	UiKit.full_rect(self)
	theme = UiKit.theme()
	_stage = STAGE.new()
	add_child(_stage)
	AudioManager.set_mood(&"day")

	var shade: TextureRect = TextureRect.new()
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.07, 0.035, 0.02, 0.0))
	gradient.set_color(1, Color(0.07, 0.035, 0.02, 0.8))
	gradient.add_point(0.55, Color(0.07, 0.035, 0.02, 0.0))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	UiKit.full_rect(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_build_header()
	_build_outfit_row()
	_build_cards()
	_build_footer()

	var heroes: Array[HeroDefinition] = HeroRoster.all()
	var start_index: int = 0
	var last: StringName = GameManager.last_hero_pick()
	for i in heroes.size():
		if heroes[i].id == last:
			start_index = i
	select(start_index, false)
	_start.grab_focus()


func _build_header() -> void:
	var ribbon_plate: PanelContainer = PanelContainer.new()
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
	ribbon_plate.add_theme_stylebox_override("panel", ribbon)
	ribbon_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_top(ribbon_plate, 22)
	add_child(ribbon_plate)
	var heading: Label = UiKit.title("Choose your hero", 34, UiKit.COLOR_GOLD_LIGHT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_constant_override("outline_size", 9)
	ribbon_plate.add_child(heading)

	var goal_text: String = "Endless: how long can you last by the campfire?" if GameManager.endless \
		else "Survive %d nights by the campfire" % GameManager.nights_to_win
	var goal: Label = UiKit.label(goal_text, 18, UiKit.COLOR_GOLD_LIGHT)
	goal.add_theme_font_override("font", Fx.bold_font())
	goal.add_theme_constant_override("outline_size", 6)
	goal.add_theme_color_override("font_outline_color", UiKit.COLOR_INK)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_top(goal, 92)
	add_child(goal)


func _build_cards() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_top = -86
	row.offset_bottom = -86
	add_child(row)
	var heroes: Array[HeroDefinition] = HeroRoster.all()
	for i in heroes.size():
		row.add_child(_card(heroes[i], i))


func _card(hero: HeroDefinition, index: int) -> Button:
	var card: Button = Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.tooltip_text = "Play as %s" % hero.display_name
	for state in ["normal", "hover", "pressed", "disabled"]:
		card.add_theme_stylebox_override(state, UiKit.panel_style(UiKit.COLOR_WOOD, UiKit.COLOR_BRASS_DARK, 14))
	card.pressed.connect(func() -> void:
		AudioManager.play_sfx(&"ui_click")
		select(index))
	_cards.append(card)

	var glow: Panel = Panel.new()
	var glow_style: StyleBoxFlat = UiKit.flat_style(Color(0, 0, 0, 0), SELECT_COLOR, 3, 10)
	glow_style.draw_center = false
	glow_style.shadow_color = Color(SELECT_COLOR, 0.45)
	glow_style.shadow_size = 10
	glow.add_theme_stylebox_override("panel", glow_style)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(glow)
	glow.offset_left = -4
	glow.offset_top = -4
	glow.offset_right = 4
	glow.offset_bottom = 4
	card.add_child(glow)
	_glows.append(glow)

	var margin: MarginContainer = MarginContainer.new()
	UiKit.full_rect(margin)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	card.add_child(margin)
	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	var portrait: HudWidgets.Portrait = HudWidgets.Portrait.new(hero.portrait)
	portrait.custom_minimum_size = Vector2(84, 84)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.ring_color = hero.ui_color.lerp(UiKit.COLOR_BRASS, 0.5)
	portrait.show_level = false
	content.add_child(portrait)

	var column: VBoxContainer = UiKit.vbox(2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(column)
	var name_label: Label = UiKit.title(hero.display_name, 28, UiKit.COLOR_GOLD_LIGHT)
	column.add_child(name_label)
	var tagline: Label = UiKit.label(hero.tagline, 14, UiKit.COLOR_TEXT)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.custom_minimum_size = Vector2(170, 0)
	column.add_child(tagline)
	column.add_child(_pips("heart", "Health", hero.rating_health, Color(0.95, 0.42, 0.36)))
	column.add_child(_pips("star", "Power", hero.rating_power, UiKit.COLOR_EMBER))
	column.add_child(_pips("arrow", "Reach", hero.rating_reach, UiKit.COLOR_MOON))

	var signature: HBoxContainer = HBoxContainer.new()
	signature.add_theme_constant_override("separation", 6)
	signature.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var first: ToolTier = hero.tier(1)
	var icon_path: String = "res://assets/icons/%s.png" % (first.icon if first != null else "")
	if ResourceLoader.exists(icon_path):
		var icon: TextureRect = TextureRect.new()
		icon.texture = load(icon_path) as Texture2D
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		signature.add_child(icon)
	var craft: Label = UiKit.label("Craft: %s" % (first.label if first != null else "-"), 14, UiKit.COLOR_GOLD_LIGHT)
	craft.add_theme_font_override("font", Fx.bold_font())
	signature.add_child(craft)
	signature.tooltip_text = "Signature craft at the Crafting Table"
	column.add_child(signature)
	return card


## One rating row: a word and 1-3 filled pips out of 3.
func _pips(kind: String, word: String, filled: int, color: Color) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = UiKit.label(word, 13, UiKit.COLOR_MUTED)
	label.custom_minimum_size = Vector2(54, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	for i in 3:
		var glyph: HudWidgets.Glyph = HudWidgets.Glyph.new(kind, color, 16)
		if i >= filled:
			glyph.modulate = Color(1, 1, 1, 0.22)
		row.add_child(glyph)
	return row


func _build_footer() -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 22)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_top = -18
	bar.offset_bottom = -18
	add_child(bar)
	var back: Button = HudWidgets.icon_button("home", "Back", _on_back, UiKit.COLOR_GOLD_LIGHT, null, true, 50)
	back.custom_minimum_size = Vector2(190, 50)
	back.add_theme_font_size_override("font_size", 20)
	back.tooltip_text = "Back to the title (Esc)"
	bar.add_child(back)

	var tag: PanelContainer = PanelContainer.new()
	var canvas: StyleBox = UiKit.art_style("canvas", 6)
	canvas.content_margin_left = 14
	canvas.content_margin_right = 16
	tag.add_theme_stylebox_override("panel", canvas)
	tag.tooltip_text = "Comes along as your AI helper. Give them jobs with F / G / T / Y / V."
	bar.add_child(tag)
	var tag_row: HBoxContainer = HBoxContainer.new()
	tag_row.add_theme_constant_override("separation", 8)
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(tag_row)
	var word: Label = UiKit.label("Companion", 14, Color(0.4, 0.27, 0.16))
	word.add_theme_font_override("font", Fx.bold_font())
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_row.add_child(word)
	_companion_portrait = TextureRect.new()
	_companion_portrait.custom_minimum_size = Vector2(30, 30)
	_companion_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_companion_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tag_row.add_child(_companion_portrait)
	_companion_name = UiKit.label("", 18, UiKit.COLOR_INK)
	_companion_name.add_theme_font_override("font", Fx.title_font(700))
	_companion_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_row.add_child(_companion_name)

	_start = HudWidgets.icon_button("play", "Start", _on_start, Color(0.55, 0.9, 0.4), null, true, 50)
	_start.custom_minimum_size = Vector2(190, 50)
	_start.add_theme_font_size_override("font_size", 20)
	_start.tooltip_text = "Start the run (Enter)"
	bar.add_child(_start)


## Picks hero `index` of the roster; `cheer` lets them cheer on stage.
func select(index: int, cheer: bool = true) -> void:
	var heroes: Array[HeroDefinition] = HeroRoster.all()
	selected = wrapi(index, 0, heroes.size())
	for i in _cards.size():
		var on: bool = i == selected
		_glows[i].visible = on
		_cards[i].modulate = Color.WHITE if on else Color(0.72, 0.68, 0.64)
	var companion: HeroDefinition = HeroRoster.get_hero(HeroRoster.default_companion(heroes[selected].id))
	_companion_portrait.texture = companion.portrait
	_companion_name.text = companion.display_name
	_stage.call("select", selected, cheer)
	_refresh_outfit_row()


# --- Outfit row (journal badges 05) ----------------------------------------

var _outfit_buttons: Dictionary = {}  # outfit id -> Button
var _tent_buttons: Dictionary = {}  # tent id -> Button


## The swatch for outfit `id` (tests).
func outfit_button(id: StringName) -> Button:
	return _outfit_buttons.get(id)


## The swatch for tent colour `id` (tests).
func tent_button(id: StringName) -> Button:
	return _tent_buttons.get(id)


func _build_outfit_row() -> void:
	var plate: PanelContainer = PanelContainer.new()
	var canvas: StyleBox = UiKit.art_style("canvas", 6)
	canvas.content_margin_left = 16
	canvas.content_margin_right = 16
	plate.add_theme_stylebox_override("panel", canvas)
	_center_top(plate, 128)
	add_child(plate)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	plate.add_child(row)
	_outfit_buttons = _swatches(row, "Outfit", Cosmetics.OUTFITS, func(id: StringName) -> void:
		if Cosmetics.choose_outfit(selected_hero().id, id):
			_stage.call("set_outfit_tint", selected, Cosmetics.outfit_tint(selected_hero().id))
		_refresh_outfit_row())
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(18, 0)
	row.add_child(gap)
	_tent_buttons = _swatches(row, "Tent", Cosmetics.TENTS, func(id: StringName) -> void:
		Cosmetics.choose_tent(id)
		_refresh_outfit_row())


func _swatches(row: HBoxContainer, word: String, entries: Array[Dictionary], pick: Callable) -> Dictionary:
	var label: Label = UiKit.label(word, 14, Color(0.4, 0.27, 0.16))
	label.add_theme_font_override("font", Fx.bold_font())
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var buttons: Dictionary = {}
	for entry in entries:
		var id: StringName = entry["id"]
		var swatch: Button = Button.new()
		swatch.custom_minimum_size = Vector2(28, 28)
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			pick.call(id))
		row.add_child(swatch)
		buttons[id] = swatch
	return buttons


## Marks the picked swatches and locks the ones whose badge isn't earned.
func _refresh_outfit_row() -> void:
	if _outfit_buttons.is_empty():
		return
	var hero: StringName = selected_hero().id
	for entry in Cosmetics.OUTFITS:
		_style_swatch(_outfit_buttons[entry["id"]], entry, entry["id"] == Cosmetics.outfit_id(hero))
	for entry in Cosmetics.TENTS:
		_style_swatch(_tent_buttons[entry["id"]], entry, entry["id"] == Cosmetics.tent_id())


func _style_swatch(swatch: Button, entry: Dictionary, picked: bool) -> void:
	var unlocked: bool = Cosmetics.is_unlocked(entry)
	# The tint over a mid cloth tone, so white reads as the painted look.
	var color: Color = Color(0.86, 0.72, 0.52) * (entry["color"] as Color)
	var border: Color = SELECT_COLOR if picked else UiKit.COLOR_BRASS_DARK
	for state in ["normal", "hover", "pressed", "disabled"]:
		swatch.add_theme_stylebox_override(state, UiKit.flat_style(color, border, 3 if picked else 2, 14))
	swatch.disabled = not unlocked
	swatch.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.35)
	swatch.tooltip_text = entry["name"] if unlocked else "%s - %s" % [entry["name"], Cosmetics.unlock_hint(entry)]


func selected_hero() -> HeroDefinition:
	return HeroRoster.all()[selected]


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var step: int = 0
	if event.is_action("ui_left") or event.is_action("move_left"):
		step = -1
	elif event.is_action("ui_right") or event.is_action("move_right"):
		step = 1
	elif event.is_action("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
		return
	if step != 0:
		get_viewport().set_input_as_handled()
		AudioManager.play_sfx(&"ui_click")
		select(selected + step)


func _on_start() -> void:
	var hero: HeroDefinition = selected_hero()
	GameManager.begin_chapter(hero.id, HeroRoster.default_companion(hero.id))


func _on_back() -> void:
	GameManager.go_to_title()


func _center_top(control: Control, y: float) -> void:
	control.set_anchors_preset(Control.PRESET_CENTER_TOP)
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	control.offset_left = 0
	control.offset_right = 0
	control.offset_top = y
	control.offset_bottom = y
