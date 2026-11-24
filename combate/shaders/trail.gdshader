// Estela de golpe: cinta aditiva que se desvanece hacia la cola.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.6, 1.0);

void fragment() {
	float a = COLOR.a;
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = tint.rgb * a * across * 1.4;
}
