class_name HudWidgets
extends RefCounted

## HudWidgets
##
## Hand-drawn (Control._draw) HUD pieces in the LoL style, so the HUD
## needs no texture assets beyond the rendered icons:
##   StatBar     - framed bar with gradient fill, damage trail, ticks, text
##   Portrait    - round character portrait, gold ring, level badge
##   AbilitySlot - square icon slot with keybind, count, cooldown sweep
##   DayClock    - sun/moon dial showing progress through the phase


class StatBar extends Control:
	var value: float = 1.0
	var max_value: float = 1.0
	var fill_color: Color = Color(0.2, 0.78, 0.3)
	var fill_top: Color = Color(0.55, 1.0, 0.5)
	var tick_every: float = 10.0
	var show_text: bool = true
	var text_override: String = ""
	var _trail: float = 0.0
	var _font: Font = null

	func _init(color: Color = Color(0.2, 0.78, 0.3), top: Color = Color(0.55, 1.0, 0.5)) -> void:
		fill_color = color
		fill_top = top
		_font = Fx.bold_font()
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_values(current: float, maximum: float) -> void:
		var old_ratio: float = value / maxf(max_value, 0.001)
		value = current
		max_value = maxf(maximum, 0.001)
		var ratio: float = value / max_value
		if ratio >= old_ratio:
			_trail = ratio
		queue_redraw()

	func _process(delta: float) -> void:
		var ratio: float = value / maxf(max_value, 0.001)
		if _trail > ratio:
			_trail = maxf(ratio, _trail - delta * 0.6)
			queue_redraw()

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.01, 0.02, 0.03, 0.95))
		var inner: Rect2 = rect.grow(-2.0)
		var ratio: float = clampf(value / max_value, 0.0, 1.0)
		if _trail > ratio:
			draw_rect(Rect2(inner.position, Vector2(inner.size.x * _trail, inner.size.y)), Color(1.0, 0.92, 0.75, 0.85))
		var fill: Rect2 = Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y))
		draw_rect(fill, fill_color)
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.45)), fill_top)
		if tick_every > 0.0 and max_value / tick_every <= 40.0:
			var ticks: int = int(max_value / tick_every)
			for i in range(1, ticks + 1):
				var x: float = inner.position.x + inner.size.x * (float(i) * tick_every / max_value)
				if x < inner.end.x - 1.0:
					draw_line(Vector2(x, inner.position.y), Vector2(x, inner.position.y + inner.size.y * 0.5), Color(0, 0, 0, 0.55), 1.0)
		draw_rect(rect, UiKit.COLOR_GOLD_DARK, false, 1.0)
		if show_text and size.y >= 12.0:
			var text: String = text_override if text_override != "" else "%d / %d" % [int(value), int(max_value)]
			var font_size: int = int(size.y * 0.72)
			var text_size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var pos: Vector2 = Vector2((size.x - text_size.x) * 0.5, (size.y + text_size.y * 0.62) * 0.5)
			draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.9))
			draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1))


