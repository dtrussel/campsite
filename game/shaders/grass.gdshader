shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// Stylized grass tufts for a MultiMesh. Blades sway in a slow wind
// that travels across the field; colour grades from a dark base to the
// per-instance tip colour (INSTANCE COLOR), which also lets a few tufts
// read as flowers.

uniform vec4 base_color : source_color = vec4(0.3, 0.5, 0.2, 1.0);
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.3;

varying float blade_height;

void vertex() {
	blade_height = clamp(VERTEX.y / 0.45, 0.0, 1.0);
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float wave = sin(world.x * 0.35 + world.z * 0.2 + TIME * wind_speed)
		+ 0.5 * sin(world.x * 1.1 - TIME * wind_speed * 1.7);
	VERTEX.x += wave * wind_strength * blade_height * blade_height;
	VERTEX.z += wave * wind_strength * 0.5 * blade_height * blade_height;
	// Point normals up so tufts light like the ground they sit on.
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 tip = COLOR.rgb;
	ALBEDO = mix(base_color.rgb, tip, smoothstep(0.0, 0.9, blade_height));
	ROUGHNESS = 1.0;
}
