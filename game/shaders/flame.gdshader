shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// Stylized flame on a camera-facing quad: a teardrop mask distorted by
// scrolling value noise, graded from white-hot core to red tips.

uniform vec4 core_color : source_color = vec4(1.0, 0.82, 0.45, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.55, 0.12, 1.0);
uniform vec4 tip_color : source_color = vec4(0.85, 0.12, 0.05, 1.0);
uniform float intensity = 1.25;
uniform float speed = 1.6;
uniform float seed = 0.0;

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
	// Cylindrical billboard: face the camera around the Y axis only.
	vec3 cam_right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	vec3 world = MODEL_MATRIX[3].xyz + cam_right * VERTEX.x * scale.x + vec3(0.0, VERTEX.y * scale.y, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed + seed * 13.0;
	float height = 1.0 - uv.y; // 0 at the base, 1 at the tip
	// Two octaves of rising noise distort the silhouette.
	float n = noise(vec2(uv.x * 3.0, uv.y * 2.5 + t * 2.0));
	float n2 = noise(vec2(uv.x * 7.0 + 3.0, uv.y * 5.0 + t * 3.4));
	float sway = (n - 0.5) * 0.45 * height * height;
	float x = abs((uv.x - 0.5 + sway) * 2.0);
	// Teardrop: a round bulb near the base tapering to a flickering tip.
	float profile = sqrt(max(0.0, 1.0 - height)) * (0.55 + 0.45 * sin(min(height * 4.0, 3.14159)));
	profile *= 0.95 + (n2 - 0.5) * 0.35;
	float body = 1.0 - smoothstep(profile * 0.7, profile, x);
	body *= smoothstep(0.0, 0.05, height);
	// Tongues of flame break off near the top.
	body *= 1.0 - smoothstep(0.62, 1.0, height + (n2 - 0.5) * 0.4);
	float heat = clamp((1.0 - x / max(profile, 0.001)) * (1.15 - height * 0.9), 0.0, 1.0);
	vec3 color = mix(tip_color.rgb, mid_color.rgb, smoothstep(0.05, 0.45, heat));
	color = mix(color, core_color.rgb, smoothstep(0.5, 0.9, heat));
	ALBEDO = color * intensity;
	ALPHA = clamp(body * 1.5, 0.0, 1.0) * 0.95;
}
