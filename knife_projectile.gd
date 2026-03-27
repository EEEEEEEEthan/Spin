extends RigidBody3D

## 命中体的 collision_layer 与此掩码有交集时才扎住并 reparent。为 0 时保持旧行为：任意碰撞体均可扎住。
@export_flags_3d_physics var stick_collision_layer_mask: int = 0

## 接触点处两物体世界速度的相对速度模长 ≥ 此值才扎住（含角速度带来的线速度）。≤0 表示不限制。
@export var min_stick_relative_speed: float = 0.0

@onready var blade: CollisionShape3D = %Blade

var _stuck: bool = false


func _hit_allows_stick(hit_body: Node) -> bool:
	if stick_collision_layer_mask == 0:
		return true
	var collision_object := hit_body as CollisionObject3D
	if collision_object == null:
		return false
	return (collision_object.collision_layer & stick_collision_layer_mask) != 0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8


func _collision_shape_index(target: CollisionShape3D) -> int:
	var index := 0
	for child in get_children():
		if child is CollisionShape3D:
			if child == target:
				return index
			index += 1
	return 0


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _stuck:
		return
	var blade_index := _collision_shape_index(blade)
	for contact_index in state.get_contact_count():
		if state.get_contact_local_shape(contact_index) != blade_index:
			continue
		var hit_body := state.get_contact_collider_object(contact_index) as Node3D
		if hit_body == null or hit_body == self:
			continue
		if not _hit_allows_stick(hit_body):
			continue
		if min_stick_relative_speed > 0.0:
			var self_at_contact := state.get_contact_local_velocity_at_position(contact_index)
			var other_at_contact := state.get_contact_collider_velocity_at_position(contact_index)
			var relative_velocity := self_at_contact - other_at_contact
			if relative_velocity.length() < min_stick_relative_speed:
				continue
		_stuck = true
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		call_deferred("_reparent_to_hit", hit_body)
		break


func _reparent_to_hit(hit_body: Node3D) -> void:
	if not is_instance_valid(hit_body) or not is_inside_tree():
		return
	reparent(hit_body)
