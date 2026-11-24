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
uniform vec4 bloods[6];
uniform float mark_r = 0.5;
uniform float blood_on = 1.0;
uniform float face_mode = 0.0;
uniform float nose_blood = 0.0;
uniform float lip_blood = 0.0;
uniform float cut_amount = 0.0;
uniform float cut_side = 1.0;
uniform float sweat = 0.0;
uniform float smear = 0.0;
// estilo de la pieza
uniform float hair_mode = 0.0;      // 1 pelo (casco que sigue el cráneo), 2 barba
uniform float wrap_mode = 0.0;      // 1 antebrazo (piel arriba, venda abajo), 2 puño vendado
uniform float wrap_start = 0.3;
uniform vec3 skin_color : source_color = vec3(0.7, 0.5, 0.4);
uniform float folds = 0.0;          // pliegues de tela
uniform float tear = 0.0;           // la tela se rompe donde se acumulan golpes
uniform float anat = 0.0;           // 1 pecho, 2 abdomen: musculatura marcada
uniform float shoe_mode = 0.0;
uniform vec3 sole_color : source_color = vec3(0.9, 0.88, 0.84);

varying vec3 lp;


float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), u.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), u.x), u.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), u.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), u.x), u.y), u.z);
}

float fold_h(vec2 uv, vec3 p) {
	float n = noise(p * 22.0);
	return sin(uv.y * 46.0 + n * 3.5 + sin(uv.x * 12.566) * 1.2) * (0.35 + 0.65 * noise(p * 9.0 + 4.0));
}


