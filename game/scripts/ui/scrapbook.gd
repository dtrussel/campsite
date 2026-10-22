class_name Scrapbook
extends Control

## Scrapbook
##
## The Ranger's scrapbook, opened from the title's
## Journal button. A walnut plate with a row of tabs; each tab is one
## page of content. The Badges tab is a grid of every Camp Badge in
## scrapbook order (Badges.definitions()): earned ones in colour, locked
## ones as dark silhouettes, each with how to earn it. Esc or Close
## emits `closed`; the opener frees it.
##
## The Journal tab is Mum's journal, a JournalBook.

## The close button or Esc was pressed; the opener frees the scrapbook.
signal closed

const BADGES_TAB: String = "Badges"
const JOURNAL_TAB: String = "Journal"
const GRID_COLUMNS: int = 5
const CARD_SIZE: Vector2 = Vector2(220, 160)
const GAP: float = 12.0
## Rows on show before the grid scrolls (fits a 720 p window).
const ROWS: int = 3
const ICON_PX: float = 52.0
## A locked badge's icon: a flat brass silhouette of its shape.
const SILHOUETTE: Color = Color(0.5, 0.36, 0.2, 0.75)
const SILHOUETTE_SHADER: String = """
shader_type canvas_item;
uniform vec4 tint : source_color;
void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
}
"""

static var _silhouette: ShaderMaterial = null

var _tab_row: HBoxContainer = null
var _pages: Control = null
var _close: Button = null
## Tab name -> [tab Button, page Control], in tab order.
var _tabs: Dictionary = {}
var _current: String = ""
## Badge id -> {"earned": bool, "card": Control}.
var _cards: Dictionary = {}


func _ready() -> void:
	UiKit.full_rect(self)
	theme = UiKit.theme()
	add_child(UiKit.dim_background())
	var center: CenterContainer = UiKit.centered()
	add_child(center)
	var plate: PanelContainer = UiKit.panel(26)
	center.add_child(plate)
	var column: VBoxContainer = UiKit.vbox(10)
	plate.add_child(column)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	var heading: Label = UiKit.title("Scrapbook", 40)
	header.add_child(heading)
	var count: Label = UiKit.label(_earned_count_text(), 18, UiKit.COLOR_GOLD_LIGHT)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(count)
	_close = HudWidgets.icon_button("close", "", close, Color(1.0, 0.45, 0.4), null, true, 48.0)
	_close.tooltip_text = "Back to the title"
	header.add_child(_close)

	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 10)
	column.add_child(_tab_row)
	var page_size: Vector2 = Vector2(GRID_COLUMNS * (CARD_SIZE.x + GAP), ROWS * (CARD_SIZE.y + GAP) - GAP)
	column.add_child(UiKit.divider(page_size.x))
	_pages = Control.new()
	_pages.custom_minimum_size = page_size
	column.add_child(_pages)

	add_tab(BADGES_TAB, _build_badges())
	add_tab(JOURNAL_TAB, JournalBook.new())
	show_tab(BADGES_TAB)
	_close.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Adds a tab whose page is `page` (sized to the page area).
func add_tab(tab_name: String, page: Control) -> void:
	var tab: Button = UiKit.button(tab_name, show_tab.bind(tab_name))
	tab.custom_minimum_size = Vector2(180, 42)
	tab.toggle_mode = true
	_tab_row.add_child(tab)
	UiKit.full_rect(page)
	page.visible = false
	_pages.add_child(page)
	_tabs[tab_name] = [tab, page]


func show_tab(tab_name: String) -> void:
	if not _tabs.has(tab_name):
		return
	_current = tab_name
	for key in _tabs:
		var shown: bool = key == tab_name
		(_tabs[key][0] as Button).set_pressed_no_signal(shown)
		(_tabs[key][1] as Control).visible = shown


## The tab on show.
func current_tab() -> String:
	return _current


## The ids of the journal pages the Journal tab lists as found.
func journal_pages() -> Array:
	return (_tabs[JOURNAL_TAB][1] as JournalBook).journal_pages()


## Opens journal page `id` on the Journal tab.
func show_page(id: StringName) -> void:
	(_tabs[JOURNAL_TAB][1] as JournalBook).show_page(id)


## The words on the Journal tab's open page.
func page_text() -> String:
	return (_tabs[JOURNAL_TAB][1] as JournalBook).page_text()


## Every word in the journal, found pages and blanks.
func all_text() -> String:
	return (_tabs[JOURNAL_TAB][1] as JournalBook).all_text()


## Every badge on the Badges tab, as {id: earned}.
func badge_states() -> Dictionary:
	var out: Dictionary = {}
	for id in _cards:
		out[id] = bool(_cards[id]["earned"])
	return out


## All the words on badge `id`'s card, or "" when it has no card.
func badge_text(id: StringName) -> String:
	if not _cards.has(id):
		return ""
	var words: PackedStringArray = PackedStringArray()
	for node in (_cards[id]["card"] as Control).find_children("*", "Label", true, false):
		words.append((node as Label).text)
	return "\n".join(words)


func close_button() -> Button:
	return _close


func close() -> void:
	closed.emit()


func _earned_count_text() -> String:
	var earned: int = 0
	for badge in Badges.definitions():
		if Badges.has_badge(badge.id):
			earned += 1
	return "%d of %d badges earned" % [earned, Badges.definitions().size()]


func _build_badges() -> Control:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid: GridContainer = GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	scroll.add_child(grid)
	for badge in Badges.definitions():
		var earned: bool = Badges.has_badge(badge.id)
		var card: Control = _badge_card(badge, earned)
		grid.add_child(card)
		_cards[badge.id] = {"earned": earned, "card": card}
	return scroll


## One badge: cream canvas and its icon in colour when earned, a dark
## slot with the icon as a silhouette when not; how to earn it on both.
func _badge_card(badge: BadgeDefinition, earned: bool) -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.add_theme_stylebox_override("panel", UiKit.art_style("canvas" if earned else "slot", 10))
	card.tooltip_text = ("Earned! " if earned else "Locked. ") + badge.how_to_earn
	var column: VBoxContainer = UiKit.vbox(2)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(column)
	var icon: TextureRect = TextureRect.new()
	icon.texture = badge.icon_texture()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not earned:
		icon.material = _silhouette_material()
	column.add_child(icon)
	var name_label: Label = UiKit.label(badge.display_name, 18, UiKit.COLOR_INK if earned else UiKit.COLOR_MUTED)
	name_label.add_theme_font_override("font", Fx.title_font(700))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var how: Label = UiKit.label(badge.how_to_earn, 13,
		Color(UiKit.COLOR_INK, 0.75) if earned else UiKit.COLOR_GOLD_LIGHT)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(CARD_SIZE.x - 24.0, 0)
	column.add_child(how)
	return card


static func _silhouette_material() -> ShaderMaterial:
	if _silhouette == null:
		var shader: Shader = Shader.new()
		shader.code = SILHOUETTE_SHADER
		_silhouette = ShaderMaterial.new()
		_silhouette.shader = shader
		_silhouette.set_shader_parameter("tint", SILHOUETTE)
	return _silhouette
