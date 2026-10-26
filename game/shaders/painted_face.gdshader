shader_type spatial;
// The front of a painted head (the face atlas): painted_prop's look, with
// the face window (brows, eyes, nose, mouth) replaced by the atlas cell
// of the state shown (a blink, a cheer, a hit, being down). UV2 is the
// head's front-projected face plane; a cell's alpha fades its edge into
// the baked head texture. CharacterVisual sets the cell.
render_mode diffuse_lambert_wrap, specular_disabled;

#include "res://shaders/painted_common.gdshaderinc"

uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float rim_amount = 0.15;
uniform float rim_tint_amount = 0.75;
uniform sampler2D face_atlas : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;
// The window in face-plane UV2 (x, y, width, height).
uniform vec4 face_window = vec4(0.0, 0.0, 1.0, 1.0);
// The shown cell's top-left corner and every cell's size, in atlas UV.
uniform vec2 cell_origin = vec2(0.0);
uniform vec2 cell_size = vec2(0.0);

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
	vec2 at = (UV2 - face_window.xy) / face_window.zw;
	float inside = step(0.0, at.x) * step(at.x, 1.0) * step(0.0, at.y) * step(at.y, 1.0);
	vec4 cell = texture(face_atlas, cell_origin + clamp(at, vec2(0.0), vec2(1.0)) * cell_size);
	c.rgb = mix(c.rgb, cell.rgb * albedo_color.rgb, cell.a * inside);
	ALBEDO = painted_finish(c.rgb, local_pos, world_pos, normalize(world_normal));
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	RIM = rim_amount;
	RIM_TINT = rim_tint_amount;
}