void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 c = albedo;
	float wet = 0.0;
	float is_skin = skin;
	// --- pelo y barba: recortados sobre el cráneo ---
	if (hair_mode > 0.5) {
		if (hair_mode < 1.5) {
			// línea del pelo: alta en la frente, entradas a los lados, patillas
			float hairline = 0.62 - 0.28 * abs(lp.x) + 0.05 * sin(lp.x * 18.0);
			bool face = lp.z < -0.05 && lp.y < hairline;
			bool side = abs(lp.x) > 0.5 && lp.y < 0.12 && lp.z < 0.22;
			bool nape = lp.y < -0.38 + 0.1 * abs(lp.x);
			if (face || side || nape) discard;
		} else {
			// barba corta: mandíbula, mentón y bigote
			bool jaw = lp.y < -0.12 - 0.1 * (1.0 - abs(lp.x)) && lp.z < 0.15;
			bool stache = abs(lp.x) < 0.32 && lp.y > -0.33 && lp.y < -0.2 && lp.z < -0.6;
			bool keep = jaw || stache;
			bool mouth = abs(lp.x) < 0.2 && lp.y > -0.46 && lp.y < -0.33 && lp.z < -0.55;
			bool cheek = false;
			if (!keep || mouth || cheek) discard;
		}
		float strand = noise(vec3(lp.x * 46.0, lp.y * 7.0, lp.z * 46.0));
		c *= 0.78 + 0.3 * strand;
	}
	// --- vendas: bandas cruzadas con costuras y bordes ---
	if (wrap_mode > 0.5) {
		bool wrapped = wrap_mode > 1.5 || UV.y > wrap_start;
		if (wrapped) {
			float band = fract(UV.y * 16.0 + UV.x * 2.0);
			float seam = smoothstep(0.0, 0.08, band) * smoothstep(1.0, 0.9, band);
			c *= 0.78 + 0.22 * seam;
			c *= 0.92 + 0.12 * noise(lp * 160.0);
			is_skin = 0.0;
		} else {
			c = skin_color;
			is_skin = 1.0;
			float edge = smoothstep(wrap_start - 0.05, wrap_start, UV.y);
			c *= 1.0 - 0.25 * edge;
		}
	}
	// --- pliegues de tela: relieve procedural ---
	if (folds > 0.0) {
		float e = 0.004;
		float h0 = fold_h(UV, lp);
		float hx = fold_h(UV + vec2(e, 0.0), lp);
		float hy = fold_h(UV + vec2(0.0, e), lp);
		vec2 grad = vec2(hx - h0, hy - h0) / e;
		NORMAL_MAP = normalize(vec3(-grad * 0.004 * folds, 1.0)) * 0.5 + 0.5;
		c *= 0.9 + 0.1 * h0;
	}
	// --- musculatura: surcos del esternón, pectorales, clavículas y abdominales ---
	if (anat > 0.5) {
		float front = smoothstep(-0.03, -0.08, lp.z);
		float g = 0.0;
		if (anat < 1.5) {
			g = max(g, (1.0 - smoothstep(0.0, 0.02, abs(lp.x))) * smoothstep(0.04, 0.08, lp.y) * smoothstep(0.28, 0.24, lp.y));
			float pec = 0.12 + 1.4 * lp.x * lp.x;
			g = max(g, (1.0 - smoothstep(0.0, 0.028, abs(lp.y - pec))) * smoothstep(0.18, 0.13, abs(lp.x)) * 0.9);
			float clav = 0.285 - 0.18 * abs(lp.x);
			g = max(g, (1.0 - smoothstep(0.0, 0.01, abs(lp.y - clav))) * step(0.025, abs(lp.x)) * step(abs(lp.x), 0.15) * 0.6);
		} else {
			g = max(g, (1.0 - smoothstep(0.0, 0.016, abs(lp.x))) * smoothstep(-0.06, -0.02, lp.y) * smoothstep(0.22, 0.18, lp.y) * 0.8);
			for (int k = 0; k < 3; k++) {
				float yy = 0.17 - float(k) * 0.07;
				g = max(g, (1.0 - smoothstep(0.0, 0.02, abs(lp.y - yy))) * smoothstep(0.085, 0.05, abs(lp.x)) * 0.55);
			}
			g = max(g, (1.0 - smoothstep(0.0, 0.015, abs(abs(lp.x) - 0.1 - lp.y * 0.12))) * step(lp.y, 0.12) * 0.5);
		}
		c *= 1.0 - 0.17 * g * front;
	}
	// --- zapatilla: suela clara y costura ---
	if (shoe_mode > 0.5) {
		if (lp.y < -0.083) c = sole_color;
		c *= 1.0 - 0.3 * (1.0 - smoothstep(0.0, 0.004, abs(lp.y + 0.079)));
	}
	float b = 0.0;
	for (int i = 0; i < 6; i++) {
		float d = distance(lp, marks[i].xyz);
		float n = noise(lp * (9.0 / mark_r) + float(i) * 3.1) - 0.5;
		float m = (1.0 - smoothstep(mark_r * 0.2, mark_r, d + n * mark_r * 0.45)) * marks[i].w;
		b = max(b, m);
	}
	if (is_skin > 0.5) {
		float l = dot(c, vec3(0.3, 0.55, 0.15));
		vec3 red = c * vec3(1.08, 0.58, 0.52);
		vec3 purple = vec3(0.36, 0.15, 0.26) * (0.7 + 0.5 * l);
		c = mix(c, mix(red, purple, smoothstep(0.55, 1.15, b)), clamp(b, 0.0, 0.85));
		// un golpe muy fuerte abre la piel: puntos de sangre en el centro del moretón
		float split = smoothstep(1.05, 1.35, b) * blood_on;
		c = mix(c, vec3(0.4, 0.02, 0.03), split * 0.8);
		wet = max(wet, split);
	} else {
		// la tela se rompe donde se acumulan golpes: deja ver la piel de debajo
		if (tear > 0.5) {
			float tn = noise(lp * 55.0) * 0.4;
			if (b > 0.95 + tn) discard;
			float fray = smoothstep(0.75 + tn, 0.95 + tn, b);
			c *= 1.0 - 0.45 * fray;
		}
		float s = smoothstep(0.38, 0.6, b) * blood_on;
		c = mix(c, vec3(0.32, 0.02, 0.03), s * 0.88);
		wet = max(wet, s * 0.45);
	}
	if (face_mode > 0.5) {
		float front = smoothstep(-0.35, -0.75, lp.z);
		// cuencas de los ojos en sombra, labios y mejillas con más color
		for (int k = 0; k < 2; k++) {
			float sx = k == 0 ? -1.0 : 1.0;
			vec3 dd = lp - vec3(sx * 0.36, 0.1, -0.9);
			c *= 1.0 - 0.28 * exp(-dot(dd, dd) / 0.03);
			vec3 ck = lp - vec3(sx * 0.55, -0.15, -0.75);
			c = mix(c, c * vec3(1.06, 0.88, 0.86), exp(-dot(ck, ck) / 0.05) * 0.6);
		}
		float lips = (1.0 - smoothstep(0.0, 0.045, abs(lp.y + 0.38))) * (1.0 - smoothstep(0.16, 0.24, abs(lp.x))) * front;
		c = mix(c, c * vec3(0.82, 0.58, 0.58), lips * 0.8);
		float mouth_line = (1.0 - smoothstep(0.0, 0.012, abs(lp.y + 0.375))) * (1.0 - smoothstep(0.14, 0.2, abs(lp.x))) * front;
		c *= 1.0 - 0.5 * mouth_line;
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
		// sangre extendida por la cara: crece con el castigo acumulado
		float sm_n = noise(lp * 6.5 + vec3(3.0, 1.0, 7.0));
		float sm = (1.0 - smoothstep(-0.05, 0.08, sm_n - smear * 0.75)) * smoothstep(0.25, -0.35, lp.y)
			* smoothstep(-0.1, -0.55, lp.z) * step(0.02, smear);
		float blood = clamp(max(max(max(nb, cb), max(lip, lip_drip)), sm) * 1.25, 0.0, 1.0) * blood_on;
		c = mix(c, vec3(0.4, 0.0, 0.02), blood * 0.97);
		wet = max(wet, blood);
	}
	// manchas de sangre sobre cualquier pieza (goteo, salpicaduras ajenas)
	float bl = 0.0;
	for (int i = 0; i < 6; i++) {
		vec3 dd = lp - bloods[i].xyz;
		// los regueros caen: la mancha se alarga hacia abajo
		dd.y = dd.y > 0.0 ? dd.y * 1.6 : dd.y * 0.45;
		float n2 = noise(lp * (14.0 / mark_r) + float(i) * 5.3) - 0.5;
		bl = max(bl, (1.0 - smoothstep(mark_r * 0.15, mark_r * 0.7, length(dd) + n2 * mark_r * 0.5)) * bloods[i].w);
	}
	bl = clamp(bl, 0.0, 1.0) * blood_on;
	c = mix(c, vec3(0.38, 0.0, 0.02), bl * 0.95);
	wet = max(wet, bl);
	wet = max(wet, sweat * 0.35);
	ALBEDO = c;
	ROUGHNESS = mix(roughness_value, 0.16, wet);
	SPECULAR = 0.5 + wet * 0.35;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color * fres * rim_strength + emission_color + vec3(hit_flash);
}
