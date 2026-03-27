shader_type spatial;

#include "res://shaders/includes/vertex_distance_rotate.gdshaderinc"

// 与 outline_unlit 相同：先按距离旋转，再沿法线外扩，cull_front 形成轮廓壳。
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec3 rotation_axis = vec3(0.0, 1.0, 0.0);
uniform vec3 axis_center_model = vec3(0.0, 0.0, 0.0);
uniform float influence_radius : hint_range(0.001, 100.0, 0.01) = 2.0;
uniform float max_angle_degrees : hint_range(-360.0, 360.0, 0.1) = 45.0;
uniform float distance_power : hint_range(0.05, 8.0, 0.01) = 2.0;

uniform vec3 outline_color : source_color = vec3(0.08, 0.09, 0.11);
uniform float outline_width : hint_range(0.0, 0.2, 0.0001) = 0.012;

void vertex() {
	vec3 rotated_vertex = VERTEX;
	vec3 rotated_normal = NORMAL;
	vec3 rotated_tangent = TANGENT.xyz;
	apply_vertex_distance_rotation(
			rotated_vertex, rotated_normal, rotated_tangent,
			rotation_axis, axis_center_model,
			influence_radius, max_angle_degrees, distance_power);
	VERTEX = rotated_vertex + normalize(rotated_normal) * outline_width;
	NORMAL = rotated_normal;
	TANGENT.xyz = rotated_tangent;
}

void fragment() {
	ALBEDO = outline_color;
}
