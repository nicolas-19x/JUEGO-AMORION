// Intercambio de paleta para las capas del personaje.
// La textura base guarda el índice del tono (0..4) en el canal R (índice*50).
// `ramp` es una textura de 5x1 con la rampa de color elegida.
shader_type canvas_item;

uniform sampler2D ramp : filter_nearest, repeat_disable;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float idx = floor(src.r * 255.0 / 50.0 + 0.5);
	vec4 col = texture(ramp, vec2((idx + 0.5) / 5.0, 0.5));
	COLOR = vec4(col.rgb, src.a * col.a) * COLOR;
}
