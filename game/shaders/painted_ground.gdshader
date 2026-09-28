shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Hand-painted ground: tiling painted textures baked by
// art/ground/textures.py (grass, packed dirt, autumn leaf litter).
// A worn dirt clearing around the campfire with a ragged edge, and a
// darker, cooler leaf-litter "haunted" forest floor toward the edge
// where the night mobs come from. Two rotated samples per texture,
// blended by large-scale noise, hide the tiling.

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaves_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grass_tile = 7.0;
uniform float dirt_tile = 5.0;
uniform float leaves_tile = 5.5;
uniform vec4 edge_tint : source_color = vec4(0.46, 0.44, 0.58, 1.0);
uniform float clearing_radius = 4.2;
uniform float edge_start = 17.0;
uniform float edge_end = 30.0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

// Two differently rotated/scaled samples, cross-faded by macro noise.
vec3 untiled(sampler2D tex, vec2 p, float tile, float macro) {
	vec2 uv_a = p / tile;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	vec2 uv_b = rot * p / (tile * 1.37) + vec2(0.37, 0.71);
	vec3 a = texture(tex, uv_a).rgb;
	vec3 b = texture(tex, uv_b).rgb;
	return mix(a, b, smoothstep(0.35, 0.65, macro));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float macro = fbm(p * 0.07);
	float tint = fbm(p * 0.035 + vec2(40.0, 11.0));

	vec3 grass = untiled(grass_tex, p, grass_tile, macro);
	// Broad sunny / shady meadow patches.
	grass *= mix(vec3(0.82, 0.86, 0.9), vec3(1.1, 1.06, 0.92), smoothstep(0.3, 0.7, tint));

	// Dirt clearing around the campfire, with a ragged painted edge.
	float r = length(p);
	float ragged = (fbm(p * 0.8) - 0.5) * 1.6;
	float dirt_mask = 1.0 - smoothstep(clearing_radius - 0.5, clearing_radius + 0.3, r + ragged);
	vec3 dirt = untiled(dirt_tex, p, dirt_tile, macro);
	// Darker scorched ring right around the fire.
	dirt = mix(dirt * vec3(0.5, 0.45, 0.42), dirt, smoothstep(0.7, 1.9, r));
	// A soft darker rim where the grass is trampled.
	float rim = smoothstep(clearing_radius - 1.2, clearing_radius, r + ragged) * dirt_mask;
	dirt *= 1.0 - rim * 0.18;
	vec3 color = mix(grass, dirt, dirt_mask);

	// Haunted edge: toward the forest, leaf litter takes over and
	// colours cool and darken.
	float edge_d = max(abs(p.x), abs(p.y)) + ragged * 2.0;
	float litter = smoothstep(edge_start - 5.0, edge_start + 3.0, edge_d + (fbm(p * 0.3) - 0.5) * 6.0);
	vec3 leaves = untiled(leaves_tex, p, leaves_tile, macro);
	color = mix(color, leaves, litter * 0.85);
	float edge = smoothstep(edge_start, edge_end, edge_d);
	color = mix(color, color * edge_tint.rgb, edge * 0.8);

	ALBEDO = color;
	ROUGHNESS = 1.0;
}
