shader_type spatial;

render_mode unshaded;

#include "res://shaders/includes/vertex_distance_rotate.gdshaderinc"

/// 顶点绕「轴上一点」旋转；距轴心越近转角越小，衰减由 distance_power 控制（越大近处越“僵”）。

uniform vec3 rotation_axis = vec3(0.0, 1.0, 0.0);
/// 轴上的参考点（模型空间，与网格顶点同一空间）。
uniform vec3 axis_center_model = vec3(0.0, 0.0, 0.0);
/// 距离达到该半径时视为「满转角」权重 1（模型空间长度）。
uniform float influence_radius : hint_range(0.001, 100.0, 0.01) = 2.0;
/// 最大转角（度）。
uniform float max_angle_degrees : hint_range(-360.0, 360.0, 0.1) = 45.0;
/// 距离权重指数：>1 时近处转角更小；=1 线性；<1 近处相对更大。
uniform float distance_power : hint_range(0.05, 8.0, 0.01) = 2.0;

void vertex() {
	vec3 rotated_vertex = VERTEX;
	vec3 rotated_normal = NORMAL;
	vec3 rotated_tangent = TANGENT.xyz;
	apply_vertex_distance_rotation(
			rotated_vertex, rotated_normal, rotated_tangent,
			rotation_axis, axis_center_model,
			influence_radius, max_angle_degrees, distance_power);
	VERTEX = rotated_vertex;
	NORMAL = rotated_normal;
	TANGENT.xyz = rotated_tangent;
}

void fragment() {
	ALBEDO = vec3(0.85, 0.88, 0.92);
}
