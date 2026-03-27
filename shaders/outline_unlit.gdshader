shader_type spatial;

// 无光照描边：顶点沿模型空间法线外扩，配合 cull_front 形成轮廓壳（非 Fresnel）。
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec3 outline_color : source_color = vec3(0.08, 0.09, 0.11);
/// 外扩距离（模型空间）。需单独 MeshInstance 材质层或复制网格做描边 pass。
uniform float outline_width : hint_range(0.0, 0.2, 0.0001) = 0.012;

void vertex() {
	VERTEX += normalize(NORMAL) * outline_width;
}

void fragment() {
	ALBEDO = outline_color;
}
