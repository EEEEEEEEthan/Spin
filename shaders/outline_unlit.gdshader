shader_type spatial;

// 无光照描边：基于视角与法线夹角（Fresnel / rim），非屏幕后处理轮廓。
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 fill_color : source_color = vec3(0.18, 0.2, 0.24);
uniform vec3 edge_color : source_color = vec3(1.0, 1.0, 1.0);
/// 越大，边缘色越早出现（描边越「厚」）。沿 rim 轴从掠射角向内计量。
uniform float hard_edge_width : hint_range(0.0, 1.0, 0.001) = 0.28;
/// 填充色到边缘色的渐变宽度（rim 轴 0–1）。为 0 时为硬切。
uniform float transition_width : hint_range(0.0, 1.0, 0.001) = 0.12;

void fragment() {
	vec3 normal_view = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);
	float ndotv = clamp(dot(normal_view, view_dir), 0.0, 1.0);
	float rim = 1.0 - ndotv;

	float upper = clamp(1.0 - hard_edge_width, 0.0, 1.0);
	float lower = clamp(upper - transition_width, 0.0, upper);

	float edge_mix;
	if (upper - lower < 1e-4) {
		edge_mix = step(upper, rim);
	} else {
		float aa = fwidth(rim);
		edge_mix = smoothstep(lower - aa, upper + aa, rim);
	}

	ALBEDO = mix(fill_color, edge_color, edge_mix);
}
