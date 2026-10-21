class_name OutfitRow
extends PanelContainer

## OutfitRow
##
## Hero select's badge cosmetics row (Cosmetics): the shown hero's
## outfit tints and the tent colours, as swatches on a canvas plate. A
## locked one is dimmed, says which badge unlocks it and can't be
## picked; a pick is kept in the profile straight away.

## An outfit was picked for `hero_id`; hero select retints the hero on
## stage.
signal outfit_picked(hero_id: StringName)

const SELECT_COLOR: Color = Color(1.0, 0.66, 0.28)

var _hero_id: StringName = &""
var _outfit_buttons: Dictionary = {}  # outfit id -> Button
var _tent_buttons: Dictionary = {}  # tent id -> Button


func _ready() -> void:
	var canvas: StyleBox = UiKit.art_style("canvas", 6)
	canvas.content_margin_left = 16
	canvas.content_margin_right = 16
	add_theme_stylebox_override("panel", canvas)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_outfit_buttons = _swatches(row, "Outfit", Cosmetics.OUTFITS, _on_outfit)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(18, 0)
	row.add_child(gap)
	_tent_buttons = _swatches(row, "Tent", Cosmetics.TENTS, _on_tent)
	refresh()


## Shows the outfits of hero `hero_id`.
func set_hero(hero_id: StringName) -> void:
	_hero_id = hero_id
	refresh()


## The swatch for outfit `id` (tests).
func outfit_button(id: StringName) -> Button:
	return _outfit_buttons.get(id)


## The swatch for tent colour `id` (tests).
func tent_button(id: StringName) -> Button:
	return _tent_buttons.get(id)


## Marks the picked swatches and locks the ones whose badge isn't earned.
func refresh() -> void:
	if _outfit_buttons.is_empty() or _hero_id == &"":
		return
	for entry in Cosmetics.OUTFITS:
		_style_swatch(_outfit_buttons[entry["id"]], entry, entry["id"] == Cosmetics.outfit_id(_hero_id))
	for entry in Cosmetics.TENTS:
		_style_swatch(_tent_buttons[entry["id"]], entry, entry["id"] == Cosmetics.tent_id())


func _on_outfit(id: StringName) -> void:
	if Cosmetics.choose_outfit(_hero_id, id):
		outfit_picked.emit(_hero_id)
	refresh()


func _on_tent(id: StringName) -> void:
	Cosmetics.choose_tent(id)
	refresh()


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
