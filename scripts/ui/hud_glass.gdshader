shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

void fragment() {
	vec3 blurred = textureLod(screen_texture, SCREEN_UV, 1.5).rgb;
	float grain = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	float reflection = exp(-pow((UV.y - 0.18) * 5.0, 2.0));
	vec3 frost = blurred + vec3(0.10, 0.12, 0.13) * reflection + grain * 0.012;
	COLOR = vec4(frost, 0.30);
}
