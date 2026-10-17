class_name HudWidgets
extends RefCounted

## HudWidgets
##
## Hand-drawn (Control._draw) HUD pieces in the campcraft style
## (feature 033): wood, brass and canvas, matching UiKit.
##   StatBar     - rounded bar in a warm trough: gradient fill, sheen,
##                 damage trail, brass ticks, optional text
##   Portrait    - round character portrait, brass ring, canvas level badge
##   AbilitySlot - brass-framed slot with a canvas key tab, count, cooldown
##   DayClock    - sun/moon medallion showing progress through the phase


class StatBar extends Control:
	var value: float = 1.0
	var max_value: float = 1.0
	var fill_color: Color = UiKit.COLOR_LEAF
	var fill_top: Color = Color(0.7, 0.92, 0.45)
	var tick_every: float = 10.0
	var show_text: bool = true
	var text_override: String = ""
	var _trail: float = 0.0
	var _font: Font = null

	func _init(color: Color = UiKit.COLOR_LEAF, top: Color = Color(0.7, 0.92, 0.45)) -> void:
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

	func _box(rect: Rect2, color: Color, radius: float) -> void:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(int(minf(radius, rect.size.x * 0.5)))
		box.anti_aliasing = true
		draw_style_box(box, rect)

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		var radius: float = size.y * 0.5
		# Brass rim, ink line, warm dark trough.
		_box(rect, UiKit.COLOR_BRASS_DARK, radius)
		_box(rect.grow(-1.0), UiKit.COLOR_INK, radius - 1.0)
		var inner: Rect2 = rect.grow(-2.0)
		_box(inner, Color(0.12, 0.07, 0.04, 0.96), radius - 2.0)
		var ratio: float = clampf(value / max_value, 0.0, 1.0)
		var inner_radius: float = inner.size.y * 0.5
		if _trail > ratio:
			_box(Rect2(inner.position, Vector2(inner.size.x * _trail, inner.size.y)), Color(1.0, 0.9, 0.7, 0.85), inner_radius)
		if ratio > 0.0:
			var fill: Rect2 = Rect2(inner.position, Vector2(maxf(inner.size.x * ratio, inner.size.y), inner.size.y))
			_box(fill, fill_color, inner_radius)
			_box(Rect2(fill.position + Vector2(1, 1), Vector2(fill.size.x - 2, fill.size.y * 0.42)), fill_top, inner_radius)
			# Glossy sheen line along the top.
			if fill.size.y >= 8.0:
				draw_line(fill.position + Vector2(inner_radius, 2), fill.position + Vector2(fill.size.x - inner_radius, 2),
					Color(1, 1, 1, 0.35), 1.0)
		if tick_every > 0.0 and max_value / tick_every <= 40.0:
			var ticks: int = int(max_value / tick_every)
			for i in range(1, ticks + 1):
				var x: float = inner.position.x + inner.size.x * (float(i) * tick_every / max_value)
				if x < inner.end.x - 2.0:
					draw_line(Vector2(x, inner.position.y + 1), Vector2(x, inner.position.y + inner.size.y * 0.5), Color(0.16, 0.09, 0.05, 0.6), 1.0)
		if show_text and size.y >= 12.0:
			var text: String = text_override if text_override != "" else "%d / %d" % [int(value), int(max_value)]
			var font_size: int = int(size.y * 0.74)
			var text_size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var pos: Vector2 = Vector2((size.x - text_size.x) * 0.5, (size.y + text_size.y * 0.62) * 0.5)
			draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, UiKit.COLOR_INK)
			draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiKit.COLOR_TEXT)


