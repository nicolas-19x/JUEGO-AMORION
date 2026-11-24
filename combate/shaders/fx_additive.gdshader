// Partículas y anillos de impacto aditivos con color por vértice.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float ring = 0.0;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	float a;
	if (ring > 0.5) {
		a = smoothstep(1.0, 0.85, d) * smoothstep(0.55, 0.85, d);
	} else {
		a = smoothstep(1.0, 0.0, d);
		a *= a;
	}
	ALBEDO = tint.rgb * COLOR.rgb * a * COLOR.a * tint.a;
}
