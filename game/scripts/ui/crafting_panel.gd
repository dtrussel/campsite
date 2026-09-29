extends CanvasLayer

## CraftingPanel
##
## C toggles a small recipe list while the boy stands near the
## campfire. Each row shows the recipe's inputs, its result and a Make
## button that is enabled only when it can be made right now (the
## inventory can pay, and an effect like Feed the Fire has something to
## do). The game keeps running while the panel is open.

const CRAFT_RANGE: float = 4.0

var _root: Control = null
var _rows: Array = []   # [{ recipe, button }]


func _ready() -> void:
	layer = 5
	add_to_group("crafting_panel")
	_root = Control.new()
	_root.theme = UiKit.theme()
	UiKit.full_rect(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var panel: PanelContainer = UiKit.panel(16)
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.position = Vector2(-460, -140)
	panel.custom_minimum_size = Vector2(400, 0)
	_root.add_child(panel)
	var column: VBoxContainer = UiKit.vbox(8)
	panel.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.add_child(_icon_rect(Fx.icon("campfire"), 56))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(HudWidgets.icon_button("close", "", close, Color(1.0, 0.45, 0.4), null, false))
	column.add_child(header)
	column.add_child(UiKit.divider(360))
	for recipe in CraftingManager.get_recipes():
		# [inputs x n] -> [result]   [make!]  (one compact row per recipe)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.tooltip_text = "%s: %s" % [recipe.display_name, recipe.description]
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		for key in recipe.inputs.keys():
			var input_def: ResourceDefinition = ResourceManager.get_definition(StringName(key))
			row.add_child(HudWidgets.icon_count(input_def.icon if input_def != null else null, "star", "%d" % int(recipe.inputs[key]), 34))
		row.add_child(HudWidgets.Glyph.new("arrow", UiKit.COLOR_GOLD, 28))
		row.add_child(_icon_rect(recipe.result_icon(), 52))
		var spacer_row: Control = Control.new()
		spacer_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer_row)
		var button: Button = HudWidgets.icon_button("check", "", _on_craft.bind(recipe), Color(0.5, 1.0, 0.55), null, false)
		button.tooltip_text = recipe.display_name
		row.add_child(button)
		column.add_child(row)
		_rows.append({ "recipe": recipe, "button": button })
	_root.visible = false
	ResourceManager.resource_changed.connect(func(_id: StringName, _v: int, _d: int) -> void: _refresh())
	GameManager.run_ended.connect(func(_won: bool, _reason: String) -> void: close())


func _icon_rect(texture: Texture2D, size_px: int) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(size_px, size_px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_refresh()
	_root.visible = true


func close() -> void:
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("open_crafting") or not GameManager.is_playing():
		return
	get_viewport().set_input_as_handled()
	if is_open():
		close()
		return
	var player: Node3D = _get_player()
	if player == null:
		return
	if not _is_near_campfire(player):
		Fx.icon_popup(player, Fx.icon("campfire"), "", Color.WHITE, true)
		return
	open()


func _process(_delta: float) -> void:
	# Walking away from the fire closes the panel.
	if is_open():
		var player: Node3D = _get_player()
		if player == null or not _is_near_campfire(player):
			close()
		else:
			_refresh()  # the campfire's HP can change while it is open


func _refresh() -> void:
	for row in _rows:
		(row["button"] as Button).disabled = not CraftingManager.can_craft(row["recipe"])


func _on_craft(recipe: CraftingRecipe) -> void:
	var player: Node3D = _get_player()
	if CraftingManager.craft(recipe, player) and player != null and recipe.output_id != &"":
		Fx.icon_popup(player, recipe.result_icon(), "+%d" % recipe.output_amount, Color(1, 0.9, 0.5))
	_refresh()


func _get_player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _is_near_campfire(player: Node3D) -> bool:
	var base: Node3D = get_tree().get_first_node_in_group("base_core") as Node3D
	return base != null and base.global_position.distance_to(player.global_position) <= CRAFT_RANGE
