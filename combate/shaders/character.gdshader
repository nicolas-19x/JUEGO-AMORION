// Material de personaje: PBR suave con luz envolvente, sombra teñida y borde de luz.
// Estilizado semi-realista: superficies limpias tipo maniquí de esgrima/lacado.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec3 albedo : source_color = vec3(0.8);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.55;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform vec3 rim_color : source_color = vec3(1.0, 0.7, 0.45);
uniform float rim_power = 3.0;
uniform float rim_strength = 0.35;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float hit_flash = 0.0;

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color * fres * rim_strength + emission_color + vec3(hit_flash);
}
