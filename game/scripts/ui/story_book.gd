class_name StoryBook
extends CanvasLayer

## StoryBook
##
## The painted storybook: the chapter intro after hero
## select, and the chapter ending before the win screen's stats. One
## painting per page with one or two voiced lines. Click, Space or
## Enter turns the page, Esc skips the rest. Runs while the game is
## paused. Emits `finished` once, then fades away.
##
##   var book: StoryBook = StoryBook.play(StoryLibrary.find(&"intro", 1))
##   book.finished.connect(...)

signal finished

const FADE_SECONDS: float = 0.3

var page: int = -1
## Bumped on every page so the last page's voices stop queueing.
var speech_id: int = 0
var _beats: Array = []
var _hero_id: StringName = &"leo"
var _root: Control = null
var _art: TextureRect = null
var _text: VBoxContainer = null
var _dots: HBoxContainer = null
var _done: bool = false


## Opens the book on top of everything and shows the first page.
static func play(beats: Array, hero_id: StringName = &"", layer_index: int = 90) -> StoryBook:
	var book: StoryBook = StoryBook.new()
	book._beats = beats
	book._hero_id = hero_id if hero_id != &"" else GameManager.hero_id
	book.layer = layer_index
	# Deferred: the root may be busy adding a scene's children.
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(book)
	return book


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("story_book")
	_build()
	if _beats.is_empty():
		_finish.call_deferred()
		return
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, FADE_SECONDS)
	show_page(0)


## False once the book has finished (it may still be fading out).
func is_open() -> bool:
	return not _done


func page_count() -> int:
	return _beats.size()


func show_page(index: int) -> void:
	page = index
	var beat: StoryBeat = _beats[index]
	if beat.painting != null:
		_art.texture = beat.painting
	for child in _text.get_children():
		child.queue_free()
	var lines: Array = beat.lines_for(_hero_id)
	for line in lines:
		_text.add_child(StoryCard.line_row(line, 30, 84))
	for i in _dots.get_child_count():
		(_dots.get_child(i) as HudWidgets.Glyph).set_kind("moon" if i <= index else "moon_empty")
	_text.modulate.a = 0.0
	create_tween().tween_property(_text, "modulate:a", 1.0, 0.25)
	speech_id += 1
	StoryCard.speak(lines, self, speech_id)


## The next page, or the end of the book.
func next() -> void:
	if _done:
		return
	AudioManager.play_sfx(&"ui_click")
	if page + 1 < _beats.size():
		show_page(page + 1)
	else:
		_finish()


func skip() -> void:
	_finish()


func _input(event: InputEvent) -> void:
	if _done:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if event.is_action_pressed("ui_cancel"):
		skip()
	elif event.is_action_pressed("ui_accept") or (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		next()
	else:
		return
	get_viewport().set_input_as_handled()


func _finish() -> void:
	if _done:
		return
	_done = true
	AudioManager.stop_voice()
	finished.emit()
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(queue_free)


func _build() -> void:
	_root = Control.new()
	UiKit.full_rect(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiKit.theme()
	add_child(_root)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.06, 0.035, 0.02)
	UiKit.full_rect(backdrop)
	_root.add_child(backdrop)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_art)
	_root.add_child(_art)

	# A dark band along the bottom so the words read over the painting.
	var shade: TextureRect = TextureRect.new()
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.07, 0.035, 0.02, 0.0))
	gradient.set_color(1, Color(0.07, 0.035, 0.02, 0.92))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 0.75)
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -300
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var column: VBoxContainer = UiKit.vbox(14)
	column.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	column.custom_minimum_size = Vector2(900, 0)
	column.position = Vector2(-450, -250)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)
	_text = UiKit.vbox(12)
	_text.custom_minimum_size = Vector2(900, 170)
	_text.alignment = BoxContainer.ALIGNMENT_END
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_text)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(footer)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 6)
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_dots)
	for i in _beats.size():
		_dots.add_child(HudWidgets.Glyph.new("moon_empty", Color(1.0, 0.92, 0.6), 22))
	footer.add_child(UiKit.key_cap("Space", 34))
	footer.add_child(UiKit.label("next", 18, UiKit.COLOR_MUTED))
	footer.add_child(UiKit.key_cap("Esc", 34))
	footer.add_child(UiKit.label("skip", 18, UiKit.COLOR_MUTED))
