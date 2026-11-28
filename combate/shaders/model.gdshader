// Personaje importado (malla con color por vértice y esqueleto).
// · Color: COLOR.rgb (lineal, como en glTF); COLOR.a = 1 en piel (moretones) y 0 en ropa.
// · Daño en la posición de reposo de la malla (UV = xy, UV2.x = z): los golpes se quedan
//   pegados al cuerpo aunque se mueva.
shader_type spatial;

uniform float roughness_value : hint_range(0.0, 1.0) = 0.7;
uniform vec3 rim_color : source_color = vec3(1.0, 0.72, 0.5);
uniform float rim_strength = 0.22;
uniform vec4 marks[10];
uniform vec4 bloods[10];
uniform float mark_r = 0.075;
uniform float blood_on = 1.0;
uniform float sweat = 0.0;
// cara (posiciones de reposo, ver tools/model_prep.py)
uniform vec3 nose_p = vec3(0.0, 1.685, -0.119);
uniform vec3 mouth_p = vec3(0.0, 1.653, -0.114);
uniform vec3 brow_p = vec3(0.038, 1.719, -0.125);
uniform float nose_blood = 0.0;
uniform float lip_blood = 0.0;
uniform float cut_amount = 0.0;
uniform float cut_side = 1.0;
uniform float smear = 0.0;
uniform float swell_l = 0.0;
uniform float swell_r = 0.0;

varying vec3 rp;
varying float skin;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), u.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), u.x), u.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), u.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), u.x), u.y), u.z);
}

void vertex() {
	rp = vec3(UV.x, UV.y, UV2.x);
	skin = COLOR.a;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float wet = 0.0;
	// golpes: moretón en la piel, sangre empapando la ropa
	float b = 0.0;
	for (int i = 0; i < 10; i++) {
		float d = distance(rp, marks[i].xyz);
		float n = noise(rp * (9.0 / mark_r) + float(i) * 3.1) - 0.5;
		b = max(b, (1.0 - smoothstep(mark_r * 0.2, mark_r, d + n * mark_r * 0.45)) * marks[i].w);
	}
	if (skin > 0.5) {
		float l = dot(c, vec3(0.3, 0.55, 0.15));
		vec3 red = c * vec3(1.08, 0.58, 0.52);
		vec3 purple = vec3(0.36, 0.15, 0.26) * (0.7 + 0.5 * l);
		c = mix(c, mix(red, purple, smoothstep(0.55, 1.15, b)), clamp(b, 0.0, 0.85));
		float split = smoothstep(1.05, 1.35, b) * blood_on;
		c = mix(c, vec3(0.4, 0.02, 0.03), split * 0.8);
		wet = max(wet, split);
	} else {
		float s = smoothstep(0.38, 0.6, b) * blood_on;
		c = mix(c, vec3(0.3, 0.02, 0.03), s * 0.85);
		wet = max(wet, s * 0.45);
	}
	// cara: nariz, labio, ceja abierta, ojo hinchado y sangre extendida
	vec3 fp = rp - nose_p;
	float front = smoothstep(0.03, -0.02, fp.z);
	float near_face = 1.0 - smoothstep(0.09, 0.13, length(fp * vec3(1.0, 0.8, 1.0)));
	float w = (noise(vec3(rp.y * 60.0, 1.3, 2.1)) - 0.5) * 0.008;
	float top = nose_p.y - 0.008;
	float bot = top - nose_blood * 0.075;
	float sx = 1.0 - smoothstep(0.006, 0.012 + nose_blood * 0.006, abs(rp.x - nose_p.x + w) - 0.008);
	float sy = smoothstep(bot - 0.002, bot + 0.004, rp.y) * (1.0 - smoothstep(top, top + 0.006, rp.y));
	float nb = sx * sy * front * step(0.01, nose_blood);
	vec2 lq = vec2(rp.x - mouth_p.x - 0.014, (rp.y - mouth_p.y) * 1.6);
	float lip = (1.0 - smoothstep(0.004, 0.011, length(lq))) * front * lip_blood;
	float lip_drip = (1.0 - smoothstep(0.003, 0.007, abs(rp.x - mouth_p.x - 0.016 + w * 0.5)))
		* step(mouth_p.y - lip_blood * 0.05, rp.y) * step(rp.y, mouth_p.y) * front * step(0.01, lip_blood);
	vec2 cp = vec2(brow_p.x * cut_side, brow_p.y + 0.004);
	float line = (1.0 - smoothstep(0.0015, 0.004, abs(rp.y - cp.y - (rp.x - cp.x) * 0.3 * cut_side)))
		* (1.0 - smoothstep(0.012, 0.02, abs(rp.x - cp.x)));
	float tx = 1.0 - smoothstep(0.004, 0.009, abs(rp.x - cp.x - 0.006 * cut_side + w * 0.7));
	float ty = step(cp.y - cut_amount * 0.09, rp.y) * step(rp.y, cp.y);
	float cb = max(line * 1.2, tx * ty * 0.9) * front * step(0.01, cut_amount);
	float sm_n = noise(rp * 60.0 + vec3(3.0, 1.0, 7.0));
	float sm = (1.0 - smoothstep(-0.05, 0.08, sm_n - smear * 0.75)) * near_face * front * step(0.02, smear);
	float blood = clamp(max(max(max(nb, cb), max(lip, lip_drip)), sm) * 1.25, 0.0, 1.0) * blood_on * near_face;
	// ojo hinchado: piel amoratada alrededor del ojo golpeado
	for (int k = 0; k < 2; k++) {
		float sd = k == 0 ? -1.0 : 1.0;
		float sw = k == 0 ? swell_l : swell_r;
		vec3 e = rp - vec3(brow_p.x * sd, brow_p.y - 0.017, nose_p.z);
		float ring = (1.0 - smoothstep(0.008, 0.022, length(e.xy))) * front * sw;
		c = mix(c, vec3(0.34, 0.14, 0.24), clamp(ring, 0.0, 0.8) * skin);
	}
	c = mix(c, vec3(0.4, 0.0, 0.02), blood * 0.97);
	wet = max(wet, blood);
	// manchas de sangre (goteo, salpicaduras): los regueros caen
	float bl = 0.0;
	for (int i = 0; i < 10; i++) {
		vec3 dd = rp - bloods[i].xyz;
		dd.y = dd.y > 0.0 ? dd.y * 1.6 : dd.y * 0.45;
		float n2 = noise(rp * (14.0 / mark_r) + float(i) * 5.3) - 0.5;
		bl = max(bl, (1.0 - smoothstep(mark_r * 0.15, mark_r * 0.7, length(dd) + n2 * mark_r * 0.5)) * bloods[i].w);
	}
	bl = clamp(bl, 0.0, 1.0) * blood_on;
	c = mix(c, vec3(0.38, 0.0, 0.02), bl * 0.95);
	wet = max(wet, bl);
	wet = max(wet, sweat * 0.35 * skin);
	ALBEDO = c;
	ROUGHNESS = mix(roughness_value, 0.16, wet);
	SPECULAR = 0.5 + wet * 0.35;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color * fres * rim_strength;
}
