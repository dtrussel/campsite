shader_type canvas_item;

// Full-screen look pass (feature 031, docs/design/art-direction.md):
// a strong tilt-shift that keeps a narrow horizontal band crisp (with a
// light sharpen) and melts the top and bottom of the frame into soft
// bokeh (the "miniature diorama" of the concept art and the HD-2D style
// target), then a warm filmic grade: S-curve, brown-lifted blacks,
// amber split tone, warm haze in the blurred zones and a warm vignette.
// Cooler at night. GL Compatibility has no built-in DOF, so the blur is
// a golden-angle disc over the screen texture's mips.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;

uniform float blur_enabled : hint_range(0.0, 1.0) = 1.0;
uniform float focus_center : hint_range(0.0, 1.0) = 0.53;  // screen y of the crisp band
uniform float focus_band : hint_range(0.0, 0.5) = 0.08;    // half height kept sharp
uniform float falloff : hint_range(0.01, 1.0) = 0.26;      // distance to full blur
uniform float bottom_boost = 1.3;                          // the foreground blurs more
uniform float max_radius = 11.0;                           // disc radius at full blur, px at 1080p
uniform float max_lod = 2.6;                               // mip level at full blur
uniform float sharpen : hint_range(0.0, 1.0) = 0.22;        // unsharp mask in the band

uniform float grade_strength : hint_range(0.0, 1.0) = 1.0;
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform float curve : hint_range(0.0, 1.0) = 0.55;         // filmic S-curve
uniform vec3 day_balance = vec3(1.0, 0.98, 0.94);           // day: greens lean orange-gold
uniform float split_amount : hint_range(0.0, 1.0) = 0.15;
uniform vec3 day_shadow : source_color = vec3(0.6, 0.34, 0.3);
uniform vec3 day_highlight : source_color = vec3(1.0, 0.9, 0.74);
uniform vec3 night_shadow : source_color = vec3(0.26, 0.36, 0.62);
uniform vec3 night_highlight : source_color = vec3(1.0, 0.74, 0.46);
uniform vec3 day_lift : source_color = vec3(0.045, 0.022, 0.01);
uniform vec3 night_lift : source_color = vec3(0.02, 0.03, 0.07);
uniform vec3 haze_color : source_color = vec3(1.0, 0.76, 0.5);
uniform float haze : hint_range(0.0, 1.0) = 0.05;
uniform float exposure = 0.8;
uniform float contrast = 1.22;                             // around a low pivot: deep shadows
uniform float pivot = 0.4;
uniform float vignette : hint_range(0.0, 1.0) = 0.3;

const float GOLDEN_ANGLE = 2.39996323;
const int TAPS = 16;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = uv.y - focus_center;  // > 0 below the band (foreground)
	float amount = smoothstep(focus_band, focus_band + falloff, abs(d));
	amount = min(amount * (d > 0.0 ? bottom_boost : 1.0), 1.3) * blur_enabled;

	vec3 sharp = textureLod(screen_tex, uv, 0.0).rgb;
	vec3 col = sharp;
	if (amount > 0.01) {
		// Golden-angle disc; bright taps weigh more so highlights bloom
		// into soft discs. The radius scales with the screen height.
		float lod = max_lod * min(amount, 1.0);
		vec2 radius = vec2(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 1.0) * (max_radius * amount / 1080.0);
		vec3 sum = vec3(0.0);
		float weights = 0.0;
		for (int i = 0; i < TAPS; i++) {
			float r = sqrt((float(i) + 0.5) / float(TAPS));
			float a = float(i) * GOLDEN_ANGLE;
			vec3 s = textureLod(screen_tex, uv + vec2(cos(a), sin(a)) * r * radius, lod).rgb;
			float w = 1.0 + 2.5 * smoothstep(0.55, 1.1, luma(s));
			sum += s * w;
			weights += w;
		}
		col = mix(sharp, sum / weights, smoothstep(0.0, 0.2, amount));
	}
	// Crisp band: a light unsharp mask brings out the painted detail.
	float crisp = (1.0 - smoothstep(0.0, 0.3, amount)) * blur_enabled * sharpen;
	if (crisp > 0.001) {
		vec2 px = SCREEN_PIXEL_SIZE;
		vec3 around = (textureLod(screen_tex, uv + vec2(px.x, 0.0), 0.0).rgb
			+ textureLod(screen_tex, uv - vec2(px.x, 0.0), 0.0).rgb
			+ textureLod(screen_tex, uv + vec2(0.0, px.y), 0.0).rgb
			+ textureLod(screen_tex, uv - vec2(0.0, px.y), 0.0).rgb) * 0.25;
		col = max(col + (sharp - around) * crisp, vec3(0.0));
	}

	vec3 graded = col;
	float day = 1.0 - night_amount;
	// Day balance: greens lean orange-gold, blues soften; darker exposure
	// leaves room for the deep warm shadows of the target.
	// Both fade out at night: there the dark blues are most of the frame
	// and the curve would crush them, leaving only the warm firelight.
	graded *= mix(vec3(1.0), day_balance * exposure, day);
	// Contrast and a filmic S-curve on luminance only, so the hues and
	// saturation survive (a per-channel curve crushes the blues).
	float l0 = max(luma(graded), 0.0001);
	float l1 = clamp((l0 - pivot) * mix(1.0, contrast, day) + pivot, 0.0, 1.2);
	float lc = clamp(l1, 0.0, 1.0);
	l1 = mix(l1, lc * lc * (3.0 - 2.0 * lc), curve * mix(1.0, 0.4, night_amount));
	graded *= l1 / l0;
	// Split tone: tint by the hue of shadow/highlight colours, keeping luminance.
	float l = luma(graded);
	vec3 shadow_tint = mix(day_shadow, night_shadow, night_amount);
	vec3 highlight_tint = mix(day_highlight, night_highlight, night_amount);
	vec3 tint = mix(shadow_tint, highlight_tint, smoothstep(0.05, 0.75, l));
	tint /= max(luma(tint), 0.001);
	graded = mix(graded, graded * tint, split_amount);
	// Lift the blacks to a warm brown (blue at night).
	graded = mix(mix(day_lift, night_lift, night_amount), vec3(1.0), graded);
	graded = mix(col, graded, grade_strength);
	// Warm haze glows over the blurred zones.
	graded += haze_color * luma(col) * haze * min(amount, 1.0) * (1.0 - 0.6 * night_amount);

	// Warm vignette, a little stronger at night.
	vec2 centered = (uv - vec2(0.5, focus_center)) * vec2(1.0, 1.25);
	float edge = smoothstep(0.35, 0.95, length(centered) * 1.2) * vignette * (1.0 + 0.5 * night_amount);
	graded = mix(graded, graded * mix(vec3(0.62, 0.42, 0.32), vec3(0.3, 0.34, 0.5), night_amount), edge);

	COLOR = vec4(graded, 1.0);
}
