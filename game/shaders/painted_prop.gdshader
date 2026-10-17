shader_type spatial;
// Painted props, buildings and characters (feature 031, milestone 4):
// the matte, wrap-lit, soft-rim look Stylize used to set on a
// StandardMaterial3D, plus the shared painted finish (top light,
// contact shade, texel detail) from painted_common.gdshaderinc.
render_mode diffuse_lambert_wrap, specular_disabled;

#include "res://shaders/painted_common.gdshaderinc"

uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float rim_amount = 0.15;
uniform float rim_tint_amount = 0.75;

varying vec3 local_pos;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 c = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = painted_finish(c.rgb, local_pos, world_pos, normalize(world_normal));
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	RIM = rim_amount;
	RIM_TINT = rim_tint_amount;
}
