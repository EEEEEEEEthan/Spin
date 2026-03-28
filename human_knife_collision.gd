extends Node3D

## 为 true 时骨骼含 layer3，飞刀可扎住；为 false 时仅保留 layer2，飞刀穿透但仍由 Area 报告击中。
@export var knife_physical_collision_enabled: bool = true:
	set(value):
		if knife_physical_collision_enabled == value:
			return
		knife_physical_collision_enabled = value
		if is_node_ready():
			_apply_knife_block_layers()

## 与人体环境碰撞相同的层（project 内骨骼原设为 layer2）。
const human_environment_collision_layer: int = 2
## 仅用于与飞刀产生物理接触的层，须与 knife 的 stick_collision_layer_mask 一致。
const human_knife_block_collision_layer: int = 4

@onready var _physical_bone_simulator: PhysicalBoneSimulator3D = $Skeleton3D/PhysicalBoneSimulator3D

var _physical_bones: Array[PhysicalBone3D] = []


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_tree_node_added)


func _exit_tree() -> void:
	var tree := get_tree()
	if tree.node_added.is_connected(_on_tree_node_added):
		tree.node_added.disconnect(_on_tree_node_added)


func _ready() -> void:
	_collect_physical_bones()
	_apply_knife_block_layers()
	for physical_bone in _physical_bones:
		_attach_knife_overlap_area(physical_bone)


func _on_tree_node_added(node: Node) -> void:
	if not (node is RigidBody3D):
		return
	call_deferred("_deferred_sync_if_knife", node)


func _deferred_sync_if_knife(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_in_group("knife_projectile"):
		return
	_sync_knife_collision_exceptions()


func _collect_physical_bones() -> void:
	_physical_bones.clear()
	if _physical_bone_simulator == null:
		return
	for child in _physical_bone_simulator.get_children():
		if child is PhysicalBone3D:
			_physical_bones.append(child)


func _apply_knife_block_layers() -> void:
	var target_layers: int
	if knife_physical_collision_enabled:
		target_layers = human_environment_collision_layer | human_knife_block_collision_layer
	else:
		target_layers = human_environment_collision_layer
	for physical_bone in _physical_bones:
		physical_bone.collision_layer = target_layers
	_sync_knife_collision_exceptions()


## 穿透时骨骼仍在 layer2（地面等），飞刀默认会撞 layer2，必须用例外消除刚体接触，速度才不会被吃掉。
func _sync_knife_collision_exceptions() -> void:
	if _physical_bones.is_empty():
		return
	var tree := get_tree()
	if tree == null:
		return
	for knife_node in tree.get_nodes_in_group("knife_projectile"):
		var knife_body := knife_node as PhysicsBody3D
		if knife_body == null:
			continue
		for physical_bone in _physical_bones:
			if knife_physical_collision_enabled:
				knife_body.remove_collision_exception_with(physical_bone)
			else:
				knife_body.add_collision_exception_with(physical_bone)


func _attach_knife_overlap_area(physical_bone: PhysicalBone3D) -> void:
	var overlap_area := Area3D.new()
	overlap_area.name = "KnifeOverlapArea"
	overlap_area.collision_layer = 0
	overlap_area.collision_mask = 1
	overlap_area.monitorable = false
	overlap_area.monitoring = true
	physical_bone.add_child(overlap_area)
	var shape_nodes: Array[CollisionShape3D] = []
	for child in physical_bone.get_children():
		if child is CollisionShape3D:
			shape_nodes.append(child)
	for collision_shape in shape_nodes:
		var duplicate_shape := CollisionShape3D.new()
		duplicate_shape.shape = collision_shape.shape
		duplicate_shape.transform = collision_shape.transform
		overlap_area.add_child(duplicate_shape)
	overlap_area.body_entered.connect(_on_overlap_body_entered.bind(physical_bone))


func _on_overlap_body_entered(hit_body: Node3D, physical_bone: PhysicalBone3D) -> void:
	if not hit_body.is_in_group("knife_projectile"):
		return
	var part_label: String = physical_bone.bone_name
	if part_label.is_empty():
		part_label = physical_bone.name
	if knife_physical_collision_enabled:
		print("飞刀击中了", part_label)
	else:
		print("飞刀击中了", part_label, "，但是穿透了")


func set_knife_physical_collision_enabled(enabled: bool) -> void:
	knife_physical_collision_enabled = enabled
