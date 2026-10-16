shader_type canvas_item;

// Full-screen look pass (feature 031, docs/design/art-direction.md):
// a tilt-shift blur that keeps a horizontal band crisp and softens the
// top and bottom of the frame (the "miniature diorama" of the concept
// art), a warm split-tone grade (plum shadows, amber highlights; cooler
// at night) and a soft vignette. GL Compatibility has no built-in DOF,
// so the blur samples the screen texture's mips with a small kernel.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;

uniform float blur_enabled : hint_range(0.0, 1.0) = 1.0;
uniform float focus_center : hint_range(0.0, 1.0) = 0.55;  // screen y of the crisp band
uniform float focus_band : hint_range(0.0, 0.5) = 0.17;    // half height kept sharp
uniform float falloff : hint_range(0.01, 1.0) = 0.32;      // distance to full blur
uniform float max_radius = 5.0;                            // kernel radius at full blur, px
uniform float max_lod = 2.2;                               // mip level at full blur

uniform float grade_strength : hint_range(0.0, 1.0) = 1.0;
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 day_shadow : source_color = vec3(0.55, 0.36, 0.42);
uniform vec3 day_highlight : source_color = vec3(1.0, 0.84, 0.6);
uniform vec3 night_shadow : source_color = vec3(0.26, 0.36, 0.62);
uniform vec3 night_highlight : source_color = vec3(1.0, 0.74, 0.46);
uniform float vignette : hint_range(0.0, 1.0) = 0.32;

const vec2 TAPS[8] = vec2[](
	vec2(1.0, 0.0), vec2(0.707, 0.707), vec2(0.0, 1.0), vec2(-0.707, 0.707),
	vec2(-1.0, 0.0), vec2(-0.707, -0.707), vec2(0.0, -1.0), vec2(0.707, -0.707)
);

void fragment() {
	vec2 uv = SCREEN_UV;
	float amount = blur_enabled * smoothstep(focus_band, focus_band + falloff, abs(uv.y - focus_center));
	vec3 col = textureLod(screen_tex, uv, max_lod * amount).rgb;
	if (amount > 0.01) {
		vec2 radius = SCREEN_PIXEL_SIZE * max_radius * amount;
		vec3 sum = col * 2.0;
		for (int i = 0; i < 8; i++) {
			sum += textureLod(screen_tex, uv + TAPS[i] * radius, max_lod * amount).rgb;
		}
		col = sum / 10.0;
	}

	// Split tone: tint by the hue of shadow/highlight colours, keeping luminance.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 shadow_tint = mix(day_shadow, night_shadow, night_amount);
	vec3 highlight_tint = mix(day_highlight, night_highlight, night_amount);
	vec3 tint = mix(shadow_tint, highlight_tint, smoothstep(0.05, 0.75, luma));
	tint /= max(dot(tint, vec3(0.299, 0.587, 0.114)), 0.001);
	col = mix(col, col * tint, 0.22 * grade_strength);

	// Vignette, a little stronger at night.
	vec2 centered = (uv - vec2(0.5, focus_center)) * vec2(1.0, 1.25);
	float edge = smoothstep(0.35, 0.95, length(centered) * 1.2);
	col *= 1.0 - edge * vignette * (1.0 + 0.5 * night_amount);

	COLOR = vec4(col, 1.0);
}
