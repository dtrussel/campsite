extends CanvasLayer

## CraftingPanel
##
## C toggles a small recipe list while the boy stands near the
## campfire. Each row shows the recipe's inputs and a Craft button
## that is enabled only when the inventory can pay for it. The game
## keeps running while the panel is open.

const CRAFT_RANGE: float = 4.0

var _root: Control = null
var _rows: Array = []   # [{ recipe, button }]


func _ready() -> void:
	layer = 5
	add_to_group("crafting_panel")
	_root = Control.new()
	UiKit.full_rect(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var panel: PanelContainer = UiKit.panel(16)
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.position = Vector2(-440, -120)
	panel.custom_minimum_size = Vector2(420, 0)
	_root.add_child(panel)
	var column: VBoxContainer = UiKit.vbox(8)
	panel.add_child(column)
	column.add_child(UiKit.label("Campfire crafting", 24, UiKit.COLOR_ACCENT))
	for recipe in CraftingManager.get_recipes():
		column.add_child(HSeparator.new())
		column.add_child(UiKit.label("%s  <-  %s" % [recipe.display_name, recipe.input_summary()], 18))
		var description: Label = UiKit.label(recipe.description, 14, UiKit.COLOR_MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(description)
		var button: Button = UiKit.button("Craft %s" % recipe.display_name, _on_craft.bind(recipe), false)
		column.add_child(button)
		_rows.append({ "recipe": recipe, "button": button })
	column.add_child(UiKit.label("C or Esc to close", 13, UiKit.COLOR_MUTED))
	_root.visible = false
	ResourceManager.resource_changed.connect(func(_id: StringName, _v: int, _d: int) -> void: _refresh())


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
		Fx.float_text(player, "Go to the campfire to craft", Color(1, 0.85, 0.5), 2.0)
		return
	open()


func _process(_delta: float) -> void:
	# Walking away from the fire closes the panel.
	if is_open():
		var player: Node3D = _get_player()
		if player == null or not _is_near_campfire(player):
			close()


func _refresh() -> void:
	for row in _rows:
		(row["button"] as Button).disabled = not CraftingManager.can_craft(row["recipe"])


func _on_craft(recipe: CraftingRecipe) -> void:
	var player: Node3D = _get_player()
	if CraftingManager.craft(recipe, player) and player != null:
		Fx.float_text(player, "+1 %s" % recipe.display_name, Color(1, 0.7, 0.3), 2.0)
	_refresh()


func _get_player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _is_near_campfire(player: Node3D) -> bool:
	var base: Node3D = get_tree().get_first_node_in_group("base_core") as Node3D
	return base != null and base.global_position.distance_to(player.global_position) <= CRAFT_RANGE
