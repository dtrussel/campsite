class_name SpeechBubble
extends Node3D

## SpeechBubble
##
## A sibling's bark over their head. The node itself is an
## anchor above the hero's health bar; the bubble is drawn on screen
## (a parchment card with an ink rim and a tail), following the anchor
## every frame, so it stays crisp and readable through the tilt-shift
## and at any zoom. It pops in, holds, then fades and frees itself.
## One bubble per hero: a new line replaces the one showing.

const NODE_NAME: String = "SpeechBubble"
const FONT_SIZE: int = 19
const MAX_TEXT_WIDTH: float = 230.0
const TAIL: Vector2 = Vector2(18, 12)
## Gap between the health bar and the tail tip, in metres.
const ABOVE_BAR: float = 0.15
const FALLBACK_HEIGHT: float = 2.6
const FADE_SECONDS: float = 0.25
## Under the HUD and menus, over the world's post effects.
const LAYER: int = 0
## Space kept between two bubbles that would overlap, in pixels.
const STACK_GAP: float = 4.0

## Bubbles on screen, oldest first: a newer one moves up out of the way.
static var _showing: Array[SpeechBubble] = []

var text: String = ""
var _layer: CanvasLayer = null
var _card: Control = null
var _tween: Tween = null


## Shows `line_text` over `speaker` for `seconds`, replacing their last
## bubble, and returns the new bubble.
static func say(speaker: Node3D, line_text: String, seconds: float = 2.5) -> SpeechBubble:
	var old: Node = speaker.get_node_or_null(NODE_NAME)
	if old != null:
		old.name = NODE_NAME + "Old"
		old.queue_free()
	var bubble: SpeechBubble = SpeechBubble.new()
	bubble.name = NODE_NAME
	bubble.text = line_text
	bubble.position = Vector3(0, _height_over(speaker), 0)
	speaker.add_child(bubble)
	bubble.show_for(seconds)
	return bubble


## The bubble over `speaker`, or null.
static func on(speaker: Node) -> SpeechBubble:
	return speaker.get_node_or_null(NODE_NAME) as SpeechBubble if speaker != null else null


static func _height_over(speaker: Node3D) -> float:
	for child in speaker.get_children():
		if child is HealthBar3D:
			return (child as HealthBar3D).position.y + ABOVE_BAR
	return FALLBACK_HEIGHT


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = UiKit.flat_style(UiKit.COLOR_CANVAS, UiKit.COLOR_INK, 3, 12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 7
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = UiKit.label(text, FONT_SIZE, UiKit.COLOR_INK)
	label.add_theme_font_override("font", Fx.bold_font())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = Fx.bold_font()
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x > MAX_TEXT_WIDTH:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = MAX_TEXT_WIDTH
	panel.add_child(label)
	_card.add_child(panel)
	var tail: Tail = Tail.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(tail)
	_layer.add_child(_card)
	panel.reset_size()
	var size_px: Vector2 = panel.get_combined_minimum_size()
	panel.size = size_px
	_card.size = Vector2(size_px.x, size_px.y + TAIL.y)
	_card.pivot_offset = Vector2(size_px.x * 0.5, _card.size.y)
	tail.position = Vector2(size_px.x * 0.5, size_px.y)
	_follow()


func _enter_tree() -> void:
	_showing.append(self)


func _exit_tree() -> void:
	_showing.erase(self)


func _process(_delta: float) -> void:
	_follow()


## Puts the tail tip on the anchor's screen position.
func _follow() -> void:
	if _card == null:
		return
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null or camera.is_position_behind(global_position):
		_card.visible = false
		return
	_card.visible = true
	var tip: Vector2 = camera.unproject_position(global_position)
	_card.position = (tip - Vector2(_card.size.x * 0.5, _card.size.y)).round()
	# Stand clear of older bubbles (kids side by side).
	for other in _showing:
		if other == self:
			break
		if other._card == null or not other._card.visible:
			continue
		var mine: Rect2 = Rect2(_card.position, _card.size)
		var theirs: Rect2 = Rect2(other._card.position, other._card.size)
		if mine.intersects(theirs):
			_card.position.y = theirs.position.y - _card.size.y - STACK_GAP


func show_for(seconds: float) -> void:
	if _tween != null:
		_tween.kill()
	_card.scale = Vector2.ONE * 0.6
	_card.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(maxf(0.4, seconds))
	_tween.tween_property(_card, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(queue_free)


## The tail, drawn over the card's bottom rim so the two join. Its
## origin is the middle of the card's bottom edge.
class Tail extends Control:
	func _draw() -> void:
		var half: float = SpeechBubble.TAIL.x * 0.5
		var depth: float = SpeechBubble.TAIL.y
		draw_colored_polygon(PackedVector2Array([Vector2(-half - 3, -3), Vector2(half + 3, -3), Vector2(0, depth + 2)]), UiKit.COLOR_INK)
		draw_colored_polygon(PackedVector2Array([Vector2(-half, -4), Vector2(half, -4), Vector2(0, depth - 2)]), UiKit.COLOR_CANVAS)
