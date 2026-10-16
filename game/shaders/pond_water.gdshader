shader_type spatial;
render_mode diffuse_lambert, cull_disabled;

// Painted pond water (feature 032). Opaque, so it needs no screen or
// depth texture (GL Compatibility). UV.x runs from the centre (0) to
// the shore (1): deep teal in the middle, shallow green-teal toward
// the bank, a broken pale foam line at the shore, slow drifting ripple
// bands and sun glints.

uniform vec4 deep_color : source_color = vec4(0.08, 0.36, 0.44, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.26, 0.56, 0.52, 1.0);
uniform vec4 foam_color : source_color = vec4(0.86, 0.94, 0.88, 1.0);
uniform float ripple_scale = 1.6;
uniform float ripple_speed = 0.25;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float shore = UV.x;
	float t = TIME * ripple_speed;
	float n1 = noise(p * ripple_scale + vec2(t, t * 0.6));
	float n2 = noise(p * ripple_scale * 2.3 - vec2(t * 0.8, -t * 1.1));
	float waves = n1 * 0.6 + n2 * 0.4;

	vec3 color = mix(deep_color.rgb, shallow_color.rgb, smoothstep(0.2, 1.0, shore + (waves - 0.5) * 0.15));
	// Ripple bands: soft lighter streaks.
	float bands = smoothstep(0.62, 0.72, waves) * (1.0 - smoothstep(0.72, 0.86, waves));
	color += vec3(0.08, 0.12, 0.11) * bands;
	// Sun glints.
	float glint = smoothstep(0.86, 0.95, n2 * n1 * 1.6);
	color += vec3(0.35, 0.34, 0.28) * glint;
	// Broken foam line at the shore.
	float foam = smoothstep(0.9, 0.97, shore + (n1 - 0.5) * 0.08) * step(0.4, n2);
	color = mix(color, foam_color.rgb, foam * 0.6);

	ALBEDO = color;
	ROUGHNESS = 0.18;
	SPECULAR = 0.3;
}