## Cream canvas disc with ink digits (level badges).
static func draw_badge(canvas: CanvasItem, center: Vector2, radius: float, text: String, font: Font) -> void:
	canvas.draw_circle(center, radius + 1.5, UiKit.COLOR_INK)
	canvas.draw_circle(center, radius, UiKit.COLOR_BRASS)
	canvas.draw_circle(center, radius - 2.0, UiKit.COLOR_CANVAS)
	var font_size: int = int(radius * 1.15)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	canvas.draw_string(font, center + Vector2(-text_size.x * 0.5, font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, UiKit.COLOR_INK)


class Portrait extends Control:
	var texture: Texture2D = null
	var level: int = 1
	var ring_color: Color = UiKit.COLOR_BRASS
	var dimmed: bool = false
	var show_level: bool = true
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
		var radius: float = minf(size.x, size.y) * 0.5 - 4.0
		# Wood backing disc, then the face, then a double brass ring.
		draw_circle(center, radius + 4.0, UiKit.COLOR_INK)
		draw_circle(center, radius + 2.5, UiKit.COLOR_WOOD_LIGHT)
		draw_circle(center, radius, Color(0.32, 0.22, 0.14))
		if texture != null:
			var points: PackedVector2Array = PackedVector2Array()
			var uvs: PackedVector2Array = PackedVector2Array()
			for i in range(40):
				var a: float = TAU * float(i) / 40.0
				var dir: Vector2 = Vector2(cos(a), sin(a))
				points.append(center + dir * radius)
				uvs.append(Vector2(0.5, 0.5) + dir * 0.5)
			var tint: Color = Color(0.5, 0.45, 0.42) if dimmed else Color.WHITE
			draw_colored_polygon(points, tint, uvs, texture)
		draw_arc(center, radius + 1.0, 0.0, TAU, 48, UiKit.COLOR_BRASS_DARK, 3.0, true)
		draw_arc(center, radius + 3.0, 0.0, TAU, 48, ring_color, 2.0, true)
		draw_arc(center, radius + 3.0, PI * 1.1, PI * 1.9, 24, Color(1.0, 0.9, 0.65, 0.8), 1.0, true)
		if show_level:
			HudWidgets.draw_badge(self, center + Vector2(radius * 0.7, radius * 0.7), clampf(radius * 0.3, 9.0, 13.0), str(level), _font)


class AbilitySlot extends Control:
	var icon: Texture2D = null
	var key_text: String = ""
	var count_text: String = ""
	var cooldown: float = 0.0   # 0..1 remaining
	var enabled: bool = true
	var highlight: bool = false:
		set(value):
			if value != highlight:
				highlight = value
				queue_redraw()
	var _font: Font = null
	var _frame: StyleBox = null

	func _init(tex: Texture2D = null, key: String = "") -> void:
		icon = tex
		key_text = key
		_font = Fx.bold_font()
		_frame = UiKit.art_style("slot", 0)
		custom_minimum_size = Vector2(48, 48)
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
		if highlight:
			draw_style_box(_glow(), rect.grow(3.0))
		draw_style_box(_frame, rect)
		if icon != null:
			draw_texture_rect(icon, rect.grow(-5.0), false, Color.WHITE if enabled else Color(0.5, 0.43, 0.38, 0.75))
		if cooldown > 0.0:
			var center: Vector2 = size * 0.5
			var points: PackedVector2Array = PackedVector2Array([center])
			var start: float = -PI * 0.5
			var steps: int = 24
			for i in range(steps + 1):
				var a: float = start + TAU * cooldown * float(i) / float(steps)
				points.append(center + (Vector2(cos(a), sin(a)) * size.x).clamp(-size * 0.5 + Vector2(4, 4), size * 0.5 - Vector2(4, 4)))
			draw_colored_polygon(points, Color(0.12, 0.06, 0.03, 0.6))
		if key_text != "":
			# Cream canvas tab pinned to the top-left corner.
			var key_width: float = 10.0 + 7.0 * key_text.length()
			var key_rect: Rect2 = Rect2(Vector2(-3, -5), Vector2(key_width, 16))
			var tab: StyleBoxFlat = UiKit.flat_style(UiKit.COLOR_CANVAS, UiKit.COLOR_INK, 1, 4)
			draw_style_box(tab, key_rect)
			draw_string(_font, Vector2(key_rect.position.x + 5, key_rect.position.y + 12.5), key_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.COLOR_INK)
		if count_text != "":
			var text_size: Vector2 = _font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
			var pos: Vector2 = Vector2(size.x - text_size.x - 4, size.y - 5)
			draw_string_outline(_font, pos, count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, UiKit.COLOR_INK)
			draw_string(_font, pos, count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiKit.COLOR_TEXT)

	func _glow() -> StyleBoxFlat:
		var box: StyleBoxFlat = UiKit.flat_style(Color(0, 0, 0, 0), Color(1.0, 0.78, 0.35, 0.95), 2, 10)
		box.draw_center = false
		box.shadow_color = Color(1.0, 0.6, 0.15, 0.55)
		box.shadow_size = 6
		return box


class DayClock extends Control:
	var progress: float = 0.0   # 0..1 through the current phase
	var phase: int = 0
	var _font: Font = null

	func _init() -> void:
		_font = Fx.title_font(800)
		custom_minimum_size = Vector2(56, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_phase_progress(new_phase: int, new_progress: float) -> void:
		new_progress = clampf(new_progress, 0.0, 1.0)
		if new_phase == phase and absf(new_progress - progress) < 0.002:
			return
		phase = new_phase
		progress = new_progress
		queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 3.0
		var is_night: bool = phase == TimeManager.Phase.NIGHT
		# Sky tied to the game's grade: golden day, rose sunset, moon-blue night.
		var sky: Color = Color(0.95, 0.66, 0.3)
		var sky_top: Color = Color(1.0, 0.84, 0.5)
		if is_night:
			sky = Color(0.1, 0.13, 0.32)
			sky_top = Color(0.2, 0.26, 0.52)
		elif phase == TimeManager.Phase.SUNSET:
			sky = Color(0.78, 0.36, 0.32)
			sky_top = Color(0.95, 0.56, 0.4)
		elif phase == TimeManager.Phase.DAWN:
			sky = Color(0.86, 0.6, 0.55)
			sky_top = Color(1.0, 0.8, 0.62)
		draw_circle(center, radius + 3.0, UiKit.COLOR_INK)
		draw_circle(center, radius, sky)
		draw_circle(center + Vector2(0, -radius * 0.35), radius * 0.62, Color(sky_top, 0.55))
		# Elapsed time as a darker wedge sweeping clockwise.
		if progress > 0.001:
			var points: PackedVector2Array = PackedVector2Array([center])
			for i in range(33):
				var a: float = -PI * 0.5 + TAU * progress * float(i) / 32.0
				points.append(center + Vector2(cos(a), sin(a)) * radius)
			draw_colored_polygon(points, Color(0.16, 0.08, 0.04, 0.32))
		if is_night:
			draw_circle(center, radius * 0.42, Color(0.95, 0.94, 0.86))
			draw_circle(center + Vector2(radius * 0.2, -radius * 0.14), radius * 0.36, Color(sky, 1.0).lerp(sky_top, 0.25))
		else:
			for i in range(8):
				var a: float = TAU * float(i) / 8.0 + PI / 8.0
				draw_line(center + Vector2(cos(a), sin(a)) * radius * 0.52,
					center + Vector2(cos(a), sin(a)) * radius * 0.74, Color(1.0, 0.95, 0.7), 3.0, true)
			draw_circle(center, radius * 0.4, Color(1.0, 0.95, 0.7))
			draw_circle(center, radius * 0.3, Color(1.0, 0.86, 0.45))
		# Brass ring with four notches and a hand pointing at "now".
		draw_arc(center, radius + 1.0, 0.0, TAU, 48, UiKit.COLOR_BRASS_DARK, 3.0, true)
		draw_arc(center, radius + 2.5, 0.0, TAU, 48, UiKit.COLOR_BRASS, 2.0, true)
		for i in range(4):
			var a: float = TAU * float(i) / 4.0 - PI * 0.5
			draw_line(center + Vector2(cos(a), sin(a)) * (radius - 3.0), center + Vector2(cos(a), sin(a)) * (radius + 2.0),
				UiKit.COLOR_BRASS, 2.0, true)
		var hand: float = -PI * 0.5 + TAU * progress
		var tip: Vector2 = center + Vector2(cos(hand), sin(hand)) * (radius + 1.0)
		draw_circle(tip, 3.5, UiKit.COLOR_INK)
		draw_circle(tip, 2.5, UiKit.COLOR_CANVAS)


## Vector pictograms for a text-light, kid-friendly UI. Drawn in code,
## so they scale crisply and need no image assets.
## The Moon Lantern's light (feature 036): a dark moon that fills slice
## by slice, one per lantern stage.
class LanternDial extends Control:
	var stage: int = 0
	var max_stage: int = 3

	func _init() -> void:
		custom_minimum_size = Vector2(40, 40)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_stage(new_stage: int, new_max: int) -> void:
		if new_stage == stage and new_max == max_stage:
			return
		stage = new_stage
		max_stage = maxi(1, new_max)
		tooltip_text = "Moon Lantern %d / %d" % [stage, max_stage]
		queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 3.0
		draw_circle(center, radius + 3.0, UiKit.COLOR_INK)
		draw_circle(center, radius, Color(0.1, 0.12, 0.26))
		var lit: Color = UiKit.COLOR_MOON.lightened(0.35)
		var step: float = TAU / float(max_stage)
		for i in range(stage):
			var points: PackedVector2Array = PackedVector2Array([center])
			for k in range(9):
				var a: float = -PI / 2.0 + step * (i + k / 8.0)
				points.append(center + Vector2(cos(a), sin(a)) * radius)
			draw_colored_polygon(points, lit)
		for i in range(max_stage):
			var a: float = -PI / 2.0 + step * i
			draw_line(center, center + Vector2(cos(a), sin(a)) * radius, UiKit.COLOR_INK, 1.5, true)
		if stage >= max_stage:
			draw_circle(center, radius * 0.35, Color(1.0, 0.98, 0.85))
		draw_arc(center, radius + 1.0, 0.0, TAU, 48, UiKit.COLOR_BRASS, 2.0, true)


class Glyph extends Control:
	var kind: String = "star"
	var color: Color = Color(1, 0.85, 0.35)
	var outline: Color = Color(0.157, 0.094, 0.055, 0.92)

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
				_star(c, r, Color(0.36, 0.27, 0.2, 0.85))
			"moon", "moon_empty":
				var fill: Color = color if kind == "moon" else Color(0.45, 0.36, 0.27, 0.9)
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
			"hammer":
				# Handle from bottom-left to the head at the top-right.
				draw_line(c + Vector2(-r * 0.75, r * 0.8), c + Vector2(r * 0.25, -r * 0.2), outline, s * 0.2, true)
				draw_line(c + Vector2(-r * 0.75, r * 0.8), c + Vector2(r * 0.25, -r * 0.2), Color(0.85, 0.62, 0.38), s * 0.12, true)
				var head: PackedVector2Array = PackedVector2Array([c + Vector2(-r * 0.05, -r * 0.55), c + Vector2(r * 0.45, -r * 1.0),
					c + Vector2(r * 1.0, -r * 0.45), c + Vector2(r * 0.55, 0.0)])
				_poly(head, color)
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

	## Moon cut-outs take the plate's wood colour.
	func _bg() -> Color:
		return Color(0.2, 0.12, 0.07, 1.0)


## Button showing a glyph (or texture) with an optional short word.
## `height` scales an icon-only button (and its glyph) down from 58 px.
static func icon_button(glyph_kind: String, caption: String, on_pressed: Callable, color: Color = UiKit.COLOR_GOLD,
		texture: Texture2D = null, focusable: bool = true, height: float = 58.0) -> Button:
	var button: Button = Button.new()
	button.text = ("      " + caption.to_upper()) if caption != "" else ""
	var icon_px: float = roundf(40.0 * height / 58.0)
	button.custom_minimum_size = Vector2(250 if caption != "" else height + 6.0, height)
	button.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(func() -> void: AudioManager.play_sfx(&"ui_click"))
	button.pressed.connect(on_pressed)
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_CENTER_LEFT if caption != "" else Control.PRESET_CENTER)
	holder.position = Vector2(14, -icon_px * 0.5) if caption != "" else Vector2(-icon_px * 0.5, -icon_px * 0.5)
	if texture != null:
		var rect: TextureRect = TextureRect.new()
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size = Vector2(icon_px, icon_px)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(rect)
	else:
		var glyph: Glyph = Glyph.new(glyph_kind, color, icon_px)
		glyph.size = Vector2(icon_px, icon_px)
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
