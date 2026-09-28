shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Hand-painted style ground: large soft patches of three grass tones,
// brushy mid-frequency variation, a worn dirt clearing around the
// campfire with an irregular edge, and a darker, desaturated "haunted"
// tint toward the forest edge where the night mobs come from.

uniform vec4 grass_dark : source_color = vec4(0.18, 0.36, 0.16, 1.0);
uniform vec4 grass_mid : source_color = vec4(0.32, 0.54, 0.22, 1.0);
uniform vec4 grass_light : source_color = vec4(0.55, 0.70, 0.30, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.52, 0.40, 0.27, 1.0);
uniform vec4 dirt_dark : source_color = vec4(0.36, 0.27, 0.19, 1.0);
uniform vec4 edge_tint : source_color = vec4(0.20, 0.22, 0.26, 1.0);
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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	// Grass: broad patches + brush strokes stretched along one axis.
	float patches = fbm(p * 0.09);
	float strokes = noise(vec2(p.x * 0.9, p.y * 0.35) + patches * 3.0);
	vec3 grass = mix(grass_dark.rgb, grass_mid.rgb, smoothstep(0.3, 0.6, patches));
	grass = mix(grass, grass_light.rgb, smoothstep(0.62, 0.85, patches + strokes * 0.12));
	grass *= 0.92 + strokes * 0.14;

	// Dirt clearing around the campfire, with a ragged painted edge.
	float r = length(p);
	float ragged = (fbm(p * 0.8) - 0.5) * 1.6;
	float dirt_mask = 1.0 - smoothstep(clearing_radius - 0.6, clearing_radius + 0.4, r + ragged);
	vec3 dirt = mix(dirt_dark.rgb, dirt_color.rgb, fbm(p * 1.3));
	// Darker scorched ring right around the fire.
	dirt = mix(dirt * 0.6, dirt, smoothstep(0.7, 1.8, r));
	vec3 color = mix(grass, dirt, dirt_mask);

	// Haunted edge: toward the forest, colours cool and darken.
	float edge = smoothstep(edge_start, edge_end, max(abs(p.x), abs(p.y)) + ragged * 2.0);
	color = mix(color, color * edge_tint.rgb * 2.2, edge * 0.75);

	ALBEDO = color;
	ROUGHNESS = 1.0;
}