class Portrait extends Control:
	var texture: Texture2D = null
	var level: int = 1
	var ring_color: Color = UiKit.COLOR_GOLD
	var dimmed: bool = false
	var _font: Font = null

	func _init(tex: Texture2D = null) -> void:
		texture = tex
		_font = Fx.bold_font()
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_level(new_level: int) -> void:
		level = new_level
		queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 3.0
		draw_circle(center, radius + 3.0, Color(0.01, 0.02, 0.03))
		if texture != null:
			var points: PackedVector2Array = PackedVector2Array()
			var uvs: PackedVector2Array = PackedVector2Array()
			for i in range(40):
				var a: float = TAU * float(i) / 40.0
				var dir: Vector2 = Vector2(cos(a), sin(a))
				points.append(center + dir * radius)
				uvs.append(Vector2(0.5, 0.5) + dir * 0.5)
			var tint: Color = Color(0.45, 0.45, 0.5) if dimmed else Color.WHITE
			draw_colored_polygon(points, tint, uvs, texture)
		draw_arc(center, radius + 1.0, 0.0, TAU, 48, UiKit.COLOR_GOLD_DARK, 4.0, true)
		draw_arc(center, radius + 2.5, 0.0, TAU, 48, ring_color, 1.5, true)
		# Level badge at the bottom of the ring.
		var badge: Vector2 = center + Vector2(radius * 0.62, radius * 0.72)
		draw_circle(badge, 13.0, Color(0.02, 0.05, 0.08))
		draw_arc(badge, 13.0, 0.0, TAU, 24, UiKit.COLOR_GOLD, 1.5, true)
		var text: String = str(level)
		var text_size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string(_font, badge + Vector2(-text_size.x * 0.5, 5.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiKit.COLOR_GOLD_LIGHT)


class AbilitySlot extends Control:
	var icon: Texture2D = null
	var key_text: String = ""
	var count_text: String = ""
	var cooldown: float = 0.0   # 0..1 remaining
	var enabled: bool = true
	var highlight: bool = false
	var _font: Font = null

	func _init(tex: Texture2D = null, key: String = "") -> void:
		icon = tex
		key_text = key
		_font = Fx.bold_font()
		custom_minimum_size = Vector2(54, 54)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_state(new_enabled: bool, new_count: String = "", new_cooldown: float = 0.0) -> void:
		if new_enabled == enabled and new_count == count_text and is_equal_approx(new_cooldown, cooldown):
			return
		enabled = new_enabled
		count_text = new_count
		cooldown = new_cooldown
		queue_redraw()

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.03, 0.06, 0.09, 0.95))
		if icon != null:
			draw_texture_rect(icon, rect.grow(-3.0), false, Color.WHITE if enabled else Color(0.35, 0.35, 0.38))
		if cooldown > 0.0:
			var center: Vector2 = size * 0.5
			var points: PackedVector2Array = PackedVector2Array([center])
			var start: float = -PI * 0.5
			var steps: int = 24
			for i in range(steps + 1):
				var a: float = start + TAU * cooldown * float(i) / float(steps)
				points.append(center + Vector2(cos(a), sin(a)) * size.x)
			draw_colored_polygon(points, Color(0, 0, 0, 0.55))
		var border: Color = UiKit.COLOR_GOLD_LIGHT if highlight else (UiKit.COLOR_GOLD if enabled else UiKit.COLOR_GOLD_DARK)
		draw_rect(rect, border, false, 2.0)
		if key_text != "":
			var key_width: float = 12.0 + 8.0 * key_text.length()
			var key_rect: Rect2 = Rect2(Vector2(-4, -6), Vector2(key_width, 18))
			draw_rect(key_rect, Color(0.02, 0.04, 0.06))
			draw_rect(key_rect, UiKit.COLOR_GOLD_DARK, false, 1.0)
			draw_string(_font, Vector2(key_rect.position.x + 5, key_rect.position.y + 14), key_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.COLOR_GOLD_LIGHT)
		if count_text != "":
			var text_size: Vector2 = _font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
			var pos: Vector2 = Vector2(size.x - text_size.x - 4, size.y - 5)
			draw_string_outline(_font, pos, count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0))
			draw_string(_font, pos, count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1))


