@tool
extends EditorScript
## 在编辑器中打开本脚本，菜单「文件 → 运行」执行。
## 当前编辑场景须为 Human.tscn（或含路径 Human/骨架/Skeleton3D 与 PhysicalBoneSimulator3D）。
## 会在 PhysicalBoneSimulator3D 下生成 PhysicalBone3D + CapsuleShape3D；重复运行会先删掉其下已有 PhysicalBone3D。
## 生成后请 Ctrl+S 保存场景。

const HUMAN_SKELETON_PATH := "Human/骨架/Skeleton3D"
const SIMULATOR_NODE_NAME := "PhysicalBoneSimulator3D"
## layer2 环境 + layer3(值4) 飞刀物理；与 knife stick_collision_layer_mask=4 对齐。human_knife_collision 关闭飞刀层时脚本会改为仅 layer2。
const TARGET_COLLISION_LAYER: int = 6


func _run() -> void:
	var editor_interface := get_editor_interface()
	var edited_root: Node = editor_interface.get_edited_scene_root()
	if edited_root == null:
		push_error("setup_human_physical_bones: 没有正在编辑的场景根节点。")
		return
	var skeleton: Skeleton3D = edited_root.get_node_or_null(HUMAN_SKELETON_PATH) as Skeleton3D
	if skeleton == null:
		skeleton = edited_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		push_error("setup_human_physical_bones: 未找到 Skeleton3D（试过路径 %s）。" % HUMAN_SKELETON_PATH)
		return
	var simulator: PhysicalBoneSimulator3D = skeleton.get_node_or_null(SIMULATOR_NODE_NAME) as PhysicalBoneSimulator3D
	if simulator == null:
		push_error("setup_human_physical_bones: 在 Skeleton3D 下未找到 %s。" % SIMULATOR_NODE_NAME)
		return
	_remove_existing_physical_bones(simulator)
	var bone_count: int = skeleton.get_bone_count()
	for bone_index in range(bone_count):
		_add_one_physical_bone(edited_root, skeleton, simulator, bone_index)
	push_warning("setup_human_physical_bones: 已生成 %d 根 PhysicalBone3D，请保存场景。" % bone_count)


func _remove_existing_physical_bones(simulator: PhysicalBoneSimulator3D) -> void:
	var to_free: Array[Node] = []
	for child in simulator.get_children():
		if child is PhysicalBone3D:
			to_free.append(child)
	for node in to_free:
		simulator.remove_child(node)
		node.free()


func _add_one_physical_bone(scene_root: Node, skeleton: Skeleton3D, simulator: PhysicalBoneSimulator3D, bone_index: int) -> void:
	var bone_length: float = _estimate_bone_length(skeleton, bone_index)
	var direction: Vector3 = _bone_tail_direction(skeleton, bone_index)
	var radius: float = clampf(bone_length * 0.14, 0.012, 0.14)
	var cylinder_height: float = maxf(bone_length - 2.0 * radius, 0.001)

	var physical_bone := PhysicalBone3D.new()
	var raw_name: String = skeleton.get_bone_name(bone_index)
	physical_bone.name = _safe_physical_bone_node_name(bone_index, raw_name)
	physical_bone.bone_name = raw_name
	physical_bone.collision_layer = TARGET_COLLISION_LAYER
	physical_bone.mass = clampf(bone_length * 0.4, 0.05, 0.35)

	var collision_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = cylinder_height
	collision_shape.shape = capsule
	var basis: Basis = _basis_from_y_axis(direction)
	var half_way: Vector3 = basis * Vector3(0.0, bone_length * 0.5, 0.0)
	collision_shape.transform = Transform3D(basis, half_way)

	# 必须先挂到场景树再设 owner，否则 scene_root 不是祖先会报 Invalid owner。
	simulator.add_child(physical_bone)
	physical_bone.owner = scene_root
	physical_bone.add_child(collision_shape)
	collision_shape.owner = scene_root


func _estimate_bone_length(skeleton: Skeleton3D, bone_index: int) -> float:
	var maximum_child_length: float = 0.0
	for child_index in range(skeleton.get_bone_count()):
		if skeleton.get_bone_parent(child_index) != bone_index:
			continue
		var child_rest: Transform3D = skeleton.get_bone_rest(child_index)
		maximum_child_length = maxf(maximum_child_length, child_rest.origin.length())
	if maximum_child_length > 0.0001:
		return maximum_child_length
	var parent_index: int = skeleton.get_bone_parent(bone_index)
	if parent_index >= 0:
		var to_joint: Vector3 = skeleton.get_bone_rest(bone_index).origin
		var from_parent: float = to_joint.length()
		if from_parent > 0.0001:
			return clampf(from_parent * 0.45, 0.03, 0.22)
	return 0.07


func _bone_tail_direction(skeleton: Skeleton3D, bone_index: int) -> Vector3:
	for child_index in range(skeleton.get_bone_count()):
		if skeleton.get_bone_parent(child_index) != bone_index:
			continue
		var child_rest: Transform3D = skeleton.get_bone_rest(child_index)
		var offset: Vector3 = child_rest.origin
		if offset.length_squared() > 1e-10:
			return offset.normalized()
	return Vector3.UP


func _basis_from_y_axis(y_direction: Vector3) -> Basis:
	var y_axis: Vector3 = y_direction.normalized()
	var reference: Vector3 = Vector3.RIGHT
	if absf(y_axis.dot(reference)) > 0.92:
		reference = Vector3.FORWARD
	var x_axis: Vector3 = reference.cross(y_axis)
	if x_axis.length_squared() < 1e-10:
		reference = Vector3.UP
		x_axis = reference.cross(y_axis)
	x_axis = x_axis.normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _safe_physical_bone_node_name(bone_index: int, bone_name_str: String) -> String:
	var safe: String = bone_name_str
	for character in [":", "/", "\\", "@"]:
		safe = safe.replace(character, "_")
	return "Phys3D_%d_%s" % [bone_index, safe]
