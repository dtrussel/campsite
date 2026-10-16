// Shared painted finish (feature 031, milestone 4): pushes baked
// painted textures toward the HD-2D diorama target. Sun-kissed warm
// tops, warm-brown undersides, fake contact shade where things meet the
// ground, and fine "texel" and blotch noise so smooth low-poly surfaces
// read as painted detail. Noise lives in object space so it never swims
// on moving characters or swaying foliage.

uniform vec3 top_warm : source_color = vec3(1.0, 0.86, 0.6);
uniform float top_light = 0.22;
uniform vec3 shade_tint : source_color = vec3(0.52, 0.34, 0.26);
uniform float under_dark = 0.32;
uniform float contact_height = 0.4;
uniform float contact_dark = 0.32;
uniform float texel_size = 0.05;
uniform float texel_amount = 0.07;
uniform float blotch_amount = 0.08;

float painted_hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float painted_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(painted_hash(i), painted_hash(i + vec3(1, 0, 0)), u.x),
		mix(painted_hash(i + vec3(0, 1, 0)), painted_hash(i + vec3(1, 1, 0)), u.x), u.y);
	float b = mix(mix(painted_hash(i + vec3(0, 0, 1)), painted_hash(i + vec3(1, 0, 1)), u.x),
		mix(painted_hash(i + vec3(0, 1, 1)), painted_hash(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(a, b, u.z);
}

// albedo: baked colour; local: object-space position; world: world
// position; world_normal: normalized world normal.
vec3 painted_finish(vec3 albedo, vec3 local, vec3 world, vec3 world_normal) {
	float up = world_normal.y;
	// Sun-kissed tops, warm-brown undersides.
	albedo *= 1.0 + top_light * smoothstep(0.1, 0.9, up) * (top_warm / max(dot(top_warm, vec3(0.333)), 0.001));
	albedo = mix(albedo, albedo * shade_tint, under_dark * smoothstep(0.0, -0.8, up));
	// Contact shade near the ground.
	float contact = 1.0 - smoothstep(0.0, contact_height, world.y);
	albedo = mix(albedo, albedo * shade_tint, contact * contact_dark);
	// Painted detail: crisp texel cells plus soft blotches.
	float texel = painted_hash(floor(local / texel_size)) - 0.5;
	float blotch = painted_noise(local * 3.1) - 0.5;
	albedo *= 1.0 + texel * texel_amount * 2.0 + blotch * blotch_amount * 2.0;
	return albedo;
}
