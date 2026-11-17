// Agua del océano y del lago. Se dibuja en coordenadas de píxel del mundo.
// `land_dist` guarda la distancia a tierra en celdas (/8), filtrada bilinealmente.
shader_type canvas_item;

uniform sampler2D land_dist : filter_linear, repeat_disable;
uniform vec2 map_px_size = vec2(896.0, 640.0);
uniform vec2 map_origin = vec2(0.0, 0.0);
uniform vec4 c_deepest : source_color = vec4(0.141, 0.30, 0.50, 1.0);
uniform vec4 c_deep : source_color = vec4(0.157, 0.36, 0.58, 1.0);
uniform vec4 c_mid : source_color = vec4(0.18, 0.43, 0.64, 1.0);
uniform vec4 c_shallow : source_color = vec4(0.184, 0.471, 0.651, 1.0);
uniform vec4 c_shore : source_color = vec4(0.29, 0.624, 0.753, 1.0);
uniform vec4 c_light : source_color = vec4(0.498, 0.784, 0.839, 1.0);
uniform vec4 c_foam : source_color = vec4(0.769, 0.925, 0.902, 1.0);
uniform vec4 c_spark : source_color = vec4(0.945, 0.984, 0.965, 1.0);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = floor(world);
	float t = TIME;
	vec2 uv = (p - map_origin + 0.5) / map_px_size;
	float d = texture(land_dist, uv).r * 8.0;
	// irregularidad orgánica de las bandas de profundidad
	float wob = vnoise(p * 0.06 + vec2(t * 0.05, 0.0)) * 0.9 - 0.45;
	float dd = d + wob;
	vec4 col = c_deepest;
	if (dd < 5.0) col = c_deep;
	if (dd < 3.2) col = c_mid;
	if (dd < 1.9) col = c_shallow;
	if (dd < 1.05) col = c_shore;
	// olas: trazos horizontales cortos que derivan lentamente
	float row = floor(p.y / 3.0);
	float lane = hash(vec2(row, 7.0));
	float sx = p.x + t * (6.0 + lane * 6.0) * (mod(row, 2.0) * 2.0 - 1.0);
	float dash = step(0.86, vnoise(vec2(sx * 0.11, row * 1.7)));
	if (dash > 0.5 && mod(p.y, 3.0) < 1.0 && d > 1.3) col = mix(col, c_light, 0.55);
	// espuma de orilla: anillos que respiran hacia fuera
	float ring = fract(d * 0.9 - t * 0.22);
	float wave_in = 0.5 + 0.5 * sin(t * 1.1 + (p.x + p.y) * 0.02);
	if (d < 0.5 + wave_in * 0.18) {
		col = c_foam;
	} else if (d < 2.2 && abs(ring - 0.5) < 0.06 + 0.03 * vnoise(p * 0.2)) {
		col = mix(col, c_foam, 0.7);
	} else if (d < 0.95 && hash(p + floor(t * 3.0)) > 0.93) {
		col = c_light;
	}
	// destellos
	vec2 cell = floor(p / 2.0);
	if (hash(cell + floor(t * 1.5)) > 0.9975 && d > 1.0) col = c_spark;
	COLOR = col;
}
