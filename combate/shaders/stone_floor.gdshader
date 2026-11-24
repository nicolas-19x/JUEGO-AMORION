// Suelo de losas de piedra procedural: sin texturas, variación por losa, juntas y desgaste.
shader_type spatial;
render_mode diffuse_lambert_wrap;

uniform vec3 stone_a : source_color = vec3(0.47, 0.42, 0.40);
uniform vec3 stone_b : source_color = vec3(0.36, 0.33, 0.34);
uniform vec3 grout : source_color = vec3(0.16, 0.14, 0.15);
uniform float tile = 1.1;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz / tile;
	float row = floor(p.y);
	p.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float h = hash(cell);
	vec3 c = mix(stone_a, stone_b, h);
	float n = noise(wpos.xz * 3.0) * 0.6 + noise(wpos.xz * 11.0) * 0.4;
	c *= 0.86 + n * 0.22;
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float g = smoothstep(0.012, 0.035, edge);
	c = mix(grout, c, g);
	// desgaste central más pulido y claro
	float wear = smoothstep(5.5, 0.5, length(wpos.xz));
	c *= 1.0 + wear * 0.08;
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.62 - wear * 0.15, g);
}
