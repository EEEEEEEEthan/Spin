// 按距离衰减的绕轴旋转（模型空间）。由主 shader 声明同名 uniform 后调用。

vec3 vertex_distance_rotate_around_axis(vec3 vector, vec3 axis_unit, float angle_radians) {
	float cosine = cos(angle_radians);
	float sine = sin(angle_radians);
	return vector * cosine + cross(axis_unit, vector) * sine
			+ axis_unit * dot(axis_unit, vector) * (1.0 - cosine);
}

/// 就地修改 vertex / normal / tangent_xyz（tangent 仅 xyz，与 Godot TANGENT 一致）。
void apply_vertex_distance_rotation(
		inout vec3 vertex,
		inout vec3 normal,
		inout vec3 tangent_xyz,
		vec3 rotation_axis,
		vec3 axis_center_model,
		float influence_radius,
		float max_angle_degrees,
		float distance_power) {
	vec3 axis_unit = normalize(rotation_axis);
	vec3 offset = vertex - axis_center_model;
	float distance_from_center = length(offset);
	float normalized_distance = clamp(distance_from_center / influence_radius, 0.0, 1.0);
	float angle_weight = pow(normalized_distance, distance_power);
	float angle_radians = radians(max_angle_degrees) * angle_weight;

	vec3 rotated_offset = vertex_distance_rotate_around_axis(offset, axis_unit, angle_radians);
	vertex = rotated_offset + axis_center_model;
	normal = normalize(vertex_distance_rotate_around_axis(normal, axis_unit, angle_radians));
	tangent_xyz = normalize(vertex_distance_rotate_around_axis(tangent_xyz, axis_unit, angle_radians));
}
