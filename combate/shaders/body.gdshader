// Piel y ropa con daño acumulado.
// · marks[]: impactos en coordenadas locales de la malla (xyz) e intensidad (w).
//   En piel: enrojecimiento → moretón morado. En ropa: mancha de sangre.
// · face_mode: la cabeza dibuja sangre de nariz/labio y una ceja abierta con su
//   reguero, sobre la esfera unidad (-Z = delante, +Y = arriba).
// Estilizado y sobrio: color oscuro, brillo húmedo, sin texturas externas.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec3 albedo : source_color = vec3(0.8);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.55;
uniform vec3 rim_color : source_color = vec3(1.0, 0.7, 0.45);
uniform float rim_power = 3.0;
uniform float rim_strength = 0.3;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float hit_flash = 0.0;
uniform float skin = 0.0;
uniform vec4 marks[6];
uniform float mark_r = 0.5;
uniform float blood_on = 1.0;
uniform float face_mode = 0.0;
uniform float nose_blood = 0.0;
uniform float lip_blood = 0.0;
uniform float cut_amount = 0.0;
uniform float cut_side = 1.0;
uniform float sweat = 0.0;

varying vec3 lp;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), u.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), u.x), u.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), u.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), u.x), u.y), u.z);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 c = albedo;
	float wet = 0.0;
	float b = 0.0;
	for (int i = 0; i < 6; i++) {
		float d = distance(lp, marks[i].xyz);
		float n = noise(lp * (9.0 / mark_r) + float(i) * 3.1) - 0.5;
		float m = (1.0 - smoothstep(mark_r * 0.2, mark_r, d + n * mark_r * 0.45)) * marks[i].w;
		b = max(b, m);
	}
	if (skin > 0.5) {
		float l = dot(c, vec3(0.3, 0.55, 0.15));
		vec3 red = c * vec3(1.08, 0.58, 0.52);
		vec3 purple = vec3(0.36, 0.15, 0.26) * (0.7 + 0.5 * l);
		c = mix(c, mix(red, purple, smoothstep(0.55, 1.15, b)), clamp(b, 0.0, 0.85));
		// un golpe muy fuerte abre la piel: puntos de sangre en el centro del moretón
		float split = smoothstep(1.05, 1.35, b) * blood_on;
		c = mix(c, vec3(0.4, 0.02, 0.03), split * 0.8);
		wet = max(wet, split);
	} else {
		float s = smoothstep(0.38, 0.6, b) * blood_on;
		c = mix(c, vec3(0.32, 0.02, 0.03), s * 0.88);
		wet = max(wet, s * 0.45);
	}
	if (face_mode > 0.5) {
		float front = smoothstep(-0.35, -0.75, lp.z);
		float w = (noise(vec3(lp.y * 7.0, 1.3, 2.1)) - 0.5) * 0.12;
		// nariz: reguero hacia la barbilla que crece con la hemorragia
		float top = -0.1;
		float bot = top - nose_blood * 0.8;
		float sx = 1.0 - smoothstep(0.06, 0.12 + nose_blood * 0.05, abs(lp.x + w));
		float sy = smoothstep(bot - 0.02, bot + 0.04, lp.y) * (1.0 - smoothstep(top, top + 0.05, lp.y));
		float nb = sx * sy * front * step(0.01, nose_blood);
		// labio partido
		float lip = (1.0 - smoothstep(0.03, 0.09, length(vec2(lp.x - 0.12, (lp.y + 0.38) * 1.6)))) * front * lip_blood;
		float lip_drip = (1.0 - smoothstep(0.025, 0.06, abs(lp.x - 0.13 + w * 0.5)))
			* step(-0.38 - lip_blood * 0.45, lp.y) * step(lp.y, -0.36) * front * step(0.01, lip_blood);
		// ceja abierta y reguero por la mejilla
		vec2 cp = vec2(cut_side * 0.42, 0.24);
		float line = (1.0 - smoothstep(0.012, 0.035, abs(lp.y - cp.y - (lp.x - cp.x) * 0.3 * cut_side)))
			* (1.0 - smoothstep(0.08, 0.16, abs(lp.x - cp.x)));
		float tx = 1.0 - smoothstep(0.03, 0.08, abs(lp.x - cp.x - 0.04 * cut_side + w * 0.7));
		float ty = step(cp.y - cut_amount * 0.85, lp.y) * step(lp.y, cp.y);
		float cb = max(line * 1.2, tx * ty * 0.9) * front * step(0.01, cut_amount);
		float blood = clamp(max(max(nb, cb), max(lip, lip_drip)), 0.0, 1.0) * blood_on;
		c = mix(c, vec3(0.45, 0.02, 0.03), blood * 0.92);
		wet = max(wet, blood);
	}
	wet = max(wet, sweat * 0.35);
	ALBEDO = c;
	ROUGHNESS = mix(roughness_value, 0.16, wet);
	SPECULAR = 0.5 + wet * 0.35;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color * fres * rim_strength + emission_color + vec3(hit_flash);
}
