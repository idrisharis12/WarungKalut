shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_tex = false;
uniform bool use_vcol = false;
uniform vec3 tint : source_color = vec3(1.0);

void fragment() {
	vec3 c = albedo.rgb * tint;
	if (use_tex) { c *= texture(albedo_tex, UV).rgb; }
	if (use_vcol) { c *= COLOR.rgb; }
	ALBEDO = c;
	ROUGHNESS = 1.0;
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float band = smoothstep(0.12, 0.2, nl) * 0.55 + smoothstep(0.55, 0.62, nl) * 0.45;
	DIFFUSE_LIGHT += LIGHT_COLOR * band * 0.9 / PI;
}
