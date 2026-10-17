shader_type spatial;
// Painted foliage with wind (feature 024). Same look as Stylize's
// painted props (painted_prop.gdshader: wrap-lit, matte, soft rim),
// plus a sway: whole crowns lean with slow gusts and leaves flutter.
// The trunk stays put: sway fades in from `sway_start` of the height.
// Feature 031 M4: the shared painted finish (sunny crown tops, warm
// shaded undersides, leaf texel detail).
render_mode diffuse_lambert_wrap, specular_disabled, cull_disabled;

#include "res://shaders/painted_common.gdshaderinc"

uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
// The mesh's local bounds (bottom and height), set per mesh.
uniform float base_y = 0.0;
uniform float height = 2.0;
uniform float sway_start = 0.3;
uniform float strength = 0.035;
uniform float speed = 1.1;
uniform float rim_amount = 0.15;
uniform float rim_tint_amount = 0.75;

varying vec3 local_pos;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	local_pos = VERTEX;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = clamp((VERTEX.y - base_y) / max(height, 0.01), 0.0, 1.0);
	float w = smoothstep(sway_start, 1.0, h);
	float phase = origin.x * 0.31 + origin.z * 0.23;
	float gust = sin(TIME * speed + phase) * 0.7 + sin(TIME * speed * 2.3 + phase * 1.7) * 0.3;
	float flutter = sin(TIME * 5.0 + VERTEX.x * 5.0 + VERTEX.z * 4.0) * 0.18;
	VERTEX.x += (gust + flutter) * strength * w * height;
	VERTEX.z += (gust * 0.5 - flutter * 0.5) * strength * w * height;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 c = texture(albedo_texture, UV) * albedo_color;
	// Double-sided leaves (M8): a leaf seen from behind shades as its front.
	vec3 n = normalize(world_normal) * (FRONT_FACING ? 1.0 : -1.0);
	ALBEDO = painted_finish(c.rgb, local_pos, world_pos, n);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	RIM = rim_amount;
	RIM_TINT = rim_tint_amount;
}