class DayClock extends Control:
	var progress: float = 0.0   # 0..1 through the current phase
	var phase: int = 0
	var _font: Font = null

	func _init() -> void:
		_font = Fx.title_font(800)
		custom_minimum_size = Vector2(64, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_phase_progress(new_phase: int, new_progress: float) -> void:
		phase = new_phase
		progress = clampf(new_progress, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 2.0
		var is_night: bool = phase == TimeManager.Phase.NIGHT
		var sky: Color = Color(0.05, 0.07, 0.2) if is_night else Color(0.25, 0.55, 0.85)
		if phase == TimeManager.Phase.SUNSET:
			sky = Color(0.75, 0.35, 0.3)
		elif phase == TimeManager.Phase.DAWN:
			sky = Color(0.85, 0.6, 0.5)
		draw_circle(center, radius, sky)
		# Remaining time as a dark wedge sweeping clockwise.
		var points: PackedVector2Array = PackedVector2Array([center])
		for i in range(33):
			var a: float = -PI * 0.5 + TAU * progress * float(i) / 32.0
			points.append(center + Vector2(cos(a), sin(a)) * radius)
		if progress > 0.001:
			draw_colored_polygon(points, Color(0, 0, 0, 0.35))
		# Sun or moon.
		if is_night:
			draw_circle(center, radius * 0.42, Color(0.92, 0.94, 1.0))
			draw_circle(center + Vector2(radius * 0.18, -radius * 0.12), radius * 0.36, Color(0.05, 0.07, 0.2))
		else:
			for i in range(8):
				var a: float = TAU * float(i) / 8.0
				draw_line(center + Vector2(cos(a), sin(a)) * radius * 0.5,
					center + Vector2(cos(a), sin(a)) * radius * 0.72, Color(1.0, 0.85, 0.35), 3.0)
			draw_circle(center, radius * 0.38, Color(1.0, 0.85, 0.35))
		draw_arc(center, radius, 0.0, TAU, 48, UiKit.COLOR_GOLD_DARK, 4.0, true)
		draw_arc(center, radius + 1.5, 0.0, TAU, 48, UiKit.COLOR_GOLD, 1.5, true)


## Vector pictograms for a text-light, kid-friendly UI. Drawn in code,
## so they scale crisply and need no image assets.
class Glyph extends Control:
	var kind: String = "star"
	var color: Color = Color(1, 0.85, 0.35)
	var outline: Color = Color(0.06, 0.04, 0.03, 0.9)

	func _init(glyph_kind: String = "star", glyph_color: Color = Color(1, 0.85, 0.35), min_size: float = 32.0) -> void:
		kind = glyph_kind
		color = glyph_color
		custom_minimum_size = Vector2(min_size, min_size)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_kind(new_kind: String, new_color: Color = color) -> void:
		kind = new_kind
		color = new_color
		queue_redraw()

	func _poly(points: PackedVector2Array, fill: Color) -> void:
		var outline_points: PackedVector2Array = points.duplicate()
		outline_points.append(points[0])
		draw_polyline(outline_points, outline, 3.0, true)
		draw_colored_polygon(points, fill)

	func _star(c: Vector2, r: float, fill: Color) -> void:
		var pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var a: float = -PI / 2 + i * PI / 5
			var rr: float = r if i % 2 == 0 else r * 0.45
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		_poly(pts, fill)

	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		var c: Vector2 = size * 0.5
		var r: float = s * 0.42
		match kind:
			"star":
				_star(c, r, color)
			"star_empty":
				_star(c, r, Color(0.2, 0.2, 0.25, 0.8))
			"moon", "moon_empty":
				var fill: Color = color if kind == "moon" else Color(0.22, 0.24, 0.35, 0.85)
				draw_circle(c, r + 1.5, outline)
				draw_circle(c, r, fill)
				draw_circle(c + Vector2(r * 0.45, -r * 0.3), r * 0.8, Color(0, 0, 0, 0) if false else _bg())
			"sun":
				for i in range(8):
					var a: float = i * TAU / 8
					draw_line(c + Vector2(cos(a), sin(a)) * r * 0.62, c + Vector2(cos(a), sin(a)) * r, color, s * 0.08, true)
				draw_circle(c, r * 0.5, color)
			"heart":
				var pts: PackedVector2Array = PackedVector2Array()
				for i in range(40):
					var t: float = i / 40.0 * TAU
					var x: float = 16 * pow(sin(t), 3)
					var y: float = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
					pts.append(c + Vector2(x, y) * r / 17.0)
				_poly(pts, color)
			"play":
				_poly(PackedVector2Array([c + Vector2(-r * 0.6, -r), c + Vector2(r, 0), c + Vector2(-r * 0.6, r)]), color)
			"pause":
				draw_rect(Rect2(c + Vector2(-r * 0.7, -r), Vector2(r * 0.5, r * 2)), color)
				draw_rect(Rect2(c + Vector2(r * 0.2, -r), Vector2(r * 0.5, r * 2)), color)
			"help":
				draw_circle(c, r, color)
				draw_arc(c + Vector2(0, -r * 0.2), r * 0.35, PI, TAU + PI * 0.4, 16, outline, s * 0.09, true)
				draw_line(c + Vector2(0, r * 0.05), c + Vector2(0, r * 0.3), outline, s * 0.09)
				draw_circle(c + Vector2(0, r * 0.55), s * 0.05, outline)
			"home":
				_poly(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(r * 0.7, 0), c + Vector2(r * 0.7, r),
					c + Vector2(-r * 0.7, r), c + Vector2(-r * 0.7, 0), c + Vector2(-r, 0)]), color)
			"restart":
				draw_arc(c, r * 0.8, -PI * 0.3, PI * 1.5, 24, color, s * 0.12, true)
				_poly(PackedVector2Array([c + Vector2(r * 0.35, -r * 1.05), c + Vector2(r * 1.0, -r * 0.55), c + Vector2(r * 0.25, -r * 0.2)]), color)
			"close":
				draw_line(c + Vector2(-r, -r) * 0.75, c + Vector2(r, r) * 0.75, color, s * 0.16, true)
				draw_line(c + Vector2(r, -r) * 0.75, c + Vector2(-r, r) * 0.75, color, s * 0.16, true)
			"check":
				draw_polyline(PackedVector2Array([c + Vector2(-r * 0.8, 0), c + Vector2(-r * 0.2, r * 0.6), c + Vector2(r * 0.85, -r * 0.6)]),
					color, s * 0.16, true)
			"shield":
				_poly(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.85, -r * 0.6), c + Vector2(r * 0.7, r * 0.3),
					c + Vector2(0, r), c + Vector2(-r * 0.7, r * 0.3), c + Vector2(-r * 0.85, -r * 0.6)]), color)
			"footsteps":
				for side in [-1, 1]:
					var fc: Vector2 = c + Vector2(side * r * 0.4, side * r * 0.35)
					draw_set_transform(fc, side * 0.25, Vector2(0.55, 1.0))
					draw_circle(Vector2.ZERO, r * 0.45, color)
					draw_set_transform(Vector2.ZERO)
			"basket":
				draw_arc(c + Vector2(0, -r * 0.1), r * 0.6, PI, TAU, 16, color, s * 0.08, true)
				_poly(PackedVector2Array([c + Vector2(-r, -r * 0.1), c + Vector2(r, -r * 0.1), c + Vector2(r * 0.7, r),
					c + Vector2(-r * 0.7, r)]), color)
			"zzz":
				var font: Font = Fx.bold_font()
				draw_string_outline(font, c + Vector2(-r * 0.9, r * 0.5), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.5), 4, outline)
				draw_string(font, c + Vector2(-r * 0.9, r * 0.5), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.5), color)
				draw_string_outline(font, c + Vector2(-r * 0.1, r * 0.0), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.7), 4, outline)
				draw_string(font, c + Vector2(-r * 0.1, r * 0.0), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.7), color)
			"mouse_left", "mouse_right":
				# Rounded mouse with the pressed button lit up and a little cable.
				var body: Rect2 = Rect2(c + Vector2(-r * 0.62, -r * 0.8), Vector2(r * 1.24, r * 1.8))
				draw_line(c + Vector2(0, -r * 0.8), c + Vector2(r * 0.25, -r * 1.05), outline, 3.0)
				var shell: StyleBoxFlat = StyleBoxFlat.new()
				shell.bg_color = Color(0.93, 0.93, 0.96)
				shell.set_corner_radius_all(int(r * 0.6))
				shell.border_color = outline
				shell.set_border_width_all(2)
				draw_style_box(shell, body)
				var button: StyleBoxFlat = StyleBoxFlat.new()
				button.bg_color = color
				var left: bool = kind == "mouse_left"
				var radius: int = int(r * 0.58)
				button.corner_radius_top_left = radius if left else 0
				button.corner_radius_top_right = 0 if left else radius
				var half: Rect2 = Rect2(body.position + Vector2(2 if left else body.size.x * 0.5, 2),
					Vector2(body.size.x * 0.5 - 2, body.size.y * 0.42))
				draw_style_box(button, half)
				draw_line(body.position + Vector2(body.size.x * 0.5, 0), body.position + Vector2(body.size.x * 0.5, body.size.y * 0.44), outline, 2.0)
				draw_line(body.position + Vector2(0, body.size.y * 0.44), body.position + Vector2(body.size.x, body.size.y * 0.44), outline, 2.0)
			"arrow":
				_poly(PackedVector2Array([c + Vector2(-r, -r * 0.25), c + Vector2(r * 0.2, -r * 0.25), c + Vector2(r * 0.2, -r * 0.65),
					c + Vector2(r, 0), c + Vector2(r * 0.2, r * 0.65), c + Vector2(r * 0.2, r * 0.25), c + Vector2(-r, r * 0.25)]), color)
			"trophy":
				_poly(PackedVector2Array([c + Vector2(-r * 0.7, -r), c + Vector2(r * 0.7, -r), c + Vector2(r * 0.5, -r * 0.1),
					c + Vector2(r * 0.15, r * 0.2), c + Vector2(r * 0.15, r * 0.6), c + Vector2(r * 0.55, r),
					c + Vector2(-r * 0.55, r), c + Vector2(-r * 0.15, r * 0.6), c + Vector2(-r * 0.15, r * 0.2), c + Vector2(-r * 0.5, -r * 0.1)]), color)
				draw_arc(c + Vector2(-r * 0.7, -r * 0.55), r * 0.3, PI * 0.5, PI * 1.5, 10, color, s * 0.06)
				draw_arc(c + Vector2(r * 0.7, -r * 0.55), r * 0.3, -PI * 0.5, PI * 0.5, 10, color, s * 0.06)
			"fire":
				_poly(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.55, -r * 0.1), c + Vector2(r * 0.7, r * 0.4),
					c + Vector2(r * 0.35, r), c + Vector2(-r * 0.35, r), c + Vector2(-r * 0.7, r * 0.4), c + Vector2(-r * 0.3, -r * 0.2),
					c + Vector2(-r * 0.1, r * 0.1)]), color)
				_poly(PackedVector2Array([c + Vector2(0, -r * 0.1), c + Vector2(r * 0.3, r * 0.55), c + Vector2(0, r * 0.9),
					c + Vector2(-r * 0.3, r * 0.55)]), Color(1.0, 0.92, 0.5))

	func _bg() -> Color:
		return Color(0.02, 0.05, 0.08, 1.0)


