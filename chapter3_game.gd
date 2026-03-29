extends Node3D

## 第三关：人体闪避 + 六个靶各有一把已扎稳的飞刀则过关。

signal all_chapter3_cleared

const _ANIM_RIGHT_HAND := &"右手闪避"
const _ANIM_RIGHT_FOOT := &"右脚闪避"
const _ANIM_RIGHT_LEG := &"右腿闪避"
const _ANIM_HEAD := &"头部闪避"
const _ANIM_BODY := &"身体闪避"
const _ANIM_RESET := &"RESET"

const _STUCK_KNIFE_NEAR_TARGET_METERS: float = 0.32

@export var dodge_preview_seconds: float = 0.8

@onready var _trigger_area: Area3D = $"%Human_Renderer/Human_Trigger/Area3D"
@onready var _animation_player: AnimationPlayer = $"%Human_Renderer/AnimationPlayer"
@onready var _mirror_root: Node3D = $"%Human_Renderer/Skeleton3D"
@onready var _wheel_target_nodes: Array[Node3D] = [
	$StaticBody3D2/Wheel/Node3D,
	$StaticBody3D2/Wheel/Node3D2,
	$StaticBody3D2/Wheel/Node3D3,
	$StaticBody3D2/Wheel/Node3D4,
	$StaticBody3D2/Wheel/Node3D5,
	$StaticBody3D2/Wheel/Node3D6,
]

var _abs_scale_x: float = 1.0
var _sign_scale_x: float = 1.0
var _knives_triggered: Dictionary = {}
var _preview_close_token: int = 0
var _completion_started: bool = false


func _ready() -> void:
	_abs_scale_x = absf(_mirror_root.scale.x)
	_sign_scale_x = signf(_mirror_root.scale.x)
	if _sign_scale_x == 0.0:
		_sign_scale_x = 1.0
	_trigger_area.part.connect(_on_human_hit_part)


func _process(_delta: float) -> void:
	if _completion_started:
		return
	if not _every_target_has_stuck_knife():
		return
	_completion_started = true
	all_chapter3_cleared.emit()


func _on_human_hit_part(body_part: StringName, knife: Node3D) -> void:
	var resolved: Variant = _resolve_hit(body_part)
	if resolved == null:
		return
	var knife_id: int = knife.get_instance_id()
	if _knives_triggered.has(knife_id):
		return
	_knives_triggered[knife_id] = true
	_start_or_extend_preview(resolved[0], resolved[1])


func _resolve_hit(body_part: StringName) -> Variant:
	match String(body_part):
		"右脚":
			return [_ANIM_RIGHT_FOOT, false]
		"右腿":
			return [_ANIM_RIGHT_LEG, false]
		"左脚":
			return [_ANIM_RIGHT_FOOT, true]
		"左腿":
			return [_ANIM_RIGHT_LEG, true]
		"髋", "左髋", "右髋", "胸":
			return [_ANIM_BODY, false]
		"头":
			return [_ANIM_HEAD, false]
		"右肩", "右臂", "右手":
			return [_ANIM_RIGHT_HAND, false]
		"左肩", "左臂", "左手":
			return [_ANIM_RIGHT_HAND, true]
		_:
			return null


func _apply_skeleton_mirror(mirror: bool) -> void:
	var flip: float = -1.0 if mirror else 1.0
	_mirror_root.scale.x = _abs_scale_x * _sign_scale_x * flip


func _start_or_extend_preview(anim: StringName, mirror: bool) -> void:
	_apply_skeleton_mirror(mirror)
	_animation_player.play(anim)
	_preview_close_token += 1
	var token: int = _preview_close_token
	await get_tree().create_timer(dodge_preview_seconds).timeout
	if token != _preview_close_token:
		return
	_animation_player.play(_ANIM_RESET)
	_apply_skeleton_mirror(false)
	_knives_triggered.clear()


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
