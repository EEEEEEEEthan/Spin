extends Node3D

## 第四关：七个靶各有一把已扎稳的飞刀则过关。

signal all_chapter4_cleared

const _STUCK_KNIFE_NEAR_TARGET_METERS: float = 0.32

var _completion_started: bool = false

@onready var _wheel_target_nodes: Array[Node3D] = [
	$StaticBody3D2/Wheel/Node3D,
	$StaticBody3D2/Wheel/Node3D2,
	$StaticBody3D2/Wheel/Node3D3,
	$StaticBody3D2/Wheel/Node3D4,
	$StaticBody3D2/Wheel/Node3D5,
	$StaticBody3D2/Wheel/Node3D6,
	$StaticBody3D2/Wheel/StaticBody3D/Node3D7,
]


func _process(_delta: float) -> void:
	if _completion_started:
		return
	if not _every_target_has_stuck_knife():
		return
	_completion_started = true
	all_chapter4_cleared.emit()


func _every_target_has_stuck_knife() -> bool:
	for target_node in _wheel_target_nodes:
		if target_node == null:
			return false
		if not _target_has_stuck_knife(target_node):
			return false
	return true


func _target_has_stuck_knife(target_root: Node3D) -> bool:
	if _node_has_knife_projectile_descendant(target_root):
		return true
	var center: Vector3 = target_root.global_position
	for node in get_tree().get_nodes_in_group("knife_projectile"):
		var knife := node as RigidBody3D
		if knife == null or not knife.freeze:
			continue
		if knife.global_position.distance_to(center) <= _STUCK_KNIFE_NEAR_TARGET_METERS:
			return true
	return false


func _node_has_knife_projectile_descendant(root_node: Node) -> bool:
	for descendant in root_node.get_children():
		if descendant.is_in_group("knife_projectile"):
			return true
		if _node_has_knife_projectile_descendant(descendant):
			return true
	return false
