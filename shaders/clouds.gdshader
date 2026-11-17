// Sombras de nubes que cruzan la isla muy despacio. Sutil: nunca tapa el escenario.
shader_type canvas_item;

uniform float opacity = 0.16;
uniform vec4 tint : source_color = vec4(0.09, 0.07, 0.2, 1.0);
uniform vec2 wind = vec2(4.0, 1.5);

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
	vec2 p = floor(world) - wind * TIME;
	float n = vnoise(p * 0.008) * 0.65 + vnoise(p * 0.02) * 0.35;
	float a = step(0.62, n);
	// borde punteado (dither) para una transición suave sin degradado
	float edge = step(0.58, n) * step(0.5, fract((floor(world.x) + floor(world.y)) * 0.5));
	COLOR = vec4(tint.rgb, max(a, edge) * opacity);
}
