shader_type canvas_item;

// --- Pseudo-3D perspective tilt driven by mouse position ---

// Set from GDScript: 1.0 when hovered/dragged, 0.0 when idle
uniform float hovering;

// Field of view for the perspective warp (higher = more dramatic tilt)
uniform float fov : hint_range(1, 179) = 90;

// Manual rotation overrides (unused by default, available for special effects)
uniform float y_rot : hint_range(-180, 180) = 0.0;
uniform float x_rot : hint_range(-180, 180) = 0.0;

// How much the edges pinch inward during perspective (0 = none, 1 = full)
uniform float inset : hint_range(0, 1) = 0.0;

// Shadow controls
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.35);
uniform vec2 shadow_offset = vec2(0.0, -140.0);
// How strongly the shadow shifts in response to card tilt (higher = more shift)
uniform float shadow_tilt_strength = 200.0;
uniform float shadow_scale = 1.3;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;
uniform float border_scale = 1.8;

// Idle wobble: subtle animation when card is at rest
uniform float rand_seed = 0.0;
uniform float rand_trans_power = 0.0;

// Back-face culling: discard pixels when card is rotated past 90 degrees
uniform bool cull_back = true;

// If true, shadow stays fixed even when the sprite rotates
uniform bool disable_rotating = false;

// Mouse position in screen/canvas coordinates, set as a global shader uniform
global uniform vec2 mouse_screen_pos;

// --- Varyings passed from vertex() to fragment() ---
varying flat vec4 modulate;
varying flat float sprite_rotation;
varying flat vec2 o;
varying vec3 p;
varying flat vec2 pivot;
varying flat vec2 region_rate;
varying flat mat3 inv_rot_mat;
// Tilt direction passed to fragment() so the shadow can shift opposite the lean
varying flat vec2 tilt_direction;

// Rotate a 2D point around a pivot by an angle in radians
vec2 rotate(vec2 uv, vec2 pivot_r, float angle) {
	mat2 rotation_mat = mat2(
		vec2(cos(angle), -sin(angle)),
		vec2(sin(angle), cos(angle))
	);
	uv -= pivot_r;
	uv = uv * rotation_mat;
	uv += pivot_r;
	return uv;
}

void vertex() {
	// Calculate the sprite's region size in UV and pixel space
	vec2 my_region_rate = abs(VERTEX) * 2.0;
	region_rate = TEXTURE_PIXEL_SIZE * my_region_rate;

	// Determine the UV pivot based on which corner this vertex is
	if (VERTEX_ID == 0) {
		pivot = UV;
	} else if (VERTEX_ID == 1) {
		pivot = UV - vec2(0.0, region_rate.y);
	} else if (VERTEX_ID == 2) {
		pivot = UV - vec2(region_rate.x, region_rate.y);
	} else if (VERTEX_ID == 3) {
		pivot = UV - vec2(region_rate.x, 0.0);
	}

	// Idle wobble: a slow random rotation that gives cards a subtle living feel
	float rand_angle = rand_trans_power * mod(TIME * (0.9 + mod(rand_seed, 0.5)), 2.0 * PI);
	vec2 rand_vec = vec2(cos(rand_angle), sin(rand_angle));

	// Convert global mouse position into the card's local coordinate space
	vec2 local_mouse = (inverse(MODEL_MATRIX) * vec4(mouse_screen_pos, 0.0, 1.0)).xy;

	// Combine mouse influence (when hovering) with idle wobble
	vec2 mouse_force = hovering * 0.5 * local_mouse / length(region_rate / TEXTURE_PIXEL_SIZE)
		+ rand_vec * 0.05 * rand_trans_power;

	// Store the tilt direction so fragment() can shift the shadow opposite the lean
	tilt_direction = mouse_force;

	// Build a 3D rotation matrix from y_rot + mouse X and x_rot + mouse Y
	float sin_b = sin(y_rot / 180.0 * PI + mouse_force.x);
	float cos_b = cos(y_rot / 180.0 * PI + mouse_force.x);
	float sin_c = sin(x_rot / 180.0 * PI + -mouse_force.y);
	float cos_c = cos(x_rot / 180.0 * PI + -mouse_force.y);

	inv_rot_mat[0][0] = cos_b;
	inv_rot_mat[0][1] = 0.0;
	inv_rot_mat[0][2] = -sin_b;
	inv_rot_mat[1][0] = sin_b * sin_c;
	inv_rot_mat[1][1] = cos_c;
	inv_rot_mat[1][2] = cos_b * sin_c;
	inv_rot_mat[2][0] = sin_b * cos_c;
	inv_rot_mat[2][1] = -sin_c;
	inv_rot_mat[2][2] = cos_b * cos_c;

	// Apply perspective distortion to the vertex position
	vec2 uv = (UV - pivot) / region_rate;
	float t = tan(fov / 360.0 * PI);
	VERTEX += (uv - 0.5) * 1.0 * my_region_rate * t * (1.0 - inset);

	// Scale vertices outward to make room for the shadow
	float final_scale = max(border_scale, border_scale * shadow_scale);
	VERTEX.xy *= vec2(final_scale);

	// Pass the sprite's modulate color and rotation to fragment()
	modulate = COLOR;
	sprite_rotation = atan(MODEL_MATRIX[0][1], MODEL_MATRIX[0][0]);
}

