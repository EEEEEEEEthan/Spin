extends Node3D

## 第四关：七个靶各有一把已扎稳的飞刀则过关。

signal all_chapter4_cleared

const _BLOOD_SCENE: PackedScene = preload("res://Blood.tscn")
const _KNIFE_BLOOD_LOCAL_POSITION: Vector3 = Vector3(0.0, -0.12, 0.0)
const _STUCK_KNIFE_NEAR_TARGET_METERS: float = 0.32
## Human_Collider/StaticBody3D 下 CollisionShape 顺序：0 髋、1 胸、2 头…
const _HUMAN_HEAD_COLLIDER_SHAPE_INDEX: int = 2

var _completion_started: bool = false
var _head_shot: bool = false

@onready var _player_name_label: Label3D = %Label3D
@onready var _human_renderer: HumanRenderer = $StaticBody3D2/Wheel/Human
@onready var _human_hit_static_body: StaticBody3D = $StaticBody3D2/Wheel/Human/Human_Collider/StaticBody3D

@onready var _wheel_target_nodes: Array[Node3D] = [
	$StaticBody3D2/Wheel/Node3D,
	$StaticBody3D2/Wheel/Node3D2,
	$StaticBody3D2/Wheel/Node3D3,
	$StaticBody3D2/Wheel/Node3D4,
	$StaticBody3D2/Wheel/Node3D5,
	$StaticBody3D2/Wheel/Node3D6,
	$StaticBody3D2/Wheel/StaticBody3D/Node3D7,
]


func _ready() -> void:
	if PlayerSession.display_name != "":
		_player_name_label.text = PlayerSession.display_name
	get_tree().node_added.connect(_on_tree_node_added)
	for node in get_tree().get_nodes_in_group("knife_projectile"):
		_connect_knife_stuck(node)


func _on_tree_node_added(node: Node) -> void:
	if node.has_signal(&"knife_stuck"):
		_connect_knife_stuck(node)


func _connect_knife_stuck(node: Node) -> void:
	var rigid := node as RigidBody3D
	if rigid == null:
		return
	var stuck_handler: Callable = _on_knife_stuck.bind(rigid)
	if not rigid.knife_stuck.is_connected(stuck_handler):
		rigid.knife_stuck.connect(stuck_handler)


func _on_knife_stuck(hit_body: Node3D, collider_shape_index: int, knife: RigidBody3D) -> void:
	if hit_body != _human_hit_static_body:
		return
	PlayerSession.register_human_hit(knife)
	_spawn_blood_on_knife(knife)
	if collider_shape_index != _HUMAN_HEAD_COLLIDER_SHAPE_INDEX:
		return
	_head_shot = true
	_human_renderer.apply_emoji_dead()


func _spawn_blood_on_knife(knife: RigidBody3D) -> void:
	var blood_particles := _BLOOD_SCENE.instantiate() as GPUParticles3D
	knife.add_child(blood_particles)
	blood_particles.position = _KNIFE_BLOOD_LOCAL_POSITION
	blood_particles.one_shot = false
	blood_particles.emitting = true
	blood_particles.restart()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		if _head_shot:
			_human_renderer.apply_emoji_dead()
		else:
			_human_renderer.apply_random_emoji_one_to_four()


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
