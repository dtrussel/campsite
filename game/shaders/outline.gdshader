shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, skip_vertex_transform;

// Soft cartoon outline (inverted hull), used as next_pass on characters
// and enemies so kids can always pick them out. The hull is pushed out
// along the view-space normal by a fixed number of world units.

uniform vec4 outline_color : source_color = vec4(0.07, 0.04, 0.09, 1.0);
uniform float thickness = 0.018;

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	view_pos.xyz += view_normal * thickness;
	VERTEX = view_pos.xyz;
	NORMAL = view_normal;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
