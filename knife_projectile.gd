extends RigidBody3D

@onready var blade: CollisionShape3D = %Blade

var _stuck: bool = false


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
