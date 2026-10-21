class_name StartingPerkRow
extends HBoxContainer

## StartingPerkRow
##
## Hero select's "Start with:" row: None or one of the perk cards a
## badge has unlocked (StartingPerks), as toggle buttons. The pick is
## kept in the profile. Hero select leaves it out while none is
## unlocked (`StartingPerkRow.is_wanted`).

var _buttons: Dictionary = {}  # StringName (&"" = none) -> Button


## Whether the row has anything to offer: some badge has unlocked a
## starting perk.
static func is_wanted() -> bool:
	return not StartingPerks.unlocked().is_empty()


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)
	var word: Label = UiKit.label("Start with:", 16, UiKit.COLOR_GOLD_LIGHT)
	word.add_theme_font_override("font", Fx.bold_font())
	word.add_theme_constant_override("outline_size", 6)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(word)
	var group: ButtonGroup = ButtonGroup.new()
	add_child(_button(&"", "None", null, "Start with no perk card", group))
	for id in StartingPerks.unlocked():
		var perk: PerkDefinition = PerkManager.get_definition(id)
		var badge: BadgeDefinition = Badges.get_badge(StartingPerks.UNLOCKS[id])
		var tip: String = "%s\nUnlocked by the %s badge" % [perk.description.format({"hero": "your hero", "companion": "your companion"}),
			badge.display_name if badge != null else "?"]
		add_child(_button(id, perk.display_name, perk.icon_texture(), tip, group))
	pick(StartingPerks.chosen())


## Picks the perk card the next run starts with (&"" for none); kept in
## the profile. A perk that is not unlocked picks none.
func pick(id: StringName) -> void:
	StartingPerks.choose(id)
	var chosen: StringName = StartingPerks.chosen()
	for key in _buttons:
		(_buttons[key] as Button).set_pressed_no_signal(key == chosen)


func _button(id: StringName, caption: String, icon: Texture2D, tip: String, group: ButtonGroup) -> Button:
	var button: Button = Button.new()
	button.text = caption
	button.icon = icon
	button.expand_icon = true
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 36)
	button.tooltip_text = tip
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_constant_override("icon_max_width", 24)
	button.pressed.connect(func() -> void:
		AudioManager.play_sfx(&"ui_click")
		pick(id))
	_buttons[id] = button
	return button
