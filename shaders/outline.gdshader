shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 ink : source_color = vec4(0.16, 0.07, 0.04, 1.0);
uniform float width = 0.022;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	VERTEX += NORMAL * (width / max(s, 0.0001));
}

void fragment() {
	ALBEDO = ink.rgb;
}
