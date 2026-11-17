// Balanceo suave de vegetación. Solo se mueve la parte superior del sprite,
// y el desplazamiento se cuantiza a píxeles enteros para respetar el pixel art.
shader_type canvas_item;

uniform float strength = 1.0;
uniform float speed = 1.3;
uniform float height_px = 16.0;

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float top = 1.0 - UV.y;
	float wave = sin(TIME * speed + world.x * 0.07 + world.y * 0.03)
			+ 0.4 * sin(TIME * speed * 2.3 + world.x * 0.13);
	VERTEX.x += floor(wave * strength * top * (height_px / 16.0) + 0.5);
}
