shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Hand-painted ground: tiling painted textures baked by
// art/ground/textures.py (grass, packed dirt, autumn leaf litter).
// A worn dirt clearing around the campfire with a ragged edge, and a
// darker, cooler leaf-litter "haunted" forest floor toward the edge
// where the night mobs come from. Two rotated samples per texture,
// blended by large-scale noise, hide the tiling. Milestone 4 of
// feature 031: fine texel mottling (HD-2D target).
// Feature 032: the map plan (WorldLayout pushes it at load) paints
// footpaths, a ground per grove, trodden mob-lane trails and the
// pond's mud bank.

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaves_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grass_tile = 7.0;
uniform float dirt_tile = 5.0;
uniform float leaves_tile = 5.5;
uniform vec4 edge_tint : source_color = vec4(0.56, 0.5, 0.54, 1.0);
uniform float clearing_radius = 5.4;
// Set by WorldLayout.apply_to_ground(): path segments (ax, az, bx, bz)
// with half-widths, groves (cx, cz, radius, zone) and the pond
// (cx, cz, radius).
uniform vec4 path_segments[24];
uniform float path_widths[24];
uniform int path_count = 0;
uniform vec4 groves[4];
uniform vec3 pond = vec3(0.0, 0.0, 0.0);
uniform vec4 needle_tint : source_color = vec4(0.72, 0.5, 0.36, 1.0);
uniform vec4 stone_tint : source_color = vec4(0.8, 0.8, 0.84, 1.0);
uniform vec4 lush_tint : source_color = vec4(0.84, 1.0, 0.78, 1.0);
uniform vec4 mud_color : source_color = vec4(0.22, 0.18, 0.13, 1.0);
uniform float lane_start = 10.0;
uniform float lane_width = 1.4;
uniform float edge_start = 17.0;
uniform float edge_end = 30.0;
uniform float texel_size = 0.06;
uniform float texel_amount = 0.12;

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

// Distance to the nearest path minus its half-width (negative inside).
float path_distance(vec2 p) {
	float best = 1000.0;
	for (int i = 0; i < 24; i++) {
		if (i >= path_count) {
			break;
		}
		vec4 seg = path_segments[i];
		vec2 ab = seg.zw - seg.xy;
		float t = clamp(dot(p - seg.xy, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
		best = min(best, length(p - seg.xy - ab * t) - path_widths[i]);
	}
	return best;
}

void fragment() {
	vec2 p = world_pos.xz;
	float macro = fbm(p * 0.07);
	float tint = fbm(p * 0.035 + vec2(40.0, 11.0));
	float ragged = (fbm(p * 0.8) - 0.5) * 1.6;
	float patchy = smoothstep(0.38, 0.62, fbm(p * 0.55 + vec2(3.0, 8.0)));

	vec3 grass = untiled(grass_tex, p, grass_tile, macro);
	// Broad sunny / shady meadow patches.
	grass *= mix(vec3(0.82, 0.86, 0.9), vec3(1.1, 1.06, 0.92), smoothstep(0.3, 0.7, tint));
	vec3 leaves = untiled(leaves_tex, p, leaves_tile, macro);
	vec3 dirt = untiled(dirt_tex, p, dirt_tile, macro);
	vec3 color = grass;

	// Grove grounds (zone ids from WorldLayout.Zone).
	for (int i = 0; i < 4; i++) {
		vec4 g = groves[i];
		if (g.z <= 0.0) {
			continue;
		}
		float d = length(p - g.xy) + (fbm(p * 0.45 + float(i) * 7.0) - 0.5) * 3.0;
		float w = 1.0 - smoothstep(g.z * 0.4, g.z, d);
		int zone = int(g.w + 0.5);
		if (zone == 2) {
			// Pine grove: rusty needle litter.
			color = mix(color, leaves * needle_tint.rgb, w * mix(0.6, 0.9, patchy));
		} else if (zone == 3) {
			// Stony pond: bare, cooler, gravelly patches.
			color = mix(color, dirt * stone_tint.rgb, w * 0.65 * patchy);
		} else if (zone == 4) {
			// Woodlot: warm fallen leaves under the trees.
			color = mix(color, leaves * vec3(1.06, 0.98, 0.84), w * 0.55 * patchy);
		} else if (zone == 5) {
			// Berry hollow: lush, deep green.
			color *= mix(vec3(1.0), lush_tint.rgb, w);
		}
	}

	// Mob lanes: trodden, darker trails in from the forest gaps.
	float lane_along = max(abs(p.x), abs(p.y));
	float lane_across = min(abs(p.x), abs(p.y)) + sin(lane_along * 0.45) * 0.5 * sign(p.x * p.y);
	float lane_mask = (1.0 - smoothstep(lane_width * 0.4, lane_width, lane_across + ragged * 0.6))
		* smoothstep(lane_start, lane_start + 5.0, lane_along);
	color = mix(color, leaves * vec3(0.72, 0.66, 0.74), lane_mask * 0.75);

	// Dirt clearing around the campfire, with a ragged painted edge,
	// and the footpaths out to the groves.
	float r = length(p);
	float dirt_mask = 1.0 - smoothstep(clearing_radius - 0.5, clearing_radius + 0.3, r + ragged);
	float path_d = path_distance(p) + ragged * 0.3;
	float path_mask = 1.0 - smoothstep(-0.22, 0.22, path_d);
	dirt_mask = max(dirt_mask, path_mask);
	// Paths: a paler, worn centre and darker trodden edges.
	vec3 path_dirt = dirt * mix(1.08, 0.88, smoothstep(-0.7, 0.0, path_d));
	dirt = mix(dirt, path_dirt, path_mask);
	// Darker scorched ring right around the fire.
	dirt = mix(dirt * vec3(0.5, 0.45, 0.42), dirt, smoothstep(0.7, 1.9, r));
	// A soft darker rim where the grass is trampled.
	float rim = smoothstep(clearing_radius - 1.2, clearing_radius, r + ragged) * dirt_mask;
	dirt *= 1.0 - rim * 0.18;
	color = mix(color, dirt, dirt_mask);

	// Haunted edge: toward the forest, leaf litter takes over and
	// colours cool and darken.
	float edge_d = max(abs(p.x), abs(p.y)) + ragged * 2.0;
	float litter = smoothstep(edge_start - 5.0, edge_start + 3.0, edge_d + (fbm(p * 0.3) - 0.5) * 6.0);
	color = mix(color, leaves, litter * 0.85);
	float edge = smoothstep(edge_start, edge_end, edge_d);
	color = mix(color, color * edge_tint.rgb, edge * 0.65);

	// The pond's dark mud bank (the water mesh sits on top).
	if (pond.z > 0.0) {
		float bank = 1.0 - smoothstep(pond.z - 0.2, pond.z + 1.1, length(p - pond.xy) + ragged * 0.5);
		color = mix(color, mud_color.rgb * (0.8 + 0.4 * macro), bank * 0.85);
	}

	// Crisp painted texels.
	color *= 1.0 + (hash(floor(p / texel_size)) - 0.5) * texel_amount;
	ALBEDO = color;
	ROUGHNESS = 1.0;
}
