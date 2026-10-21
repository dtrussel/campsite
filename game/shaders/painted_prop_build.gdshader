shader_type spatial;
// A painted prop under construction (feature 045): painted_prop's
// finish, cut off above build_clip_y (world) so the building rises out
// of its site from the bottom up while the blueprint ghost shows the
// rest. Back faces show through the cut as shaded insides, and fresh
// timber just under the cut is a little paler.
render_mode diffuse_lambert_wrap, specular_disabled, cull_disabled;

#include "res://shaders/painted_common.gdshaderinc"

uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float rim_amount = 0.15;
uniform float rim_tint_amount = 0.75;
uniform float build_clip_y = 100000.0;

varying vec3 local_pos;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float below = build_clip_y - world_pos.y;
	if (below < 0.0) {
		discard;
	}
	vec4 c = texture(albedo_texture, UV) * albedo_color;
	vec3 albedo = painted_finish(c.rgb, local_pos, world_pos, normalize(world_normal));
	albedo = mix(albedo, albedo * 1.25 + vec3(0.05, 0.04, 0.0), (1.0 - smoothstep(0.0, 0.05, below)) * 0.6);
	ALBEDO = FRONT_FACING ? albedo : albedo * 0.4;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	RIM = rim_amount;
	RIM_TINT = rim_tint_amount;
}
