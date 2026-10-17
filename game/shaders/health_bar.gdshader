shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled, blend_mix;

// Unit health bar on a camera-facing quad, in the HUD's campcraft style:
// a brass rim around an ink line and a warm dark trough, a fill with a
// lit top half, a pale "recent damage" trail that drains after the fill,
// and thin tick marks every `segment_hp` hit points. Corners are clipped.

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float trail : hint_range(0.0, 1.0) = 1.0;
uniform float max_hp = 100.0;
uniform float segment_hp = 10.0;
uniform vec4 fill_color : source_color = vec4(0.25, 0.85, 0.3, 1.0);
uniform vec4 fill_color_top : source_color = vec4(0.55, 1.0, 0.5, 1.0);
uniform vec4 back_color : source_color = vec4(0.12, 0.07, 0.04, 0.92);
uniform vec4 frame_color : source_color = vec4(0.157, 0.094, 0.055, 1.0);
uniform vec4 rim_color : source_color = vec4(0.79, 0.59, 0.29, 1.0);
uniform vec4 trail_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float border_px = 0.16; // in UV-y units

void vertex() {
	// Full billboard, preserving the node's scale.
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	vec3 world = MODEL_MATRIX[3].xyz + right * VERTEX.x * scale.x + up * VERTEX.y * scale.y;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 uv = UV;
	float aspect = 7.0; // quad is about 7x wider than tall
	float bx = border_px / aspect;
	float by = border_px;
	bool inside = uv.x > bx && uv.x < 1.0 - bx && uv.y > by && uv.y < 1.0 - by;
	// Outer half of the border is brass, inner half ink.
	float edge = min(min(uv.x * aspect, (1.0 - uv.x) * aspect), min(uv.y, 1.0 - uv.y));
	vec4 color = edge < border_px * 0.5 ? rim_color : frame_color;
	// Clip the corners for a rounded look.
	vec2 corner = vec2(min(uv.x, 1.0 - uv.x) * aspect, min(uv.y, 1.0 - uv.y));
	if (corner.x < 0.12 && corner.y < 0.12 && length(vec2(0.12) - corner) > 0.12) {
		discard;
	}
	if (inside) {
		float x = (uv.x - bx) / (1.0 - 2.0 * bx);
		float y = (uv.y - by) / (1.0 - 2.0 * by);
		color = back_color;
		if (x <= trail) {
			color = trail_color;
		}
		if (x <= fill) {
			color = mix(fill_color_top, fill_color, smoothstep(0.25, 0.6, y));
			color.rgb += vec3(0.25) * (1.0 - smoothstep(0.0, 0.18, y));
		}
		// Tick marks every segment_hp.
		float segments = max_hp / max(segment_hp, 1.0);
		float cell = fract(x * segments);
		float tick = step(cell, 0.035 * segments / 10.0) * step(0.001, x) * step(y, 0.55);
		color.rgb = mix(color.rgb, frame_color.rgb, tick * 0.85);
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
