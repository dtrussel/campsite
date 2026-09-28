shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled, blend_mix;

// LoL-style unit health bar on a camera-facing quad: dark frame, fill,
// a pale "recent damage" trail that drains after the fill, and thin
// tick marks every `segment_hp` hit points.

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float trail : hint_range(0.0, 1.0) = 1.0;
uniform float max_hp = 100.0;
uniform float segment_hp = 10.0;
uniform vec4 fill_color : source_color = vec4(0.25, 0.85, 0.3, 1.0);
uniform vec4 fill_color_top : source_color = vec4(0.55, 1.0, 0.5, 1.0);
uniform vec4 back_color : source_color = vec4(0.05, 0.05, 0.07, 0.9);
uniform vec4 frame_color : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform vec4 trail_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float border_px = 0.06; // in UV-y units

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
	vec4 color = frame_color;
	if (inside) {
		float x = (uv.x - bx) / (1.0 - 2.0 * bx);
		float y = (uv.y - by) / (1.0 - 2.0 * by);
		color = back_color;
		if (x <= trail) {
			color = trail_color;
		}
		if (x <= fill) {
			color = mix(fill_color_top, fill_color, smoothstep(0.0, 0.8, y));
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
