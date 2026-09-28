shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;

// Hover highlight overlay: a bright fresnel rim plus a faint body tint,
// used as material_overlay on whatever the pointer is over.

uniform vec4 rim_color : source_color = vec4(1.0, 0.3, 0.2, 1.0);
uniform float rim_power = 2.2;
uniform float body = 0.12;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float pulse = 0.85 + 0.15 * sin(TIME * 6.0);
	ALBEDO = rim_color.rgb * (fresnel * 1.6 + body) * pulse;
}
