shader_type spatial;
// Blueprint ghost (feature 045): a see-through, pale-blue copy of the
// finished building over its construction site. Scrolling stripes, a
// bright fresnel edge and a slow pulse say "not built yet". Fragments
// below clip_y (world) are cut away: there the solid, built part shows
// instead, with a glowing build line just above it.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 ghost_color : source_color = vec4(0.38, 0.68, 1.0, 0.34);
uniform vec4 edge_color : source_color = vec4(0.86, 0.96, 1.0, 1.0);
uniform float clip_y = -1000.0;
uniform float stripe_spacing = 0.14;
uniform float line_width = 0.07;
// 1 on a hammer blow, decaying (set from Building.on_build_hit).
uniform float hit_flash = 0.0;
// 1 while a blueprint, tweened to 0 when the building is finished.
uniform float fade = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float above = world_pos.y - clip_y;
	if (above < 0.0) {
		discard;
	}
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float band = abs(fract(world_pos.y / stripe_spacing - TIME * 0.35) - 0.5);
	float stripe = smoothstep(0.38, 0.48, band);
	float line = 1.0 - smoothstep(0.0, line_width, above);
	float pulse = 0.85 + 0.15 * sin(TIME * 3.0);
	float glow = clamp(fres * 0.8 + stripe * 0.45 + line + hit_flash * 0.6, 0.0, 1.0);
	ALBEDO = mix(ghost_color.rgb, edge_color.rgb, glow);
	ALPHA = clamp(ghost_color.a * pulse + fres * 0.4 + stripe * 0.16 + line * 0.75 + hit_flash * 0.25, 0.0, 1.0) * fade;
}