## Button showing a glyph (or texture) with an optional short word.
static func icon_button(glyph_kind: String, caption: String, on_pressed: Callable, color: Color = UiKit.COLOR_GOLD,
		texture: Texture2D = null, focusable: bool = true) -> Button:
	var button: Button = Button.new()
	button.text = ("      " + caption.to_upper()) if caption != "" else ""
	button.custom_minimum_size = Vector2(250 if caption != "" else 64, 58)
	button.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(func() -> void: AudioManager.play_sfx(&"ui_click"))
	button.pressed.connect(on_pressed)
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_CENTER_LEFT if caption != "" else Control.PRESET_CENTER)
	holder.position = Vector2(14, -20) if caption != "" else Vector2(-20, -20)
	if texture != null:
		var rect: TextureRect = TextureRect.new()
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size = Vector2(40, 40)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(rect)
	else:
		var glyph: Glyph = Glyph.new(glyph_kind, color, 40)
		glyph.size = Vector2(40, 40)
		holder.add_child(glyph)
	button.add_child(holder)
	return button


## Icon + number row (e.g. imp icon x 7) for stat lists.
static func icon_count(texture: Texture2D, glyph_kind: String, count_text: String, size_px: float = 40.0) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture != null:
		var rect: TextureRect = TextureRect.new()
		rect.texture = texture
		rect.custom_minimum_size = Vector2(size_px, size_px)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(rect)
	else:
		row.add_child(Glyph.new(glyph_kind, UiKit.COLOR_GOLD, size_px))
	var label: Label = UiKit.label(count_text, int(size_px * 0.6))
	label.add_theme_font_override("font", Fx.bold_font())
	label.add_theme_constant_override("outline_size", 6)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row
