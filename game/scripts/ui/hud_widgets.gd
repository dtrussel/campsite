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
