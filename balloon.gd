extends RigidBody3D

@onready var balloon_visual: Node3D = $Balloon
@onready var explode_effect: MeshInstance3D = %Explode


func _ready() -> void:
	add_to_group("balloon")


func explode() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	collision_layer = 0
	collision_mask = 0
	balloon_visual.hide()
	explode_effect.show()
	await get_tree().create_timer(0.2).timeout
	queue_free()