// Sample texture, returning transparent for out-of-bounds UVs
vec4 sample_texture_safe(sampler2D tex, vec2 uv) {
	return (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
		? vec4(0.0)
		: texture(tex, uv);
}

// Apply a gaussian blur for the shadow
vec4 apply_gaussian_blur(sampler2D tex, vec2 uv, vec2 pixel_size) {
	if (blur_amount <= 0.0) return sample_texture_safe(tex, uv);

	vec4 color_blur = vec4(0.0);
	float total_weight = 0.0;
	int kernel_size = int(blur_amount * 3.0);

	for (int x = -kernel_size; x <= kernel_size; x++) {
		for (int y = -kernel_size; y <= kernel_size; y++) {
			vec2 blur_offset = vec2(float(x), float(y)) * pixel_size;
			float weight = exp(-0.5 * float(x * x + y * y) / (blur_amount * blur_amount));
			color_blur += sample_texture_safe(tex, uv + blur_offset) * weight;
			total_weight += weight;
		}
	}

	return total_weight > 0.0 ? color_blur / total_weight : vec4(0.0);
}

// Rotate a 2D point by an angle (used for shadow offset)
vec2 rotate_point(vec2 point, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return vec2(point.x * c - point.y * s, point.x * s + point.y * c);
}

// Fade edges smoothly so the shadow doesn't have hard cutoffs
float calculate_fade(float coord, float scale) {
	if (coord < 0.0) {
		return 1.0 + (coord / (scale - 1.0));
	} else if (coord > 1.0) {
		return 1.0 - ((coord - 1.0) / (scale - 1.0));
	}
	return 1.0;
}

// Process either the main card texture or the shadow layer
vec4 process_texture(vec2 uv, sampler2D tex, bool is_main, vec2 pixel_size) {
	if (is_main) {
		return sample_texture_safe(tex, uv) * modulate;
	}
	// Shadow pass: blur the texture, tint it, and fade edges
	vec4 blurred = apply_gaussian_blur(tex, uv, pixel_size);
	float fade_x = calculate_fade(uv.x, shadow_scale);
	float fade_y = calculate_fade(uv.y, shadow_scale);
	float fade = smoothstep(0.0, 1.0, min(fade_x, fade_y));
	return vec4(shadow_color.rgb, (blurred.a - (1.0 - shadow_color.a)) * modulate.a * fade);
}

void fragment() {
	// Apply the inverse rotation matrix to get perspective-corrected UVs
	vec2 uv = (UV - pivot) / region_rate;
	float t = tan(fov / 360.0 * PI);
	p = inv_rot_mat * vec3((uv - 0.5), 0.5 / t);
	float v = (0.5 / t) + 0.5;
	p.xy *= v * inv_rot_mat[2].z;
	o = v * inv_rot_mat[2].xy;

	// Discard back-facing pixels if culling is enabled
	if (cull_back && p.z <= 0.0) discard;

	// Project 3D coordinates back to 2D texture coordinates
	uv = (p.xy / p.z).xy - o;
	uv += 0.5;

	// Correct aspect ratio for non-square textures
	float asp = (region_rate / TEXTURE_PIXEL_SIZE).y / (region_rate / TEXTURE_PIXEL_SIZE).x;
	uv.y *= asp;

	// Apply idle wobble rotation
	uv = rotate(uv, vec2(0.5, 0.5),
		rand_trans_power * 0.05 * sin(TIME * (0.9 + mod(rand_seed, 0.5)) + rand_seed * 123.8985));
	uv.y /= asp;

	// Discard pixels outside the card's texture bounds
	if (uv.x > 1.0 || uv.x < 0.0) discard;
	if (uv.y > 1.0 || uv.y < 0.0) discard;

	// Convert back to the full UV space for texture sampling
	vec2 perspective_uv = pivot + uv * region_rate;
	float final_scale = max(border_scale, border_scale * shadow_scale);
	vec2 scaled_uv = perspective_uv * final_scale - (0.5 * (final_scale - 1.0));

	// Sample the main card texture with perspective correction
	vec4 main_texture = process_texture(scaled_uv, TEXTURE, true, TEXTURE_PIXEL_SIZE);

	// Sample the shadow layer: offset, blurred, and tinted
	// Base offset (static position) adjusted for sprite rotation
	vec2 adjusted_offset = disable_rotating
		? shadow_offset
		: rotate_point(shadow_offset, -sprite_rotation);
	// Dynamic shift: shadow moves opposite to the card's tilt direction
	vec2 dynamic_shift = -tilt_direction * shadow_tilt_strength;
	vec2 shadow_uv = scaled_uv + (adjusted_offset + dynamic_shift) * TEXTURE_PIXEL_SIZE;
	vec4 shadow = process_texture(shadow_uv, TEXTURE, false, TEXTURE_PIXEL_SIZE);

	// Composite: shadow underneath, card on top
	COLOR = mix(shadow, main_texture, main_texture.a);
}
