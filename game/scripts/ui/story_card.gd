class_name StoryCard
extends PanelContainer

## StoryCard
##
## The dawn card: a small campcraft plate down the left
## edge of the HUD where the played hero and the companion talk about the night
## (and read a page of Mum's notebook they found),
## with a hint about the Moon Lantern underneath. It never pauses the
## game: it plays the voiced lines one after another, then fades by
## itself (or on a click).
##
##   hud.add_child(StoryCard.make(beat, GameManager.hero_id, hint))

signal dismissed

## Shown at least this long, longer if the voices need it.
const MIN_SECONDS: float = 6.0
const FADE_SECONDS: float = 0.5

var _lines: Array = []
var _closing: bool = false


static func make(beat: StoryBeat, hero_id: StringName, hint: String = "") -> StoryCard:
	var card: StoryCard = StoryCard.new()
	card._lines = beat.lines_for(hero_id) if beat != null else []
	card._build(hint)
	return card


## One line of dialogue: the speaker's portrait, name and words. Shared
## with StoryBook.
static func line_row(line: Dictionary, text_size: int, portrait_size: float, centered: bool = false) -> HBoxContainer:
	var speaker: String = String(line.get("speaker", "narrator"))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait: Texture2D = StoryLibrary.speaker_portrait(speaker, String(line.get("face", "")))
	if portrait != null:
		var face: TextureRect = TextureRect.new()
		face.texture = portrait
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.custom_minimum_size = Vector2(portrait_size, portrait_size)
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(face)
	var column: VBoxContainer = UiKit.vbox(0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var name_text: String = StoryLibrary.speaker_name(speaker)
	if name_text != "":
		var who: Label = UiKit.title(name_text, int(text_size * 0.75), UiKit.COLOR_GOLD_LIGHT)
		column.add_child(who)
	var text: String = UiKit.party_text(String(line.get("text", "")))
	var color: Color = UiKit.COLOR_TEXT if name_text != "" else UiKit.COLOR_MOON.lightened(0.4)
	if speaker == "note":
		# A page of Mum's notebook: her words in quotes, moonlit.
		text = "\u201c%s\u201d" % text
		color = UiKit.COLOR_MOON.lightened(0.6)
	var words: Label = UiKit.label(text, text_size, color)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centered:
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_theme_constant_override("outline_size", 6)
	words.add_theme_color_override("font_outline_color", UiKit.COLOR_INK)
	column.add_child(words)
	# Mum's note comes with her sketch, a taped scrap of her notebook.
	var sketch_path: String = String(line.get("sketch", ""))
	if sketch_path != "" and ResourceLoader.exists(sketch_path):
		var sketch: TextureRect = TextureRect.new()
		sketch.texture = load(sketch_path) as Texture2D
		sketch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sketch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sketch.custom_minimum_size = Vector2(portrait_size * 2.4, portrait_size * 2.4)
		sketch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sketch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sketch.name = "Sketch"
		row.add_child(sketch)
	return row


## Plays the lines' voices one after another; returns once they are
## done, `owner_node` has left the tree, or its `speech_id` no longer
## matches `speech` (a page was turned). Missing recordings take no time.
static func speak(lines: Array, owner_node: Node, speech: int = -1) -> void:
	for line in lines:
		if not is_instance_valid(owner_node) or not owner_node.is_inside_tree():
			return
		if speech >= 0 and int(owner_node.get(&"speech_id")) != speech:
			return
		var seconds: float = AudioManager.play_voice(StoryLibrary.voice(String((line as Dictionary).get("id", ""))))
		if seconds <= 0.0:
			continue
		await owner_node.get_tree().create_timer(seconds + 0.25, true, false, true).timeout


func lines() -> Array:
	return _lines


func _build(hint: String) -> void:
	add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COLOR_WOOD, UiKit.COLOR_BRASS_DARK, 14))
	custom_minimum_size = Vector2(430, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Click to close"
	var column: VBoxContainer = UiKit.vbox(8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	for line in _lines:
		column.add_child(line_row(line, 20, 52))
	if hint != "":
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(row)
		row.add_child(HudWidgets.Glyph.new("moon", UiKit.COLOR_MOON, 20))
		var tip: Label = UiKit.label(hint, 15, UiKit.COLOR_MOON.lightened(0.3))
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tip)


func _ready() -> void:
	# Wrapped labels report a tall first layout; shrink back to fit.
	minimum_size_changed.connect(reset_size)
	reset_size.call_deferred()
	# Slides in from the left edge.
	modulate.a = 0.0
	position.x = -40.0
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	tween.tween_property(self, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_run()


func _run() -> void:
	var started: float = Time.get_ticks_msec() / 1000.0
	await speak(_lines, self)
	if not is_inside_tree():
		return
	var left: float = MIN_SECONDS - (Time.get_ticks_msec() / 1000.0 - started)
	if left > 0.0:
		await get_tree().create_timer(left, false).timeout
	dismiss()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		accept_event()
		dismiss()


func is_closing() -> bool:
	return _closing


func dismiss() -> void:
	if _closing or not is_inside_tree():
		return
	_closing = true
	AudioManager.stop_voice()
	dismissed.emit()
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(queue_free)
