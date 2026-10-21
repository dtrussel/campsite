class_name JournalBook
extends Control

## JournalBook
##
## The scrapbook's Journal tab (journal badges 04): Mum's journal as an
## open book. The left page lists every page by number, the found ones
## by title and the rest as blanks; the right page shows the chosen one,
## her words in quotes with her face and her sketch, as on a dawn card.
## A page not yet found can't be opened. The frame is a placeholder (a
## leather cover with two cream pages) until the team's book art comes.

const COVER: Color = Color(0.36, 0.17, 0.1)
const PAGE_PAPER: Color = Color(0.96, 0.91, 0.8)
const SPINE: Color = Color(0.25, 0.11, 0.06)
const LIST_WIDTH: float = 380.0
const FACE_PX: float = 120.0
const SKETCH_PX: float = 170.0
const NOTEBOOK_PAPER: String = "res://assets/ui/story/notebook_page.webp"

var _list: VBoxContainer = null
var _page_box: VBoxContainer = null
var _entries: Dictionary = {}
var _shown: StringName = &""


func _ready() -> void:
	var cover: PanelContainer = PanelContainer.new()
	var cover_style: StyleBoxFlat = UiKit.flat_style(COVER, UiKit.COLOR_BRASS_DARK, 4, 14)
	cover_style.set_content_margin_all(14)
	cover.add_theme_stylebox_override("panel", cover_style)
	UiKit.full_rect(cover)
	add_child(cover)
	var spread: HBoxContainer = HBoxContainer.new()
	spread.add_theme_constant_override("separation", 0)
	cover.add_child(spread)
	spread.add_child(_build_left_page())
	var spine: ColorRect = ColorRect.new()
	spine.color = SPINE
	spine.custom_minimum_size = Vector2(8, 0)
	spread.add_child(spine)
	var right: PanelContainer = _paper(true)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spread.add_child(right)
	_page_box = UiKit.vbox(10)
	right.add_child(_page_box)
	var found: Array[JournalPage] = Journal.found()
	show_page(found[0].id if not found.is_empty() else &"")


## The ids of the pages found, as the left page lists them.
func journal_pages() -> Array:
	var out: Array = []
	for id in _entries:
		if not (_entries[id] as Button).disabled:
			out.append(StringName(id))
	return out


## Opens page `id` on the right. A page not found (or none) shows the
## blank page that says how pages are found.
func show_page(id: StringName) -> void:
	var page: JournalPage = Journal.get_page(id)
	if page == null or not Journal.is_found(id):
		page = null
	_shown = page.id if page != null else &""
	for entry_id in _entries:
		(_entries[entry_id] as Button).set_pressed_no_signal(entry_id == _shown)
	for child in _page_box.get_children():
		child.queue_free()
		_page_box.remove_child(child)
	if page == null:
		_fill_blank()
	else:
		_fill_page(page)


## The words on the open page.
func page_text() -> String:
	return _labels_text(_page_box)


## Every word in the book.
func all_text() -> String:
	return _labels_text(self)


func _build_left_page() -> Control:
	var left: PanelContainer = _paper(false)
	left.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	var column: VBoxContainer = UiKit.vbox(4)
	left.add_child(column)
	var heading: Label = UiKit.title("Mum's journal", 28, UiKit.COLOR_INK)
	column.add_child(heading)
	var count: Label = UiKit.label("%d of %d pages found" % [Journal.found().size(), Journal.pages().size()], 15,
		Color(UiKit.COLOR_INK, 0.7))
	column.add_child(count)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_list = UiKit.vbox(2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var number: int = 0
	for page in Journal.pages():
		number += 1
		var found: bool = Journal.is_found(page.id)
		var entry: Button = Button.new()
		entry.text = "%d.  %s" % [number, page.title if found else "? ? ?"]
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.toggle_mode = true
		entry.disabled = not found
		entry.flat = true
		entry.focus_mode = Control.FOCUS_ALL if found else Control.FOCUS_NONE
		entry.add_theme_font_size_override("font_size", 17)
		entry.add_theme_color_override("font_color", UiKit.COLOR_INK)
		entry.add_theme_color_override("font_hover_color", UiKit.COLOR_BRASS_DARK)
		entry.add_theme_color_override("font_pressed_color", UiKit.COLOR_EMBER.darkened(0.35))
		entry.add_theme_color_override("font_hover_pressed_color", UiKit.COLOR_EMBER.darkened(0.35))
		entry.add_theme_color_override("font_disabled_color", Color(UiKit.COLOR_INK, 0.3))
		entry.tooltip_text = "" if found else _how_found(page)
		entry.pressed.connect(show_page.bind(page.id))
		_list.add_child(entry)
		_entries[page.id] = entry
	return left


## A page of the book: cream paper (the notebook paper on the right).
func _paper(notebook: bool) -> PanelContainer:
	var paper: PanelContainer = PanelContainer.new()
	var style: StyleBox = null
	if notebook and ResourceLoader.exists(NOTEBOOK_PAPER):
		var textured: StyleBoxTexture = StyleBoxTexture.new()
		textured.texture = load(NOTEBOOK_PAPER) as Texture2D
		textured.modulate_color = Color(1, 1, 1, 0.9)
		style = textured
	else:
		style = UiKit.flat_style(PAGE_PAPER, Color(UiKit.COLOR_BRASS_DARK, 0.5), 1, 4)
	style.set_content_margin_all(24)
	style.content_margin_left = 28
	paper.add_theme_stylebox_override("panel", style)
	return paper


func _fill_page(page: JournalPage) -> void:
	var number: int = Journal.pages().find(page) + 1
	var heading: Label = UiKit.title(page.title, 30, UiKit.COLOR_INK)
	_page_box.add_child(heading)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box.add_child(row)
	var face: TextureRect = _picture(StoryLibrary.speaker_portrait("note", page.face_shown()), FACE_PX)
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(face)
	var words: Label = UiKit.label("“%s”" % page.text(), 24, UiKit.COLOR_INK)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(words)
	if page.sketch_path() != "":
		var sketch: TextureRect = _picture(load(page.sketch_path()) as Texture2D, SKETCH_PX)
		sketch.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(sketch)
	var footer: Label = UiKit.label("Page %d  •  Mum" % number, 15, Color(UiKit.COLOR_INK, 0.6))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_page_box.add_child(footer)


func _fill_blank() -> void:
	var heading: Label = UiKit.title("An empty page", 30, Color(UiKit.COLOR_INK, 0.6))
	_page_box.add_child(heading)
	var help: Label = UiKit.label("Mum's pages turn up at dawn, in chests by the trees, and with some badges.",
		20, Color(UiKit.COLOR_INK, 0.75))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_box.add_child(help)


func _picture(texture: Texture2D, px: float) -> TextureRect:
	var picture: TextureRect = TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(px, px)
	return picture


func _how_found(page: JournalPage) -> String:
	match page.found_in:
		&"dawn":
			return "Found at dawn, on a story card."
		&"badge":
			var badge: BadgeDefinition = Badges.get_badge(page.badge)
			return "Earn the %s badge." % (badge.display_name if badge != null else String(page.badge))
	return "Hidden in a chest by the trees."


func _labels_text(root: Node) -> String:
	var words: PackedStringArray = PackedStringArray()
	for node in root.find_children("*", "", true, false):
		if node is Label:
			words.append((node as Label).text)
		elif node is Button:
			words.append((node as Button).text + "\n" + (node as Button).tooltip_text)
	return "\n".join(words)
